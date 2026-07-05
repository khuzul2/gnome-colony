class_name RavennaUI
extends RefCounted
## R8.1 [leg §L-ui] — the menu skin: late-antique Christian-mosaic register applied
## to the chrome. Night-lapis grounds, cream body, gold headings, gold-lit on
## hover/focus, the sacred monogram as emblem, a meander (Greek-key) rule. Static
## helpers so MainMenu / WizardView share one look. Colors come from Palette
## [rav §R-art]; presentation-only.

const SEAT_MARK := "☩"  ## the sacred monogram, used as the menu emblem
const MENU_FONT := 18
const TITLE_FONT := 34
const HEADING_FONT := 20
const GUTTER := 16.0  ## min gap between the wizard's two panes [leg §L-ui]


## A night-lapis panel background with a margin.
static func panel_style(margin := 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COLORS[Palette.NIGHT_LAPIS]
	style.set_content_margin_all(margin)
	style.set_corner_radius_all(2)
	return style


## Skin a Control as a full-bleed night-lapis ground (a PanelContainer wrapper the
## caller fills). Returns the wrapper; add content to it.
static func ground() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return panel


## Skin a menu Button: cream text, gold-lit on hover/focus, flat, min font.
static func skin_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", MENU_FONT)
	button.add_theme_color_override("font_color", Palette.COLORS[Palette.CREAM])
	button.add_theme_color_override("font_hover_color", Palette.COLORS[Palette.GOLD_LIT])
	button.add_theme_color_override("font_focus_color", Palette.COLORS[Palette.GOLD_LIT])
	button.add_theme_color_override("font_pressed_color", Palette.COLORS[Palette.GOLD])
	button.add_theme_color_override("font_disabled_color", Palette.COLORS[Palette.SLATE_GREY])
	button.flat = true


## A gold heading label.
static func heading(text: String, size := HEADING_FONT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Palette.COLORS[Palette.GOLD])
	return label


## A cream body label.
static func body(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", MENU_FONT)
	label.add_theme_color_override("font_color", Palette.COLORS[Palette.CREAM])
	return label


## A thin gold meander (Greek-key) rule — a bordered strip under a title.
static func meander_rule() -> Control:
	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(0.0, 3.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COLORS[Palette.GOLD]
	rule.add_theme_stylebox_override("panel", style)
	return rule
