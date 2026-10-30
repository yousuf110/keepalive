import AVFoundation
import Network
import SwiftUI

/// Keeps the app alive in the background with a looping silent audio clip
/// (the only thing iOS allows for a normal app), and sends one tiny request
/// every N seconds, but ONLY while the phone is on cellular. This keeps the
/// cellular data session from going idle.
///
/// Battery notes:
///  - 8 kHz mono silent clip: the cheapest possible audio stream.
///  - `.mixWithOthers`: never interrupts or ducks Spotify and other apps.
///  - Timer has generous leeway so iOS can batch it with other wake-ups.
///  - No ping at all while on Wi-Fi.
///  - Each ping is a ~100 byte request to apple.com.
final class KeepAliveEngine: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Off"
    @Published private(set) var pings = 0
    @Published private(set) var lastPing: Date?

    /// Seconds between pings (30 / 60 / 120 / 180). Saved between launches.
    @Published var interval: Int {
        didSet {
            UserDefaults.standard.set(interval, forKey: "interval")
            if isRunning { scheduleTimer() }
        }
    }

    private var player: AVAudioPlayer?
    private var timer: DispatchSourceTimer?
    private let monitor = NWPathMonitor()
    private var onCellular = false
    private let session: URLSession
    private let url = URL(string: "https://www.apple.com/library/test/success.html")!

    init() {
        let saved = UserDefaults.standard.integer(forKey: "interval")
        interval = saved == 0 ? 60 : saved

        let cfg = URLSessionConfiguration.ephemeral
        cfg.allowsCellularAccess = true
        cfg.timeoutIntervalForRequest = 15
        cfg.waitsForConnectivity = false
        session = URLSession(configuration: cfg)

        monitor.pathUpdateHandler = { [weak self] path in
            let cell = path.status == .satisfied
                && path.usesInterfaceType(.cellular)
                && !path.usesInterfaceType(.wifi)
            DispatchQueue.main.async {
                self?.onCellular = cell
                self?.refreshStatus()
            }
        }
        monitor.start(queue: DispatchQueue(label: "keepalive.network"))

        // Resume audio after a phone call, Siri, alarm, etc.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self, self.isRunning,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            self.resumeAudio()
        }

        // iOS occasionally resets the media services; rebuild if it does.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            self.player = nil
            self.resumeAudio()
        }
    }

    // MARK: - Start / stop

    func start() {
        guard !isRunning else { return }
        guard startAudio() else {
            status = "Could not start audio"
            return
        }
        isRunning = true
        scheduleTimer()
        refreshStatus()
        ping() // first one right away
    }

    func stop() {
        timer?.cancel()
        timer = nil
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
        status = "Off"
    }

    // MARK: - Audio

    private func startAudio() -> Bool {
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try s.setActive(true)
            if player == nil {
                let p = try AVAudioPlayer(data: Self.silentWAV())
                p.numberOfLoops = -1
                p.prepareToPlay()
                player = p
            }
            return player?.play() ?? false
        } catch {
            return false
        }
    }

    private func resumeAudio() {
        if !startAudio() {
            status = "Audio stopped, tap Stop then Start"
        }
    }

    /// One second of silence, 8 kHz, mono, 16-bit, built in memory (no asset file needed).
    private static func silentWAV(seconds: Int = 1, sampleRate: Int = 8000) -> Data {
        let dataSize = seconds * sampleRate * 2
        var d = Data()
        func u32(_ v: UInt32) { d.append(contentsOf: withUnsafeBytes(of: v.littleEndian) { Array($0) }) }
        func u16(_ v: UInt16) { d.append(contentsOf: withUnsafeBytes(of: v.littleEndian) { Array($0) }) }
        d.append(contentsOf: Array("RIFF".utf8))
        u32(UInt32(36 + dataSize))
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8))
        u32(16)                        // fmt chunk size
        u16(1)                         // PCM
        u16(1)                         // mono
        u32(UInt32(sampleRate))
        u32(UInt32(sampleRate * 2))    // byte rate
        u16(2)                         // block align
        u16(16)                        // bits per sample
        d.append(contentsOf: Array("data".utf8))
        u32(UInt32(dataSize))
        d.append(Data(count: dataSize)) // zeros = silence
        return d
    }

    // MARK: - Network ping

    private func scheduleTimer() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(
            deadline: .now() + .seconds(interval),
            repeating: .seconds(interval),
            leeway: .seconds(max(5, interval / 4))
        )
        t.setEventHandler { [weak self] in self?.ping() }
        t.resume()
        timer = t
    }

    private func ping() {
        guard isRunning, onCellular else { return }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        session.dataTask(with: req) { [weak self] _, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if error == nil {
                    self.pings += 1
                    self.lastPing = Date()
                }
                self.refreshStatus()
            }
        }.resume()
    }

    private func refreshStatus() {
        guard isRunning else { status = "Off"; return }
        status = onCellular
            ? "Running, keeping cellular active"
            : "Running, idle on Wi-Fi (pings only on cellular)"
    }
}
