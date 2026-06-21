# ==============================================================================
# Description: Standalone Status Overlay component.
#              Manages full-screen cinematic messages like "GAME OVER", 
#              "LEVEL CLEARED", and "GENERATING SYSTEM...", as well as 
#              cinematic transitions and Screen Glitch VFX.
#              Phase 3 Update (AAA Visuals):
#              - Death Glitch Shader: Implemented a programmatic screen-space 
#                shader that simulates a hardware crash (Chromatic Aberration 
#                and tearing) when the player is killed.
#              SOLID Refactoring:
#              - SRP Compliance: Extracted from hud.gd to handle screen-blocking 
#                presentations exclusively. Replaced manual _process alpha 
#                fading with highly optimized Godot Tweens.
#              - OCP Compliance: Exposes a flexible API to display any message 
#                or trigger full-screen VFX without modifying internal UI nodes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name StatusOverlay

var bg_rect : ColorRect
var status_label : Label

# --- PHASE 3: SCREEN GLITCH VFX COMPONENTS ---
var glitch_rect : ColorRect
var glitch_material : ShaderMaterial

const GLITCH_SHADER_CODE : String = """
shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Pseudo-random noise generator
float rand(vec2 co) {
	return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	if (glitch_intensity <= 0.0) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		// 1. Tearing / Wave Distortion
		float noise = rand(vec2(TIME, SCREEN_UV.y)) * 2.0 - 1.0;
		float offset = noise * 0.05 * glitch_intensity;
		
		// Create sharp horizontal cuts (tearing)
		if (fract(SCREEN_UV.y * 10.0 + TIME) > 0.8) {
			offset *= 2.5;
		}
		
		vec2 distorted_uv = vec2(SCREEN_UV.x + offset, SCREEN_UV.y);
		
		// 2. Chromatic Aberration (RGB split)
		float rgb_shift = 0.03 * glitch_intensity;
		
		float r = texture(screen_texture, distorted_uv + vec2(rgb_shift, 0.0)).r;
		float g = texture(screen_texture, distorted_uv).g;
		float b = texture(screen_texture, distorted_uv - vec2(rgb_shift, 0.0)).b;
		
		// 3. Scanline overlay
		float scanline = sin(SCREEN_UV.y * 800.0) * 0.04 * glitch_intensity;
		
		COLOR = vec4(r - scanline, g - scanline, b - scanline, 1.0);
	}
}
"""

func _ready() -> void:
	# Enforce processing during pause states (Game Over requires this to render)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false # Hidden by default
	
	_build_ui()
	_build_glitch_layer()

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

# Programmatically compiles the screen-reading shader layer on top of everything
func _build_glitch_layer() -> void:
	glitch_rect = ColorRect.new()
	
	var shader := Shader.new()
	shader.code = GLITCH_SHADER_CODE
	
	glitch_material = ShaderMaterial.new()
	glitch_material.shader = shader
	glitch_material.set_shader_parameter("glitch_intensity", 0.0)
	
	glitch_rect.material = glitch_material
	glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't block clicks!
	
	add_child(glitch_rect)
	glitch_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Public API to display a cinematic message (e.g., "GAME OVER")
func show_status(message: String, solid_black: bool = false) -> void:
	# Reset alpha in case a tween previously faded it out
	modulate.a = 1.0 
	visible = true
	bg_rect.visible = true
	
	status_label.text = message
	bg_rect.color = Color(0.0, 0.0, 0.0, 1.0 if solid_black else 0.75)

# Public API to hide the overlay instantly
func hide_status() -> void:
	visible = false

# Clean, decoupled Tween animation to replace manual _process fading
func fade_in_from_black(duration: float = 0.6) -> void:
	visible = true
	bg_rect.visible = true
	status_label.text = "" # Clear text for a pure cinematic fade
	bg_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	modulate.a = 1.0
	
	var tween = create_tween()
	# Interpolate transparency down to 0
	tween.tween_property(self, "modulate:a", 0.0, duration)
	# Hide completely once the tween finishes to save rendering performance
	tween.tween_callback(hide_status)

# Checks if the text overlay is actively blocking the screen
func is_active() -> bool:
	return visible and bg_rect.visible and modulate.a > 0.0

# --- GLITCH EFFECT CONTROLLER ---

# Temporarily enables the screen, spikes the shader intensity, and fades it out
func trigger_death_glitch() -> void:
	# Make sure the master control is visible to render the shader layer
	visible = true
	bg_rect.visible = false # We don't want the black background here
	modulate.a = 1.0
	
	# Spike intensity to 100%
	glitch_material.set_shader_parameter("glitch_intensity", 1.0)
	
	var tween = create_tween()
	# Violently snap to 0.5, then fade to 0.0 over half a second
	tween.tween_property(glitch_material, "shader_parameter/glitch_intensity", 0.5, 0.1)
	tween.tween_property(glitch_material, "shader_parameter/glitch_intensity", 0.0, 0.4)
	
	# Hide the container entirely when done to save GPU cycles
	tween.tween_callback(hide_status)
