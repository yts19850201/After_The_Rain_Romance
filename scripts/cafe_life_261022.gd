extends "res://scripts/novel_261022.gd"

var life_data: Dictionary = {}
var week = preload("res://scripts/cafe_week_state_261022.gd").new()
var life_active: bool = false
var life_hub: PanelContainer
var day_card: PanelContainer
var day_label: Label
var day_note: Label
var action_buttons: Dictionary = {}
var episode_button: Button
var next_day_button: Button
var life_start_button: Button
var continue_week_button: Button
var journal_button: Button
var ending_gallery_button: Button
var minjae_art: Texture2D


func _ready() -> void:
	life_data = _read_json("res://data/cafe_life_261022.json")
	week.configure(life_data)
	super._ready()
	_build_life_ui()
	show_menu()


func start_scene() -> void:
	life_active = false
	_hide_life_ui()
	if relationship_panel:
		relationship_panel.configure_rules(relationship_rules)
	super.start_scene()


func show_menu() -> void:
	life_active = false
	_hide_life_ui()
	if relationship_panel:
		relationship_panel.configure_rules(relationship_rules)
	super.show_menu()


func start_life() -> void:
	_close_overlay()
	_cancel_transition()
	gallery_replay = false
	life_active = true
	week.reset()
	selected_choices.clear()
	affection = 0
	_show_life_state()


func _hide_life_ui() -> void:
	if character_art:
		character_art.anchor_top = 0.11
		character_art.anchor_bottom = 1.27
	for control in [life_hub, day_card, continue_week_button, journal_button]:
		if control:
			control.hide()
	if ending_gallery_button:
		ending_gallery_button.show()


func _show_life_state() -> void:
	menu.hide()
	complete_panel.hide()
	choices_panel.hide()
	toolbar.show()
	day_card.show()
	character_art.anchor_top = 0.20
	character_art.anchor_bottom = 1.36
	day_label.text = "%d / 5일차 · %s   |   남은 행동 %d / 2" % [week.day, life_data.days[week.day - 1], week.remaining()]
	day_note.text = life_data.day_notes[week.day - 1]
	background_art.texture = art.evening if week.day >= 4 else art.rain
	character_art.texture = art.neutral
	$Chapter/Label.text = "새로운 한 주 · " + str(life_data.days[week.day - 1])
	_play_music("cafe")
	affection = week.score()
	relationship_panel.configure_rules(life_data.relationship)
	relationship_panel.set_state(affection)
	relationship_panel.show()
	continue_week_button.hide()
	journal_button.hide()
	if week.phase == "event":
		life_hub.hide()
		dialogue_panel.show()
		phase = "life_event"
		current_lines = _lines(life_data.events[week.event_id].lines)
		line_index = 0
		next_button.disabled = false
		for button in action_buttons.values():
			button.release_focus()
		life_start_button.release_focus()
		_show_line()
	elif week.phase == "week_complete":
		_show_complete()
	else:
		mode = Mode.CHOICE
		typing = false
		phase = "life_hub"
		current_lines = []
		line_index = 0
		dialogue_panel.hide()
		life_hub.show()
		for id in action_buttons:
			var used: bool = week.used_today(id)
			action_buttons[id].disabled = used or week.remaining() <= 0
			action_buttons[id].text = life_data.actions[id].label + (" · 오늘 완료" if used else "")
		var available: int = 0
		for id in life_data.episodes:
			if week.eligible(id) and not week.seen.has(id):
				available += 1
		episode_button.text = "추가 이야기 · 새로 %d개" % available
		next_day_button.text = ("한 주 마치기" if week.day == 5 else "오늘 마치고 다음 날로") + (" · 남은 행동 포기" if week.remaining() > 0 else "")
		_focus_life_hub()


func _focus_life_hub() -> void:
	if not life_active or week.phase != "hub" or not overlay_kind.is_empty():
		return
	for button in action_buttons.values():
		if not button.disabled:
			button.grab_focus()
			return
	next_day_button.grab_focus()


func _show_line() -> void:
	super._show_line()
	if life_active:
		var speaker: String = current_lines[line_index].speaker
		if speaker == "minjae":
			speaker_label.text = "민재"
			character_art.texture = minjae_art
		elif speaker == "seoyun":
			character_art.texture = art[current_lines[line_index].expression]


func _finish_reveal() -> void:
	super._finish_reveal()
	if life_active and line_index == current_lines.size() - 1:
		next_button.text = "카페로 돌아가기"


func advance() -> void:
	if not life_active:
		super.advance()
		return
	if not overlay_kind.is_empty() or transitioning or week.phase != "event" or mode != Mode.DIALOGUE:
		return
	if typing:
		_finish_reveal()
		return
	_play_sfx("confirm")
	if line_index + 1 < current_lines.size():
		line_index += 1
		_show_line()
	else:
		week.finish_event()
		_show_life_state()


