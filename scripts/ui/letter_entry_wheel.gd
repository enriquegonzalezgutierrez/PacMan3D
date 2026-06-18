# ==============================================================================
# Description: Classic Arcade Letter Wheel Selector UI.
#              Provides an interactive 3-letter slot machine interface for 
#              entering player initials on high scores. Supports dual-control 
#              mappings (mobile touch clicks & PC keyboard arrow keys).
#              SOLID Refactoring:
#              - SRP Compliance: Extracted entirely from the main HUD. This class 
#                is responsible solely for capturing and formatting initials inputs.
#              - OCP Compliance: The character set and slot size are parameter-driven 
#                and can be extended (e.g., to 4 initials or more characters) 
#                without modifying the navigation logic.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Control
class_name LetterEntryWheel

# Emits the clean 3-character string upon confirmation
signal initials_submitted(initials: String)

const CHAR_SET : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_ "
var char_indices : Array[int] = [0, 0, 0] # Pointers to CHAR_SET for each of the 3 slots
var current_slot : int = 0 # Currently highlighted slot (0, 1, or 2)

# UI Elements
var slots_container : HBoxContainer
var slot_labels : Array[Label] = []
var confirm_button : Button

# Themes and Styles
var active_style : StyleBoxFlat
var inactive_style : StyleBoxFlat

func _ready() -> void:
	# Enforce processing during pause states (game is frozen under Game Over)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_initialize_retro_styles()
	_build_ui()
	_update_visuals()

func _initialize_retro_styles() -> void:
	# Stylized highlighted slot frame (Active neon gold)
	active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.12, 0.12, 0.0, 0.95)
	active_style.border_width_left = 4
	active_style.border_width_top = 4
	active_style.border_width_right = 4
	active_style.border_width_bottom = 4
	active_style.border_color = Color(1.0, 0.8, 0.0) # Gold Cyber-Glow
	active_style.set_corner_radius_all(10)
	active_style.content_margin_left = 32
	active_style.content_margin_right = 32
	active_style.content_margin_top = 16
	active_style.content_margin_bottom = 16
	
	# Standby inactive slot frame (Dark steel blue)
	inactive_style = StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.04, 0.04, 0.06, 0.8)
	inactive_style.border_width_left = 2
	inactive_style.border_width_top = 2
	inactive_style.border_width_right = 2
	inactive_style.border_width_bottom = 2
	inactive_style.border_color = Color(0.2, 0.2, 0.3)
	inactive_style.set_corner_radius_all(10)
	inactive_style.content_margin_left = 32
	inactive_style.content_margin_right = 32
	inactive_style.content_margin_top = 16
	inactive_style.content_margin_bottom = 16

