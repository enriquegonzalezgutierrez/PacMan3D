# ==============================================================================
# Description: Base class (Strategy Pattern) for Ghost targeting behaviors.
#              Enables strict adherence to SOLID Open/Closed Principle (OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name GhostBehavior

# Virtual method to be overridden by specific ghost behavior subclasses
# Returns the 3D target coordinate that the ghost should navigate towards
func get_target_position(ghost: CharacterBody3D, player: Node3D) -> Vector3:
	# Fallback target is always the player's direct position
	if player:
		return player.global_position
	return ghost.global_position
