class_name UiPalette
extends RefCounted
## The colours of the menus, the HUD and the touch controls (#69), taken from
## the art style (resources/documents/art_style_constraints.md): muted,
## earthy, low saturation: charcoal, raw umber, burnt sienna, pale parchment,
## a sickly yellow for highlights and an oxidized crimson for danger.
##
## [GameTheme] builds the styles from these, and the HUD gauges and the touch
## buttons draw with them, so the art pass (#70) changes them in one place.

# --- Menus -----------------------------------------------------------------------

## Behind every menu: a night pasture once it is painted.
const BACKDROP: Color = Color(0.07, 0.065, 0.055)
const BOARD: Color = Color(0.14, 0.115, 0.09, 0.94)
const BOARD_BORDER: Color = Color(0.36, 0.28, 0.19)
const BUTTON: Color = Color(0.23, 0.18, 0.135)
const BUTTON_HOVER: Color = Color(0.3, 0.235, 0.17)
## A pressed or chosen button: burnt sienna.
const BUTTON_PRESSED: Color = Color(0.42, 0.26, 0.15)
const BUTTON_DISABLED: Color = Color(0.15, 0.135, 0.115)
const BUTTON_BORDER: Color = Color(0.54, 0.42, 0.27)
const TEXT: Color = Color(0.89, 0.855, 0.77)
const TEXT_DISABLED: Color = Color(0.48, 0.45, 0.4)
## Sickly yellow: titles, focus and what is chosen.
const HIGHLIGHT: Color = Color(0.85, 0.79, 0.54)
## Problems and hints that need attention.
const WARNING: Color = Color(0.95, 0.75, 0.45)

# --- HUD and touch controls ------------------------------------------------------

## Under bars, icons and text outlines.
const HUD_BACKGROUND: Color = Color(0.0, 0.0, 0.0, 0.45)
## A full bar, a bullet, a meter: pale parchment.
const HUD_FILL: Color = Color(0.92, 0.88, 0.78, 0.9)
const HUD_EMPTY: Color = Color(1.0, 1.0, 1.0, 0.18)
const HUD_COOLDOWN: Color = Color(0.0, 0.0, 0.0, 0.6)
## Something happening right now: oxidized crimson, bright enough to read.
const HUD_ACTIVE: Color = Color(0.85, 0.25, 0.2, 0.95)
const HUD_MARK: Color = Color(1.0, 1.0, 1.0, 0.95)
const TOUCH_FILL: Color = Color(1.0, 1.0, 1.0, 0.16)
const TOUCH_FILL_PRESSED: Color = Color(1.0, 1.0, 1.0, 0.42)
const TOUCH_OUTLINE: Color = Color(1.0, 1.0, 1.0, 0.7)
const TOUCH_COOLDOWN: Color = Color(0.0, 0.0, 0.0, 0.55)
