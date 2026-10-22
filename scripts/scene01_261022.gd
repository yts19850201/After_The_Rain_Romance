extends Control

enum Mode { MENU, DIALOGUE, CHOICE, COMPLETE }
@export_range(0.0, 90.0, 1.0) var characters_per_second: float = 32.0
@onready var menu: Control = $Menu
@onready var dialogue_panel: PanelContainer = $Dialogue
@onready var speaker_label: Label = $Dialogue/Margin/Content/Speaker
@onready var body: RichTextLabel = $Dialogue/Margin/Content/Body
@onready var hint: Label = $Dialogue/Margin/Content/Footer/Hint
@onready var next_button: Button = $Dialogue/Margin/Content/Footer/Next
@onready var choices_panel: Control = $Choices
@onready var choice_a: Button = $Choices/Margin/Content/A
@onready var choice_b: Button = $Choices/Margin/Content/B
@onready var complete_panel: Control = $Complete
@onready var start_button: Button = $Menu/Margin/Content/Start
@onready var replay_button: Button = $Complete/Margin/Content/Replay
@onready var menu_button: Button = $Complete/Margin/Content/Menu
@onready var portrait: Node2D = $Portrait

var mode: Mode = Mode.MENU
var affection: int = 0
var chosen_option_id: String = ""
var line_index: int = 0
var typing: bool = false
var in_reaction: bool = false
var revealed_count: float = 0.0
var scene_data: Dictionary = {}
var choice_data: Dictionary = {}
var current_lines: Array = []


func _ready() -> void:
	start_button.pressed.connect(start_scene)
	next_button.pressed.connect(advance)
	choice_a.pressed.connect(_choose_option.bind("C01_A"))
	choice_b.pressed.connect(_choose_option.bind("C01_B"))
	replay_button.pressed.connect(start_scene)
	menu_button.pressed.connect(show_menu)
	dialogue_panel.gui_input.connect(_on_dialogue_input)
	if not _load_dialogue():
		start_button.disabled = true
		$Menu/Margin/Content/Premise.text = "대화 데이터를 읽지 못했습니다. 프로젝트 파일을 확인해 주세요."
	show_menu()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing dialogue file: " + path)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_error("Invalid dialogue JSON: " + path)
		return {}
	return json.data


func _load_dialogue() -> bool:
	scene_data = _read_json("res://data/scene01_dialogue_261022.json")
	var outline: Dictionary = _read_json("res://data/story_outline_261022.json")
	for choice in outline.get("choices", []):
		if choice.get("id") == "C01":
			choice_data = choice
	if scene_data.get("scene_id") != "S01" or choice_data.get("options", []).size() != 2:
		return false
	if scene_data.get("common", []).is_empty() or scene_data.get("closing", []).is_empty():
		return false
	for option in choice_data.options:
		if scene_data.get("reactions", {}).get(option.id, []).is_empty():
			return false
	choice_a.text = choice_data.options[0].label
	choice_b.text = choice_data.options[1].label
	return true


func start_scene() -> void:
	if scene_data.is_empty() or choice_data.is_empty():
		return
	affection = 0
	chosen_option_id = ""
	in_reaction = false
	line_index = 0
	current_lines = scene_data.common
	menu.hide()
	complete_panel.hide()
	choices_panel.hide()
	dialogue_panel.show()
	next_button.disabled = false
	for button in [start_button, replay_button, menu_button, choice_a, choice_b]:
		button.release_focus()
	_show_line()


func show_menu() -> void:
	mode = Mode.MENU
	typing = false
	affection = 0
	chosen_option_id = ""
	portrait.expression = "neutral"
	dialogue_panel.hide()
	choices_panel.hide()
	complete_panel.hide()
	menu.show()
	if not start_button.disabled:
		start_button.grab_focus()


func _show_line() -> void:
	mode = Mode.DIALOGUE
	var line: Dictionary = current_lines[line_index]
	var speakers: Dictionary = {"narrator": "이야기", "player": "나", "seoyun": "서윤"}
	speaker_label.text = speakers.get(line.speaker, "이야기")
	body.text = line.text
	body.visible_characters = 0
	revealed_count = 0.0
	portrait.expression = line.get("expression", "neutral")
	typing = true
	next_button.text = "모두 표시"
	hint.text = "클릭 · Enter · Space로 문장 표시"
	if characters_per_second <= 0.0:
		_finish_reveal()


func _process(delta: float) -> void:
	if mode != Mode.DIALOGUE or not typing:
		return
	revealed_count += delta * characters_per_second
	body.visible_characters = int(revealed_count)
	if body.visible_characters >= body.get_total_character_count():
		_finish_reveal()


func _finish_reveal() -> void:
	typing = false
	body.visible_characters = -1
	hint.text = "클릭 · Enter · Space로 다음 대화"
	if line_index == current_lines.size() - 1:
		next_button.text = "첫 만남 마치기" if in_reaction else "답변 고르기"
	else:
		next_button.text = "다음"


func advance() -> void:
	if mode != Mode.DIALOGUE:
		return
	# 한 입력은 문장 완성 또는 다음 줄 진행 중 하나만 실행합니다.
	if typing:
		_finish_reveal()
		return
	if line_index < current_lines.size() - 1:
		line_index += 1
		_show_line()
	elif in_reaction:
		_show_complete()
	else:
		mode = Mode.CHOICE
		choices_panel.show()
		choice_a.disabled = false
		choice_b.disabled = false
		next_button.disabled = true
		hint.text = "답변을 선택해 주세요. 방향키로 이동하고 Enter로 고를 수 있습니다."
		choice_a.grab_focus()


func _choose_option(option_id: String) -> void:
	if mode != Mode.CHOICE or not chosen_option_id.is_empty():
		return
	for option in choice_data.options:
		if option.id != option_id:
			continue
		chosen_option_id = option_id
		affection += int(option.affection_delta)
		choice_a.disabled = true
		choice_b.disabled = true
		choice_a.release_focus()
		choice_b.release_focus()
		choices_panel.hide()
		next_button.disabled = false
		current_lines = scene_data.reactions[option_id].duplicate()
		current_lines.append_array(scene_data.closing)
		in_reaction = true
		line_index = 0
		_show_line()
		return


func _show_complete() -> void:
	mode = Mode.COMPLETE
	dialogue_panel.hide()
	choices_panel.hide()
	complete_panel.show()
	replay_button.grab_focus()


func _on_dialogue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance()
		dialogue_panel.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		show_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and mode == Mode.DIALOGUE:
		advance()
		get_viewport().set_input_as_handled()
