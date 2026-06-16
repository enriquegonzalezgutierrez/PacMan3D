# ==============================================================================
# Description: Cowardly/Wanderer behavior strategy for Clyde (Orange).
#              Implements SOLID Open/Closed Principle (OCP).
#              Updates: Overrode visual hooks to make Clyde plump and 
#                       shift his pupils downward to look clumsy/worried.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends GhostBehavior
class_name ClydeBehavior

# Clyde targets player if far away, but runs back to spawn corner if too close
func get_target_position(_ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		var dist_to_player : float = _ghost.global_position.distance_to(player.global_position)
		if dist_to_player > 14.0: # 7 tiles away
			return player.global_position
		
		# If too close, target own spawn corner
		if _ghost is Ghost:
			return _ghost.spawn_position
		return _ghost.global_position
	return _ghost.global_position

# --- GRAPHICS OVERRIDES (SRP/OCP/LSP Compliance) ---

func get_capsule_radius() -> float:
	return 1.05 # Plump

func get_capsule_height() -> float:
	return 1.65 # Round

func get_pupil_offsets() -> Dictionary:
	# Shift both pupil offsets downwards to look worried/pokey (SRP/OCP Compliance)
	return {
		"left": Vector3(-0.35, 0.32, -0.93),
		"right": Vector3(0.35, 0.32, -0.93)
	}
