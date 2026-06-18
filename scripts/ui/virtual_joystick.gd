# ==============================================================================
# Description: Standalone Virtual Analog Joystick component.
#              Programmatically draws and maps a 360-degree floating analog stick, 
#              simulating standard key action presses inside the native Godot 
#              Input registry.
#              SOLID Refactoring:
#              - SRP Compliance: Extracted from hud.gd. This class now has a 
#                single reason to change: modifications to mobile touch inputs 
#                and joystick rendering.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name VirtualJoystick

var base_radius : float = 160.0 # Sized up significantly for 1080p high-DPI thumb comfort
var knob_radius : float = 65.0 # Enlarged central knob
var is_dragging : bool = false
var touch_id : int = -1

var base_center : Vector2
var knob_pos : Vector2

# Dict to monitor currently simulated pressed actions
var simulated_actions : Dictionary = {
	"ui_left": false,
	"ui_right": false,
	"ui_up": false,
	"ui_down": false
}

func _ready() -> void:
	# Define control boundaries for input detection
	custom_minimum_size = Vector2(320, 320)
	base_center = Vector2(160, 160)
	knob_pos = base_center

func _draw() -> void:
	# 1. Draw Translucent Base ring
	draw_circle(base_center, base_radius, Color(0.08, 0.08, 0.1, 0.45))
	# Neon cyan thick border
	draw_arc(base_center, base_radius, 0, TAU, 32, Color(0.0, 0.8, 1.0, 0.6), 5.0)
	
	# 2. Draw Translucent Glowing Knob
	draw_circle(knob_pos, knob_radius, Color(1.0, 1.0, 0.0, 0.65)) # Glowing yellow
	# Orange neon border for high-contrast visibility
	draw_arc(knob_pos, knob_radius, 0, TAU, 24, Color(1.0, 0.5, 0.0, 0.8), 3.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not is_dragging:
			is_dragging = true
			touch_id = event.index
			_update_joystick_displacement(event.position)
		elif not event.pressed and event.index == touch_id:
			_reset_joystick_state()
			
	elif event is InputEventScreenDrag and is_dragging and event.index == touch_id:
		_update_joystick_displacement(event.position)

# Calculates 2D offset vector and applies digital simulation mapping
func _update_joystick_displacement(touch_pos: Vector2) -> void:
	var direction_vector : Vector2 = touch_pos - base_center
	var current_distance : float = direction_vector.length()
	
	# Clamp knob within physical outer base boundary
	if current_distance > base_radius:
		direction_vector = direction_vector.normalized() * base_radius
		
	knob_pos = base_center + direction_vector
	queue_redraw() # Request frame redraw instantly
	
	# Convert continuous analog vector to simulated action presses (0.35 Dead-zone)
	var normalized_ratio : Vector2 = direction_vector / base_radius
	
	_simulate_action("ui_left", normalized_ratio.x < -0.35)
	_simulate_action("ui_right", normalized_ratio.x > 0.35)
	_simulate_action("ui_up", normalized_ratio.y < -0.35)
	_simulate_action("ui_down", normalized_ratio.y > 0.35)

# Restores knob to dead-center and releases all simulated keyboard bindings
func _reset_joystick_state() -> void:
	is_dragging = false
	touch_id = -1
	knob_pos = base_center
	queue_redraw()
	
	for action in simulated_actions.keys():
		_simulate_action(action, false)

# Safely commits Mock Input states directly into the native Godot Engine Registry
func _simulate_action(action_name: String, should_press: bool) -> void:
	if simulated_actions[action_name] != should_press:
		simulated_actions[action_name] = should_press
		if should_press:
			Input.action_press(action_name)
		else:
			Input.action_release(action_name)
