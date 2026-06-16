# ==============================================================================
# Description: Independent cinematic scrolling Credits screen. Programmatically 
#              constructs and crawls vertical rolling labels over a darkened 
#              background, ending in a neon "Thank You" splash.
#              SOLID Refactoring & Fixes:
#              - BUG FIX: Corrected compilation crash by swapping PRESET_TOP_CENTER 
#                with the correct Godot constant PRESET_CENTER_TOP on line 143.
#              - POSITION FIX: Anchored scroller to TOP_LEFT and vbox to CENTER_TOP 
#                to guarantee massive layouts start 100% hidden below the screen.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name CreditsScreen

const SCROLL_SPEED : float = 45.0 # Pixels per second
const FADE_SPEED : float = 1.2 # Thank you text fade speed

# Credits Roll Configuration Data (Enrique's Professional Profile)
var credits_data : Array[Dictionary] = [
	{"text": "PAC-MAN 3D", "type": "title"},
	{"text": "A modern 3D arcade reimagining", "type": "subtitle"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "LEAD DEVELOPER & SOFTWARE ARCHITECT", "type": "header"},
	{"text": "Enrique González Gutiérrez", "type": "name"},
	{"text": "Senior Software Engineer  |  PHP (Laravel & Symfony)\nSystem Architecture  |  Fullstack & DevOps  |  Remoto ES\nInca, Balearic Islands, Spain", "type": "subtitle"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "PROFESSIONAL PROFILE", "type": "header"},
	{"text": "A veteran Senior Software Engineer with nearly 20 years of hands-on experience designing, scaling, and maintaining complex distributed systems. Possessing complete engineering autonomy to navigate the entire product lifecycle—from pixel-perfect Frontend applications (React/TypeScript) to robust, high-traffic Backend architectures and fully automated containerized deployments (Docker/CI-CD).", "type": "paragraph"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "ARCHITECTURAL PHILOSOPHY", "type": "header"},
	{"text": "Engineering is about pragmatism and reliability. Architecture is not an abstract theory, but a primary tool to build highly maintainable, secure, and profitable software. Expert in implementing Domain-Driven Design (DDD), Hexagonal Architectures (Ports & Adapters), and Event-Sourcing models to decouple core business domains from infrastructure dependencies.", "type": "paragraph"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "ENGINEERING HIGHLIGHTS", "type": "header"},
	{"text": "● PERFORMANCE OPTIMIZATION\nSpecialized in critical database optimization. At Habitissimo, engineered a massive data-layer redesign on high-traffic MySQL systems, achieving a 40% reduction in query latencies.\n\n● DEVOPS & INFRASTRUCTURE\nExpertise in automating environments with Docker, GNU Make, and robust GitLab/GitHub CI-CD pipelines, guaranteeing absolute environment parity and high-availability deployments.", "type": "paragraph"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "procedural research & side projects", "type": "header"},
	{"text": "● SHORTFORGE / Z-REALISM AI (Python)\nDesigned and orchestrated a local AI visual production studio, utilizing Hexagonal Architecture to decouple PyTorch inference models from FastAPI/Redis workers. Implemented sequential VRAM offloading to run heavy LLMs (Llama 3.1) and SDXL Lightning under strict hardware limitations (6GB VRAM).\n\n● BREWPOINT POS (PostgreSQL RPC)\nDeveloped an enterprise-grade transactional POS system for Web/iOS/Android. Encapsulated core financial business logic inside PostgreSQL RPC functions to guarantee atomic, consistent transactions.\n\n● NUMISTA (Laravel 12)\nAn e-commerce multi-tenant architecture utilizing Domain-Driven Design and a dynamic Entity-Attribute-Value (EAV) data model for collectibles management.\n\n● AETHELGARD (TypeScript & Redis)\nA persistent, concurrent MUD game engine. Uses Redis Mutex locks for atomic cross-entity concurrency and Ports & Adapters to decouple game states from Telnet and WebSockets protocols.", "type": "paragraph"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "PROFESSIONAL TIMELINE", "type": "header"},
	{"text": "● Senior Backend Engineer  |  Transformación Digital  (2025 - 2026)\n● Senior Software Engineer  |  Habitissimo  (2019 - 2025)\n● Senior Fullstack Engineer  |  EISI SOFT  (2018 - 2019)\n● Senior Fullstack Developer  |  Kitmaker Entertainment  (2015 - 2018)\n● Senior PHP Developer & Tech Consultant  |  Independent  (2010 - 2015)", "type": "timeline"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "CORE TECHNOLOGIES", "type": "header"},
	{"text": "PHP  •  Laravel  •  Symfony  •  Software Architecture  •  Docker  •  PostgreSQL  •  Python  •  Redis", "type": "subtitle"},
	{"text": "", "type": "spacer_large"},
	
	{"text": "SPECIAL THANKS", "type": "header"},
	{"text": "Godot Engine Community\nJolt Physics 3D\nRetro Arcade Pioneers\n\nAND YOU!\nThank you for playing!", "type": "name"}
]

