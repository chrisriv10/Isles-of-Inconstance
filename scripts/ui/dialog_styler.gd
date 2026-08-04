class_name DialogStyler
## Shared theming for popup dialogs (AcceptDialog / ConfirmationDialog) so
## every popup in the game matches the golden wood UI.
##
## IMPORTANT: In Godot 4.x there is NO "title_bar" stylebox on Window (old
## 4.0-era title_bar / close_button overrides are silently ignored). The
## engine draws the embedded-window frame AND the title strip from the
## "embedded_border" stylebox, centering the title text over its TOP BAND.
## So this helper makes that top band a solid golden header — that IS the
## frame behind the title.
##
## MUST be called AFTER add_child() so the dialog's buttons exist
## (AcceptDialog builds them in _ready).

# UI Style constants (consts are already static — usable from static functions)
const LIGHT_WOOD: StyleBoxTexture = preload("res://resources/ui/wood_panel.tres")
const DARK_WOOD: StyleBoxTexture = preload("res://resources/ui/dark_wood_panel.tres")
const DARK_WOOD_BORDER: StyleBoxTexture = preload("res://resources/ui/dark_wood_border.tres")


static func style_dialog(dialog: AcceptDialog) -> void:
	# Window panel: light wood (wood_panel.tres already has a 6px 9-slice
	# border frame + golden tint baked in via texture margins & modulate_color)
	var panel_style := LIGHT_WOOD.duplicate()
	panel_style.set_content_margin_all(8)
	dialog.add_theme_stylebox_override("panel", panel_style)

	# Golden frame + solid golden title band (as tall as the title strip).
	#
	# The engine draws the window title text ABOVE the content rect (negative
	# Y, in the title_height strip) and draws this stylebox over the content
	# rect GROWN by its expand margins (StyleBoxFlat::draw grows the rect by
	# expand_margin_*). Without a top expand margin the stylebox sits exactly
	# under the content texture and nothing is visible behind the title — the
	# default theme hides this with expand_margin_top = 32. We expand the top
	# by title_height so the 36px golden top band lands directly behind the
	# title text, and the sides/bottom form the golden frame around the panel.
	var title_band := dialog.get_theme_constant("title_height", "Window")
	var embed_border := StyleBoxFlat.new()
	embed_border.bg_color = Color(0.102, 0.063, 0.031, 0.97)
	embed_border.border_color = Color(0.722, 0.525, 0.176, 1.0)
	embed_border.border_width_top = title_band
	embed_border.border_width_left = 2
	embed_border.border_width_right = 2
	embed_border.border_width_bottom = 2
	embed_border.set_corner_radius_all(8)
	embed_border.expand_margin_top = title_band
	embed_border.expand_margin_left = 3
	embed_border.expand_margin_right = 3
	embed_border.expand_margin_bottom = 3
	dialog.add_theme_stylebox_override("embedded_border", embed_border)
	dialog.add_theme_stylebox_override("embedded_unfocused_border", embed_border)

	# Dark title text on the golden band — the band is the frame, the text
	# must contrast against it. Size bumped up (project theme defaults to 12).
	dialog.add_theme_color_override("title_color", Color(0.15, 0.1, 0.05))
	dialog.add_theme_font_size_override("title_font_size", 20)

	# Close X sits on the golden band too — it's an icon (close_button
	# styleboxes no longer exist), theme it dark to match.
	var close_icon := _make_close_icon(Color(0.15, 0.1, 0.05))
	dialog.add_theme_icon_override("close", close_icon)
	dialog.add_theme_icon_override("close_pressed", close_icon)

	# OK / Cancel buttons
	var btn_style_normal := StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.361, 0.239, 0.118, 0.9)
	btn_style_normal.set_border_width_all(2)
	btn_style_normal.border_color = Color(0.545, 0.412, 0.122, 0.6)
	btn_style_normal.set_corner_radius_all(8)

	var btn_style_hover := StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.478, 0.333, 0.188, 1.0)
	btn_style_hover.set_border_width_all(2)
	btn_style_hover.border_color = Color(0.722, 0.525, 0.176, 0.8)
	btn_style_hover.set_corner_radius_all(8)

	var btn_style_pressed := StyleBoxFlat.new()
	btn_style_pressed.bg_color = Color(0.55, 0.42, 0.14, 1.0)
	btn_style_pressed.set_border_width_all(2)
	btn_style_pressed.border_color = Color(0.9, 0.7, 0.3, 1.0)
	btn_style_pressed.set_corner_radius_all(8)

	var cancel_btn: Button = null
	var ok_btn := dialog.get_ok_button()
	if ok_btn:
		ok_btn.add_theme_stylebox_override("normal", btn_style_normal)
		ok_btn.add_theme_stylebox_override("hover", btn_style_hover)
		ok_btn.add_theme_stylebox_override("pressed", btn_style_pressed)
		ok_btn.add_theme_stylebox_override("focus", btn_style_hover)
		ok_btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	if dialog is ConfirmationDialog:
		cancel_btn = dialog.get_cancel_button()
	if cancel_btn:
		cancel_btn.add_theme_stylebox_override("normal", btn_style_normal)
		cancel_btn.add_theme_stylebox_override("hover", btn_style_hover)
		cancel_btn.add_theme_stylebox_override("pressed", btn_style_pressed)
		cancel_btn.add_theme_stylebox_override("focus", btn_style_hover)
		cancel_btn.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))


## Builds a small 16x16 "X" icon for the window close button, tinted p_color.
static func _make_close_icon(p_color: Color) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i: int in range(16):
		for k: int in range(2):
			var y := clampi(i + k - 1, 0, 15)
			img.set_pixel(i, y, p_color)
			img.set_pixel(15 - i, y, p_color)
	return ImageTexture.create_from_image(img)
