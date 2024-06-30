extends Node2D

@export var pacman_scene : PackedScene 
@export var crossroad_scene : PackedScene
var pacman : Pacman

@onready var hud : HUD = $HUD
@onready var pacman_spawn : Marker2D = $PacmanSpawn

# Called when the node enters the scene tree for the first time.
func _ready():
	var crossroads : Array[Crossroad]
	for marker in $Crossroads.get_children():
		var crossroad = crossroad_scene.instantiate() as Crossroad
		crossroad.position = marker.position
		add_child(crossroad)
		crossroads.push_back(crossroad)
	
	pacman = pacman_scene.instantiate() as Pacman
	pacman.position = pacman_spawn.position
	pacman.pellets = $Pellets
	pacman.crossroads = crossroads
	pacman.space_state = get_world_2d().direct_space_state
	pacman.ate_pellet.connect(hud._on_pacman_ate_pellet)
	
	add_child(pacman)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
