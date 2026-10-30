# KeepAlive

A tiny personal-use iPhone app that keeps the cellular data session from going idle while the screen is off.

**How it works**
- Loops an 8 kHz silent audio clip so iOS keeps the app running in the background. It mixes with other audio, so Spotify and calls are not affected.
- While on cellular (never on Wi-Fi), sends one ~100 byte request to apple.com every 30/60/120/180 seconds (you choose).

**Honest limits**
- This is a workaround. It keeps the data path warm; it does not fix whatever your carrier or 5G idle mode is doing.
- Incoming calls rely on carrier paging, not on app data, so this may not speed up calls. Test it.
- It uses a small amount of extra battery. Use the longest interval that still gives on-time notifications.
- Not for the App Store (Apple rejects keep-alive apps). Personal sideloading only.

## Build it without a Mac (free)

1. Create a free account at github.com and make a **new public repository** (public repos get free macOS build minutes).
2. Upload everything in this folder to the repo, **including the hidden `.github` folder**. Easiest: on the repo page choose *Add file → Upload files* and drag the whole folder contents in. If `.github` won't drag, use *Add file → Create new file*, type `.github/workflows/build.yml` as the name and paste the file's contents.
3. Open the **Actions** tab → **Build IPA** → **Run workflow**. Wait about 3-5 minutes.
4. Open the finished run and download the **KeepAlive-ipa** artifact. Unzip it to get `KeepAlive.ipa`.

If the build fails, open the failed run, copy the red error text and send it to me.

## Install on your iPhone (Windows or Mac, free Apple ID)

The IPA is unsigned, so a sideloading tool signs it with your own Apple ID.

- **Sideloadly** (sideloadly.io) on Windows or Mac. On Windows, install iTunes and iCloud from apple.com (not the Microsoft Store versions) first. Plug in the iPhone, drag in `KeepAlive.ipa`, enter your Apple ID, click Start.
- Or **AltStore** (altstore.io).

Then on the iPhone:
1. Settings → Privacy & Security → **Developer Mode** → On (restart).
2. Settings → General → VPN & Device Management → trust your Apple ID.
3. Open KeepAlive, tap **Start**, and leave it running. Do not swipe it away from the app switcher.

A free Apple ID signature lasts **7 days**. Re-install with Sideloadly weekly (Sideloadly can auto-refresh while your PC is on).

## Test whether it helps

Turn on Start, lock the phone for 10+ minutes, and have someone message you on an app and call you on cellular. Try 60s first, then 120s or 180s to save battery.
