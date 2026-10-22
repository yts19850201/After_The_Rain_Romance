extends SceneTree

var failures: int = 0

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_list_261022.json"))
	for asset in manifest.assets:
		if not asset.required:
			continue
		_check(asset.status == "integrated" and FileAccess.file_exists("res://" + asset.path), "Missing asset: " + asset.id)
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(FileAccess.get_file_as_bytes("res://" + asset.path))
		_check(context.finish().hex_encode().to_upper() == asset.sha256, "Asset hash mismatch: " + asset.id)
	for sprite in ["seoyun_neutral", "seoyun_smile", "seoyun_thoughtful", "seoyun_shy", "minjae_neutral"]:
		var picture := Image.new()
		_check(picture.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/%s_261022.png" % sprite)) == OK, "Sprite PNG unreadable")
		_check(picture.get_size() == Vector2i(1024, 1536), "Sprite dimensions changed")
		for point in [Vector2i(0, 0), Vector2i(1023, 0), Vector2i(0, 1535), Vector2i(1023, 1535), Vector2i(40, 600)]:
			_check(picture.get_pixelv(point).a == 0.0, "Non-transparent sprite edge: " + sprite)
	for name_value in ["cafe", "ending", "confirm", "select", "transition"]:
		var wav: AudioStreamWAV = load("res://assets/audio/%s_261022.wav" % name_value)
		_check(wav.mix_rate == 22050 and wav.format == AudioStreamWAV.FORMAT_16_BITS, "Unexpected audio format")
		var peak: float = 0.0
		var energy: float = 0.0
		var samples: PackedByteArray = wav.data
		for index in range(samples.size() / 2):
			var value: float = float(samples.decode_s16(index * 2)) / 32768.0
			peak = maxf(peak, absf(value))
			energy += value * value
		var rms: float = sqrt(energy / (samples.size() / 2))
		_check(peak < 0.95 and peak > 0.01 and rms > 0.005, "Silent or clipped audio: " + name_value)
		if name_value in ["cafe", "ending"]:
			_check(is_equal_approx(wav.get_length(), 20.0), "Music loop duration changed")
			_check(absi(samples.decode_s16(0)) < 20 and absi(samples.decode_s16(samples.size() - 2)) < 20, "Music loop clicks at boundary")
		print("Audio ", name_value, ": duration=", snappedf(wav.get_length(), 0.01), "s peak=", snappedf(peak, 0.001), " rms=", snappedf(rms, 0.001))
	print("ASSET TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
