extends SceneTree

var game
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	game.user_data_root = "res://.godot/week_endings_test_261022"
	root.add_child(game)
	await process_frame
	game.settings.music = false
	game.settings.sfx = false
	game._apply_audio_settings()
	var verifier: Node = load("res://scripts/week_verification_261022.gd").new()
	root.add_child(verifier)
	failures += verifier.run(game, OS.get_cmdline_user_args().has("--persist-read"))
	# 끝나는 조건을 바꾸는 순수 모델을 전수 검사합니다: 하루 선택 7가지 ^ 5일.
	if not OS.get_cmdline_user_args().has("--persist-read"):
		# 최소 창 크기에서 세 결과 화면과 대화·감상 목록도 확인합니다.
		if DisplayServer.get_name() != "headless":
			root.size = Vector2i(960, 540)
			for index in range(6):
				await process_frame
			verifier.prepare_romance()
			game.week.day = 5
			game.week.phase = "week_complete"
			game.week.event_id = ""
			for ending in game.life_data.endings:
				if ending.id == "W02":
					game.week.seen.erase("window")
				elif ending.id == "W03":
					game.week.seen.erase("club")
				game._show_life_state()
				for index in range(6):
					await process_frame
				var content: VBoxContainer = game.get_node("Complete/Margin/Content")
				for child in content.get_children():
					if child is Control and child.is_visible_in_tree() and not game.complete_panel.get_global_rect().encloses(child.get_global_rect()):
						failures += 1
				var summary: Label = content.get_node("Summary")
				if summary.get_line_count() * summary.get_line_height() > summary.size.y + 1:
					failures += 1
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/qa_35_small_%s_261022.png" % ending.id)
				game._replay_ending(ending.id)
				game._finish_reveal()
				for index in range(4):
					await process_frame
				if game.body.get_content_height() > game.body.size.y + 1:
					failures += 1
				game._finish_ending()
		var options: Array = [[], ["talk"], ["read"], ["help"], ["talk", "read"], ["talk", "help"], ["read", "help"]]
		var coverage: Dictionary = {"W01": 0, "W02": 0, "W03": 0}
		for route in range(16807):
			var model = load("res://scripts/cafe_week_state_261022.gd").new()
			model.configure(game.life_data)
			var encoded: int = route
			for day in range(1, 6):
				for id in options[encoded % 7]:
					model.act(id)
					model.finish_event()
				encoded /= 7
				for id in game.life_data.episodes:
					if model.start_episode(id):
						model.finish_event()
				model.next_day()
				if model.phase == "event":
					model.finish_event()
			var ending: String = model.resolved_ending()
			coverage[ending] += 1
			var expected: String = "W01" if model.score() >= 8 and model.seen.has("window") else ("W02" if model.score() >= 5 and model.seen.has("club") else "W03")
			if model.phase != "ending" or model.event_id != expected or not model.valid(model.state()):
				failures += 1
		for id in coverage:
			if coverage[id] == 0:
				failures += 1
		print("Ending route coverage: ", coverage, " / 16807")
	game.bgm.stop()
	game.sfx.stop()
	OS.delay_msec(120)
	game.queue_free()
	verifier.queue_free()
	for index in range(8):
		await process_frame
	print("WEEK_ENDINGS_35: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
