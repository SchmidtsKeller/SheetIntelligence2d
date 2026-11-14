# Pairing: two browsers, no server

How two devices connect in the Web build (GDD §9.4), and what was measured while building it (#7). The transport itself is described in [networking.md](networking.md#the-web-build-webrtc-with-pairing-codes).

## How players pair

1. One player taps **Host a game**. Their device shows a QR code: the *offer*.
2. The other player taps **Join a game** and reads the offer with **Scan code** (camera) or **Enter code** (paste the text code, e.g. sent through a messenger). Their device then shows its own QR code: the *answer*.
3. The host reads the answer with **Scan answer** or **Enter answer**, and the devices connect.

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

**Clipboard from GDScript** was not used. Godot 4.7.2's Web `clipboard_get()` starts an asynchronous read and returns the text it cached before, so it lags one call behind; `clipboard_set()` gives no result back (see `platform/web/display_server_web.cpp`). Both work better in JavaScript, where the result of the clipboard API is known.

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
- When the guest closed its browser, the host showed *The other player left the session* within 15 s.
- Refused codes (random text, the host's own offer, an offer cut in half) were explained on screen; a denied camera too.
- The only host any page contacted was the one serving the game.

### Devices

| Pairing | Text codes | QR codes | Notes |
|:--|:-:|:-:|:--|
| Chrome ↔ Chrome, Windows (two instances, one PC) | ✅ | ✅ (fake camera) | Automated, see above |
| Firefox (PC) ↔ Android Chrome | pending | pending | To be tested by the team |
| Safari (macOS, iOS) | not tested | not tested | No device available |

## Testing on devices

Camera and clipboard only work in a secure context: `https://` or `localhost`.

- **Deployed build:** the GitHub Pages URL is HTTPS. Use it once the change is on `main`.
- **Before merging:** download the pull request's `web-build` artifact (or run `tools/export_web.sh`), serve it with `tools/serve_web.sh --lan`, and open `http://localhost:8060` on the computer that serves it. On an Android phone, open `http://<computer's address>:8060` after adding that address in Chrome under `chrome://flags/#unsafely-treat-insecure-origin-as-secure` (then restart Chrome). Without the flag, the phone can still pair with text codes typed in by hand, but neither the camera nor the clipboard works.

## Known limits

- Safari is untested.
- The connection needs a network in which the devices reach each other directly; there is no fallback through a server.
- On a phone held upright, the Godot screens (including this one) are drawn small, because the 1280 × 720 base view is fitted to the screen's width. The HTML parts (camera, fields) are not affected. Layout for phones is part of the lobby (#20) and the art pass (#22).
- A guest that never gets read by the host waits until its player cancels.
