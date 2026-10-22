extends "res://scripts/scene01_261022.gd"

# 22단계의 대화창과 입력 규칙을 재사용하고 전체 이야기를 연결합니다.
var user_data_root: String = "user://romance"
var story: Dictionary = {}
var all_choices: Dictionary = {}
var ending_rule: Dictionary = {}
var relationship_rules: Dictionary = {}
var relationship_panel: Control
var selected_choices: Dictionary = {}
var active_scene_id: String = "S01"
var phase: String = "common"
var seen_endings: Array = []
var settings: Dictionary = {"speed": 32.0, "music": true, "sfx": true, "music_db": -22.0, "sfx_db": -18.0, "transitions": true}
var ui_ready: bool = false
var transitioning: bool = false
var transitions_enabled: bool = true
var transition_tween: Tween
var gallery_replay: bool = false
var gallery_return: Dictionary = {}
var overlay_kind: String = ""
var background_art: TextureRect
var character_art: TextureRect
var fade: ColorRect
var toolbar: HBoxContainer
var overlay: Control
var overlay_content: VBoxContainer
var toast: Label
var toast_time: float = 0.0
var art: Dictionary = {}
var bgm: AudioStreamPlayer
var sfx: AudioStreamPlayer
var current_music: String = ""
var music_tween: Tween


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("--verify-release"):
		var data_index: int = arguments.find("--qa-data")
		if data_index < 0 or data_index + 1 >= arguments.size() or not arguments[data_index + 1].is_absolute_path():
			push_error("Release verification requires an absolute --qa-data folder")
			get_tree().quit(1)
			return
		user_data_root = arguments[data_index + 1]
	super._ready()
	for button in [choice_a, choice_b]:
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
	choice_a.pressed.connect(_select_option.bind(0))
	choice_b.pressed.connect(_select_option.bind(1))
	_build_ui()
	_load_preferences()
	ui_ready = true
	show_menu()
	if arguments.has("--verify-release"):
		var verifier: Node = load("res://scripts/release_verification_261022.gd").new()
		add_child(verifier)
		verifier.call_deferred("run", self)


func _load_dialogue() -> bool:
	story = _read_json("res://data/story_dialogue_261022.json").get("scenes", {})
	var outline: Dictionary = _read_json("res://data/story_outline_261022.json")
	ending_rule = outline.get("ending_rule", {})
	relationship_rules = outline.get("affection", {})
	for item in outline.get("choices", []):
		all_choices[item.scene_id] = item
	return story.size() == 5 and all_choices.size() == 3


func _lines(rows: Array) -> Array:
	var result: Array = []
	for row in rows:
		result.append({"speaker": row[0], "expression": row[1], "text": row[2]})
	return result


func start_scene() -> void:
	_close_overlay()
	_cancel_transition()
	gallery_replay = false
	selected_choices.clear()
	affection = 0
	_enter_scene("S01")


func show_menu() -> void:
	if not ui_ready:
		super.show_menu()
		return
	_close_overlay()
	_cancel_transition()
	gallery_replay = false
	selected_choices.clear()
	super.show_menu()
	toolbar.hide()
	relationship_panel.hide()
	relationship_panel.set_state(0)
	background_art.texture = art.rain
	character_art.texture = art.neutral
	$Chapter/Label.text = "비가 그치면, 한 잔 더"
	_play_music("cafe")


func _enter_scene(id: String) -> void:
	active_scene_id = id
	scene_data = story[id]
	phase = "ending" if id.begins_with("E") else "common"
	choice_data = all_choices.get(id, {})
	in_reaction = false
	chosen_option_id = ""
	current_lines = _lines(scene_data.lines)
	line_index = 0
	menu.hide()
	complete_panel.hide()
	choices_panel.hide()
	dialogue_panel.show()
	toolbar.show()
	next_button.disabled = false
	for button in [start_button, replay_button, menu_button, choice_a, choice_b]:
		button.release_focus()
	if not choice_data.is_empty():
		choice_a.text = choice_data.options[0].label
		choice_b.text = choice_data.options[1].label
	_apply_scene_art()
	_show_line()
	_sync_relationship()


