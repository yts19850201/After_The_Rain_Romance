extends SceneTree

var failures: int = 0
var game
const TEST_ROOT: String = "res://.godot/romance_test_261022"

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame

func _key(key: Key, echo_value: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		event.echo = echo_value and pressed
		Input.parse_input_event(event)
		await _frames()

func _click(control: Control) -> void:
	await _frames(5)
	var position: Vector2 = control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames()

func _to_choice() -> void:
	for step in range(150):
		if game.mode != game.Mode.DIALOGUE:
			break
		game.advance()
	_check(game.mode == game.Mode.CHOICE, "Expected a choice")

func _finish_part() -> void:
	var id: String = game.active_scene_id
	for step in range(150):
		if game.active_scene_id != id or game.mode == game.Mode.COMPLETE:
			break
		game.advance()

func _capture(name_value: String) -> void:
	await _frames(6)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://.godot/qa_%s_261022.png" % name_value) == OK, "Capture failed")

func _same_position(expected: Dictionary, caption: String) -> void:
	_check(game.snapshot() == expected, caption)

func _ui_bounds() -> void:
	await _frames(8)
	for control in [game.menu, game.start_button, game.toolbar, game.dialogue_panel, game.choices_panel, game.complete_panel]:
		if control.is_visible_in_tree():
			_check(root.get_visible_rect().encloses(control.get_global_rect()), "UI outside viewport: " + str(control.get_path()))
	if game.choices_panel.visible:
		_check(not game.choices_panel.get_global_rect().intersects(game.dialogue_panel.get_global_rect()), "Choices overlap dialogue")
	if game.dialogue_panel.visible:
		_check(game.body.get_content_height() <= game.body.size.y + 1.0, "Dialogue text is clipped")

func _all_text_bounds() -> void:
	for id in game.story:
		game._enter_scene(id)
		var groups: Array = [game.scene_data.lines]
		for rows in game.scene_data.get("reactions", {}).values():
			groups.append(rows + game.scene_data.closing)
		for group in groups:
			game.current_lines = game._lines(group)
			for index in range(game.current_lines.size()):
				game.line_index = index
				game._show_line()
				game._finish_reveal()
				await _frames(1)
				_check(game.body.get_content_height() <= game.body.size.y + 1.0, "Text clipping at %s:%d" % [id, index])

func _run() -> void:
	game = load("res://scenes/novel_261022.tscn").instantiate()
	game.user_data_root = TEST_ROOT
	root.add_child(game)
	await _frames(8)
	game.transitions_enabled = false
	game.settings.music = true
	game._apply_audio_settings()
	_check(game.bgm.playing and game.bgm.stream.loop_end == 441000, "Music playback or full loop length is wrong")
	game.settings.sfx = true
	game._play_sfx("confirm")
	_check(game.sfx.playing, "Confirmation sound did not start")
	game.settings.sfx = false
	game.settings.music = false
	game._apply_audio_settings()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--persist-read"):
		_check(game.load_slot(3), "Fresh process could not load")
		_check(game.active_scene_id == "S02" and game.phase == "reaction" and game.affection == 2 and game.selected_choices.size() == 2, "Fresh process loaded wrong state")
		_check(game.seen_endings.size() == 2 and game.settings.speed == 41, "Profile/settings did not persist separately")
		_finish_part()
		_check(game.active_scene_id == "S03" and game.affection == 2, "Score duplicated on fresh-process resume")
		await _finish()
		return
	# Test files only: ordinary play data is never touched.
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)
	for name_value in ["save_1_261022.json", "save_2_261022.json", "save_3_261022.json", "profile_261022.json", "settings_261022.json"]:
		DirAccess.remove_absolute(TEST_ROOT.path_join(name_value))
	game.seen_endings.clear()
	await _ui_bounds()
	await _capture("26_menu")
	game._open_gallery()
	_check(game.overlay_content.get_child(2).disabled and game.overlay_content.get_child(3).disabled, "Unseen ending was unlocked")
	game._close_overlay()
	await _key(KEY_ENTER)
	_check(game.line_index == 0 and game.typing, "Start confirm skipped the first line")
	await _key(KEY_SPACE)
	_check(game.line_index == 0 and not game.typing, "Reveal advanced twice")
	await _key(KEY_SPACE, true)
	_check(game.line_index == 0, "Echo key advanced story")
	await _key(KEY_SPACE)
	_check(game.line_index == 1, "Confirm failed to advance once")
	game.characters_per_second = 0
	game._finish_reveal()
	await _capture("26_dialogue")
	# A modal must freeze both text and input behind it, including keyboard focus.
	game._open_settings()
	game.overlay_content.get_child(2).grab_focus()
	var frozen: Dictionary = game.snapshot()
	await _key(KEY_SPACE)
	_same_position(frozen, "Settings key leaked into dialogue")
	await _capture("26_settings")
	await _key(KEY_ESCAPE)
	_check(game.overlay_kind.is_empty() and game.line_index == 1, "Esc reset story")
	# Partial text survives a save, including exact reveal position.
	game.characters_per_second = 32
	game._show_line()
	game.body.visible_characters = 7
	game.revealed_count = 7
	var partial: Dictionary = game.snapshot()
	_check(game.save_slot(1), "Partial save failed")
	game.advance()
	_check(game.load_slot(1), "Partial load failed")
	_same_position(partial, "Partial reveal was not restored")
	game.characters_per_second = 0
	game._finish_reveal()
	_to_choice()
	await _ui_bounds()
	await _capture("26_choices")
	var choosing: Dictionary = game.snapshot()
	_check(game.save_slot(2), "Choice save failed")
	game._open_settings()
	game.overlay_content.get_child(2).grab_focus()
	await _key(KEY_SPACE)
	_same_position(choosing, "Modal key selected a choice behind the overlay")
	await _key(KEY_ESCAPE)
	await _key(KEY_ENTER)
	_check(game.phase == "reaction" and game.line_index == 0 and game.affection == 1, "Choice confirm skipped reaction or scored twice")
	game._select_option(0)
	_check(game.affection == 1, "Repeated choice scored twice")
	_check(game.load_slot(2), "Choice load failed")
	_same_position(choosing, "Choice state not restored")
	await _click(game.choice_b)
	_check(game.phase == "reaction" and game.affection == 0, "Mouse did not select alternative")
	var reaction: Dictionary = game.snapshot()
	_check(game.save_slot(2) and game.load_slot(2), "Overwrite/reaction resume failed")
	_same_position(reaction, "Reaction resume changed state")
	_finish_part()
	_check(game.active_scene_id == "S02" and game.affection == 0, "Wrong scene after reaction resume")
	# All eight complete routes, not only the endpoint score calculation.
	var endings: Dictionary = {"E01": 0, "E02": 0}
	for combination in range(8):
		game.start_scene()
		var score: int = 0
		for visit in range(3):
			_check(game.active_scene_id == "S%02d" % (visit + 1), "Scene order changed")
			_to_choice()
			var option_index: int = (combination >> visit) & 1
			score += 1 if option_index == 0 else 0
			game._select_option(option_index)
			_check(game.affection == score, "Score wrong at visit")
			_finish_part()
		var ending: String = "E01" if score >= 2 else "E02"
		_check(game.active_scene_id == ending, "Wrong route ending")
		_check(game.save_slot(1) and game.load_slot(1), "Ending save/load failed")
		_finish_part()
		_check(game.mode == game.Mode.COMPLETE, "Ending did not finish")
		endings[ending] += 1
		if combination in [0, 7]:
			await _capture("26_" + ending)
	_check(endings == {"E01": 4, "E02": 4}, "Route coverage should be 4+4")
	_check(game.seen_endings.size() == 2, "Gallery did not record endings")
	var complete_snapshot: Dictionary = game.snapshot()
	var save_before: String = FileAccess.get_file_as_string(TEST_ROOT.path_join("save_1_261022.json"))
	game._open_gallery()
	await _capture("26_gallery")
	game._replay_ending("E01")
	_check(not game.save_slot(1), "Gallery replay could overwrite progress")
	_finish_part()
	_check(game.mode == game.Mode.COMPLETE and not game.gallery_replay, "Gallery did not return to completion")
	_same_position(complete_snapshot, "Gallery changed completed story")
	_check(FileAccess.get_file_as_string(TEST_ROOT.path_join("save_1_261022.json")) == save_before, "Gallery changed a slot")
	game.show_menu()
	game._replay_ending("E02")
	_finish_part()
	_check(game.mode == game.Mode.MENU, "Menu gallery did not return to menu")
	game.start_scene()
	_check(game.affection == 0 and game.selected_choices.is_empty(), "New game retained score")
	# Save a second-visit reaction for an entirely new Godot process to load.
	_to_choice()
	game._select_option(0)
	_finish_part()
	_to_choice()
	game._select_option(0)
	_check(game.save_slot(3), "Persistent test save failed")
	game.settings.speed = 41
	game._save_settings()
	var valid: Dictionary = game.snapshot()
	for mutation in [{"schema": 99}, {"story_version": 999}, {"scene_id": "UNKNOWN"}, {"phase": "ending"}, {"line_index": -1}, {"line_index": 1.5}, {"affection": 3}, {"selected_choices": {"C02": "C02_A"}}, {"visible_characters": -8}, {"expression": "bad"}, {"background": "bad"}, {"typing": "true"}]:
		var invalid: Dictionary = valid.duplicate(true)
		invalid.merge(mutation, true)
		_check(not game._valid_snapshot(invalid), "Malformed save accepted: " + str(mutation))
	var broken := FileAccess.open(TEST_ROOT.path_join("save_2_261022.json"), FileAccess.WRITE)
	broken.store_string("{broken-json")
	broken.close()
	_check(not game.load_slot(2), "Corrupt save accepted")
	_same_position(valid, "Failed load changed progress")
	game._open_slots(false)
	await _capture("26_slots")
	game._close_overlay()
	# Check all dialogue, reactions and ending text at both supported sizes.
	await _all_text_bounds()
	# Actual animated transition completes and blocks input while fading.
	game.start_scene()
	game.transitions_enabled = true
	game.settings.transitions = true
	game._transition_to("S02")
	_check(game.transitioning, "Fade did not start")
	game.advance()
	_check(game.line_index == 0, "Input advanced during fade")
	await create_timer(0.7).timeout
	_check(game.active_scene_id == "S02" and not game.transitioning, "Fade did not complete")
	# Smaller supported window and the longest choice.
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960, 540)
		await _frames(8)
	game.transitions_enabled = false
	game.characters_per_second = 0
	await _all_text_bounds()
	game._enter_scene("S03")
	_to_choice()
	await _ui_bounds()
	await _capture("26_small_choices")
	game.show_menu()
	await _ui_bounds()
	await _capture("26_small_menu")
	# Each final expression is inspected against the bright cafe background.
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		await _frames(5)
	game.start_scene()
	game._finish_reveal()
	for expression in ["neutral", "smile", "thoughtful", "shy"]:
		game.character_art.texture = game.art[expression]
		await _capture("26_portrait_" + expression)
	await _finish()

func _finish() -> void:
	game.bgm.stop()
	game.sfx.stop()
	OS.delay_msec(120) # Allow the audio thread to release stopped playbacks.
	game.queue_free()
	await _frames(10)
	print("NOVEL TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
