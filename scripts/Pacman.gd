class_name Pacman
extends CharacterBody2D

signal ate_pellet
signal died

const SPEED = 35

@onready var animated_sprite := $AnimatedSprite2D
@onready var eat_area := $EatArea
@onready var action_area := $ActionArea

var space_state : PhysicsDirectSpaceState2D

var next_movement_direction = Vector2.ZERO
var movement_direction = Vector2.ZERO
var shape_query = PhysicsShapeQueryParameters2D.new()

# Array of {position, direction} elements
var a_star_depth : int
var actions : Array
var destination : Vector2
var pellets : Node2D


#region AStar2D

class AStarPacman:
	extends AStar2D
	
	var space_state : PhysicsDirectSpaceState2D
	var crossroads : Array[Crossroad]
	
	func _init(in_space_state : PhysicsDirectSpaceState2D, in_crossroads : Array[Crossroad]):
		space_state = in_space_state
		crossroads = in_crossroads
	
	func get_crossroad_position(id : int) -> Vector2:
		for crossroad in crossroads:
			if crossroad.get_rid().get_id() == id:
				return crossroad.position
		return Vector2.ZERO
	
	func _compute_cost(from_id : int, to_id : int) -> float:
		var cost = 1000.0
		var from_pos = get_crossroad_position(from_id)
		var to_pos = get_crossroad_position(to_id)
		var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos, 0b0100)
		query.collide_with_areas = true
		var hit = space_state.intersect_ray(query)
		while hit:
			cost = cost - 10.0
			var excluded = Array(query.exclude)
			excluded.append(hit.collider.get_rid())
			query.exclude = excluded
			hit = space_state.intersect_ray(query)
		return cost
	
var a_star : AStarPacman
var crossroads : Array[Crossroad]

func get_neighbour_point_ids(crossroad : Crossroad) -> Array:
	var result : Array[int]
	var pos = crossroad.global_position
	var rid = crossroad.get_body().get_rid()
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var query = PhysicsRayQueryParameters2D.create(pos, pos, 0b1001, [self])
	for dir in directions:
		query.to = pos + dir * 300
		var hit = space_state.intersect_ray(query)
		if hit:
			print(hit.collider.name)
			var hit_crossroad = hit.collider as Crossroad
			if hit_crossroad:
				hit_crossroad.get_body()
				result.append(hit.collider.get_rid().get_id())
			else:
				print("hit.collider")
	return result

func init_a_star(crossroads : Array[Crossroad]):
	a_star = AStarPacman.new(get_world_2d().direct_space_state, crossroads)
	a_star.reserve_space(10 * 10)
	for crossroad in crossroads:
		var c_id = crossroad.get_rid().get_id()
		var c_pos = crossroad.position
		a_star.add_point(c_id, c_pos)
	for crossroad in crossroads:
		var c_id = crossroad.get_rid().get_id()
		for neighbour_id in get_neighbour_point_ids(crossroad):
			a_star.connect_points(c_id, neighbour_id)
			
func reconstruct_path(path : PackedVector2Array) -> Array:
	var result = Array()
	if path.size() <= 1:
		return result
	for i in range(1, path.size()):
		var from_position = path[i - 1]
		var to_position = path[i]
		if from_position.x > to_position.x:
			result.push_back(Vector2.LEFT)
		elif from_position.x < to_position.x:
			result.push_back(Vector2.RIGHT)
		elif from_position.y > to_position.y:
			result.push_back(Vector2.UP)
		else:
			result.push_back(Vector2.DOWN)
	return result

#endregion

func _ready():
	init_a_star(crossroads)	
	var pacman_id = a_star.get_closest_point(position)
	var to_id = a_star.get_closest_point(Vector2(116,44))
	print(reconstruct_path(a_star.get_point_path(pacman_id, to_id)))
	#print(a_star.get_id_path(crossroads[3].get_body().get_rid().get_id(), crossroads[20].get_body().get_rid().get_id()))
	a_star_depth = get_node("/root/Globals").depth
	shape_query.shape = $CollisionShape2D.shape
	shape_query.collision_mask = 1
	shape_query.exclude = [self]
	animated_sprite.play("eating")
	eat_area.area_entered.connect(_on_eat_area_entered)
	action_area.body_entered.connect(_on_action_area_body_entered)
	#destination = position
	#actions = a_star_get_actions(position, a_star_depth)
	#_on_action_area_body_entered(null)

func _physics_process(delta):
	next_movement_direction = Vector2.ZERO
	if movement_direction == Vector2.ZERO:
		movement_direction = next_movement_direction
	if can_move_in_direction(next_movement_direction, delta):
		movement_direction = next_movement_direction
		rotation = next_movement_direction.angle()
	
	velocity = movement_direction * SPEED
	move_and_slide()

func can_move_in_direction(dir: Vector2, delta: float) -> bool:
	shape_query.transform = global_transform.translated(dir * SPEED * delta * 3)
	var result = get_world_2d().direct_space_state.intersect_shape(shape_query)
	return result.size() < 1	

func _on_action_area_body_entered(body : Node2D): 
	if actions.is_empty():
		actions = a_star_get_actions(destination, a_star_depth)
	next_movement_direction = actions.pop_front()

func _on_eat_area_entered(area : Area2D):
	if area.is_in_group("Pellets"):
		area.queue_free()
		ate_pellet.emit()

