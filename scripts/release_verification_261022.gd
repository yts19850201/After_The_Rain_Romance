extends Node

# --verify-release 옵션을 명시한 경우에만 실행하는 배포 검증입니다.
# 실제 플레이 저장과 분리한 --qa-data 절대 경로가 필수입니다.
var root: Window
var game
var failures: int = 0
var data_root: String = ""
var screenshot_root: String = ""

func run(game_instance: Control) -> void:
	game = game_instance
	root = get_tree().root
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if args[index] == "--qa-data":
			data_root = args[index + 1]
		elif args[index] == "--screenshots":
			screenshot_root = args[index + 1]
	if data_root.is_empty() or not data_root.is_absolute_path():
		push_error("An absolute --qa-data folder is required")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _frames(count: int = 4) -> void:
	for index in range(count):
		await get_tree().process_frame

func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames()

func _to_choice() -> void:
	for index in range(150):
		if game.mode != game.Mode.DIALOGUE:
			break
		game.advance()
	_check(game.mode == game.Mode.CHOICE, "Did not reach a packaged choice")

func _finish_part() -> void:
	var scene_id: String = game.active_scene_id
	for index in range(150):
		if game.active_scene_id != scene_id or game.mode == game.Mode.COMPLETE:
			break
		game.advance()

func _capture(name_value: String) -> void:
	if screenshot_root.is_empty() or DisplayServer.get_name() == "headless":
		return
	if game.toast_time > 0.0:
		await get_tree().create_timer(4.2).timeout
	await _frames(6)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(screenshot_root.path_join(name_value + "_261022.png")) == OK, "Screenshot failed")

func _run() -> void:
	_check(not OS.has_feature("editor"), "This test must use the exported executable")
	_check(not ResourceLoader.exists("res://tests/novel_flow_261022.gd"), "Test code was included in PCK")
	_check(not FileAccess.file_exists("res://planning/game_plan_261022.md"), "Planning docs were included in PCK")
	_check(FileAccess.file_exists("res://data/story_dialogue_261022.json"), "Story JSON missing from PCK")
	game.user_data_root = data_root
	await _frames(10)
	game.settings.music = false
	game.settings.sfx = false
	game._apply_audio_settings()
	game.transitions_enabled = false
	_check(game.story.size() == 5 and game.art.size() == 6, "Packaged data incomplete")
	_check(not FileAccess.get_file_as_string("res://assets/fonts/NotoSansKR_OFL_261022.txt").is_empty(), "Packaged font notice missing")
	if OS.get_cmdline_user_args().has("--read"):
		_check(game.load_slot(3), "Fresh exported process could not load slot")
		_check(game.active_scene_id == "S02" and game.phase == "reaction" and game.affection == 2, "Fresh exported state wrong")
		_check(game.seen_endings.size() == 2 and game.settings.speed == 47, "Exported profile/settings did not persist")
		game.characters_per_second = 0
		game._finish_reveal()
		_finish_part()
		_check(game.active_scene_id == "S03" and game.affection == 2, "Exported resume duplicated points")
		await _finish()
		return
	DirAccess.make_dir_recursive_absolute(data_root)
	for name_value in ["save_1_261022.json", "save_2_261022.json", "save_3_261022.json", "profile_261022.json", "settings_261022.json"]:
		DirAccess.remove_absolute(data_root.path_join(name_value))
	game.seen_endings.clear()
	await _capture("title")
	await _key(KEY_ENTER)
	_check(game.line_index == 0 and game.typing, "Exported initial input skipped a line")
	await _key(KEY_SPACE)
	_check(game.line_index == 0 and not game.typing, "Exported reveal advanced twice")
	game.characters_per_second = 0
	for index in range(4):
		game.advance()
	await _capture("conversation")
	_to_choice()
	_check(game.save_slot(1), "Exported choice save failed")
	await _capture("choice")
	await _key(KEY_ENTER)
	_check(game.phase == "reaction" and game.affection == 1 and game.line_index == 0, "Exported choice skipped reaction or scored twice")
	_check(game.save_slot(2) and game.load_slot(2), "Exported reaction save/load failed")
	_finish_part()
	_check(game.active_scene_id == "S02" and game.affection == 1, "Exported reaction resume wrong")
	_check(game.load_slot(1) and game.mode == game.Mode.CHOICE and game.affection == 0, "Exported choice resume wrong")
	var endings: Dictionary = {"E01": 0, "E02": 0}
	for combination in range(8):
		game.start_scene()
		var expected_score: int = 0
		for visit in range(3):
			_to_choice()
			var index: int = (combination >> visit) & 1
			expected_score += 1 if index == 0 else 0
			game._select_option(index)
			_finish_part()
			_check(game.affection == expected_score, "Exported score mismatch")
			if visit == 1 and combination == 0:
				await _capture("evening")
		var ending: String = "E01" if expected_score >= 2 else "E02"
		_check(game.active_scene_id == ending, "Exported ending wrong")
		_finish_part()
		_check(game.mode == game.Mode.COMPLETE, "Exported ending incomplete")
		endings[ending] += 1
	_check(endings == {"E01": 4, "E02": 4}, "Exported route coverage wrong")
	var before: Dictionary = game.snapshot()
	game._replay_ending("E01")
	_check(not game.save_slot(1), "Exported gallery could overwrite slot")
	_finish_part()
	_check(game.snapshot() == before and game.mode == game.Mode.COMPLETE, "Exported gallery changed progress")
	game._open_credits()
	game._open_licenses()
	_check(game.overlay_kind == "licenses" and game.overlay_content.get_child_count() >= 5, "Exported license viewer failed")
	game._close_overlay()
	game.start_scene()
	_to_choice()
	game._select_option(0)
	_finish_part()
	_to_choice()
	game._select_option(0)
	_check(game.save_slot(3), "Exported persistence fixture failed")
	game.settings.speed = 47
	game._save_settings()
	var frozen: Dictionary = game.snapshot()
	var file := FileAccess.open(data_root.path_join("save_2_261022.json"), FileAccess.WRITE)
	file.store_string("{invalid")
	file.close()
	_check(not game.load_slot(2) and game.snapshot() == frozen, "Exported corrupt file changed progress")
	await _finish()

func _finish() -> void:
	game.bgm.stop()
	game.sfx.stop()
	OS.delay_msec(120)
	await _frames(8)
	print("RELEASE_SMOKE: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	get_tree().quit(0 if failures == 0 else 1)
