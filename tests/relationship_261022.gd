extends SceneTree

var game
var failures: int = 0
const TEST_ROOT: String = "res://.godot/relationship_test_261022"

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

func _to_choice() -> void:
	for index in range(150):
		if game.mode == game.Mode.CHOICE:
			break
		game.advance()
	_check(game.mode == game.Mode.CHOICE, "Choice not reached")

func _finish_part() -> void:
	var id: String = game.active_scene_id
	for index in range(150):
		if game.active_scene_id != id or game.mode == game.Mode.COMPLETE:
			break
		game.advance()

func _layout() -> void:
	await _frames(6)
	var card: Rect2 = game.relationship_panel.status_card.get_global_rect()
	_check(root.get_visible_rect().encloses(card), "Relationship card outside viewport")
	for other in [game.get_node("Chapter"), game.toolbar, game.choices_panel, game.dialogue_panel, game.complete_panel]:
		if other.is_visible_in_tree():
			_check(not card.intersects(other.get_global_rect()), "Relationship card overlaps " + other.name)
	var panel = game.relationship_panel
	_check(panel.stage_label.get_global_rect().encloses(Rect2(panel.stage_label.global_position, panel.stage_label.get_minimum_size())), "Relationship name clipped")
	_check(panel.progress.get_global_rect().end.y <= card.end.y, "Relationship progress outside card")
	if game.choices_panel.visible:
		_check(not panel.feedback_card.visible, "Old feedback overlaps next choice")
	for control in [panel, panel.status_card, panel.stage_label, panel.score_label, panel.progress, panel.feedback_card, panel.feedback_label]:
		_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Relationship UI intercepts mouse")

func _capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _frames(5)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://.godot/qa_31_%s_261022.png" % name_value) == OK, "Capture failed")

func _run() -> void:
	game = load("res://scenes/novel_261022.tscn").instantiate()
	game.user_data_root = TEST_ROOT
	root.add_child(game)
	await _frames(8)
	game.settings.music = false
	game.settings.sfx = false
	game._apply_audio_settings()
	game.transitions_enabled = false
	game.characters_per_second = 0
	var panel = game.relationship_panel
	if OS.get_cmdline_user_args().has("--persist-read"):
		_check(game.load_slot(2), "Old-format slot failed in new process")
		_check(game.affection == 2 and panel.displayed_score == 2 and panel.relationship_name == "편안한 사이", "Relationship not reconstructed in new process")
		_check(not panel.feedback_card.visible and is_equal_approx(panel.progress.value, 2.0), "Loading replayed gain animation")
		_finish_part()
		_check(game.affection == 2 and game.active_scene_id == "S03", "Resuming added points again")
		await _finish()
		return
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)
	for slot in [1, 2]:
		DirAccess.remove_absolute(TEST_ROOT.path_join("save_%d_261022.json" % slot))
	_check(not panel.visible, "Relationship visible in title menu")
	game.start_scene()
	_check(panel.visible and panel.relationship_name == "낯선 사이" and panel.score_label.text == "호감도 0 / 3", "Initial relationship wrong")
	await _layout()
	await _capture("initial")
	_to_choice()
	game._select_option(1)
	_check(game.affection == 0 and panel.feedback_label.text == "호감도 유지 · 낯선 사이", "Neutral choice did not report unchanged score")
	panel.feedback_remaining = 1.0
	game._select_option(1)
	_check(panel.feedback_remaining == 1.0 and game.affection == 0, "Repeated choice repeated feedback")
	await _capture("unchanged")
	game.start_scene()
	var names: Array[String] = ["알아가는 사이", "편안한 사이", "가까운 사이"]
	for visit in range(3):
		_to_choice()
		await _key(KEY_ENTER)
		_check(game.phase == "reaction" and game.line_index == 0 and game.affection == visit + 1, "Relationship choice consumed reaction or scored twice")
		_check(panel.relationship_name == names[visit] and panel.displayed_score == visit + 1, "Wrong relationship tier")
		_check(panel.feedback_card.visible and panel.feedback_label.text.begins_with("호감도 +1"), "No positive feedback")
		if visit < 2:
			_check(game.save_slot(visit + 1), "Relationship progress save failed")
			var saved: Dictionary = game._read_file("save_%d_261022.json" % (visit + 1))
			_check(saved.state.schema == 1 and not saved.state.has("relationship_name"), "Save format was changed for derived UI")
		if visit == 0:
			game._open_settings()
			var paused_feedback: float = panel.feedback_remaining
			var paused_progress: float = panel.progress.value
			await _frames(15)
			_check(panel.feedback_remaining == paused_feedback and panel.progress.value == paused_progress, "Feedback advanced behind modal")
			await _key(KEY_ESCAPE)
		await create_timer(0.35).timeout
		_check(is_equal_approx(panel.progress.value, float(visit + 1)), "Progress animation did not reach score")
		await _layout()
		await _capture("tier_%d" % (visit + 1))
		if visit == 1:
			await create_timer(4.1).timeout
			_check(not panel.feedback_card.visible, "Feedback never disappeared")
		_finish_part()
	_finish_part()
	_check(game.mode == game.Mode.COMPLETE and panel.visible and panel.relationship_name == "가까운 사이", "Final relationship missing")
	await _layout()
	var before: Dictionary = game.snapshot()
	game._replay_ending("E01")
	_check(not panel.visible, "Gallery shows current relationship on archived ending")
	_finish_part()
	_check(game.snapshot() == before and panel.visible and panel.displayed_score == 3, "Gallery return changed relationship")
	_check(game.load_slot(1) and panel.relationship_name == "알아가는 사이" and panel.displayed_score == 1, "Earlier relationship not restored")
	_check(not panel.feedback_card.visible and panel.progress.value == 1, "Load announced a new gain")
	_check(game.load_slot(2) and panel.relationship_name == "편안한 사이" and game.affection == 2, "Second relationship not restored")
	game.show_menu()
	_check(not panel.visible and not panel.feedback_card.visible and panel.displayed_score == 0, "Menu retained old relationship")
	game.start_scene()
	_check(panel.relationship_name == "낯선 사이" and panel.progress.value == 0, "New game retained progress")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960, 540)
		await _frames(8)
	_to_choice()
	await _layout()
	await _capture("small_choice")
	game._select_option(0)
	await _layout()
	await _capture("small_gain")
	await _finish()

func _finish() -> void:
	game.bgm.stop()
	game.sfx.stop()
	OS.delay_msec(120)
	game.queue_free()
	await _frames(8)
	print("RELATIONSHIP_31: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