#region Pacman AI using A* algorithm

# Represents Pacman's state (position + eaten pellets) for the A* algorithm
class State:
	var position : Vector2
	var eaten_pellets : Array

	func _init(arg, pellets : Array = []):
		if arg is String:
			var position_str = arg.get_slice("|", 0)
			position_str = position_str.trim_prefix("(").trim_suffix(")")
			var position_values = position_str.split_floats(", ")
			position = Vector2(position_values[0], position_values[1])
			
			var pellets_str = arg.get_slice("|", 1)
			if pellets_str.is_empty():
				return
			pellets_str = pellets_str.split(",", false)
			eaten_pellets = Array(pellets_str).map(func(id): return rid_from_int64(int(id)))
		elif arg is Vector2:
			position = arg
			eaten_pellets = pellets
	
	func _to_string():
		var result = str(position) + "|"
		for pellet in eaten_pellets:
			result = result + str(pellet) + ","
		return result

# Check if a states position is already in states
func is_state_already_in(states, new_state):
	for state in states:
		if State.new(state).position == State.new(new_state).position:
			return true;
	return false;

# Runs A* algorithm to get the actions to perform
func a_star_get_actions(start_pos : Vector2, depth : int):
	assert(depth > 0)
	var start_state = State.new(start_pos)
	var start_state_str = str(start_state)
	var frontier = [str(start_state)]
	var came_from = {}
	var g_scores = {}
	var f_scores = {}
	g_scores[str(start_state)] = 0
	f_scores[str(start_state)] = h(start_state_str)
	
	while frontier.size() > 0:
		var current = frontier.pop_front()
		depth = depth - 1
		if State.new(current).eaten_pellets.size() >= pellets.get_child_count() or depth <= 0:
			return get_action_sequence(came_from, current, start_pos)
		for neighbor in get_neighbour_states(current):
			if is_state_already_in(frontier, neighbor):
				continue
			var tentative_g_score = g_scores[current] + 1
			if g_scores.find_key(neighbor) == null or tentative_g_score < g_scores[neighbor]:
				came_from[neighbor] = current
				g_scores[neighbor] = tentative_g_score
				f_scores[neighbor] = tentative_g_score + h(neighbor)
				if neighbor not in frontier:
					frontier.append(neighbor)
					frontier.sort_custom(func(a,b): return f_scores[a] < f_scores[b])
	return []

# The Heuristic function (the amount pellets left to eat + the distance from the closest pellet)
func h(state_str : String):
	var state = State.new(state_str)
	var closest_pellet_dist = INF
	for pellet in pellets.get_children():
		var pellet_distance = state.position.distance_to(pellet.global_position)
		if pellet_distance < closest_pellet_dist:
			closest_pellet_dist = pellet_distance
	var pellets_left = pellets.get_child_count() - state.eaten_pellets.size()
	return pellets_left + closest_pellet_dist * 0.1

# Translates the path of states to a sequence of actions
func get_action_sequence(came_from : Dictionary, current : String, start_pos : Vector2) -> Array:
	var result = []
	var total_path = [current]
	destination = State.new(current).position
	while current in came_from.keys():
		var to_remove = current
		current = came_from[current]
		came_from.erase(to_remove)
		if is_state_already_in(total_path, current):
			continue
		total_path.push_front(current)
		if State.new(current).position.is_equal_approx(start_pos):
			break
	assert(total_path.size() > 1)
	for i in range(1, total_path.size()):
		result.append(get_action(total_path[i - 1], total_path[i]))
	return result

# Gets the action needed to get from one state to another
func get_action(from : String, to : String) -> Vector2:
	var from_position = State.new(from).position
	var to_position = State.new(to).position
	if from_position.x > to_position.x:
		return Vector2.LEFT
	elif from_position.x < to_position.x:
		return Vector2.RIGHT
	elif from_position.y > to_position.y:
		return Vector2.UP
	else:
		return Vector2.DOWN

func get_raycast_query_from_state(state_str : String) -> PhysicsRayQueryParameters2D:
	var state = State.new(state_str)
	var result = PhysicsRayQueryParameters2D.create(state.position, state.position, 0b1101)
	result.collide_with_areas = true
	result.exclude = state.eaten_pellets
	return result 

# Raycast in all direction to get neighbour states
func get_neighbour_states(state_str : String) -> Array:
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var result = []
	for direction in directions:
		var new_state = get_state_in_direction(get_raycast_query_from_state(state_str), direction)
		if new_state.is_empty():
			continue
		new_state = new_state + state_str.get_slice("|", 1)
		result.append(new_state)
	return result

func get_state_in_direction(query : PhysicsRayQueryParameters2D, direction : Vector2) -> String:
	var result = ""
	query.to = query.from + direction * 300
	var pellets = []
	var hit = space_state.intersect_ray(query)
	while hit:
		if hit.collider is TileMap:
			return result
		elif hit.collider is Area2D:
			pellets.append(hit.collider.get_rid())
		else:
			result = str(hit.collider.position) + "|"
			for pellet in pellets:
				result = result + str(pellet.get_id()) + ","
			return result	
		var excluded = Array(query.exclude)
		excluded.append(hit.collider.get_rid())
		query.exclude = excluded
		hit = space_state.intersect_ray(query)
	return result
	
	#endregion
