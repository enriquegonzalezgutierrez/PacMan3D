# ROADMAP - PacMan3D

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

### 4. Player Entity (Pac-Man) [X]
*   Implemented physics-based kinematics using `move_and_slide()` alongside responsive directional buffering.
*   Decoupled the diorama camera controller entirely into `diorama_camera.gd`, utilizing steep perspective angles, telephoto narrow FOVs, and LERP tracking.
*   Programmed a modular sequential death state triggering local GPUParticles3D explosions.

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
*   Programmed a static physics laser barrier on Layer 4 (8) to block Pac-Man from entering.
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
*   Programmed a highly responsive GPUParticles3D ribbon-style light trail that dynamically changes color (Yellow, Gold, Cyan) depending on active states.
*   Instantiated an energetic downward gold-neon spark jet exhaust upon jumping.

### 4. Mobile Virtual Joystick & Controls [X]
*   Replaced the rigid 4-button D-Pad with a custom 360-degree floating analog stick (320px base, 130px knob) and enlarged JUMP button to 220px for ultimate ergonomics.

### 5. Cinematic System Loader [X]
*   Designed a dedicated black loading screen ("GENERATING SYSTEM...") with deferred frame rendering and an 800ms minimum pacing delay to ensure seamless transitions on high-end PCs.

---

## Phase 5: Tournament Mode, settings & 3D Audio (FUTURE SCOPE)

### 1. Local Tournament Leaderboard (Top 5)
*   Expand the high-score serialization into a top 5 local leaderboard array.
*   Develop an arcade-classic letter-wheel entry interface (A-Z) in the HUD to let players input their 3-letter initials (e.g. `ENR`, `AAA`) on Game Over.

### 2. 3D Positional Audio Attenuation
*   Replace standard AudioStreamPlayers with AudioStreamPlayer3Ds for waka-waka and ghost sirens, attenuating volume based on distance to the diorama camera.

### 3. Interactive Settings Panel
*   Create a clean, cyber-style settings menu inside the Main Menu to adjust master, sfx, and music volumes.

---

## Phase 6: Advanced Graphic VFX & Custom Shaders (FUTURE SCOPE)

### 1. Screen Glitch VFX
*   Implement screen-space chromatic aberration and noise glitches on camera during player death or ghost consumption.

### 2. Baked ReflectionProbes
*   Optimize mobile render performance by baking static ReflectionProbes on the satin metals, achieving locked high-framerate executions on budget mobile GPUs.
