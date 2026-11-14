// Page behaviour for the Web build. Loaded from the export preset's Head
// Include and copied next to the exported game by tools/export_web.
//
// This is the hook for JavaScript that has to ship with the game files, like
// the pairing helpers in pairing.js and the libraries in vendor/. Put further
// files into web/ and load them from the Head Include. Nothing may come from a
// CDN: the game has to work on a local network without internet access.

(function () {
	"use strict";

	// The game runs as its own page (GDD §9.4). Inside another site's frame the
	// browser may deny camera and clipboard access, which pairing needs.
	if (window.top !== window.self) {
		console.warn("Hide in Sheep Clothing is embedded in a frame; camera and clipboard may be unavailable.");
	}

	// A long press or right click must not open the browser's context menu,
	// except on the pairing overlay, whose text fields need it to paste.
	window.addEventListener("contextmenu", function (event) {
		if (!(event.target instanceof Element && event.target.closest(".sheep-overlay"))) {
			event.preventDefault();
		}
	});

	// iOS Safari ignores `user-scalable=no` and zooms on pinch and double tap.
	["gesturestart", "gesturechange", "gestureend"].forEach(function (type) {
		document.addEventListener(type, function (event) {
			event.preventDefault();
		});
	});

	// Keys that scroll the page (space, arrows) belong to the game. Godot stops
	// them while the canvas has focus; this covers the moment before it does.
	window.addEventListener("keydown", function (event) {
		var scrolling = [" ", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "PageUp", "PageDown"];
		var typing = event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement;
		if (!typing && scrolling.indexOf(event.key) !== -1) {
			event.preventDefault();
		}
	});
})();