func _sync_relationship() -> void:
	if relationship_panel:
		relationship_panel.visible = mode != Mode.MENU and not gallery_replay
		relationship_panel.set_state(affection)


func _apply_scene_art() -> void:
	if not ui_ready:
		return
	background_art.texture = art[scene_data.background]
	$Chapter/Label.text = ("엔딩 감상  ·  " if gallery_replay else "") + scene_data.title
	_play_music(scene_data.music)


func _show_line() -> void:
	super._show_line()
	if ui_ready:
		character_art.texture = art[current_lines[line_index].expression]


func _finish_reveal() -> void:
	super._finish_reveal()
	if line_index == current_lines.size() - 1:
		next_button.text = {"common": "답변 고르기", "reaction": "다음 만남", "ending": "이야기 마치기"}.get(phase, "다음")
		if phase == "reaction" and active_scene_id == "S03":
			next_button.text = "마지막 이야기"


func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		toast.visible = toast_time > 0.0
	if not overlay_kind.is_empty() or transitioning:
		return
	if relationship_panel:
		relationship_panel.tick(delta)
	super._process(delta)


func advance() -> void:
	if not overlay_kind.is_empty() or transitioning or mode != Mode.DIALOGUE:
		return
	if typing:
		_finish_reveal()
		return
	_play_sfx("confirm")
	if line_index + 1 < current_lines.size():
		line_index += 1
		_show_line()
	elif phase == "common":
		_offer_choice()
	elif phase == "reaction":
		var next_id: String = choice_data.next.get("scene_id", "")
		if next_id.is_empty():
			next_id = _resolved_ending(affection)
		_transition_to(next_id)
	else:
		_finish_ending()


func _offer_choice() -> void:
	phase = "choice"
	relationship_panel.clear_feedback()
	mode = Mode.CHOICE
	typing = false
	choices_panel.show()
	choice_a.disabled = false
	choice_b.disabled = false
	next_button.disabled = true
	hint.text = "방향키로 이동 · Enter로 선택"
	choice_a.grab_focus()


func _select_option(index: int) -> void:
	if mode != Mode.CHOICE or not overlay_kind.is_empty() or transitioning or selected_choices.has(choice_data.id):
		return
	var option: Dictionary = choice_data.options[index]
	selected_choices[choice_data.id] = option.id
	chosen_option_id = option.id
	affection = _score(selected_choices)
	phase = "reaction"
	in_reaction = true
	current_lines = _lines(scene_data.reactions[option.id] + scene_data.closing)
	line_index = 0
	choices_panel.hide()
	for button in [choice_a, choice_b]:
		button.disabled = true
		button.release_focus()
	next_button.disabled = false
	_play_sfx("select")
	_show_line()
	relationship_panel.set_state(affection, true)


func _score(picks: Dictionary) -> int:
	var score: int = 0
	for data in all_choices.values():
		for option in data.options:
			if picks.get(data.id, "") == option.id:
				score += int(option.affection_delta)
	return score


func _resolved_ending(score: int) -> String:
	return ending_rule.at_or_above_scene_id if score >= int(ending_rule.threshold) else ending_rule.below_scene_id


func _transition_to(id: String) -> void:
	_play_sfx("transition")
	if not transitions_enabled or not settings.transitions:
		_enter_scene(id)
		return
	transitioning = true
	fade.show()
	fade.modulate.a = 0.0
	transition_tween = create_tween()
	transition_tween.tween_property(fade, "modulate:a", 1.0, 0.22)
	transition_tween.tween_callback(_enter_scene.bind(id))
	transition_tween.tween_property(fade, "modulate:a", 0.0, 0.3)
	transition_tween.tween_callback(func():
		transitioning = false
		fade.hide())


func _cancel_transition() -> void:
	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()
	transitioning = false
	if fade:
		fade.hide()


