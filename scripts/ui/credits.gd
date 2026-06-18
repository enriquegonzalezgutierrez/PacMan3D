# ==============================================================================
# Description: Independent cinematic scrolling Credits screen. Programmatically 
#              constructs and crawls vertical rolling labels over a darkened 
#              background, ending in a neon "Thank You" splash.
#              SOLID Refactoring & Fixes:
#              - CANVASLAYER FIX: Correctly implemented a root Control container 
#                (main_container) inside the CanvasLayer to handle all anchor 
#                presets and viewport rect calculations without throwing base 
#                object errors.
#              - CROSS-PLATFORM INPUT: Added InputEventScreenTouch support.
#              Phase 2 Updates:
#              - FULL HD SCALE COMPLIANCE: Scaled up all typography (Titles to 82px, 
#                paragraphs to 20px with 1200px reading width, and "Thank You" 
#                to 72px) and increased scroll speed to 75px/sec to look spectacular 
#                on Full HD 1080p canvases.
#              - PROGRAMMATIC SCENE RESET FIX: Replaced reload_current_scene() 
#                with explicit change_scene_to_file() to guarantee a successful 
#                return to the Main Menu since this node is generated programmatically.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends CanvasLayer
class_name CreditsScreen

const SCROLL_SPEED : float = 75.0 # Pixels per second (Sized up for 1080p travel comfort)
const FADE_SPEED : float = 1.2 # Thank you text fade speed

# Credits Roll Configuration Data (Project Specific)
var credits_data : Array[Dictionary] = [
	{"text": "MARTÍNMAN 3D", "type": "title"},
	{"text": "A modern 3D retro-cyberpunk arcade", "type": "subtitle"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "LEAD DEVELOPER & SOFTWARE ARCHITECT", "type": "header"},
	{"text": "Enrique González Gutiérrez", "type": "name"},
	{"text": "enrique.gonzalez.gutierrez@gmail.com", "type": "subtitle"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "PROCEDURAL LEVEL DESIGN", "type": "header"},
	{"text": "Python-based DFS/BFS Maze Generator\nDynamic Connectivity & Topological Validator\nProcedural Mesh Assembly (Pipes, Blocks, Pillars)", "type": "paragraph"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "AI & GAMEPLAY MECHANICS", "type": "header"},
	{"text": "Strategy Pattern Ghost Behaviors (Blinky, Pinky, Inky, Clyde)\nSolid State Machine AI (Chase, Scatter, Frightened)\nPhysics-based Kinematic Diorama Camera\nCustom 3D Movement Dynamics", "type": "paragraph"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "GRAPHICS & VISUAL POLISH", "type": "header"},
	{"text": "Dynamic Neon Lighting & Post-Processing Bloom\nProcedural Primitive 3D Character Models\nProcedural Retro Animations (Skirt Ruffles, Blinking Eyes)", "type": "paragraph"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "AUDIO & SFX", "type": "header"},
	{"text": "Dynamic BGM Tracks\nRetro Arcade Sound Effects (Waka-Waka, Siren)", "type": "paragraph"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "CORE TECHNOLOGIES", "type": "header"},
	{"text": "Godot Engine 4\nGDScript\nJolt Physics 3D\nPython", "type": "paragraph"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "SPECIAL THANKS", "type": "header"},
	{"text": "Godot Engine Community\nJolt Physics Team\nRetro Arcade Pioneers\n\nAND YOU!\nThank you for playing!", "type": "name"}
]

# Internal UI components
var main_container : Control
var bg_rect : TextureRect
var scroll_container : Control
var vbox_container : VBoxContainer
var thank_you_label : Label
var credits_bgm_player : AudioStreamPlayer

# State tracking
var is_scroll_finished : bool = false
var thank_you_alpha : float = 0.0
var is_mobile : bool = false

func _ready() -> void:
	# Detect mobile/web platform for dynamic text
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web")
	
	# Create the root Control container to hold all UI elements inside this CanvasLayer
	main_container = Control.new()
	add_child(main_container)
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_build_background()
	_build_credits_scroller()
	_build_thank_you_splash()
	_setup_credits_bgm()

# Programmatically builds the full-screen background
func _build_background() -> void:
	bg_rect = TextureRect.new()
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	main_container.add_child(bg_rect)
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Defensive Fallback: Try loading credits_bg, fallback to main_menu_bg if not found
	var bg_tex = load("res://assets/ui/images/credits_bg.png")
	if not bg_tex:
		bg_tex = load("res://assets/ui/images/main_menu_bg.png")
	bg_rect.texture = bg_tex
	
	# Add a dark cinematic overlay to increase text contrast
	var darken_overlay := ColorRect.new()
	darken_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	bg_rect.add_child(darken_overlay)
	darken_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Procedurally constructs the vertical rolling label stack
