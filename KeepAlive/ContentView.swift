import SwiftUI

struct ContentView: View {
    @StateObject private var engine = KeepAliveEngine()

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("KeepAlive")
                .font(.largeTitle.bold())

            Button {
                engine.isRunning ? engine.stop() : engine.start()
            } label: {
                Text(engine.isRunning ? "Stop" : "Start")
                    .font(.title2.bold())
                    .frame(width: 180, height: 180)
                    .foregroundColor(.white)
                    .background(Circle().fill(engine.isRunning ? Color.green : Color.gray))
            }

            Text(engine.status)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: 8) {
                Text("Ping every")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Picker("Ping every", selection: $engine.interval) {
                    ForEach([30, 60, 120, 180], id: \.self) { s in
                        Text("\(s)s").tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 32)

            if engine.pings > 0, let last = engine.lastPing {
                Text("Pings sent: \(engine.pings), last at \(last.formatted(date: .omitted, time: .standard))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Longer interval = less battery. Start with 60s, raise it if notifications are still on time.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
                .padding(.bottom)
        }
    }
}