func _finish_ending() -> void:
	if gallery_replay:
		var previous: Dictionary = gallery_return.duplicate(true)
		gallery_replay = false
		if previous.get("menu", true):
			show_menu()
		else:
			_restore(previous.snapshot)
			_show_complete()
		return
	if not seen_endings.has(active_scene_id):
		seen_endings.append(active_scene_id)
		if not _write_file("profile_261022.json", {"schema": 1, "seen_endings": seen_endings}):
			_notify("엔딩 기록을 저장하지 못했습니다. 저장 폴더를 확인해 주세요.")
	_show_complete()


func _show_complete() -> void:
	super._show_complete()
	typing = false
	toolbar.hide()
	_sync_relationship()
	$Complete/Margin/Content/Title.text = scene_data.title
	$Complete/Margin/Content/Summary.text = scene_data.summary


func _on_dialogue_input(event: InputEvent) -> void:
	if overlay_kind.is_empty() and not transitioning:
		super._on_dialogue_input(event)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		if transitioning:
			get_viewport().set_input_as_handled()
			return
		if not overlay_kind.is_empty():
			_close_overlay()
		elif gallery_replay:
			_finish_ending()
		elif mode != Mode.MENU:
			_open_pause()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_accept") and overlay_kind.is_empty() and not transitioning and mode == Mode.DIALOGUE:
		advance()
		get_viewport().set_input_as_handled()


# 메뉴와 대화창은 컨테이너 레이아웃을 유지하고, 그림만 화면 뒤에 배치합니다.
func _build_ui() -> void:
	theme = theme.duplicate()
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansKR_261022.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 400.0}
	theme.default_font = font
	$Background.hide()
	$Portrait.hide()
	for key in ["rain", "evening"]:
		art[key] = load("res://assets/art/cafe_%s_261022.png" % key)
	for key in ["neutral", "smile", "thoughtful", "shy"]:
		art[key] = load("res://assets/art/seoyun_%s_261022.png" % key)
	background_art = TextureRect.new()
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background_art)
	background_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(background_art, 0)
	character_art = TextureRect.new()
	character_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(character_art)
	character_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_art.anchor_left = 0.54
	character_art.anchor_top = 0.11
	character_art.anchor_bottom = 1.27
	move_child(character_art, 1)
	$Shade.color = Color(0.02, 0.035, 0.04, 0.12)
	$Chapter.anchor_right = 0.53
	menu.anchor_top = 0.16
	menu.anchor_bottom = 0.94
	$Menu/Margin/Content.add_theme_constant_override("separation", 9)
	$Menu/Margin.add_theme_constant_override("margin_top", 20)
	$Menu/Margin.add_theme_constant_override("margin_bottom", 20)
	$Menu/Margin/Content/Title.add_theme_font_size_override("font_size", 34)
	$Menu/Margin/Content/Subtitle.text = "31단계 실습 · 서윤과의 관계 알아보기"
	$Menu/Margin/Content/Hint.text = "클릭 · Enter · Space로 대화 / Esc로 잠깐 멈춤"
	start_button.text = "새 이야기"
	start_button.custom_minimum_size.y = 44
	var content: VBoxContainer = $Menu/Margin/Content
	for spec in [["불러오기", func(): _open_slots(false)], ["엔딩 감상", _open_gallery], ["설정 · 제작 정보", _open_settings]]:
		var button: Button = _button(spec[0], spec[1], content)
		content.move_child(button, content.get_child_count() - 2)
	choice_a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Choices.anchor_right = 0.66
	$Choices.anchor_top = 0.19
	$Choices.anchor_bottom = 0.55
	$Complete.anchor_top = 0.19
	$Complete.anchor_bottom = 0.9
	$Complete/Margin/Content/Title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("엔딩 감상", _open_gallery, $Complete/Margin/Content)
	replay_button.text = "처음부터 다시"
	relationship_panel = load("res://scripts/relationship_panel_261022.gd").new()
	relationship_panel.name = "Relationship"
	add_child(relationship_panel)
	relationship_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	relationship_panel.anchor_left = 0.05
	relationship_panel.anchor_right = 0.47
	relationship_panel.anchor_top = 0.115
	relationship_panel.anchor_bottom = 0.27
	relationship_panel.setup(relationship_rules)
	toolbar = HBoxContainer.new()
	add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toolbar.anchor_left = 0.54
	toolbar.anchor_right = 0.95
	toolbar.anchor_top = 0.035
	toolbar.anchor_bottom = 0.105
	toolbar.alignment = BoxContainer.ALIGNMENT_END
	for spec in [["저장", func(): _open_slots(true)], ["불러오기", func(): _open_slots(false)], ["설정", _open_settings], ["메뉴", _open_pause]]:
		var button: Button = _button(spec[0], spec[1], toolbar)
		button.add_theme_font_size_override("font_size", 17)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", theme.get_stylebox("normal", "Button"))
	fade = ColorRect.new()
	fade.color = Color(0.03, 0.045, 0.05)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.hide()
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	overlay = Control.new()
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.theme = theme
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.025, 0.03, 0.8)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.16
	panel.anchor_right = 0.84
	panel.anchor_top = 0.13
	panel.anchor_bottom = 0.9
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	overlay_content = VBoxContainer.new()
	overlay_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_content.add_theme_constant_override("separation", 12)
	scroll.add_child(overlay_content)
	overlay.hide()
	toast = Label.new()
	toast.theme = theme
	toast.add_theme_font_size_override("font_size", 18)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast.anchor_top = 0.92
	toast.anchor_bottom = 0.99
	toast.hide()
	bgm = AudioStreamPlayer.new()
	sfx = AudioStreamPlayer.new()
	add_child(bgm)
	add_child(sfx)