func _build_credits_scroller() -> void:
	scroll_container = Control.new()
	main_container.add_child(scroll_container)
	
	# Anchor to top-left so position.y is directly equivalent to viewport pixels
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	
	# Center horizontally and place completely off-screen at the bottom of the viewport
	var viewport_size = get_viewport().get_visible_rect().size
	scroll_container.position.x = viewport_size.x / 2.0
	scroll_container.position.y = viewport_size.y + 100.0 # Starts fully hidden below
	
	vbox_container = VBoxContainer.new()
	vbox_container.add_theme_constant_override("separation", 36) # Increased spacing
	vbox_container.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll_container.add_child(vbox_container)
	
	# Anchor to CENTER_TOP so the top of the vbox sits exactly on scroll_container's Y position
	# This prevents massive text layouts from overlapping the screen on start
	vbox_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	vbox_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	
	# Parse data and generate labels dynamically
	for line in credits_data:
		if line["type"] == "spacer_small":
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 24)
			vbox_container.add_child(spacer)
			continue
		elif line["type"] == "spacer_large":
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 64)
			vbox_container.add_child(spacer)
			continue
			
		var label := Label.new()
		label.text = line["text"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_container.add_child(label)
		
		match line["type"]:
			"title":
				label.add_theme_font_size_override("font_size", 82) # Large crisp title
				label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0)) # Yellow
				label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 1.0)) # Blue outline
				label.add_theme_constant_override("outline_size", 14)
			"subtitle":
				label.add_theme_font_size_override("font_size", 24) # Clear subtitle
				label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			"header":
				label.text = label.text.to_upper()
				label.add_theme_font_size_override("font_size", 28) # Pronounced header
				label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0)) # Cyan
				label.add_theme_constant_override("outline_size", 6)
				label.add_theme_color_override("font_outline_color", Color(0,0,0))
			"name":
				label.add_theme_font_size_override("font_size", 34)
				label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			"timeline":
				label.add_theme_font_size_override("font_size", 20)
				label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
				label.add_theme_constant_override("line_spacing", 8)
			"paragraph":
				# Enable text wrapping on a comfortable reading column width (Scaled up for 1080p)
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.custom_minimum_size = Vector2(1200, 0) # Spreads out wider
				label.add_theme_font_size_override("font_size", 20) # Sized up
				label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
				label.add_theme_constant_override("line_spacing", 8)

# Builds the hidden "THANK YOU" label sitting at the center of the screen
func _build_thank_you_splash() -> void:
	thank_you_label = Label.new()
	thank_you_label.text = "THANK YOU FOR PLAYING"
	thank_you_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thank_you_label.add_theme_font_size_override("font_size", 72) # Large cinematic splash
	thank_you_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0)) # Neon Yellow
	thank_you_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	thank_you_label.add_theme_constant_override("outline_size", 12)
	
	# Initial visibility state is fully transparent
	thank_you_label.modulate.a = 0.0
	main_container.add_child(thank_you_label)
	thank_you_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	thank_you_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	thank_you_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Add dynamic skip instruction
	var skip_label := Label.new()
	skip_label.text = "Tap screen to return to menu" if is_mobile else "Press SPACE to return to menu"
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_label.add_theme_font_size_override("font_size", 24)
	skip_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	main_container.add_child(skip_label)
	skip_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skip_label.position.y -= 64.0

# Programmatically configures and plays the credits background soundtrack
func _setup_credits_bgm() -> void:
	credits_bgm_player = AudioStreamPlayer.new()
	
	# Load credits_bgm, fallback to main_menu_bgm if the file is missing
	var bgm_stream = load("res://assets/audio/bgm/credits_bgm.mp3")
	if not bgm_stream:
		bgm_stream = load("res://assets/audio/bgm/main_menu_bgm.mp3")
		
	if bgm_stream:
		credits_bgm_player.stream = bgm_stream
		credits_bgm_player.volume_db = -8.0
		credits_bgm_player.autoplay = true
		add_child(credits_bgm_player)
		credits_bgm_player.play()

func _process(delta: float) -> void:
	# 1. Roll the credit container upwards
	if not is_scroll_finished:
		scroll_container.position.y -= SCROLL_SPEED * delta
		
		# Stop scrolling only once the bottom of the container fully clears the top of the viewport (Y=0.0)
		var scroller_bottom : float = scroll_container.position.y + vbox_container.size.y
		if scroller_bottom < 0.0:
			is_scroll_finished = true
	else:
		# 2. Fade in the "THANK YOU" splash slowly
		if thank_you_alpha < 1.0:
			thank_you_alpha += FADE_SPEED * delta
			thank_you_label.modulate.a = clampf(thank_you_alpha, 0.0, 1.0)

func _input(event: InputEvent) -> void:
	# Support both Keyboard (ESC/SPACE) and Mobile Screen Touches
	var is_skip_triggered = false
	
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE:
			is_skip_triggered = true
			
	elif event is InputEventScreenTouch and event.pressed:
		is_skip_triggered = true
		
	if is_skip_triggered:
		get_tree().paused = false
		if GameManager:
			GameManager.reset_game()
		
		# --- STABLE PHYSICAL SCENE TRANSITION FIX ---
		# Explicitly loading the physics main scene file resolves the programmatic 
		# reload limitations of code-only scenes.
		get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
