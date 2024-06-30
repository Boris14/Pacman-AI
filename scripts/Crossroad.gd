class_name Crossroad
extends StaticBody2D

func get_body() -> Shape2D:
	return $CollisionShape2D.shape