func _button(text_value: String, action: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _label(text_value: String, size_value: int = 22) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_content.add_child(label)
	return label


func _open_overlay(kind: String, title_value: String) -> void:
	if transitioning:
		return
	overlay_kind = kind
	for child in overlay_content.get_children():
		overlay_content.remove_child(child)
		child.queue_free()
	overlay.show()
	_label(title_value, 28)
	# Mouse filtering alone does not block keyboard focus on controls behind a modal.
	for path in ["Menu", "Dialogue", "Choices", "Complete"]:
		get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	toolbar.process_mode = Node.PROCESS_MODE_DISABLED


func _close_overlay() -> void:
	if not overlay:
		return
	overlay.hide()
	overlay_kind = ""
	for path in ["Menu", "Dialogue", "Choices", "Complete"]:
		get_node(path).process_mode = Node.PROCESS_MODE_INHERIT
	toolbar.process_mode = Node.PROCESS_MODE_INHERIT
	if mode == Mode.CHOICE:
		choice_a.grab_focus()
	elif mode == Mode.MENU:
		start_button.grab_focus()
	elif mode == Mode.COMPLETE:
		replay_button.grab_focus()


func _close_button() -> void:
	_button("닫기 · Esc", _close_overlay, overlay_content).grab_focus()


func _open_pause() -> void:
	_open_overlay("pause", "잠깐 쉬어가기")
	_label("시작 화면으로 가기 전에 저장하면 이 자리에서 이어갈 수 있어요.", 20)
	_button("이야기로 돌아가기", _close_overlay, overlay_content).grab_focus()
	_button("저장하기", func(): _open_slots(true), overlay_content)
	_button("시작 화면으로", show_menu, overlay_content)


func _open_slots(saving: bool) -> void:
	_open_overlay("slots", "저장하기" if saving else "불러오기")
	if saving and not _can_save():
		_label("이야기를 진행하는 중에 저장할 수 있습니다. 엔딩 감상은 저장하지 않습니다.", 20)
	for slot in range(1, 4):
		var saved: Dictionary = _read_file("save_%d_261022.json" % slot)
		var state: Dictionary = saved.get("state", {}) if saved.get("state", {}) is Dictionary else {}
		var valid: bool = _valid_snapshot(state)
		var caption: String = "비어 있음"
		if FileAccess.file_exists(_path("save_%d_261022.json" % slot)):
			caption = _slot_caption(state, saved.get("saved_at", "")) if valid else "읽을 수 없는 저장 파일"
		_label("슬롯 %d  |  %s" % [slot, caption], 19)
		var row := HBoxContainer.new()
		overlay_content.add_child(row)
		if saving:
			var save_button := _button("덮어쓰기" if valid else "여기에 저장", func():
				if save_slot(slot):
					_open_slots(true), row)
			save_button.disabled = not _can_save()
		var load_button := _button("불러오기", func(): load_slot(slot), row)
		load_button.disabled = not valid
	_close_button()


func _slot_caption(state: Dictionary, saved_at: String) -> String:
	return "%s · 대화 %d · %s" % [story[state.scene_id].title, int(state.line_index) + 1, saved_at]


func _open_gallery() -> void:
	if mode != Mode.MENU and mode != Mode.COMPLETE:
		return
	_open_overlay("gallery", "엔딩 감상")
	_label("끝까지 읽은 엔딩을 다시 볼 수 있습니다.", 20)
	for id in ["E01", "E02"]:
		var unlocked: bool = seen_endings.has(id)
		var button := _button(story[id].title if unlocked else "미확인 엔딩", func(): _replay_ending(id), overlay_content)
		button.disabled = not unlocked
	_close_button()


func _replay_ending(id: String) -> void:
	if not seen_endings.has(id) or (mode != Mode.MENU and mode != Mode.COMPLETE):
		return
	gallery_return = {"menu": mode == Mode.MENU, "snapshot": snapshot()}
	_close_overlay()
	gallery_replay = true
	_enter_scene(id)


func _open_settings() -> void:
	_open_overlay("settings", "설정")
	_label("글자 표시 속도 · 0이면 한 번에 표시", 19)
	var speed := HSlider.new()
	speed.min_value = 0
	speed.max_value = 90
	speed.step = 1
	speed.value = settings.speed
	speed.custom_minimum_size.y = 28
	overlay_content.add_child(speed)
	speed.value_changed.connect(func(value: float):
		settings.speed = value
		characters_per_second = value
		if value == 0 and typing:
			_finish_reveal()
		_save_settings())
	for spec in [["music", "배경 음악", "music_db"], ["sfx", "효과음", "sfx_db"]]:
		var toggle := CheckButton.new()
		toggle.text = spec[1]
		toggle.button_pressed = settings[spec[0]]
		overlay_content.add_child(toggle)
		toggle.toggled.connect(func(value: bool):
			settings[spec[0]] = value
			_apply_audio_settings()
			_save_settings())
		var volume := HSlider.new()
		volume.min_value = -40
		volume.max_value = 0
		volume.value = settings[spec[2]]
		volume.custom_minimum_size.y = 24
		overlay_content.add_child(volume)
		volume.value_changed.connect(func(value: float):
			settings[spec[2]] = value
			_apply_audio_settings()
			_save_settings())
	var transitions := CheckButton.new()
	transitions.text = "장면 전환 효과"
	transitions.button_pressed = settings.transitions
	overlay_content.add_child(transitions)
	transitions.toggled.connect(func(value: bool):
		settings.transitions = value
		_save_settings())
	_button("제작 · 자산 정보", _open_credits, overlay_content)
	_close_button()


func _open_credits() -> void:
	_open_overlay("credits", "제작 · 자산 정보")
	_label("비가 그치면, 한 잔 더\nGodot 게임 제작 학습 프로젝트", 22)
	_label("대본 · 프로그래밍 · 합성 음악/효과음: 이 프로젝트에서 제작\n배경 2종 · 서윤 표정 4종: OpenAI image_gen으로 생성\n글꼴: Noto Sans KR / Adobe / SIL Open Font License 1.1\n게임 엔진: Godot / MIT License", 18)
	_label(str(ProjectSettings.get_setting("application/config/version")) + " · 자세한 출처는 assets/ASSET_SOURCES_261022.md에 있습니다.\n서윤 28세 · 주인공 29세. 짧은 만남과 관계를 다룬 오리지널 이야기입니다.\n그림과 대본 등은 AI 도움으로 제작했으며 실행 중 AI를 사용하지 않습니다.", 18)
	_button("엔진 · 글꼴 라이선스 전문", _open_licenses, overlay_content)
	_close_button()


func _open_licenses() -> void:
	_open_overlay("licenses", "엔진 · 글꼴 라이선스")
	_label(Engine.get_license_text(), 17)
	_label(FileAccess.get_file_as_string("res://assets/fonts/NotoSansKR_OFL_261022.txt"), 17)
	_label("추가 엔진 구성 요소의 고지는 배포본 licenses/Godot_ThirdParty_261022.txt에 포함되어 있습니다.", 17)
	_close_button()


func _notify(message: String) -> void:
	if toast:
		toast.text = message
		toast_time = 4.0
		toast.show()


# 슬롯 파일은 검증이 끝난 뒤에만 실행 상태에 반영합니다.
func _path(name_value: String) -> String:
	return user_data_root.path_join(name_value)


func _read_file(name_value: String) -> Dictionary:
	if not FileAccess.file_exists(_path(name_value)):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(_path(name_value))) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