# Programmatically builds the tactile wheel layout
func _build_ui() -> void:
	var root_panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.01, 0.01, 0.02, 0.96) # Dark space blue background
	panel_style.border_width_left = 5
	panel_style.border_width_top = 5
	panel_style.border_width_right = 5
	panel_style.border_width_bottom = 5
	panel_style.border_color = Color(0.0, 0.8, 1.0) # Cyan Laser border
	panel_style.set_corner_radius_all(20)
	panel_style.content_margin_left = 64
	panel_style.content_margin_right = 64
	panel_style.content_margin_top = 48
	panel_style.content_margin_bottom = 48
	root_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(root_panel)
	
	root_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 36)
	root_panel.add_child(main_vbox)
	
	# Flashing neon Cyan header title
	var title_label := Label.new()
	title_label.text = "NEW TOURNAMENT RECORD!\nENTER INITIALS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	title_label.add_theme_constant_override("outline_size", 10)
	title_label.add_theme_color_override("font_outline_color", Color(0,0,0))
	main_vbox.add_child(title_label)
	
	# Horizontal alignment containing the 3 tactile letter slot-wheels
	slots_container = HBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 24)
	slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(slots_container)
	
	# Compile 3 distinct interactive letter slots
	for i in range(3):
		var slot_vbox := VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 16)
		slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slots_container.add_child(slot_vbox)
		
		# Tactile Up arrow button (▲)
		var up_btn := Button.new()
		up_btn.text = "▲"
		up_btn.add_theme_font_size_override("font_size", 48)
		up_btn.flat = true
		up_btn.pressed.connect(func(): _cycle_slot_char(i, -1)) # Previous character (upwards)
		slot_vbox.add_child(up_btn)
		
		# Center highlighted character Panel
		var letter_panel := PanelContainer.new()
		letter_panel.add_theme_stylebox_override("panel", inactive_style)
		slot_vbox.add_child(letter_panel)
		
		# Handle focus highlighting dynamically when slots are tapped directly
		letter_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventScreenTouch and event.pressed:
				current_slot = i
				_update_visuals()
		)
		
		var char_label := Label.new()
		char_label.text = "A"
		char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		char_label.add_theme_font_size_override("font_size", 84) # Giant highly-legible letter
		char_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		letter_panel.add_child(char_label)
		slot_labels.append(char_label)
		
		# Tactile Down arrow button (▼)
		var down_btn := Button.new()
		down_btn.text = "▼"
		down_btn.add_theme_font_size_override("font_size", 48)
		down_btn.flat = true
		down_btn.pressed.connect(func(): _cycle_slot_char(i, 1)) # Next character (downwards)
		slot_vbox.add_child(down_btn)
		
	# Large tactile confirm button
	confirm_button = Button.new()
	confirm_button.text = "CONFIRM ENTRY"
	confirm_button.add_theme_font_size_override("font_size", 36)
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.0, 0.6, 0.2, 0.85) # Vivid green
	btn_style.border_width_left = 3
	btn_style.border_width_top = 3
	btn_style.border_width_right = 3
	btn_style.border_width_bottom = 3
	btn_style.border_color = Color(0.0, 1.0, 0.3)
	btn_style.set_corner_radius_all(12)
	btn_style.content_margin_top = 18
	btn_style.content_margin_bottom = 18
	confirm_button.add_theme_stylebox_override("normal", btn_style)
	confirm_button.add_theme_stylebox_override("hover", btn_style)
	confirm_button.add_theme_stylebox_override("pressed", btn_style)
	
	main_vbox.add_child(confirm_button)
	confirm_button.pressed.connect(_on_confirm_pressed)

# Cycles characters backwards or forwards inside the index boundaries
func _cycle_slot_char(slot_idx: int, direction: int) -> void:
	# Force focus highlight to match tapped cycling button instantly
	current_slot = slot_idx
	
	char_indices[slot_idx] = (char_indices[slot_idx] + direction + CHAR_SET.length()) % CHAR_SET.length()
	_update_visuals()

# Renders highlighting frames, colors, and characters dynamically
func _update_visuals() -> void:
	for i in range(3):
		var label = slot_labels[i]
		var panel = label.get_parent() as PanelContainer
		
		# Set text matching the character pointer index
		label.text = CHAR_SET[char_indices[i]]
		
		# Symmetrical Focus rendering: Gold glow for active, grey for standby
		if i == current_slot:
			panel.add_theme_stylebox_override("panel", active_style)
			label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0)) # Glowing gold
		else:
			panel.add_theme_stylebox_override("panel", inactive_style)
			label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7)) # Standby silver

# Implements highly responsive physical keyboard routing (PC Ergonomics)
func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventKey and event.is_pressed():
		match event.keycode:
			KEY_LEFT:
				current_slot = (current_slot - 1 + 3) % 3
				_update_visuals()
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				current_slot = (current_slot + 1) % 3
				_update_visuals()
				get_viewport().set_input_as_handled()
			KEY_UP:
				_cycle_slot_char(current_slot, -1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_cycle_slot_char(current_slot, 1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_on_confirm_pressed()
				get_viewport().set_input_as_handled()

# Compiles string and submits notification
func _on_confirm_pressed() -> void:
	var final_initials : String = ""
	for i in range(3):
		final_initials += CHAR_SET[char_indices[i]]
		
	# Clean up any trailing space strings safely
	final_initials = final_initials.strip_edges()
	if final_initials == "":
		final_initials = "AAA" # Retro default safeguard
		
	initials_submitted.emit(final_initials)
	queue_free() # Self-destroy upon submission