func choose_action(id: String) -> void:
	if not life_active or not overlay_kind.is_empty() or not week.act(id):
		return
	# 행동 기록과 소모는 대화 시작 전에 한 번만 확정합니다.
	var previous: int = affection
	_show_life_state()
	relationship_panel.set_state(previous)
	relationship_panel.set_state(affection, true)
	_play_sfx("select")


func finish_day() -> void:
	if not life_active or not overlay_kind.is_empty() or not week.next_day():
		return
	_show_life_state()


func _show_complete() -> void:
	if not life_active:
		replay_button.text = "처음부터 다시"
		if continue_week_button:
			continue_week_button.show()
		if ending_gallery_button:
			ending_gallery_button.show()
		super._show_complete()
		return
	mode = Mode.COMPLETE
	typing = false
	life_hub.hide()
	dialogue_panel.hide()
	choices_panel.hide()
	complete_panel.show()
	ending_gallery_button.hide()
	continue_week_button.hide()
	journal_button.show()
	$Complete/Margin/Content/Title.text = "함께 보낸 한 주"
	var viewed: int = 0
	for id in life_data.episodes:
		if week.seen.has(id):
			viewed += 1
	$Complete/Margin/Content/Summary.text = "호감도 %d / 10 · 함께한 행동 %d회\n추가 이야기 %d / 4개 감상\n쌓인 문장과 만남을 한 주의 기록에 남겼습니다." % [week.score(), week.history.size(), viewed]
	replay_button.text = "한 주 다시 보내기"
	relationship_panel.clear_feedback()
	replay_button.grab_focus()


func _open_episodes() -> void:
	if not life_active or week.phase != "hub":
		return
	_open_overlay("episodes", "관계 속에서 열리는 이야기")
	_label("행동 횟수를 쓰지 않으며, 각 이야기는 한 주에 한 번 읽습니다.", 18)
	for id in life_data.episodes:
		var event: Dictionary = life_data.events[id]
		var viewed: bool = week.seen.has(id)
		_label(event.title + (" · 감상 완료" if viewed else ""), 22)
		_label(event.condition, 16)
		var button := _button("감상 완료" if viewed else ("이야기 읽기" if week.eligible(id) else "아직 조건을 채우지 못했어요"), _read_episode.bind(id), overlay_content)
		button.disabled = viewed or not week.eligible(id)
	_close_button()


func _read_episode(id: String) -> void:
	if not life_active or overlay_kind != "episodes" or not week.start_episode(id):
		return
	_close_overlay()
	_show_life_state()


func _open_journal() -> void:
	if not life_active:
		return
	_open_overlay("journal", "우리의 한 주")
	_label("호감도 %d / 10 · %d일차 · 남은 행동 %d / 2" % [week.score(), week.day, week.remaining()], 20)
	for day in range(1, week.day + 1):
		var names: PackedStringArray = []
		for entry in week.history:
			if int(entry.day) == day:
				names.append(life_data.actions[entry.action].label)
		_label("%s: %s" % [life_data.days[day - 1], " · ".join(names) if not names.is_empty() else "기록한 행동 없음"], 18)
	_label("민재와 첫 만남: " + ("완료" if week.seen.has("intro_minjae") else "화요일에 만나요"), 18)
	for id in life_data.episodes:
		_label(("✓ " if week.seen.has(id) else "○ ") + life_data.events[id].title, 18)
	_close_button()


func _open_overlay(kind: String, title_value: String) -> void:
	super._open_overlay(kind, title_value)
	if life_hub:
		life_hub.process_mode = Node.PROCESS_MODE_DISABLED


func _close_overlay() -> void:
	super._close_overlay()
	if life_hub:
		life_hub.process_mode = Node.PROCESS_MODE_INHERIT
	_focus_life_hub()


func _open_gallery() -> void:
	if life_active:
		return
	super._open_gallery()


func _replay_ending(id: String) -> void:
	if not life_active:
		super._replay_ending(id)


func _open_credits() -> void:
	super._open_credits()
	var additional := _label("새로운 한 주: 서브 캐릭터 민재(30세), 동네 서점 직원 겸 책 모임 참가자\n민재 인물 그림 1종도 OpenAI image_gen으로 생성했습니다.", 18)
	overlay_content.move_child(additional, 2)


func _can_save() -> bool:
	return (not transitioning and not gallery_replay) if life_active else super._can_save()


func snapshot() -> Dictionary:
	if not life_active:
		return super.snapshot()
	var value: Dictionary = week.state()
	value.line_index = line_index if week.phase == "event" else 0
	value.typing = typing if week.phase == "event" else false
	value.visible_characters = body.visible_characters if week.phase == "event" else -1
	return value


