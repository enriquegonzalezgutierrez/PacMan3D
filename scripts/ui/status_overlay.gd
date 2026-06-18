# ==============================================================================
# Description: Standalone Status Overlay component.
#              Manages full-screen cinematic messages like "GAME OVER", 
#              "LEVEL CLEARED", and "GENERATING SYSTEM...", as well as 
#              cinematic fade-in transitions.
#              SOLID Refactoring:
#              - SRP Compliance: Extracted from hud.gd to handle screen-blocking 
#                presentations exclusively. Replaced manual _process alpha 
#                fading with highly optimized Godot Tweens.
#              - OCP Compliance: Exposes a flexible API to display any message 
#                without modifying internal UI nodes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name StatusOverlay

var bg_rect : ColorRect
var status_label : Label

func _ready() -> void:
	# Enforce processing during pause states (Game Over requires this to render)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false # Hidden by default
	
	_build_ui()

func _build_ui() -> void:
	# Background Overlay
	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.0, 0.0, 0.0, 0.75) 
	add_child(bg_rect)
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Centered Text Label
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 54) # Large clear text
	status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	status_label.add_theme_constant_override("outline_size", 8)
	status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	bg_rect.add_child(status_label)
	
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	status_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	status_label.grow_vertical = Control.GROW_DIRECTION_BOTH

# Public API to display a cinematic message (e.g., "GAME OVER")
func show_status(message: String, solid_black: bool = false) -> void:
	# Reset alpha in case a tween previously faded it out
	modulate.a = 1.0 
	visible = true
	
	status_label.text = message
	bg_rect.color = Color(0.0, 0.0, 0.0, 1.0 if solid_black else 0.75)

# Public API to hide the overlay instantly
func hide_status() -> void:
	visible = false

# Clean, decoupled Tween animation to replace manual _process fading
func fade_in_from_black(duration: float = 0.6) -> void:
	visible = true
	status_label.text = "" # Clear text for a pure cinematic fade
	bg_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	modulate.a = 1.0
	
	var tween = create_tween()
	# Interpolate transparency down to 0
	tween.tween_property(self, "modulate:a", 0.0, duration)
	# Hide completely once the tween finishes to save rendering performance
	tween.tween_callback(hide_status)

# Checks if the overlay is actively blocking the screen
func is_active() -> bool:
	return visible and modulate.a > 0.0
