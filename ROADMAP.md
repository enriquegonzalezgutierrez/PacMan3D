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

## Phase 3: High-Score Persistence & Advanced Mechanics (FUTURE SCOPE)

### 1. High-Score Storage & Serialization
*   Build a lightweight file serializer to save and load player high-scores locally (`user://high_scores.dat`).
*   Encrypt/Secure the save file using simple cryptographic checks (or Godot's built-in FileAccess encrypted mode) to prevent manual save tampering.

### 2. Dynamic Ghost House Door Gate
*   Programmatically prevent ghosts from entering back into the foso while in Chase/Scatter mode, but allow them to pass through dynamically when in Eaten (floating eyes) state.

### 3. Fruits Variety & Spawn Cycles
*   Introduce dynamic fruit variations per level (Cherries, Strawberries, Peaches, Apple, Key) with escalating point awards.
*   Create a dual-spawn trigger: fruit spawns once at 70 pellets consumed, and again at 170 pellets consumed.

---

## Phase 4: Optimization, Platform Polish & Shaders (FUTURE SCOPE)

### 1. Performance Profiling
*   Leverage Godot's built-in Profiler and Monitor tools to optimize mesh rendering calls (Static Draw Call batching).
*   Bake static lighting or use ReflectionProbes to generate ultra-realistic local reflections on the metallic pipe rails on budget hardware.

### 2. Custom Screen Shaders
*   Develop a canvas-layer post-processing Retro CRT / Curved Screen arcade shader.
*   Implement screen chromatic aberration glitches when Pac-Man gets hit.
