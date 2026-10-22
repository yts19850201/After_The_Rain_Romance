extends SceneTree

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://distribution/licenses")
	_write("Godot_MIT_261022.txt", Engine.get_license_text())
	var notice: String = "Godot Engine third-party notices\nEngine version: " + Engine.get_version_info().string + "\n\n"
	for library in Engine.get_copyright_info():
		notice += str(library.get("name", "")) + "\n"
		for part in library.get("parts", []):
			notice += "Files: " + ", ".join(part.get("files", [])) + "\n"
			notice += "Copyright: " + "\n".join(part.get("copyright", [])) + "\n"
			notice += "License: " + str(part.get("license", "")) + "\n\n"
	var texts: Dictionary = Engine.get_license_info()
	var names: Array = texts.keys()
	names.sort()
	for name_value in names:
		notice += "\n===== " + str(name_value) + " =====\n" + str(texts[name_value]) + "\n"
	_write("Godot_ThirdParty_261022.txt", notice)
	print("Exported engine notices for ", Engine.get_version_info().string)
	quit()

func _write(name_value: String, content: String) -> void:
	var file := FileAccess.open("res://distribution/licenses/" + name_value, FileAccess.WRITE)
	assert(file != null, "Cannot write notices")
	file.store_string(content)
	file.close()
