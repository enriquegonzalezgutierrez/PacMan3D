# ROADMAP - MartínMan 3D

<!--
==============================================================================
Description: Project development roadmap and progress tracker.
Author: Enrique González Gutiérrez
Email: enrique.gonzalez.gutierrez@gmail.com
==============================================================================
-->

## Phase 1: Core Mechanics & Refactoring (COMPLETED)

### 1. Project Setup & Folder Structure [X]
*   Established a clean, scalable folder layout.
*   Enforced strict English-only naming conventions and standard file header templates.

### 2. Level Design, Procedural Generation, & Verification [X]
*   Created `generate_levels.py`, a robust Python-based procedural level generator utilizing DFS maze generation and self-healing BFS connectivity passes.
*   Enforced mathematical checks to guarantee 100% connected paths, zero dead-ends, and zero 2x2 hollow plazas on every run.
*   Implemented three procedural rendering styles: connected pipes, solid neon cubes, and futuristic cylindrical pillars topped with emissive spheres.

### 3. Physics & World Generation [X]
*   Decoupled world loading, map validation, and mesh instantiation into specialized, single-responsibility scripts.
*   Built dynamic wall color tinting reading directly from level JSON data.
*   Implemented identical physics box colliders across all three visual styles to guarantee 100% consistent movement physics.

### 4. Player Entity (MartínMan) [X]
*   Implemented physics-based kinematics using `move_and_slide()` alongside responsive directional buffering.
*   Decoupled the diorama camera controller entirely into `diorama_camera.gd`, utilizing steep perspective angles, telephoto narrow FOVs, and LERP tracking.
*   Programmed a modular sequential death state triggering local CPUParticles3D explosions.

### 5. Enemy Entities (Ghosts) [X]
*   Designed a decoupled state machine (Leaving, Chase, Scatter, Frightened).
*   Integrated behavior strategies using clean strategy patterns (Blinky, Pinky, Inky, Clyde).
*   Implemented arcade-accurate foso exit paths and a physical one-way gate, preventing ghosts from wandering back into the Ghost House.
*   Applied dynamic alignment calculations to prevent entities from clipping/freezing during odd and even map size transitions.

### 6. SOLID Refactoring Phase [X]
*   **Single Responsibility Principle (SRP):** Split the massive `LevelManager` God Class into `LevelManager` (high-level orchestrator), `MapValidator` (topological checker), and `LevelBuilder` (3D mesh assembler).
*   **Dependency Inversion Principle (DIP):** Wired dynamically generated entities up to the manager through loose signals and callbacks instead of hardcoded paths.

---

## Phase 2: Gameplay Polish & Progression (COMPLETED)

### 1. Automated Level Progression [X]
*   Implemented automatic level transitions in `LevelManager` (loading next `.json` once all pellets are consumed).
*   Added a cinematic victory transition screen to show level-clear text before loading.
*   Designed difficulty scaling sequence, increasing ghost speed and reducing frightened timers as level numbers increase.

### 2. Advanced Ghost AI State Cycles [X]
*   Introduced Chase / Scatter timers (standard arcade timing) where ghosts periodically scatter to designated corners before chasing.
*   Added a proper "Eaten" state where ghosts return to the foso as floating eyes on the shortest path before spawning.

### 3. Audio & SFX Balancing [X]
*   Implemented dynamic BGM pitch scaling (speeding up music as remaining pellets drop and difficulty increases).
*   Toned down post-processing bloom, adjusted Directional Light angles to match camera perspective, and adjusted materials to brushed satin metallic chrome.

### 4. Visual Polish & HUD Enhancements [X]
*   Added screen-shake effects during Player death and ghost consumption.
*   Up-scaled all UI layout components, Minimap (280x280), and typography to display cleanly in Full HD (1920x1080) resolution.

---

## Phase 3: High-Score Persistence & Advanced Mechanics (COMPLETED)

### 1. High-Score Storage & Serialization [X]
*   Built a secure, encrypted local high-score persistence system (`user://high_scores.dat`) using AES-256 password protection to prevent manual save tampering.
*   Synchronized HUD values directly with GameManager on startup to prevent Autoload race conditions.

### 2. Dynamic Ghost House Door Gate [X]
*   Programmed a static physics laser barrier on Layer 4 (8) to block MartínMan from entering.
*   Enabled ghosts to dynamically toggle their collision mask to pass through the door during LEAVING/EATEN states, and collide with it in active chase modes.

### 3. Fruits Variety & Spawn Cycles [X]
*   Developed 5 procedural, level-adapted visual fruits (Cherries, Strawberries, Peaches, Apples, and Keys) with escalating points.
*   Replaced timer-based spawning with event-driven triggers inside `LevelManager`, spawning bonus fruits exactly at 70 and 170 pellets eaten.

---

## Phase 4: Optimizations, Platform Polish & VFX (COMPLETED)

### 1. Cyber Circuits Theme & Spawn Pods [X]
*   Developed a fourth modular rendering style (`circuits`) featuring dark carbon boards wrapped with glowing, level-tinted holographic micro-conduits and nodes.
*   Attached color-matched glowing cyber-spawn pads flat on the foso floor under each ghost's starting spawn coordinates.

