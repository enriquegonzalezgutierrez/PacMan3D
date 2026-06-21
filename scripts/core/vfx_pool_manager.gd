# ==============================================================================
# Description: Global Object Pool Manager (Autoload Singleton).
#              Pre-allocates highly volatile nodes (Floating Scores, Death Particles, 
#              Jump Sparks) into memory arrays at startup. Reuses them instead 
#              of instantiating and freeing them dynamically via queue_free().
#              SOLID Refactoring:
#              - SRP Compliance: Isolates memory pooling logic completely from 
#                the Player and LevelBuilder.
#              - Performance: Eliminates mid-game Garbage Collection spikes 
#                (stutters) on mobile devices by reusing inactive nodes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends Node

# Pool Configurations (How many to pre-allocate)
const SCORE_POOL_SIZE : int = 15
const DEATH_PARTICLE_POOL_SIZE : int = 3
const SHIELD_SHATTER_POOL_SIZE : int = 2

# The actual arrays holding the pre-allocated nodes
var score_pool : Array[FloatingScore3D] = []
var death_particle_pool : Array[CPUParticles3D] = []
var shatter_particle_pool : Array[CPUParticles3D] = []

func _ready() -> void:
	# Build the pools silently during the black loading screen
	_build_score_pool()
	_build_death_particle_pool()
	_build_shatter_particle_pool()

# --- POOL INITIALIZATION ---

func _build_score_pool() -> void:
	for i in range(SCORE_POOL_SIZE):
		var score_lbl = FloatingScore3D.new()
		# Add to tree but keep completely hidden and inactive
		score_lbl.visible = false
		score_lbl.set_process(false)
		add_child(score_lbl)
		score_pool.append(score_lbl)

func _build_death_particle_pool() -> void:
	for i in range(DEATH_PARTICLE_POOL_SIZE):
		var particles := CPUParticles3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.15, 0.15, 0.15)
		
		# Base generic material (will be overridden on request)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 1.0, 0.0)
		mesh.material = mat
		
		particles.mesh = mesh
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 0.3
		particles.direction = Vector3.UP
		particles.spread = 180.0
		particles.initial_velocity_min = 4.0
		particles.initial_velocity_max = 7.0
		particles.gravity = Vector3(0.0, -12.0, 0.0)
		
		particles.amount = 30
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.lifetime = 0.8
		
		particles.emitting = false
		add_child(particles)
		death_particle_pool.append(particles)

func _build_shatter_particle_pool() -> void:
	for i in range(SHIELD_SHATTER_POOL_SIZE):
		var shatter := CPUParticles3D.new()
		var piece := BoxMesh.new()
		piece.size = Vector3(0.1, 0.1, 0.1)
		
		var mat := StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.0, 0.8, 1.0)
		piece.material = mat
		
		shatter.mesh = piece
		shatter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		shatter.emission_sphere_radius = 1.0
		shatter.direction = Vector3.UP
		shatter.spread = 180.0
		shatter.initial_velocity_min = 4.0
		shatter.initial_velocity_max = 8.0
		shatter.gravity = Vector3(0, -9.8, 0)
		
		shatter.amount = 24
		shatter.one_shot = true
		shatter.explosiveness = 1.0
		shatter.lifetime = 0.6
		
		shatter.emitting = false
		add_child(shatter)
		shatter_particle_pool.append(shatter)


# --- PUBLIC POOL REQUEST APIS ---

# Spawns a floating score from the pool using a custom string and color
func spawn_floating_score(pos: Vector3, text_value: String, color: Color) -> void:
	for score_lbl in score_pool:
		# Find the first inactive label
		if not score_lbl.visible:
			score_lbl.global_position = pos + Vector3(0.0, 1.2, 0.0)
			score_lbl.text = text_value
			score_lbl.modulate = color
			
			# "Wake up" the node
			score_lbl.visible = true
			score_lbl.modulate.a = 1.0
			score_lbl.set_process(true)
			return
			
	# If pool is exhausted (rare), instantiate a fallback dynamically
	push_warning("VFXPoolManager: Floating Score pool exhausted! Generating fallback.")
	var fallback := FloatingScore3D.new()
	fallback.text = text_value
	fallback.modulate = color
	fallback.global_position = pos + Vector3(0.0, 1.2, 0.0)
	get_tree().current_scene.add_child(fallback)

# Spawns death explosion particles from the pool
func spawn_death_particles(pos: Vector3, color: Color) -> void:
	for p in death_particle_pool:
		if not p.emitting:
			p.global_position = pos
			# Override material color safely
			if p.mesh and p.mesh.material:
				(p.mesh.material as StandardMaterial3D).albedo_color = color
				
			p.restart() # Forces CPUParticles3D to emit from the beginning
			p.emitting = true
			return

# Spawns glass shatter particles from the pool
func spawn_shield_shatter_particles(pos: Vector3) -> void:
	for p in shatter_particle_pool:
		if not p.emitting:
			p.global_position = pos
			p.restart()
			p.emitting = true
			return
