class_name GamePanel
extends PanelContainer
## A board behind a group of texts and buttons (#69): the perk choice, the
## scoreboard, the pairing steps. Its looks come from [GameTheme]: painted
## parchment (#83), so what stands on it is written in dark ink.


## A board named [param panel_name] holding [param content].
static func create(panel_name: String, content: Control) -> GamePanel:
	var panel: GamePanel = GamePanel.new()
	panel.name = panel_name
	panel.theme_type_variation = GameTheme.BOARD_PANEL
	panel.theme = GameTheme.get_board_theme()
	panel.add_child(content)
	return panel
