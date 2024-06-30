extends Control

func _ready():
	get_window().size = get_window().size * 3

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ENTER:
			var in_depth = int($TextEdit.text)
			if in_depth and in_depth > 1:
				get_node("/root/Globals").depth = in_depth
				get_tree().change_scene_to_file("res://scenes/Main.tscn")
