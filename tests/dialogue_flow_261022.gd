extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	await process_frame


func _key(key: Key, echo_event: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		event.echo = echo_event and pressed
		Input.parse_input_event(event)
		await _frames(2)


func _click_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)


func _click(button: Button) -> void:
	# 화면 전환 뒤 컨테이너의 배치가 끝난 위치에서 클릭합니다.
	await _frames(4)
	_check(button.is_visible_in_tree() and not button.disabled, "Required button is unavailable.")
	await _click_at(button.get_global_rect().get_center())


func _to_choice(game) -> void:
	for index in range(40):
		if game.mode != game.Mode.DIALOGUE:
			break
		await _key(KEY_SPACE)
	await _frames(8)
	_check(game.mode == game.Mode.CHOICE, "Common dialogue did not reach choices.")


func _to_complete(game) -> void:
	for index in range(20):
		if game.mode != game.Mode.DIALOGUE:
			break
		await _key(KEY_SPACE)
	_check(game.mode == game.Mode.COMPLETE, "Reaction dialogue did not complete.")


func _capture(name_suffix: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://.godot/qa_%s_261022.png" % name_suffix) == OK, "Screenshot failed.")


func _run() -> void:
	var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	await _frames(6)
	_check(game.mode == game.Mode.MENU and game.menu.visible and not game.dialogue_panel.visible, "Initial menu state is wrong.")
	_check(root.get_visible_rect().encloses(game.start_button.get_global_rect()), "Start button is outside the viewport.")
	await _capture("menu")
	await _key(KEY_ENTER)
	_check(game.mode == game.Mode.DIALOGUE and game.line_index == 0 and game.typing, "Enter did not start at the first line.")
	await _frames(8)
	_check(game.body.visible_characters > 0 and game.body.visible_characters < game.body.get_total_character_count(), "Typewriter did not reveal partial text.")
	await _key(KEY_SPACE)
	_check(game.line_index == 0 and not game.typing and game.body.visible_characters == -1, "Reveal input skipped the first line.")
	await _key(KEY_ENTER)
	_check(game.line_index == 1 and game.speaker_label.text == "서윤", "Next input did not advance one line/change speaker.")
	await _click_at(game.dialogue_panel.get_global_rect().position + Vector2(90, 65))
	_check(game.line_index == 1 and not game.typing, "Dialogue-panel click did not reveal only the current sentence.")
	await _capture("dialogue")
	await _to_choice(game)
	_check(game.affection == 0 and game.choice_a.visible and game.choice_b.visible, "Choices were not shown before scoring.")
	_check(root.get_visible_rect().encloses(game.choices_panel.get_global_rect()), "Choices are outside the viewport.")
	_check(game.choices_panel.get_global_rect().end.y < game.dialogue_panel.get_global_rect().position.y, "Choices overlap dialogue.")
	await _capture("choice")
	await _click_at(game.dialogue_panel.get_global_rect().position + Vector2(90, 65))
	_check(game.mode == game.Mode.CHOICE and game.chosen_option_id.is_empty(), "Background click selected or skipped a choice.")
	await _key(KEY_ENTER)
	_check(game.chosen_option_id == "C01_A" and game.affection == 1, "Keyboard choice A did not score exactly once.")
	_check(game.in_reaction and game.line_index == 0 and game.mode == game.Mode.DIALOGUE, "Choice confirmation skipped the first reaction.")
	_check(game.body.text == game.scene_data.reactions.C01_A[0].text and game.portrait.expression == "smile", "Choice A reaction or expression is wrong.")
	game._choose_option("C01_A")
	_check(game.affection == 1, "Repeated selection added affection twice.")
	await _key(KEY_SPACE, true)
	_check(game.line_index == 0, "Held-key echo skipped a reaction.")
	await _key(KEY_SPACE)
	_check(game.line_index == 0 and not game.typing, "Reaction reveal input advanced the line.")
	await _capture("reaction")
	await _to_complete(game)
	_check(game.affection == 1 and game.complete_panel.visible, "Completion lost score or its panel.")
	_check(root.get_visible_rect().encloses(game.menu_button.get_global_rect()), "Completion buttons are outside the viewport.")
	await _capture("complete")
	await _click(game.replay_button)
	_check(game.affection == 0 and game.chosen_option_id.is_empty() and game.line_index == 0, "Replay retained choice or score.")
	await _to_choice(game)
	await _key(KEY_DOWN)
	_check(root.gui_get_focus_owner() == game.choice_b, "Arrow-key choice navigation failed.")
	await _click(game.choice_b)
	_check(game.chosen_option_id == "C01_B" and game.affection == 0, "Mouse choice B has wrong score.")
	_check(game.body.text == game.scene_data.reactions.C01_B[0].text and game.line_index == 0, "Choice B skipped or reused reaction A.")
	await _to_complete(game)
	await _click(game.menu_button)
	_check(game.mode == game.Mode.MENU and game.chosen_option_id.is_empty(), "Completion-to-menu did not reset.")
	await _click(game.start_button)
	_check(game.mode == game.Mode.DIALOGUE, "Mouse Start did not enter dialogue after returning from completion.")
	await _to_choice(game)
	await _key(KEY_ESCAPE)
	_check(game.mode == game.Mode.MENU and not game.choices_panel.visible, "Esc from a choice did not return to menu.")
	game.characters_per_second = 0
	await _key(KEY_ENTER)
	_check(game.mode == game.Mode.DIALOGUE and not game.typing and not game.next_button.disabled, "Immediate-text restart retained disabled Next.")
	await _frames(60)
	_check(game.line_index == 0, "Immediate text advanced automatically.")
	await _click(game.next_button)
	_check(game.line_index == 1 and not game.typing, "Next button did not advance one instant-text line.")
	await _key(KEY_ESCAPE)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960, 540)
		await _frames(8)
		_check(root.get_visible_rect().encloses(game.start_button.get_global_rect()), "Small-window Start is outside the viewport.")
		await _click(game.start_button)
		_check(game.body.get_content_height() <= game.body.size.y, "Dialogue clips in a smaller window.")
		await _to_choice(game)
		_check(game.choices_panel.get_global_rect().end.y < game.dialogue_panel.get_global_rect().position.y, "Small-window choices overlap dialogue.")
		await _capture("small_choice")
		await _key(KEY_ESCAPE)
	print("DIALOGUE_FLOW: %s (real input, typewriter/reveal separation, speaker/expression, both choices, single score, no skipped reaction, replay/menu/Esc, instant text, layout)" % ("PASS" if failures == 0 else "FAIL"))
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
