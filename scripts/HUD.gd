class_name HUD
extends Control

@onready var points_text := $PointsContainer/PointsLabel
@onready var points : int = 0
@onready var lives : int = 3

# Called when the node enters the scene tree for the first time.
func _ready():
	set_points(0)
	
func _on_pacman_ate_pellet():
	set_points(points + 10)
			
func set_points(points_count : int):
	points = points_count
	points_text.text = str(points)
		