func _valid_snapshot(value: Dictionary) -> bool:
	if value.get("schema") != 2:
		return super._valid_snapshot(value)
	if not week.valid(value) or not _integer(value.get("line_index")) or not _integer(value.get("visible_characters")) or not value.get("typing") is bool:
		return false
	if value.phase != "event":
		return value.line_index == 0 and value.visible_characters == -1 and not value.typing
	var rows: Array = life_data.events[value.event_id].lines
	var index: int = int(value.line_index)
	if index < 0 or index >= rows.size():
		return false
	var count: int = int(value.visible_characters)
	return count >= -1 and count <= str(rows[index][2]).length() and ((value.typing and count >= 0) or (not value.typing and count == -1))


func _restore(value: Dictionary) -> void:
	if value.schema != 2:
		life_active = false
		_hide_life_ui()
		relationship_panel.configure_rules(relationship_rules)
		super._restore(value)
		return
	life_active = true
	week.restore(value)
	_show_life_state()
	if week.phase == "event":
		line_index = int(value.line_index)
		_show_line()
		if value.typing:
			typing = true
			revealed_count = float(value.visible_characters)
			body.visible_characters = int(value.visible_characters)
		else:
			_finish_reveal()


func _slot_caption(value: Dictionary, saved_at: String) -> String:
	if value.schema == 2:
		return "새로운 한 주 · %d일차 %s · %s" % [int(value.day), {"hub": "행동 선택", "event": life_data.events.get(value.event_id, {}).get("title", "대화"), "week_complete": "한 주 마무리"}.get(value.phase, ""), saved_at]
	return super._slot_caption(value, saved_at)


func _build_life_ui() -> void:
	minjae_art = load(life_data.characters.minjae.portrait)
	$Menu/Margin/Content/Subtitle.text = "32~34단계 실습 · 함께 보내는 한 주"
	start_button.text = "첫 만남 읽기 · 기존 이야기"
	life_start_button = _button("새로운 한 주 시작", start_life, $Menu/Margin/Content)
	$Menu/Margin/Content.move_child(life_start_button, $Menu/Margin/Content/Start.get_index())
	$Menu/Margin/Content/Title.add_theme_font_size_override("font_size", 30)
	$Menu/Margin/Content/Premise.text = "첫 세 번의 만남 뒤, 새로운 한 주.\n하루 두 번의 행동으로 이야기를 열어보세요."
	$Menu/Margin/Content.add_theme_constant_override("separation", 6)
	$Menu/Margin/Content/Hint.text = "첫 만남과 일상은 별도로 시작합니다."
	menu.anchor_top = 0.13
	for connection in replay_button.pressed.get_connections():
		replay_button.pressed.disconnect(connection.callable)
	replay_button.pressed.connect(func():
		if life_active:
			start_life()
		else:
			start_scene())
	for child in $Complete/Margin/Content.get_children():
		if child is Button and child.text == "엔딩 감상":
			ending_gallery_button = child
	continue_week_button = _button("서윤과 새로운 한 주", start_life, $Complete/Margin/Content)
	journal_button = _button("한 주 기록 보기", _open_journal, $Complete/Margin/Content)
	day_card = PanelContainer.new()
	add_child(day_card)
	day_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	day_card.anchor_left = 0.54
	day_card.anchor_right = 0.95
	day_card.anchor_top = 0.115
	day_card.anchor_bottom = 0.185
	day_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_label = Label.new()
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", 17)
	day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_card.add_child(day_label)
	life_hub = PanelContainer.new()
	add_child(life_hub)
	life_hub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	life_hub.anchor_left = 0.05
	life_hub.anchor_right = 0.60
	life_hub.anchor_top = 0.205
	life_hub.anchor_bottom = 0.95
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	life_hub.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "오늘의 카페"
	title.add_theme_font_size_override("font_size", 27)
	column.add_child(title)
	var information := Label.new()
	information.text = "하루 두 번 · 같은 행동은 하루에 한 번\n모든 행동은 호감도 +1, 서로 다른 이야기 조건을 쌓아요."
	information.add_theme_font_size_override("font_size", 16)
	column.add_child(information)
	day_note = Label.new()
	day_note.add_theme_font_size_override("font_size", 16)
	day_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(day_note)
	for id in life_data.actions:
		var action: Dictionary = life_data.actions[id]
		var button := _button(action.label, choose_action.bind(id), column)
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 20)
		button.tooltip_text = action.hint
		action_buttons[id] = button
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	episode_button = _button("추가 이야기", _open_episodes, row)
	episode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	episode_button.add_theme_font_size_override("font_size", 18)
	var journal := _button("한 주 기록", _open_journal, row)
	journal.add_theme_font_size_override("font_size", 18)
	next_day_button = _button("오늘 마치기", finish_day, column)
	next_day_button.add_theme_font_size_override("font_size", 18)
	_hide_life_ui()
