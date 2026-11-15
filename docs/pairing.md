# Pairing: two browsers, no server

How two devices connect in the Web build (GDD §9.4), and what was measured while building it (#7). The transport itself is described in [networking.md](networking.md#the-web-build-webrtc-with-pairing-codes).

## How players pair

1. One player taps **Host a game** and allows the camera. Their device shows a QR code: the *offer*.
2. The other player taps **Join a game**, allows the camera, and reads the offer with **Scan code** (camera) or **Enter code** (paste the text code, e.g. sent through a messenger). Their device then shows its own QR code: the *answer*.
3. The host reads the answer with **Scan answer** or **Enter answer**, and the devices connect.

The camera is asked for on both devices, even for text codes, because browsers only put a device's real addresses into its code while the page uses the camera or may use it ([see below](#connecting-in-a-real-network)). It stays on until the device's code is made. A player who declines can still pair; if the connection then fails, the message suggests allowing the camera.

Both devices must be in the same network, and the network must let devices reach each other: guest Wi-Fi with client isolation does not work. There is no STUN or TURN server, so nothing leaves the local network.

Without a second device, the first step also offers a match against the computer, in either role (see the README, *Offline match against the computer*).

Until the lobby (#20) has its own pairing, the [PairingPanel](../ui/pairing/pairing_panel.gd) in the lobby placeholder does this. Once connected, it shrinks to a line with the round trip time of a ping through Godot's multiplayer API.

## The pairing code

A [PairingCode](../services/network/pairing_code.gd) carries one WebRTC session description with all of its ICE candidates written in, so one code per direction is enough.

- **Trimmed:** TCP candidates are left out (the browser only makes *active* ones, which cannot meet each other), as are the optional extensions at the end of each candidate and two session lines a data channel does not use (`a=extmap-allow-mixed`, `a=msid-semantic`).
- **Packed:** format version, kind (offer or answer), the host's session id, a 4-byte checksum (SHA-256), then the description compressed with Deflate.
- **Written as Base32** (A–Z, 2–7). Every character is in the QR code's alphanumeric mode, and the text survives messengers: case, spaces, dashes and line breaks are ignored when it is read back.

A code is refused with a reason when it is not a code, is damaged or cut off, comes from another game version, is the wrong kind (an offer where an answer is expected, or the other way round), or is an answer to another host's offer.

## Browser side

Godot cannot use the camera on the Web, has no QR support, and its text fields do not open the keyboard on phones while the export's experimental virtual keyboard is off. So [pairing.js](../web/pairing.js) does these parts in plain HTML laid over the game:

- **QR codes** are made with qrcode-generator and drawn by Godot, one pixel per module, scaled without filtering.
- **Scanning** shows the camera (the rear one on phones) with a Cancel button and searches every frame for a code with jsQR, at most 960 px on the long side.
- **Copy** uses the browser's clipboard API. If the browser refuses, the code is shown in a field to copy by hand.
- **Enter** shows a field to paste or type into, with a Paste button where the browser offers clipboard reading.

The libraries ship with the game; see [web/vendor/README.md](../web/vendor/README.md).

- **The camera for addresses** (see below) is opened with the scanner's settings and kept on until GDScript releases it once the code is made. The scanner uses it if it is still on, so a phone opens its camera only once.

**Clipboard from GDScript** was not used. Godot 4.7.2's Web `clipboard_get()` starts an asynchronous read and returns the text it cached before, so it lags one call behind; `clipboard_set()` gives no result back (see `platform/web/display_server_web.cpp`). Both work better in JavaScript, where the result of the clipboard API is known.

## Connecting in a real network

Pairing between two Windows PCs on a phone's hotspot (Chrome and Firefox) failed with *Not connected* or *Connecting took too long* (#56). A guest page that logged the WebRTC state and statistics showed two separate causes.

### Hidden addresses

- Unless the page may use the camera or microphone, Chrome and Firefox write a random `<uuid>.local` name (mDNS) into each candidate instead of the device's address. The other device has to resolve that name through multicast DNS.
- In that network, it could not: the guest got no usable candidate for the host, and the host none for the guest. With the host's real address written into the same code, the connection checks succeeded within a second, in both directions and through both Windows firewalls.
- **Chrome** shows real addresses while the page has the camera or microphone permission (also a one-time one).
- **Firefox** shows them only while the page is using the camera or microphone, or if the permission was saved with *Remember this decision* (`MediaManager::IsActivelyCapturingOrHasAPermission`, checked when the browser starts looking for addresses).
- So **Host** and **Join** turn the camera on, and it stays on until the device's code is made. A code with real addresses is longer, because it lists every interface (see the table below).

### Who starts the encryption

- After the connection checks, the two devices set up encryption (DTLS). By default the answering device, the guest, starts it (`a=setup:active` in its answer) as soon as its checks succeed, which can be long before the host has read the answer.
- Chrome keeps such early handshake messages and uses them once the answer is in (libwebrtc `dtls_transport.cc`, `cached_client_hello_`). Firefox as host did not: the guest's next retry came late, and the host gave up after 15 s.
- The guest now answers with `a=setup:passive` ([RFC 5763](https://www.rfc-editor.org/rfc/rfc5763#section-5) lets the answering side choose), so the host starts the handshake the moment it reads the answer. After reading the answer, the host now waits 30 s for the connection instead of 15 s.

## Measurements

Chrome 157 on Windows 11, two separate browser instances on one PC, run headless and scripted against the debug Web build (`tools/export_web.sh --debug`).

### Code size

| Situation | Candidates | Code (characters) | QR code |
|:--|:-:|:-:|:-:|
| Before trimming, camera allowed | 14 (7 interfaces × UDP and TCP) | 1,210 | 97 × 97 (version 20) |
| Trimmed, camera allowed | 7 | 836 | 81 × 81 (version 16) |
| Trimmed, no camera permission | 1 | 637 | 73 × 73 (version 14) |

All QR codes use error correction level L.

- Chrome hides the device's addresses behind random `<uuid>.local` names (mDNS) and offers a single candidate, **unless the page was allowed to use the camera**: then it lists every interface with its real address. This PC has seven (Hyper-V and WSL adapters, the LAN, IPv6). A phone has fewer.
- The description itself (fingerprint, ICE credentials, session line) accounts for most of a code: compressed it shrinks to about 75 %, and Base32 adds 60 %. A code is about 1.2 times as long as the trimmed description.
- If real devices cannot scan codes of this size reliably, the next step is a format with only the parts that change (ICE credentials, fingerprint, candidates), with the rest rebuilt on the other device: about 150–200 characters, a QR code of about 41 × 41 to 49 × 49.

### Scanning

Chrome's fake camera played a video of the host's offer (73 × 73 modules) at several sizes in a 1280 × 720 frame. The guest read it and made its answer every time:

| QR code in the frame | Pixels per module after scaling to 960 px | Result |
|:-:|:-:|:--|
| 600 px | 5.6 | read |
| 400 px | 3.7 | read |
| 300 px | 2.8 | read |
| 250 px | 2.3 | read |
| 200 px | 1.9 | read |

These are clean synthetic frames. A real camera adds blur, glare and moiré, so this only shows that the pipeline works (camera → jsQR → code → answer); real devices decide whether the size is a problem.

### Connection

- The offer is ready about 0.4 s after **Host a game** (gathering finishes quickly without STUN).
- Text codes: offer and answer exchanged, connected, session with roles started on both devices; the ping round trip was 35 ms (headless, software rendering).
- The host read the answer 45 s after the guest made it: still connected. A human scanning in between is no problem.
- With the camera step and the passive answer (#56, fake cameras): both codes had seven real addresses and no `.local` name; the guest scanned the offer with the camera that was still on; the host read the answer 90 s after the guest made it and connected 83 ms later, as DTLS client, with the guest as DTLS server. Both cameras were off once their codes were made.
- When the guest closed its browser, the host showed *The other player left the session* within 15 s.
- Refused codes (random text, the host's own offer, an offer cut in half) were explained on screen; a denied camera too.
- The only host any page contacted was the one serving the game.

### Devices

| Pairing | Text codes | QR codes | Notes |
|:--|:-:|:-:|:--|
| Chrome ↔ Chrome, Windows (two instances, one PC) | ✅ | ✅ (fake camera) | Automated, see above |
| Firefox (PC) ↔ Android Chrome | pending | pending | To be tested by the team |
| Firefox (PC) ↔ Chrome (PC), phone hotspot | failed before #56; pending | pending | The network from [Connecting in a real network](#connecting-in-a-real-network) |
| Safari (macOS, iOS) | not tested | not tested | No device available |

## Testing on devices

The game starts only in a *secure context*: `https://`, `localhost`, or an address the browser was told to treat as secure. Godot 4.7.2's web loader refuses to start without one, with or without threads ([`Engine.getMissingFeatures()`](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/js/engine/features.js#L90)). The page then shows only "Secure Context - Check web server configuration (use HTTPS)". Camera and clipboard need a secure context as well.

- **Deployed build:** the GitHub Pages URL is HTTPS. Use it once the change is on `main`.
- **Before merging:** download the pull request's `web-build` artifact (or run `tools/export_web.sh`), serve it with `tools/serve_web.sh --lan`, and open `http://localhost:8060` on the computer that serves it. Another device can open `http://<computer's address>:8060` only after its browser treats that address as secure:
  - **Chrome** (also on Android): add the address under `chrome://flags/#unsafely-treat-insecure-origin-as-secure`, then restart Chrome.
  - **Firefox:** set `dom.securecontext.allowlist` in `about:config` to the computer's address, without the port; separate several with commas. The setting is in Firefox's source ([`nsMixedContentBlocker::IsPotentiallyTrustworthyOrigin`](https://hg.mozilla.org/mozilla-central/file/d8bafdec3ad5c530e76809804fefa9cf90ada931/dom/security/nsMixedContentBlocker.cpp#l307), which decides `window.isSecureContext`). Mozilla's documentation doesn't mention it, and it hasn't been tried with this game yet. `media.devices.insecure.enabled` and `media.getusermedia.insecure.enabled` only allow the camera; they don't make the page a secure context.
  - Without such a setting the device shows only Godot's error, and nothing can be tested there.

## Known limits

- Safari is untested.
- The connection needs a network in which the devices reach each other directly; there is no fallback through a server.
- Without the camera, a code holds only a hidden `.local` name, and pairing works only where the network resolves it (multicast DNS).
- On a phone held upright, the Godot screens (including this one) are drawn small, because the 1280 × 720 base view is fitted to the screen's width. The HTML parts (camera, fields) are not affected. Layout for phones is part of the lobby (#20) and the art pass (#22).
- A guest that never gets read by the host waits until its player cancels.
