# Third-party code shipped with the Web build

These libraries are copied next to the exported game (see [docs/web-build.md](../../docs/web-build.md)) and loaded by the export preset's Head Include. Nothing is loaded from a CDN: the game has to work in a local network without internet access.

| Library | Version | File | Licence | Used for |
|:--|:--|:--|:--|:--|
| [qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator) by Kazuhiko Arase | 2.0.4 | `qrcode-generator/qrcode.js` (the package's `dist/qrcode.js`) | MIT, notice in the file header | Making the QR code of a pairing code |
| [jsQR](https://github.com/cozmo/jsQR) by Cosmo Wolfe | 1.4.0 | `jsqr/jsQR.js` (the package's `dist/jsQR.js`) | Apache-2.0, see `jsqr/LICENSE` | Reading QR codes from camera frames |

Both were taken unchanged from the npm packages, fetched with `npm pack`, which checks them against the registry:

| Package | npm integrity | SHA-256 of the shipped file |
|:--|:--|:--|
| `qrcode-generator@2.0.4` | `sha512-mZSiP6RnbHl4xL2Ap5HfkjLnmxfKcPWpWe/c+5XxCuetEenqmNFf1FH/ftXPCtFG5/TDobjsjz6sSNL0Sr8Z9g==` | `79ec86f82856005b1c887905cfccfcfbec3821ca61c7fd5a952faa5f778f791c` |
| `jsqr@1.4.0` | `sha512-dxLob7q65Xg2DvstYkRpkYtmKm2sPJ9oFhrhmudT1dZvNFFTlroai3AWSpLey/w5vMcLBXRgOJsbXpdN9HzU/A==` | `bc40c8a15196236b2314db0856f72ca0b49980cd5413b8c852a7349f5fee0859` |

"QR Code" is a registered trademark of DENSO WAVE INCORPORATED.
