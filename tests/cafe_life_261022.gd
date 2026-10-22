extends SceneTree

var failures: int = 0
var game
const TEST_ROOT: String = "res://.godot/cafe_life_test_261022"

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _frames(count: int = 4) -> void:
	for index in range(count):
		await process_frame

func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames()

func _click(button: Button) -> void:
	await _frames(6)
	_check(button.is_visible_in_tree() and not button.disabled, "Required button unavailable")
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		root.push_input(event, true)
		await _frames()

func _finish_event() -> void:
	for index in range(80):
		if game.week.phase != "event":
			break
		game.advance()
	_check(game.week.phase == "hub", "Event did not return to hub")

func _act(id: String) -> void:
	var previous: int = game.week.score()
	game.choose_action(id)
	_check(game.week.phase == "event" and game.week.score() == previous + 1, "Action did not commit exactly once")
	game.choose_action(id)
	_check(game.week.score() == previous + 1, "Action repeated during dialogue")
	_finish_event()

func _episode(id: String) -> void:
	game._open_episodes()
	game._read_episode(id)
	_check(game.week.phase == "event" and game.week.event_id == id, "Eligible episode failed: " + id)
	_finish_event()
	_check(game.week.seen.has(id), "Finished episode not recorded")

func _finish_classic_part() -> void:
	var id: String = game.active_scene_id
	for index in range(150):
		if game.active_scene_id != id or game.mode == game.Mode.COMPLETE:
			break
		game.advance()

func _capture(name_value: String) -> void:
	await _frames(6)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://.godot/qa_34_%s_261022.png" % name_value) == OK, "Capture failed")

func _layout() -> void:
	await _frames(6)
	for node in [game.menu, game.day_card, game.life_hub, game.complete_panel, game.dialogue_panel]:
		if node.is_visible_in_tree():
			_check(root.get_visible_rect().encloses(node.get_global_rect()), "UI outside viewport: " + node.name)
	if game.life_hub.visible:
		_check(not game.life_hub.get_global_rect().intersects(game.day_card.get_global_rect()), "Hub overlaps date card")
		_check(game.life_hub.get_global_rect().encloses(game.next_day_button.get_global_rect()), "Next-day button clipped")
	if game.dialogue_panel.visible:
		_check(game.body.get_content_height() <= game.body.size.y + 1, "Event text clipped")

