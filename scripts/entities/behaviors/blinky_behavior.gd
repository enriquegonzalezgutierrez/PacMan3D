# ==============================================================================
# Description: Direct Chaser behavior strategy for Blinky (Red).
#              Implements SOLID Open/Closed Principle (OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends GhostBehavior
class_name BlinkyBehavior

# Blinky always targets the player's exact direct position
func get_target_position(_ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		return player.global_position
	return _ghost.global_position
