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
*   Enforced strict strict English-only naming conventions and standard file header templates.

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
*   Designed a decoupled state machine (Leaving, Chase, Frightened).
*   Integrated behavior strategies using clean strategy patterns (Blinky, Pinky, Inky, Clyde).
*   Implemented arcade-accurate foso exit paths and a physical one-way gate, preventing ghosts from wandering back into the Ghost House.
*   Applied dynamic alignment calculations to prevent entities from clipping/freezing during odd and even map size transitions.

### 6. SOLID Refactoring Phase [X]
*   **Single Responsibility Principle (SRP):** Split the massive `LevelManager` God Class into `LevelManager` (high-level orchestrator), `MapValidator` (topological checker), and `LevelBuilder` (3D mesh assembler).
*   **Dependency Inversion Principle (DIP):** Wired dynamically generated entities up to the manager through loose signals and callbacks instead of hardcoded paths.

---

## Phase 2: Gameplay Polish & Progression (Future Scope)

### 1. Automated Level Progression
*   Implement automatic level transitions in `GameManager` (e.g., loading `level_02.json` once all pellets are consumed).
*   Design a progression sequence, increasing ghost speed and reducing frightened timers as level numbers increase.

### 2. Advanced Ghost AI State Cycles
*   Introduce Chase / Scatter timers (standard arcade timing) where ghosts periodically stop chasing and retreat to their designated corners before resuming.
*   Add a proper "Eaten" state where ghosts return to the foso as floating eyeballs before respawning.

### 3. Audio & SFX Balancing
*   Implement dynamic BGM pitch scaling (speeding up music as remaining pellets drop below 20%).
*   Add audio attenuation based on distance for 3D positional waka-waka and ghost siren sound effects.

### 4. Visual Polish & HUD Enhancements
*   Add screen-shake effects during Player death and ghost consumption.
*   Implement transition overlays (fade-to-black) between levels and menu selections.