func _run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	game.user_data_root = TEST_ROOT
	root.add_child(game)
	await _frames(8)
	game.settings.music = false
	game.settings.sfx = false
	game._apply_audio_settings()
	game.transitions_enabled = false
	game.characters_per_second = 0
	if OS.get_cmdline_user_args().has("--persist-read"):
		_check(game.load_slot(2), "Fresh process failed to load life save")
		_check(game.life_active and game.week.day == 3 and game.week.event_id == "club" and game.week.remaining() == 1 and game.affection == 5, "Fresh process restored wrong life state")
		_check(game.line_index == 1 and not game.week.seen.has("club"), "Mid-episode state was lost")
		_finish_event()
		_check(game.week.seen.has("club") and game.week.score() == 5 and game.week.remaining() == 1, "Fresh resume repeated rewards")
		await _finish()
		return
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)
	for slot in range(1, 4):
		DirAccess.remove_absolute(TEST_ROOT.path_join("save_%d_261022.json" % slot))
	await _layout()
	await _capture("menu")
	await _click(game.life_start_button)
	_check(game.life_active and game.week.day == 1 and game.week.remaining() == 2 and game.week.score() == 0, "New week initial state wrong")
	await _layout()
	await _capture("hub")
	_check(game.save_slot(1), "Hub save failed")
	var hub_state: Dictionary = game.snapshot()
	game._open_journal()
	game.choose_action("read")
	game.finish_day()
	_check(game.snapshot() == hub_state, "Modal allowed a background action or day change")
	await _key(KEY_ENTER)
	_check(game.overlay_kind.is_empty() and game.week.history.is_empty(), "Closing journal selected a background action")
	game._open_episodes()
	game._read_episode("club")
	_check(game.week.phase == "hub" and game.overlay_kind == "episodes", "Locked episode started")
	await _capture("locked")
	game._close_overlay()
	# A real Enter must select an action, not also skip the first response.
	await _key(KEY_ENTER)
	_check(game.week.phase == "event" and game.week.event_id == "action_talk" and game.line_index == 0 and game.week.score() == 1, "Action confirm skipped first response")
	var committed: Dictionary = game.snapshot()
	_check(game.save_slot(3) and game.load_slot(3) and game.snapshot() == committed, "Action save/load changed costs or score")
	game.characters_per_second = 32
	game._show_line()
	game.body.visible_characters = 5
	game.revealed_count = 5
	var partial: Dictionary = game.snapshot()
	_check(game.save_slot(3), "Partial-text save failed")
	game.advance()
	_check(game.line_index == 0 and not game.typing, "Reveal skipped the response")
	_check(game.load_slot(3) and game.snapshot() == partial, "Partial text did not restore")
	game.characters_per_second = 0
	game._finish_reveal()
	game.finish_day()
	game.choose_action("read")
	_check(game.week.day == 1 and game.week.history.size() == 1, "Action/next-day input escaped dialogue")
	_finish_event()
	game.choose_action("talk")
	_check(game.week.phase == "hub" and game.week.history.size() == 1, "Same daily action repeated")
	_act("read")
	_check(game.week.remaining() == 0 and game.week.score() == 2, "Daily allowance wrong")
	game.choose_action("help")
	_check(game.week.phase == "hub" and game.week.score() == 2, "Third daily action accepted")
	_episode("bookmark")
	_check(game.week.remaining() == 0 and game.week.score() == 2, "Episode spent action or added score")
	game._open_episodes()
	game._read_episode("bookmark")
	_check(game.week.phase == "hub", "Finished episode repeated")
	game._close_overlay()
	game.finish_day()
	_check(game.week.day == 2 and game.week.phase == "event" and game.week.event_id == "intro_minjae", "Minjae intro not scheduled")
	_check(game.save_slot(3), "Intro save failed")
	game.line_index = 2
	game._show_line()
	game._finish_reveal()
	_check(game.speaker_label.text == "민재" and game.character_art.texture == game.minjae_art, "Minjae name/portrait missing")
	await _capture("minjae")
	_finish_event()
	_check(game.week.seen.has("intro_minjae") and game.week.remaining() == 2, "Introduction repeated or spent action")
	_act("help")
	_act("read")
	_episode("break")
	game.finish_day()
	_check(game.week.day == 3 and game.week.phase == "hub", "Intro repeated on third day")
	_act("talk")
	game._open_episodes()
	game._read_episode("club")
	game.line_index = 1
	game._show_line()
	game._finish_reveal()
	var mid_episode: Dictionary = game.snapshot()
	_check(game.save_slot(2), "Mid-episode save failed")
	_finish_event()
	_act("help")
	_episode("window")
	_check(game.week.seen.size() == 5 and game.week.score() == 6, "All four episodes not completed")
	game._open_journal()
	await _capture("journal")
	game._close_overlay()
	var frozen: Dictionary = game.snapshot()
	for mutation in [{"day": 0}, {"day": 2.5}, {"affection": 99}, {"history": [{"day": 1, "action": "talk"}, {"day": 1, "action": "talk"}]}, {"history": [{"day": 1, "action": "unknown"}]}, {"history": [{"day": 5, "action": "help"}]}, {"history": [{"day": 1, "action": "talk"}, {"day": 1, "action": "read"}, {"day": 1, "action": "help"}]}, {"seen_events": ["unknown"]}, {"seen_events": ["intro_minjae", "intro_minjae"]}, {"life_version": 99}, {"phase": "bad"}, {"phase": "week_complete"}, {"event_id": "club"}, {"typing": "true"}]:
		var invalid: Dictionary = frozen.duplicate(true)
		invalid.merge(mutation, true)
		_check(not game._valid_snapshot(invalid), "Invalid life save accepted: " + str(mutation))
	var invalid_ongoing: Dictionary = mid_episode.duplicate(true)
	invalid_ongoing.event_id = "window"
	_check(not game._valid_snapshot(invalid_ongoing), "Unearned episode accepted in save")
	var broken_state: Dictionary = frozen.duplicate(true)
	broken_state.affection = 99
	game._write_file("save_3_261022.json", {"state": broken_state})
	_check(not game.load_slot(3) and game.snapshot() == frozen, "Rejected life save changed progress")
	game._open_slots(false)
	await _capture("slots")
	game._close_overlay()
	game.finish_day()
	_act("talk")
	_act("read")
	game.finish_day()
	_act("help")
	_act("talk")
	game.finish_day()
	_check(game.week.phase == "week_complete" and game.mode == game.Mode.COMPLETE and game.week.score() == 10, "Week did not complete at max score")
	await _layout()
	await _capture("summary")
	_check(game.save_slot(3), "Summary save failed")
	game.start_life()
	_check(game.load_slot(3) and game.week.phase == "week_complete" and game.week.score() == 10, "Summary restore failed")
	game.finish_day()
	game.choose_action("talk")
	_check(game.week.day == 5 and game.week.score() == 10, "Completed week accepted more actions")
	_check(game.load_slot(2) and game.snapshot() == mid_episode, "Mid-episode restore changed progress")
	_finish_event()
	_check(game.week.score() == 5 and game.week.remaining() == 1, "Episode restore spent actions again")
	_check(game.load_slot(1) and game.week.day == 1 and game.week.history.is_empty(), "Earlier hub restore failed")
	# Original story uses schema 1 and shares the existing settings/profile safely.
	game.start_scene()
	_check(not game.life_active and game.relationship_panel.progress.max_value == 3, "Classic mode kept life rules")
	for index in range(150):
		if game.mode == game.Mode.CHOICE:
			break
		game.advance()
	game._select_option(0)
	var legacy: Dictionary = game.snapshot()
	_check(legacy.schema == 1 and game.save_slot(3), "Classic save schema changed")
	game.start_life()
	_check(game.load_slot(3) and not game.life_active and game.snapshot() == legacy, "Legacy slot did not restore classic mode")
	_finish_classic_part()
	for visit in range(2):
		for line in range(150):
			if game.mode == game.Mode.CHOICE:
				break
			game.advance()
		game._select_option(0)
		_finish_classic_part()
	_finish_classic_part()
	_check(game.mode == game.Mode.COMPLETE and game.continue_week_button.visible and not game.journal_button.visible, "Classic completion lost new-week entry")
	await _layout()
	await _capture("classic_continue")
	var classic_complete: Dictionary = game.snapshot()
	game._replay_ending("E01")
	_finish_classic_part()
	_check(game.snapshot() == classic_complete and game.continue_week_button.visible, "Classic gallery did not restore completion")
	await _click(game.continue_week_button)
	_check(game.life_active and game.week.phase == "hub" and game.week.day == 1, "New week did not connect from original ending")
	# A quiet week can finish without forced grinding or unreachable next-day buttons.
	game.start_life()
	for day in range(1, 6):
		game.finish_day()
		if game.week.phase == "event":
			_finish_event()
	_check(game.week.phase == "week_complete" and game.week.score() == 0, "Rest-only week softlocked")
	# Every new dialogue line fits at the minimum supported window size.
	game.start_life()
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960, 540)
	await _layout()
	await _capture("small_hub")
	for id in game.life_data.events:
		game.week.phase = "event"
		game.week.event_id = id
		game._show_life_state()
		for index in range(game.current_lines.size()):
			game.line_index = index
			game._show_line()
			game._finish_reveal()
			await _frames(1)
			_check(game.body.get_content_height() <= game.body.size.y + 1, "New text clipped: " + id)
	await _finish()

func _finish() -> void:
	game.bgm.stop()
	game.sfx.stop()
	OS.delay_msec(120)
	game.queue_free()
	await _frames(8)
	print("CAFE_LIFE_32_34: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
