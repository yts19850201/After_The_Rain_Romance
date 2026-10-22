extends RefCounted

var data: Dictionary
var day: int = 1
var history: Array = []
var seen: Array = []
var phase: String = "hub"
var event_id: String = ""

func configure(configuration: Dictionary) -> void:
	data = configuration

func reset() -> void:
	day = 1
	history = []
	seen = []
	phase = "hub"
	event_id = ""

func score(entries: Variant = null) -> int:
	if entries == null:
		entries = history
	var total: int = 0
	for entry in entries:
		total += int(data.actions[entry.action].affection)
	return total

func count(action: String, entries: Variant = null) -> int:
	if entries == null:
		entries = history
	var total: int = 0
	for entry in entries:
		if entry.action == action:
			total += 1
	return total

func remaining() -> int:
	var used: int = 0
	for entry in history:
		if int(entry.day) == day:
			used += 1
	return int(data.actions_per_day) - used

func used_today(action: String) -> bool:
	for entry in history:
		if int(entry.day) == day and entry.action == action:
			return true
	return false

func act(action: String) -> bool:
	if phase != "hub" or not data.actions.has(action) or remaining() <= 0 or used_today(action):
		return false
	history.append({"day": day, "action": action})
	event_id = data.actions[action].event_id
	phase = "event"
	return true

func eligible(id: String, entries: Variant = null, viewed: Variant = null, current_day: int = -1) -> bool:
	if entries == null:
		entries = history
	if viewed == null:
		viewed = seen
	if current_day < 0:
		current_day = day
	if not data.events.has(id):
		return false
	var event: Dictionary = data.events[id]
	if current_day < int(event.get("min_day", 1)) or score(entries) < int(event.get("min_affection", 0)):
		return false
	for action in event.get("requires", {}):
		if count(action, entries) < int(event.requires[action]):
			return false
	for required in event.get("requires_seen", []):
		if not viewed.has(required):
			return false
	return true

func start_episode(id: String) -> bool:
	if phase != "hub" or not data.episodes.has(id) or seen.has(id) or not eligible(id):
		return false
	phase = "event"
	event_id = id
	return true

func finish_event() -> void:
	if phase == "ending":
		phase = "week_complete"
		event_id = ""
		return
	if phase != "event":
		return
	if not event_id.begins_with("action_") and not seen.has(event_id):
		seen.append(event_id)
	phase = "hub"
	event_id = ""

func next_day() -> bool:
	if phase != "hub":
		return false
	if day == data.days.size():
		phase = "ending"
		event_id = resolved_ending()
		return true
	day += 1
	if day == 2 and not seen.has("intro_minjae"):
		phase = "event"
		event_id = "intro_minjae"
	return true

func resolved_ending(entries: Variant = null, viewed: Variant = null) -> String:
	if entries == null:
		entries = history
	if viewed == null:
		viewed = seen
	for ending in data.endings:
		if score(entries) < int(ending.min_affection):
			continue
		var ready: bool = true
		for id in ending.requires_seen:
			if not viewed.has(id):
				ready = false
		if ready:
			return ending.id
	return "W03"

func state() -> Dictionary:
	return {"schema": 3, "life_version": int(data.version), "scene_id": "LIFE", "day": day, "history": history.duplicate(true), "seen_events": seen.duplicate(), "phase": phase, "event_id": event_id, "affection": score()}

func restore(value: Dictionary) -> void:
	day = int(value.day)
	history = []
	for entry in value.history:
		history.append({"day": int(entry.day), "action": str(entry.action)})
	seen = value.seen_events.duplicate()
	phase = value.phase
	event_id = value.event_id
	# 34단계의 마무리 저장도 새 엔딩을 처음부터 읽도록 옮깁니다.
	if value.schema == 2 and phase == "week_complete":
		phase = "ending"
		event_id = resolved_ending()

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func valid(value: Dictionary) -> bool:
	var legacy: bool = value.get("schema") == 2 and value.get("life_version") == 1
	if not legacy and not (value.get("schema") == 3 and value.get("life_version") == data.version):
		return false
	if value.get("scene_id") != "LIFE":
		return false
	if not _integer(value.get("day")) or int(value.day) < 1 or int(value.day) > data.days.size():
		return false
	if not value.get("history") is Array or not value.get("seen_events") is Array or value.get("phase") not in (["hub", "event", "week_complete"] if legacy else ["hub", "event", "ending", "week_complete"]) or not value.get("event_id") is String:
		return false
	var entries: Array = value.history
	if entries.size() > data.days.size() * int(data.actions_per_day):
		return false
	var previous_day: int = 1
	var counts: Dictionary = {}
	var unique: Array = []
	for entry in entries:
		if not entry is Dictionary or not _integer(entry.get("day")) or not entry.get("action") is String or not data.actions.has(entry.action):
			return false
		var entry_day: int = int(entry.day)
		var key: String = "%d:%s" % [entry_day, entry.action]
		if entry_day < previous_day or entry_day > int(value.day) or unique.has(key):
			return false
		previous_day = entry_day
		unique.append(key)
		counts[entry_day] = int(counts.get(entry_day, 0)) + 1
		if counts[entry_day] > int(data.actions_per_day):
			return false
	if not _integer(value.get("affection")) or int(value.affection) != score(entries):
		return false
	var viewed: Array = value.seen_events
	var known: Array = []
	for id in viewed:
		if not id is String or known.has(id) or (id != "intro_minjae" and not data.episodes.has(id)):
			return false
		known.append(id)
		if not eligible(id, entries, viewed, int(value.day)):
			return false
	if int(value.day) >= 2 and not viewed.has("intro_minjae") and not (int(value.day) == 2 and value.phase == "event" and value.event_id == "intro_minjae"):
		return false
	if int(value.day) == 1 and viewed.has("intro_minjae"):
		return false
	if value.phase == "week_complete" and int(value.day) != data.days.size():
		return false
	if value.phase == "ending":
		return int(value.day) == data.days.size() and value.event_id == resolved_ending(entries, viewed)
	if value.phase != "event":
		return value.event_id.is_empty()
	if not data.events.has(value.event_id):
		return false
	if value.event_id.begins_with("action_"):
		return not entries.is_empty() and int(entries.back().day) == int(value.day) and data.actions[entries.back().action].event_id == value.event_id
	if value.event_id != "intro_minjae" and not data.episodes.has(value.event_id):
		return false
	if viewed.has(value.event_id) or not eligible(value.event_id, entries, viewed, int(value.day)):
		return false
	return value.event_id != "intro_minjae" or int(value.day) == 2
