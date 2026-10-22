extends Node2D

var expression: String = "neutral":
	set(value):
		expression = value
		queue_redraw()


func _draw() -> void:
	# 같은 포즈에서 얼굴만 바꾸는 임시 인물 표시입니다.
	draw_colored_polygon(PackedVector2Array([Vector2(-64, -137), Vector2(-91, 18), Vector2(94, 18), Vector2(64, -137)]), Color("4c605b"))
	draw_rect(Rect2(-19, -180, 38, 54), Color("dfb99d"))
	draw_colored_polygon(PackedVector2Array([Vector2(-48, -233), Vector2(-41, -266), Vector2(18, -277), Vector2(49, -247), Vector2(54, -143), Vector2(-55, -143)]), Color("453c38"))
	draw_circle(Vector2(0, -220), 37, Color("edcbb1"))
	draw_colored_polygon(PackedVector2Array([Vector2(-38, -232), Vector2(-26, -259), Vector2(24, -258), Vector2(41, -229), Vector2(14, -239), Vector2(0, -252), Vector2(-14, -238)]), Color("453c38"))
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -136), Vector2(-34, -90), Vector2(-50, 18), Vector2(51, 18), Vector2(34, -90), Vector2(40, -136)]), Color("d4bd95"))
	draw_line(Vector2(-32, -88), Vector2(33, -88), Color("9d8768"), 2)
	for x in [-14.0, 14.0]:
		if expression == "smile":
			draw_arc(Vector2(x, -222), 5, PI, TAU, 10, Color("4c3e39"), 2)
		else:
			draw_line(Vector2(x - 4, -221), Vector2(x + 4, -221), Color("4c3e39"), 2)
	if expression in ["smile", "shy"]:
		draw_arc(Vector2(0, -212), 10, 0.3, PI - 0.3, 16, Color("9d625a"), 2)
	else:
		draw_line(Vector2(-5, -205), Vector2(5, -205), Color("9d625a"), 2)
	if expression == "thoughtful":
		draw_line(Vector2(-21, -232), Vector2(-8, -235), Color("4c3e39"), 2)
	if expression == "shy":
		draw_circle(Vector2(-23, -208), 7, Color(0.9, 0.5, 0.5, 0.3))
		draw_circle(Vector2(23, -208), 7, Color(0.9, 0.5, 0.5, 0.3))
