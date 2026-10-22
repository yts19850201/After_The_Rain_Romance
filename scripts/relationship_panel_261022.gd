extends Control

# 진행 값을 소유하지 않는 표시 전용 화면입니다. 점수는 선택 기록에서만 계산합니다.
var status_card: PanelContainer
var stage_label: Label
var score_label: Label
var progress: ProgressBar
var feedback_card: PanelContainer
var feedback_label: Label
var rules: Dictionary = {}
var displayed_score: int = 0
var relationship_name: String = ""
var feedback_remaining: float = 0.0


func setup(configuration: Dictionary) -> void:
	rules = configuration
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_card = _card()
	status_card.offset_bottom = 49
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_inset(status_card).add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	stage_label = Label.new()
	stage_label.add_theme_font_size_override("font_size", 18)
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stage_label)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 16)
	score_label.add_theme_color_override("font_color", Color(0.91, 0.79, 0.57))
	row.add_child(score_label)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 6
	progress.max_value = int(rules.get("max", 3))
	progress.show_percentage = false
	for spec in [["background", Color(0.17, 0.24, 0.25)], ["fill", Color(0.73, 0.80, 0.60)]]:
		var style := StyleBoxFlat.new()
		style.bg_color = spec[1]
		style.set_corner_radius_all(3)
		progress.add_theme_stylebox_override(spec[0], style)
	column.add_child(progress)
	feedback_card = _card()
	feedback_card.offset_top = 55
	feedback_card.offset_bottom = 96
	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 17)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inset(feedback_card).add_child(feedback_label)
	_ignore_mouse(self)
	set_state(0)


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	add_child(card)
	card.anchor_right = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.105, 0.12, 0.96)
	style.border_color = Color(0.77, 0.68, 0.49, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", style)
	return card


func _inset(card: PanelContainer) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	card.add_child(margin)
	return margin


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _name_for(score: int) -> String:
	var result: String = "관계"
	for level in rules.get("levels", []):
		if score >= int(level.min):
			result = level.label
	return result


func configure_rules(configuration: Dictionary) -> void:
	rules = configuration
	progress.max_value = int(rules.get("max", 3))
	set_state(displayed_score)


func set_state(score: int, announce: bool = false) -> void:
	var previous_score: int = displayed_score
	displayed_score = clampi(score, 0, int(progress.max_value))
	relationship_name = _name_for(displayed_score)
	stage_label.text = "서윤 · " + relationship_name
	score_label.text = "호감도 %d / %d" % [displayed_score, int(progress.max_value)]
	if announce:
		var difference: int = displayed_score - previous_score
		feedback_label.text = ("호감도 +%d · " % difference if difference > 0 else "호감도 유지 · ") + relationship_name
		feedback_label.add_theme_color_override("font_color", Color(0.82, 0.92, 0.71) if difference > 0 else Color(0.93, 0.88, 0.77))
		feedback_remaining = 4.0
		feedback_card.show()
	else:
		progress.value = displayed_score
		clear_feedback()


func clear_feedback() -> void:
	feedback_remaining = 0.0
	feedback_card.hide()


func tick(delta: float) -> void:
	if not is_visible_in_tree():
		return
	progress.value = move_toward(progress.value, displayed_score, delta * 5.0)
	if feedback_remaining > 0.0:
		feedback_remaining = maxf(0.0, feedback_remaining - delta)
		feedback_card.visible = feedback_remaining > 0.0
