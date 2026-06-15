# ==============================================================================
# Description: Ambusher behavior strategy for Pinky (Pink).
#              Implements SOLID Open/Closed Principle (OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends GhostBehavior
class_name PinkyBehavior

# Pinky targets 8 meters (4 grid tiles) ahead of the player's current moving direction
func get_target_position(_ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		var player_dir : Vector3 = player.velocity.normalized()
		if player_dir != Vector3.ZERO:
			return player.global_position + (player_dir * 8.0)
		return player.global_position
	return _ghost.global_position
