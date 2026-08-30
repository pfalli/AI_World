class_name UIFactory
extends RefCounted

static func panel(color := Color(0.025, 0.075, 0.05, 0.94)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.34, 0.58, 0.36, 0.8)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func label(text: String, size := 16, color := Color(0.9, 0.96, 0.86, 1)) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node

static func button(text: String) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, 38)
	node.add_theme_font_size_override("font_size", 14)
	return node

static func field_label(text: String) -> Label:
	return label(text.to_upper(), 11, Color(0.65, 0.82, 0.64, 1))
