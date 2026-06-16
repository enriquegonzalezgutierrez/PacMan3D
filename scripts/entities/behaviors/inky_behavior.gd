# ==============================================================================
# Description: Flanker/Tactician behavior strategy for Inky (Cyan).
#              Implements SOLID Open/Closed Principle (OCP).
#              Updates: Overrode visual hooks to make Inky stubby and 
#                       offset his pupils inward to look cross-eyed.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends GhostBehavior
class_name InkyBehavior

# Inky uses Blinky's position and the player's position to flank the player
func get_target_position(_ghost: CharacterBody3D, player: Node3D) -> Vector3:
	if player:
		var blinky : Node3D = null
		var ghosts = _ghost.get_tree().get_nodes_in_group("ghosts")
		
		for g in ghosts:
			if g is Ghost and g.ghost_type == "Blinky":
				blinky = g
				break
		
		if blinky:
			var vec_to_player : Vector3 = player.global_position - blinky.global_position
			return player.global_position + vec_to_player
		return player.global_position
	return _ghost.global_position

# --- GRAPHICS OVERRIDES (SRP/OCP/LSP Compliance) ---

func get_capsule_radius() -> float:
	return 1.0 # Stubby

func get_capsule_height() -> float:
	return 1.55 # Short

func get_pupil_offsets() -> Dictionary:
	# Shift both pupil offsets inward to look cross-eyed/derpy (SRP/OCP Compliance)
	return {
		"left": Vector3(-0.23, 0.4, -0.93),
		"right": Vector3(0.23, 0.4, -0.93)
	}
