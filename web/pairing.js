// The browser side of pairing (GDD §9.4): QR codes, the camera scanner and the
// clipboard. GDScript reaches it as window.SheepPairing through
// JavaScriptBridge (see ui/pairing/pairing_browser.gd).
//
// Godot cannot use the camera on the Web and has no QR support, and its text
// fields do not open the keyboard on phones, so these parts are plain HTML
// laid over the game. The libraries ship in vendor/; nothing is loaded from or
// sent to another host.

(function () {
	"use strict";

	// Frames are scaled to at most this many pixels on their long side before
	// they are searched for a code: enough for a dense code, fast on phones.
	var SCAN_SIZE = 960;
	var CAMERA = { video: { facingMode: { ideal: "environment" } }, audio: false };

	var overlay = null;
	var stream = null;
	// The camera kept on from requestCamera until releaseCamera, and a count of
	// the requests, so that a camera arriving after its release is let go.
	var held = null;
	var requests = 0;

	// The modules of a QR code for `text` (Base32, so alphanumeric mode), one
	// row of "0" and "1" per line; "" if it does not fit into a QR code.
	function qrMatrix(text, level) {
		var qr;
		try {
			qr = qrcode(0, level || "L");
			qr.addData(text, "Alphanumeric");
			qr.make();
		} catch (error) {
			return "";
		}
		var size = qr.getModuleCount();
		var rows = [];
		for (var row = 0; row < size; row++) {
			var line = "";
			for (var column = 0; column < size; column++) {
				line += qr.isDark(row, column) ? "1" : "0";
			}
			rows.push(line);
		}
		return rows.join("\n");
	}

	// Turns the camera on and keeps it on until releaseCamera; the scanner uses
	// it too. While the page has the camera permission (Chrome) or uses the
	// camera (Firefox), browsers put the device's real addresses into WebRTC
	// connection data instead of hidden .local names, which other devices often
	// cannot resolve (docs/pairing.md). Calls back("camera", "granted"),
	// back("camera", "denied") or back("camera", "unavailable").
	function requestCamera(back) {
		releaseCamera();
		if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
			back("camera", "unavailable");
			return;
		}
		var request = requests;
		navigator.mediaDevices.getUserMedia(CAMERA).then(function (camera) {
			if (request !== requests) {
				stop(camera);
				return;
			}
			held = camera;
			back("camera", "granted");
		}, function () {
			back("camera", "denied");
		});
	}

	function releaseCamera() {
		requests++;
		if (held) {
			stop(held);
			held = null;
		}
	}

	// Shows the camera and calls back("code", text) when it sees a QR code,
	// back("cancel", "") or back("error", message for the player).
	function scan(back) {
		var box = open("Point the camera at the code on the other device.");
		var video = document.createElement("video");
		video.setAttribute("playsinline", "");
		video.muted = true;
		box.appendChild(video);
		var finished = false;
		var finish = function (kind, value) {
			if (finished) {
				return;
			}
			finished = true;
			close();
			back(kind, value);
		};
		addButton(box, "Cancel", function () {
			finish("cancel", "");
		});
		if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
			finish("error", "This browser cannot use the camera here. Use the text code instead.");
			return;
		}
		var canvas = document.createElement("canvas");
		var context = canvas.getContext("2d", { willReadFrequently: true });
		var look = function () {
			if (finished) {
				return;
			}
			if (video.readyState >= 2 && video.videoWidth > 0) {
				var scale = Math.min(1, SCAN_SIZE / Math.max(video.videoWidth, video.videoHeight));
				canvas.width = Math.round(video.videoWidth * scale);
				canvas.height = Math.round(video.videoHeight * scale);
				context.drawImage(video, 0, 0, canvas.width, canvas.height);
				var image = context.getImageData(0, 0, canvas.width, canvas.height);
				var found = jsQR(image.data, image.width, image.height, { inversionAttempts: "dontInvert" });
				if (found && found.data) {
					finish("code", found.data);
					return;
				}
			}
			requestAnimationFrame(look);
		};
		var opening = held && held.active ? Promise.resolve(held) : navigator.mediaDevices.getUserMedia(CAMERA);
		opening
			.then(function (camera) {
				if (finished) {
					if (camera !== held) {
						stop(camera);
					}
					return;
				}
				stream = camera;
				video.srcObject = camera;
				video.play();
				requestAnimationFrame(look);
			})
			.catch(function (error) {
				finish("error", error.name === "NotAllowedError"
					? "The camera was not allowed. Allow it in the browser, or use the text code."
					: "The camera could not be started (" + error.name + "). Use the text code instead.");
			});
	}

	// Puts `text` on the clipboard and calls back("copied", ""). If the browser
	// refuses, it shows the text to copy by hand and calls back("closed", "")
	// when the player is done.
	function copy(text, back) {
		var byHand = function () {
			var box = open("Copy this code and send it to the other player.");
			var field = addField(box, text, true);
			var status = addText(box, "");
			addButton(box, "Copy", function () {
				field.select();
				write(text, field).then(function () {
					status.textContent = "Copied.";
				}, function () {
					status.textContent = "Select the text and copy it.";
				});
			});
			addButton(box, "Close", function () {
				close();
				back("closed", "");
			});
			field.select();
		};
		write(text, null).then(function () {
			back("copied", "");
		}, byHand);
	}

	// Asks for a code to be pasted or typed. Calls back("code", text) or
	// back("cancel", "").
	function enter(title, back) {
		var box = open(title);
		var field = addField(box, "", false);
		field.placeholder = "Paste the code here";
		var status = addText(box, "");
		if (navigator.clipboard && navigator.clipboard.readText) {
			addButton(box, "Paste", function () {
				navigator.clipboard.readText().then(function (text) {
					field.value = text;
				}, function () {
					status.textContent = "Paste into the field instead (long press or Ctrl+V).";
				});
			});
		}
		addButton(box, "Use code", function () {
			close();
			back("code", field.value);
		});
		addButton(box, "Cancel", function () {
			close();
			back("cancel", "");
		});
		field.focus();
	}

	// The clipboard API, or the old copy command on a selected field.
	function write(text, field) {
		if (navigator.clipboard && navigator.clipboard.writeText) {
			return navigator.clipboard.writeText(text);
		}
		if (field && document.execCommand && document.execCommand("copy")) {
			return Promise.resolve();
		}
		return Promise.reject(new Error("no clipboard"));
	}

	function open(title) {
		close();
		overlay = document.createElement("div");
		overlay.className = "sheep-overlay";
		addText(overlay, title);
		document.body.appendChild(overlay);
		return overlay;
	}

	function stop(camera) {
		camera.getTracks().forEach(function (track) {
			track.stop();
		});
	}

	// Closes the scanner or a field; the held camera stays on.
	function close() {
		if (stream) {
			if (stream !== held) {
				stop(stream);
			}
			stream = null;
		}
		if (overlay) {
			overlay.remove();
			overlay = null;
		}
	}

	function addText(box, text) {
		var paragraph = document.createElement("p");
		paragraph.textContent = text;
		box.appendChild(paragraph);
		return paragraph;
	}

	function addField(box, text, readOnly) {
		var field = document.createElement("textarea");
		field.value = text;
		field.readOnly = readOnly;
		field.spellcheck = false;
		field.autocapitalize = "off";
		field.autocomplete = "off";
		box.appendChild(field);
		return field;
	}

	function addButton(box, label, action) {
		var button = document.createElement("button");
		button.type = "button";
		button.textContent = label;
		button.addEventListener("click", action);
		box.appendChild(button);
		return button;
	}

	window.SheepPairing = {
		requestCamera: requestCamera,
		releaseCamera: releaseCamera,
		qrMatrix: qrMatrix,
		scan: scan,
		copy: copy,
		enter: enter,
		close: function () {
			close();
			releaseCamera();
		},
	};
})();