# Internal UI components
var bg_rect : TextureRect
var scroll_container : Control
var vbox_container : VBoxContainer
var thank_you_label : Label
var credits_bgm_player : AudioStreamPlayer

# State tracking
var is_scroll_finished : bool = false
var thank_you_alpha : float = 0.0

func _ready() -> void:
	# Enforce full screen preset
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_build_background()
	_build_credits_scroller()
	_build_thank_you_splash()
	_setup_credits_bgm()

# Programmatically builds the full-screen background
func _build_background() -> void:
	bg_rect = TextureRect.new()
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg_rect)
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
	add_child(scroll_container)
	
	# Anchor to top-left so position.y is directly equivalent to viewport pixels
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	
	# Center horizontally and place completely off-screen at the bottom of the viewport
	var viewport_size = get_viewport_rect().size
	scroll_container.position.x = viewport_size.x / 2.0
	scroll_container.position.y = viewport_size.y + 100.0 # Starts fully hidden below
	
	vbox_container = VBoxContainer.new()
	vbox_container.add_theme_constant_override("separation", 16)
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
			spacer.custom_minimum_size = Vector2(0, 16)
			vbox_container.add_child(spacer)
			continue
		elif line["type"] == "spacer_large":
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 48)
			vbox_container.add_child(spacer)
			continue
			
		var label := Label.new()
		label.text = line["text"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_container.add_child(label)
		
		match line["type"]:
			"title":
				label.add_theme_font_size_override("font_size", 54)
				label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0)) # Yellow
				label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 1.0)) # Blue outline
				label.add_theme_constant_override("outline_size", 10)
			"subtitle":
				label.add_theme_font_size_override("font_size", 18)
				label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			"header":
				label.text = label.text.to_upper()
				label.add_theme_font_size_override("font_size", 18)
				label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0)) # Cyan
				label.add_theme_constant_override("outline_size", 4)
				label.add_theme_color_override("font_outline_color", Color(0,0,0))
			"name":
				label.add_theme_font_size_override("font_size", 24)
				label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			"timeline":
				label.add_theme_font_size_override("font_size", 16)
				label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
				label.add_theme_constant_override("line_spacing", 6)
			"paragraph":
				# Enable text wrapping on a comfortable reading column width
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.custom_minimum_size = Vector2(800, 0)
				label.add_theme_font_size_override("font_size", 15)
				label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
				label.add_theme_constant_override("line_spacing", 6)

# Builds the hidden "THANK YOU" label sitting at the center of the screen
func _build_thank_you_splash() -> void:
	thank_you_label = Label.new()
	thank_you_label.text = "THANK YOU FOR PLAYING"
	thank_you_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thank_you_label.add_theme_font_size_override("font_size", 48)
	thank_you_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0)) # Neon Yellow
	thank_you_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	thank_you_label.add_theme_constant_override("outline_size", 8)
	
	# Initial visibility state is fully transparent
	thank_you_label.modulate.a = 0.0
	add_child(thank_you_label)
	thank_you_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	thank_you_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	thank_you_label.grow_vertical = GROW_DIRECTION_BOTH

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
	# Press ESC or SPACE to skip/exit the credits and return to the main menu scene
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE:
			get_tree().paused = false
			if GameManager:
				GameManager.reset_game()
			get_tree().reload_current_scene()