### 2. Holographic Portal Gateways [X]
*   Programmed glowing neon-cyan gate arches and shimmering energy curtains at teleport boundaries, dynamically self-aligning their rotation.

### 3. Energy Motion Trails & Thrusters [X]
*   Programmed a highly responsive CPUParticles3D ribbon-style light trail that dynamically changes color (Yellow, Gold, Cyan) depending on active states.
*   Instantiated an energetic downward gold-neon spark jet exhaust upon jumping.

### 4. Mobile Virtual Joystick & Controls [X]
*   Replaced the D-Pad with a custom 360-degree floating analog stick (320px base, 130px knob) and enlarged JUMP button to 220px for ultimate ergonomics.

### 5. Cinematic System Loader [X]
*   Designed a dedicated black loading screen ("GENERATING SYSTEM...") with deferred frame rendering and an 800ms minimum pacing delay to ensure seamless transitions on high-end PCs.

---

## Phase 5: Tournament Mode, Settings & 3D Audio (COMPLETED)

### 1. Local Tournament Leaderboard (Top 5) [X]
*   Expanded the high-score serialization into an encrypted Top 5 local leaderboard array, including automatic legacy migration of older high score saves.
*   Developed an arcade-classic letter-wheel entry interface (A-Z) to let players input their 3-letter initials on Game Over.

### 2. 3D Positional Audio Attenuation [X]
*   Upgraded stereo audio players to AudioStreamPlayer3D, implementing real-time dynamic panning, distance attenuation, and low-pass air absorption filters.

### 3. Interactive Settings Panel [X]
*   Created a clean, cyber-style settings menu inside the Main Menu to adjust master, sfx, and music volumes, utilizing dynamic audio bus generation and encrypted persistence.

### 4. Menorcan Gin Xoriguer Collectibles [X]
*   Swapped 100% of flat procedural pellet items with high-resolution, unshaded, double-sided 3D models (Green clay Xoriguer bottles, giant golden bottles with golden sparks, ice.fbx cubes with cold mist, and lemon.fbx with electric sparks).
*   Programmed 4 gigantic backlit neon perimetric billboards (2.6x4.0 meters) standing on steel posts outside boundaries, displaying a transparent PNG of the Xoriguer logo.

---

## Phase 6: High-Performance Engine Optimizations & Steering (COMPLETED)

### 1. High-Resolution Performance Telemetry [X]
*   Integrated high-resolution millisecond profiling timers wrapping the level generation process to map, trace, and resolve startup bottlenecks with total mathematical precision.

### 2. Class-Level Asset Caching [X]
*   Centralized high-density visual asset loads (standard/power pellets, ice cubes, lemons, and all four individual ghost models) inside `LevelBuilder` during game launch. Spawning entities now query the RAM cache directly, dropping dynamic runtime disk operations to zero.

### 3. Precompiled Animation Libraries [X]
*   Developed an automated startup compiler that instantiates, reads, and remaps bones for all 5 Mixamo FBX animations, caching them into a single `AnimationLibrary` in RAM. MartínMan now spawns natively at level start with 0ms track remapping overhead, resolving Godot's skeletal T-pose duplicate bugs.

### 4. Single-Body Physics Fusion [X]
*   Eliminated the heavy memory overhead of registering 487 separate wall colliders. All static block shapes now reference a single shared `BoxShape3D` and are compiled as a single compound physical static body inside the SceneTree, reducing Jolt body registries by 99.8%.

### 5. Dynamic Visual Mesh Merging [X]
*   Programmed an offline mesh-merging algorithm utilizing `SurfaceTool` to recursively group and weld the 1,400+ procedurally generated pipe visual meshes into 1 or 2 single unified `ArrayMesh` nodes in RAM based on active materials, dropping GPU Draw Calls to exactly 1.

### 6. Offline Level Assembly [X]
*   Optimized Godot's `SceneTree` propagation bottlenecks. The 3D world is generated, merged, and linked completely offline inside an unparented root node in RAM (taking only **`34ms`**), adding the entire completed branch to the active scene in a single atomic frame.

### 7. Grid-Guided Arcade Movement & Lane Snapping [X]
*   Overhauled player movement to read coordinates directly from the grid layout matrix. Removed `test_move()` collision checks for straight-line corridor navigation to prevent side-wall clipping. Added corner-cutting tolerance and automatic lane alignment: when a turn is buffered, MartínMan smoothly snaps to the exact center of the intersection, sliding around corners with fluid arcade steering.

---

## Phase 7: Advanced Graphic VFX & Custom Shaders (FUTURE SCOPE)

### 1. Screen Glitch VFX [ ]
*   Implement screen-space chromatic aberration and noise glitches on camera during player death or ghost consumption.

### 2. Baked ReflectionProbes [ ]
*   Optimize mobile render performance by baking static ReflectionProbes on the satin metals, achieving locked high-framerate executions on budget mobile GPUs.