func _write_file(name_value: String, value: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(user_data_root) != OK:
		return false
	var target: String = _path(name_value)
	var temporary: String = target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(temporary, target) == OK


func _load_preferences() -> void:
	var saved_settings: Dictionary = _read_file("settings_261022.json")
	if saved_settings.get("schema") == 1 and saved_settings.get("settings") is Dictionary:
		var values: Dictionary = saved_settings.settings
		for key in ["music", "sfx", "transitions"]:
			if values.get(key) is bool:
				settings[key] = values[key]
		for key in ["speed", "music_db", "sfx_db"]:
			if _number(values.get(key)):
				settings[key] = clampf(float(values[key]), 0.0 if key == "speed" else -40.0, 90.0 if key == "speed" else 0.0)
	characters_per_second = settings.speed
	var profile: Dictionary = _read_file("profile_261022.json")
	if profile.get("schema") == 1 and profile.get("seen_endings") is Array:
		for id in profile.seen_endings:
			if id in ["E01", "E02"] and not seen_endings.has(id):
				seen_endings.append(id)
	_apply_audio_settings()


func _save_settings() -> void:
	if not _write_file("settings_261022.json", {"schema": 1, "settings": settings}):
		_notify("설정을 저장하지 못했습니다.")


func _can_save() -> bool:
	return mode in [Mode.DIALOGUE, Mode.CHOICE] and not gallery_replay and not transitioning


func snapshot() -> Dictionary:
	if current_lines.is_empty():
		return {}
	return {"schema": 1, "story_version": 1, "scene_id": active_scene_id, "phase": phase,
		"line_index": line_index, "selected_choices": selected_choices.duplicate(), "affection": affection,
		"visible_characters": body.visible_characters, "typing": typing,
		"background": scene_data.background, "expression": current_lines[line_index].expression}


func save_slot(slot: int) -> bool:
	if slot < 1 or slot > 3 or not _can_save():
		_notify("지금은 저장할 수 없습니다.")
		return false
	var state: Dictionary = snapshot()
	if not _valid_snapshot(state):
		_notify("현재 진행 상태를 저장하지 못했습니다.")
		return false
	var success: bool = _write_file("save_%d_261022.json" % slot, {"saved_at": Time.get_datetime_string_from_system().replace("T", " "), "state": state})
	_notify("슬롯 %d에 저장했습니다." % slot if success else "저장하지 못했습니다. 저장 폴더를 확인해 주세요.")
	return success


func load_slot(slot: int) -> bool:
	if slot < 1 or slot > 3:
		return false
	var saved: Dictionary = _read_file("save_%d_261022.json" % slot)
	var state: Variant = saved.get("state")
	if not state is Dictionary or not _valid_snapshot(state):
		_notify("저장 파일이 없거나 형식이 맞지 않아 불러올 수 없습니다.")
		return false
	_close_overlay()
	_cancel_transition()
	gallery_replay = false
	_restore(state)
	_notify("슬롯 %d에서 이어갑니다." % slot)
	return true


func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floorf(float(value))


func _valid_snapshot(state: Dictionary) -> bool:
	if state.get("schema") != 1 or state.get("story_version") != 1 or not state.get("scene_id") is String or not story.has(state.scene_id):
		return false
	if not state.get("phase") is String or not state.get("selected_choices") is Dictionary or not state.get("typing") is bool:
		return false
	if not _integer(state.get("line_index")) or not _integer(state.get("affection")) or not _integer(state.get("visible_characters")):
		return false
	var id: String = state.scene_id
	var step: String = state.phase
	var picks: Dictionary = state.selected_choices
	var expected_count: int = 3 if id.begins_with("E") else int(id.right(2)) - 1
	if id.begins_with("E"):
		if step != "ending":
			return false
	elif step not in ["common", "choice", "reaction"]:
		return false
	elif step == "reaction":
		expected_count += 1
	if picks.size() != expected_count:
		return false
	for index in range(expected_count):
		var choice_id: String = "C%02d" % (index + 1)
		if picks.get(choice_id) not in [choice_id + "_A", choice_id + "_B"]:
			return false
	var score: int = _score(picks)
	if score != int(state.affection):
		return false
	if id.begins_with("E") and id != _resolved_ending(score):
		return false
	var data: Dictionary = story[id]
	var rows: Array = data.lines
	if step == "reaction":
		rows = data.reactions[picks[data.choice_id]] + data.closing
	var index: int = int(state.line_index)
	if index < 0 or index >= rows.size():
		return false
	if state.get("background") != data.background or state.get("expression") != rows[index][1]:
		return false
	var count: int = int(state.visible_characters)
	if count < -1 or count > str(rows[index][2]).length() or (state.typing and count == -1) or (not state.typing and count != -1):
		return false
	if step == "choice" and (index != rows.size() - 1 or state.typing):
		return false
	return true


func _restore(state: Dictionary) -> void:
	selected_choices = state.selected_choices.duplicate()
	affection = _score(selected_choices)
	_enter_scene(state.scene_id)
	phase = state.phase
	in_reaction = phase == "reaction"
	if in_reaction:
		chosen_option_id = selected_choices[choice_data.id]
		current_lines = _lines(scene_data.reactions[chosen_option_id] + scene_data.closing)
	line_index = int(state.line_index)
	_show_line()
	if state.typing:
		typing = true
		revealed_count = float(state.visible_characters)
		body.visible_characters = int(state.visible_characters)
	else:
		_finish_reveal()
	if phase == "choice":
		_offer_choice()


func _play_music(track: String) -> void:
	if not bgm or track == current_music:
		return
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	current_music = track
	var stream: AudioStreamWAV = load("res://assets/audio/%s_261022.wav" % track).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
	bgm.stream = stream
	bgm.volume_db = -60
	if settings.music:
		bgm.play()
	music_tween = create_tween()
	music_tween.tween_property(bgm, "volume_db", float(settings.music_db), 0.6)


func _play_sfx(name_value: String) -> void:
	if sfx and settings.sfx:
		sfx.stream = load("res://assets/audio/%s_261022.wav" % name_value)
		sfx.volume_db = settings.sfx_db
		sfx.play()


func _apply_audio_settings() -> void:
	if not bgm:
		return
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	bgm.volume_db = settings.music_db
	if settings.music and not bgm.playing and bgm.stream:
		bgm.play()
	elif not settings.music:
		bgm.stop()
	sfx.volume_db = settings.sfx_db
	if not settings.sfx:
		sfx.stop()


func _exit_tree() -> void:
	if bgm:
		bgm.stop()
	if sfx:
		sfx.stop()
