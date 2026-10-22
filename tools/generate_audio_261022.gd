extends SceneTree

# 외부 샘플 없이 사인파와 배음으로 만드는 짧은 오리지널 루프입니다.
const RATE: int = 22050
const BEAT: float = 0.625

func _initialize() -> void:
	_music("cafe", [[48, 52, 55, 59], [45, 48, 52, 55], [41, 45, 48, 52], [43, 47, 50, 55]])
	_music("ending", [[53, 57, 60, 64], [48, 52, 55, 59], [50, 53, 57, 60], [55, 59, 62, 65]])
	_effect("confirm", [76, 79], 0.15)
	_effect("select", [72, 76, 79], 0.34)
	_effect("transition", [60, 67, 72, 76], 0.85)
	quit()

func _frequency(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)

func _tone(time_value: float, frequency: float) -> float:
	return sin(TAU * frequency * time_value) + 0.22 * sin(TAU * frequency * 2.0 * time_value) + 0.06 * sin(TAU * frequency * 3.0 * time_value)

func _music(name_value: String, chords: Array) -> void:
	var duration: float = BEAT * 32.0
	var pcm := PackedByteArray()
	pcm.resize(int(duration * RATE) * 2)
	var pattern: Array[int] = [0, 2, 1, 3, 2, 1, 3, 2]
	for index in range(pcm.size() / 2):
		var time_value: float = float(index) / RATE
		var beat_index: int = int(time_value / BEAT)
		var chord: Array = chords[beat_index / 8]
		var local_time: float = fmod(time_value, BEAT)
		var envelope: float = (1.0 - exp(-local_time * 70.0)) * exp(-local_time * 4.0)
		var sample: float = _tone(local_time, _frequency(int(chord[pattern[beat_index % 8]]) + 12)) * envelope * 0.15
		var bar_time: float = fmod(time_value, BEAT * 8.0)
		var pad_envelope: float = sin(PI * bar_time / (BEAT * 8.0))
		for note in chord:
			sample += sin(TAU * _frequency(int(note)) * bar_time) * pad_envelope * 0.035
		var edge: float = minf(1.0, minf(time_value / 0.05, (duration - time_value) / 0.12))
		pcm.encode_s16(index * 2, int(clampf(sample * edge, -1.0, 1.0) * 32767.0))
	_write(name_value, pcm)

func _effect(name_value: String, notes: Array, duration: float) -> void:
	var pcm := PackedByteArray()
	pcm.resize(int(duration * RATE) * 2)
	for index in range(pcm.size() / 2):
		var time_value: float = float(index) / RATE
		var sample: float = 0.0
		for note_index in range(notes.size()):
			var local_time: float = time_value - note_index * duration * 0.12
			if local_time >= 0.0:
				var envelope: float = (1.0 - exp(-local_time * 100.0)) * exp(-local_time * 9.0 / duration)
				sample += _tone(local_time, _frequency(notes[note_index])) * envelope * 0.18
		var edge: float = minf(1.0, (duration - time_value) / 0.03)
		pcm.encode_s16(index * 2, int(clampf(sample * edge, -1.0, 1.0) * 32767.0))
	_write(name_value, pcm)

func _write(name_value: String, pcm: PackedByteArray) -> void:
	# 각 음원의 최고 음량을 맞춘 뒤 게임 안에서 별도 음량을 조절합니다.
	var peak: int = 1
	for index in range(pcm.size() / 2):
		peak = maxi(peak, absi(pcm.decode_s16(index * 2)))
	var gain: float = 0.72 * 32767.0 / peak
	for index in range(pcm.size() / 2):
		pcm.encode_s16(index * 2, int(pcm.decode_s16(index * 2) * gain))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = pcm
	var error: Error = stream.save_to_wav("res://assets/audio/%s_261022.wav" % name_value)
	assert(error == OK, "Audio generation failed")
	print("Created audio: ", name_value)
