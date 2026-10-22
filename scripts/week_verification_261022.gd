extends Node

# 소스와 실제 Windows 배포본에서 같은 엔딩·호환성 검사를 실행합니다.
var failures: int = 0
var game

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func finish_dialogue() -> void:
	for index in range(100):
		if game.mode != game.Mode.DIALOGUE:
			break
		game.advance()

func action(id: String) -> void:
	game.choose_action(id)
	finish_dialogue()

func episode(id: String) -> void:
	game._open_episodes()
	game._read_episode(id)
	finish_dialogue()

func day() -> void:
	game.finish_day()
	if game.week.phase == "event":
		finish_dialogue()

func prepare_romance() -> void:
	game.start_life()
	action("talk")
	action("read")
	episode("bookmark")
	day()
	action("read")
	action("help")
	episode("break")
	day()
	action("talk")
	game._open_episodes()
	game._read_episode("club")
	game.line_index = 1
	game._show_line()
	game._finish_reveal()
	# 실제 저장을 건드리지 않고 QA 경로에만 이전 schema 2 자료를 만듭니다.
	var legacy: Dictionary = game.snapshot()
	legacy.schema = 2
	legacy.life_version = 1
	game._write_file("save_1_261022.json", {"state": legacy})
	finish_dialogue()
	action("help")
	episode("window")
	day()
	action("talk")
	action("read")
	day()

func replay_checks(id: String) -> void:
	var before: Dictionary = game.snapshot()
	var profile_before: Array = game.seen_week_endings.duplicate()
	game._open_gallery()
	game._replay_ending(id)
	check(game.gallery_replay and not game.relationship_panel.visible and not game.day_card.visible, "Weekly gallery leaked live HUD")
	check(not game.save_slot(3), "Gallery allowed save overwrite")
	finish_dialogue()
	check(not game.gallery_replay and game.snapshot() == before and game.mode == game.Mode.COMPLETE, "Weekly gallery changed completion")
	check(game.seen_week_endings == profile_before, "Replay changed unlock record")
	game._replay_ending(id)
	game._finish_ending() # Esc로 나갈 때도 같은 복귀 경로를 사용합니다.
	check(game.snapshot() == before and not game.gallery_replay, "Gallery cancel changed progress")

func run(instance: Control, read_only: bool = false) -> int:
	game = instance
	game.characters_per_second = 0
	game.transitions_enabled = false
	if read_only:
		check(game.seen_week_endings.size() == 3, "Weekly ending records missing after restart")
		check(game.load_slot(2), "Fresh process failed to load new ending")
		check(game.life_active and game.week.phase == "ending" and game.week.event_id == "W01" and game.line_index == 2 and game.typing and game.body.visible_characters == 5, "New ending cursor was not restored")
		var score: int = game.week.score()
		finish_dialogue()
		check(game.week.phase == "week_complete" and game.week.score() == score and game.seen_week_endings.size() == 3, "Ending resume duplicated score or records")
		check(game.load_slot(1) and game.week.phase == "event" and game.week.event_id == "club" and game.line_index == 1, "Fresh process failed to migrate schema 2")
		finish_dialogue()
		check(game.week.score() == 5 and game.week.remaining() == 1, "Legacy resume repeated action costs")
		return failures
	game.seen_week_endings.clear()
	game._write_file("week_endings_261022.json", {"schema": 1, "seen_endings": []})
	# 세 가지 분기와 두 조건을 모두 충족한 경우의 우선순위.
	prepare_romance()
	check(game.week.score() == 8 and game.week.resolved_ending() == "W01", "Romance ending threshold/priority wrong")
	day()
	check(game.week.phase == "ending" and game.week.event_id == "W01" and not game.seen_week_endings.has("W01"), "Ending unlocked before final line")
	game.line_index = 2
	game.characters_per_second = 32
	game._show_line()
	game.body.visible_characters = 5
	game.revealed_count = 5
	var partial: Dictionary = game.snapshot()
	check(game.save_slot(2), "Ending save failed")
	game.advance()
	check(game.line_index == 2 and not game.typing, "Ending reveal skipped a line")
	var loaded: bool = game.load_slot(2)
	check(loaded and game.snapshot() == partial, "Partial ending restore changed state")
	game.characters_per_second = 0
	finish_dialogue()
	check(game.week.phase == "week_complete" and game.seen_week_endings.has("W01"), "Romance ending was not recorded")
	replay_checks("W01")
	var complete: Dictionary = game.snapshot()
	# 34단계 마무리 저장은 새 엔딩 첫 줄로 이행하고 자동 해제하지 않습니다.
	var old_complete: Dictionary = complete.duplicate(true)
	old_complete.schema = 2
	old_complete.life_version = 1
	check(game._valid_snapshot(old_complete), "Legacy completed week rejected")
	game._restore(old_complete)
	check(game.week.phase == "ending" and game.week.event_id == "W01" and game.line_index == 0, "Legacy summary did not migrate to ending")
	game._restore(complete)
	# 본편 엔딩 감상 후 주간 완료 화면으로 돌아옵니다.
	if game.seen_endings.has("E01"):
		game._replay_ending("E01")
		for index in range(100):
			if not game.gallery_replay:
				break
			game.advance()
		check(game.life_active and game.snapshot() == complete, "Classic replay failed to return to week")
	# 책 모임 분기: 5점과 완료한 club, window는 읽지 않습니다.
	game.start_life()
	action("read")
	action("help")
	day()
	action("read")
	action("help")
	day()
	action("talk")
	episode("club")
	day()
	day()
	day()
	check(game.week.phase == "ending" and game.week.event_id == "W02", "Club ending wrong")
	finish_dialogue()
	check(game.seen_week_endings.has("W02"), "Club ending not recorded")
	replay_checks("W02")
	# 쉬기만 한 주도 실패 화면 없이 고유한 결말로 끝납니다.
	game.start_life()
	for index in range(5):
		day()
	check(game.week.phase == "ending" and game.week.event_id == "W03", "Quiet ending wrong")
	finish_dialogue()
	check(game.week.score() == 0 and game.seen_week_endings.has("W03"), "Quiet week could not finish")
	replay_checks("W03")
	# 임의 엔딩·중간 날짜의 엔딩·일반 이벤트로 위장한 엔딩은 거부합니다.
	var frozen: Dictionary = game.snapshot()
	for mutation in [{"phase": "ending", "event_id": "W01"}, {"phase": "ending", "event_id": "W03", "day": 4}, {"phase": "event", "event_id": "W03"}, {"schema": 3, "life_version": 1}, {"schema": 2, "life_version": 2}, {"schema": 99}]:
		var invalid: Dictionary = frozen.duplicate(true)
		invalid.merge(mutation, true)
		check(not game._valid_snapshot(invalid), "Invalid ending save accepted: " + str(mutation))
	game.show_menu()
	game._replay_ending("W03")
	finish_dialogue()
	check(game.mode == game.Mode.MENU and not game.life_active, "Menu gallery return wrong")
	var legacy_loaded: bool = game.load_slot(1)
	check(legacy_loaded and game.week.event_id == "club" and game.week.score() == 5, "Legacy dialogue migration failed")
	finish_dialogue()
	check(game.week.score() == 5 and game.week.remaining() == 1, "Legacy rewards duplicated")
	return failures
