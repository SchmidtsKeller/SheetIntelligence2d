# Web build, CI and deployment

The Web build is the game's only shipping target (GDD §9.1). Every pull request is checked, tested and exported for the Web, and `main` is deployed as a static site over HTTPS.

## Export settings

The preset "Web" in [export_presets.cfg](../export_presets.cfg):

| Setting | Value | Reason |
|:--|:--|:--|
| Thread Support | **off** | See the decision below |
| Progressive Web App | off | See the decision below |
| Canvas resize policy | Adaptive | The canvas fills the browser window and follows resize and orientation changes |
| VRAM texture compression | desktop and mobile | The same build runs in desktop and mobile browsers |
| Head Include | `page.css`, `page.js`, `vendor/qrcode-generator/qrcode.js`, `vendor/jsqr/jsQR.js`, `pairing.js` | Page rules, and the JavaScript that ships with the game (in this order: `pairing.js` needs the libraries) |
| Excluded from the build | `tests/`, `tools/`, `web/`, `docs/`, `build/` | Not part of the game |

The engine's default HTML shell is used. The game is served as its own page, not inside another site's frame (GDD §9.4).

### Decision: no Thread Support, no Progressive Web App

Godot's threaded Web build needs `SharedArrayBuffer`, which browsers only provide on pages that are *cross-origin isolated*, meaning the server sends the `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers. **GitHub Pages cannot send custom headers.** GDD §9.4 names the two ways out: export without Thread Support, or enable the Progressive Web App option, whose service worker adds the headers in the browser.

The build is exported **without Thread Support and without the PWA option**:

- It works on any static host and in every target browser, including iOS Safari, with no first-visit reload.
- The PWA route installs a service worker that caches the game. During development that means stale builds on test devices, which is the opposite of what a continuously deployed test build is for.
- A cross-origin isolated page may not load cross-origin resources that do not opt in. The game has none today, but the restriction would apply to anything added later.

**What this means for audio (input for #10).** Godot's Web builds play audio in *Sample* mode by default: sounds are handed to the browser's Web Audio API, which keeps latency low without threads. Godot's documentation warns that in this mode "positional audio may not always work correctly depending on the node's properties". *Stream* mode supports all audio features, but without Thread Support the audio is mixed on the main thread, which adds latency and can crackle when a frame takes long. So with this export decision, #10 has to make spatial audio work in *Sample* mode, or compute volume and panning in script. If neither is good enough, the fallback is to revisit this decision: Thread Support plus the PWA option. #10 kept *Sample* mode: positional audio works there as intended; see [audio.md](audio.md#the-web-build-sample-playback).

### Page files

Everything in [web/](../web) is copied next to the exported game:

- `page.css` keeps the page from scrolling, bouncing, zooming and selecting text while playing.
- `page.js` blocks the context menu (except on the pairing overlay, whose fields need it to paste) and iOS pinch zoom.
- `pairing.js` is the browser side of pairing: QR codes, the camera scanner and the clipboard (see [pairing.md](pairing.md)).
- `vendor/` holds the libraries `pairing.js` uses, with their versions, licences and checksums in [vendor/README.md](../web/vendor/README.md).

Nothing may be loaded from a CDN, because the game has to work on a local network without internet access.

## Build and serve locally

Requirements: **the standard build of Godot 4.7** with the Web export templates installed (*Editor → Manage Export Templates*). The .NET build of Godot cannot export to the Web.

Export and serve in one step:

```bash
tools/export_web.sh --serve
```

On Windows:

```powershell
tools\export_web.ps1 --serve
```

Then open <http://localhost:8060>. The scripts use the executable named by the `GODOT` environment variable, or `godot` from the `PATH`.

| Command | Effect |
|:--|:--|
| `tools/export_web.sh` | Release build into `build/web` |
| `tools/export_web.sh --debug` | Debug build, with readable errors in the browser console |
| `tools/serve_web.sh` | Serve `build/web` at `http://localhost:8060` |
| `tools/serve_web.sh --port=9000` | Use another port |
| `tools/serve_web.sh --lan` | Also accept connections from other devices in the network |

The server is a small GDScript ([tools/serve_web.gd](../tools/serve_web.gd)), so Godot is the only requirement. It is for development only.

## Continuous integration

[.github/workflows/ci.yml](../.github/workflows/ci.yml) runs on every pull request and on every push to `main`:

| Job | What it does | Fails when |
|:--|:--|:--|
| **GDScript format and lint** | `gdformat --diff` and `gdlint` (gdtoolkit) on all scripts | A script is not formatted, or breaks a lint rule |
| **Import check and unit tests** | `tools/check_import.sh`, then `tools/run_tests.sh` | A resource cannot be imported, a script does not compile, or a test fails |
| **Web export** | `tools/export_web.sh`, uploads the build as the artifact `web-build` | The export fails |
| **Deploy to GitHub Pages** | Publishes the artifact; only on `main` and only after all jobs above passed | The deployment fails |

Whether every script compiles is checked by a unit test (`tests/unit/test_scripts_compile.gd`), not by the import: the import does not compile scripts it has no reason to load, and `godot --check-only` knows no autoloads, so it rejects valid scripts that use `Services` or `SceneFlow`. The test loads each script inside the running project instead.

Godot and the export templates are pinned to the version in `GODOT_VERSION` at the top of the workflow, downloaded from the official release, verified against the release's checksums, and cached.

### Required checks

For branch protection on `main`, require these three status checks:

- `GDScript format and lint`
- `Import check and unit tests`
- `Web export`

### Trying the build of a pull request

1. Open the pull request's **Checks** tab, select the **CI** run, and download the artifact **web-build**.
2. Unpack it into `build/web`.
3. Run `tools/serve_web.sh` and open <http://localhost:8060>.

## Deployment

Every push to `main` is deployed to GitHub Pages:

**<https://schmidtskeller.github.io/SheetIntelligence2d/>**

GitHub Pages has to be switched on once by the repository owner: *Settings → Pages → Build and deployment → Source: **GitHub Actions***. Until then the workflow skips the deployment and shows a warning on the run; `main` stays green.

## Testing on a phone

Use the deployed build: open the Pages URL on the phone. Both devices have to be in the same Wi-Fi for pairing (GDD §9.4).

Serving the build from a computer with `tools/serve_web.sh --lan` and opening `http://<lan-ip>:8060` on the phone is fine for checking layout and touch controls, but **not for pairing**: browsers allow camera and clipboard access only in a *secure context*, which is `https://` or `localhost`. A plain `http://` address in the local network is neither, so QR scanning and copy/paste do not work there.
