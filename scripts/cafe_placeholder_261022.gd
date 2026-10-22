extends Node2D

# 최종 배경 그림을 준비하기 전 사용하는 코드로 그린 임시 무대입니다.
var rain_time: float = 0.0


func _process(delta: float) -> void:
	rain_time = fmod(rain_time + delta * 85.0, 350.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("c6b79c"))
	draw_rect(Rect2(0, 480, 1280, 240), Color("81725f"))
	draw_rect(Rect2(54, 62, 602, 390), Color("665b50"))
	draw_rect(Rect2(68, 76, 574, 362), Color("718b92"))
	for index in range(35):
		var x: float = 82.0 + fmod(index * 83.0, 540.0)
		var y: float = 82.0 + fmod(index * 59.0 + rain_time, 330.0)
		draw_line(Vector2(x, y), Vector2(x - 5, y + 18), Color(0.82, 0.91, 0.93, 0.45), 2.0)
	draw_rect(Rect2(350, 76, 10, 362), Color("665b50"))
	draw_rect(Rect2(68, 256, 574, 10), Color("665b50"))
	draw_rect(Rect2(40, 438, 632, 20), Color("e0cdaa"))
	draw_rect(Rect2(714, 78, 480, 220), Color("ad987b"))
	for row in range(2):
		draw_rect(Rect2(730, 164 + row * 106, 450, 9), Color("6e5947"))
		for book in range(9):
			var colors: Array[Color] = [Color("725c5b"), Color("6b7d71"), Color("d4be91")]
			draw_rect(Rect2(744 + book * 43, 104 + row * 106, 25, 60), colors[(book + row) % 3])
	draw_rect(Rect2(665, 398, 615, 28), Color("5c4940"))
	draw_rect(Rect2(684, 426, 596, 184), Color("a58a69"))
	draw_line(Vector2(1110, 0), Vector2(1110, 50), Color("574a40"), 3)
	draw_colored_polygon(PackedVector2Array([Vector2(1080, 50), Vector2(1140, 50), Vector2(1164, 94), Vector2(1056, 94)]), Color("efe0ba"))
	draw_circle(Vector2(1110, 104), 24, Color(1, 0.87, 0.6, 0.12))
