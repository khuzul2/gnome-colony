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
## HUD chrome [leg §L-hud]: the in-run panels float over the live 3D world, so
## they read as translucent night-lapis panes (a mosaic vault seen through gauze)
## with a thin gold edge — not the opaque grounds the menus use. Alpha chosen so
## text stays legible while the world shows through beneath.
const HUD_ALPHA := 0.72
const HUD_HEADING_FONT := 15


## A night-lapis panel background with a margin.
static func panel_style(margin := 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COLORS[Palette.NIGHT_LAPIS]
	style.set_content_margin_all(margin)
	style.set_corner_radius_all(2)
	return style


## A SEMI-TRANSPARENT night-lapis pane with a thin gold border, for the in-run
## HUD panels that float over the world [leg §L-hud]. The bg alpha is HUD_ALPHA so
## the mosaic terrain shows through faintly beneath the chrome.
static func hud_panel_style(margin := 10.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg: Color = Palette.COLORS[Palette.NIGHT_LAPIS]
	bg.a = HUD_ALPHA
	style.bg_color = bg
	style.set_content_margin_all(margin)
	style.set_corner_radius_all(3)
	style.set_border_width_all(1)
	style.border_color = Palette.COLORS[Palette.GOLD_DEEP]
	return style


## Skin a HUD panel (PanelContainer) with the translucent night-lapis pane.
static func skin_hud_panel(panel: PanelContainer, margin := 10.0) -> void:
	panel.add_theme_stylebox_override("panel", hud_panel_style(margin))


## A small gold HUD heading label (the panel titles).
static func hud_heading(text: String) -> Label:
	return heading(text, HUD_HEADING_FONT)


## A transparent (background-free) box style — for inner widgets nested inside a
## translucent HUD pane, so their own solid ground doesn't double the opacity.
static func clear_style() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## One filled, bordered tessera-style box for an action button state.
static func _action_box(bg: int, bg_alpha: float, border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var fill: Color = Palette.COLORS[bg]
	fill.a = bg_alpha
	style.bg_color = fill
	style.set_corner_radius_all(2)
	style.set_border_width_all(1)
	style.border_color = Palette.COLORS[border]
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


## Skin a phenomenon ACT button [user request 2026-07-06]: a real, distinct
## gold-edged tessera (not flat text) so each act reads as its own button, gold-lit
## on hover, dimmed-with-a-slate-edge when tier-locked. Cream label, gold on press.
static func skin_action_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Palette.COLORS[Palette.CREAM])
	button.add_theme_color_override("font_hover_color", Palette.COLORS[Palette.GOLD_LIT])
	button.add_theme_color_override("font_pressed_color", Palette.COLORS[Palette.GOLD])
	button.add_theme_color_override("font_disabled_color", Palette.COLORS[Palette.SLATE_GREY])
	button.add_theme_stylebox_override(
		"normal", _action_box(Palette.DEEP_LAPIS, 0.85, Palette.GOLD_DEEP)
	)
	button.add_theme_stylebox_override(
		"hover", _action_box(Palette.MID_BLUE, 0.9, Palette.GOLD_LIT)
	)
	button.add_theme_stylebox_override(
		"pressed", _action_box(Palette.GOLD_DEEP, 0.85, Palette.GOLD)
	)
	button.add_theme_stylebox_override(
		"disabled", _action_box(Palette.NIGHT_LAPIS, 0.55, Palette.SLATE_GREY)
	)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


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
