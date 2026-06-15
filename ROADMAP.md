# ROADMAP - PacMan3D (Phase 1)

## 1. Project Setup & Folder Structure
**Objective:** Establish a clean, scalable, and English-only project structure in Godot 4.

*   `res://data/`: Will contain the JSON files used to build the levels.
*   `res://scenes/`: Will hold all `.tscn` files.
    *   `res://scenes/levels/`: For the main game scene.
    *   `res://scenes/entities/`: For the player, ghosts, pellets, etc.
    *   `res://scenes/ui/`: For the Heads-Up Display (HUD) and menus.
*   `res://scripts/`: Will hold all `.gd` scripts.
    *   `res://scripts/core/`: Game managers, JSON parsers.
    *   `res://scripts/entities/`: Logic for player and enemies.
*   `res://materials/`: Will contain standard materials (colors for primitive shapes).

*Note: All future scripts will strictly include the following header:*
```text
# ==============================================================================
# Description: [Brief description of the file's purpose]
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
```

## 2. Level Design & JSON Parsing
**Objective:** Define the level architecture in a JSON file and create a parser to interpret it in Godot.

*   **JSON Structure Definition:** 
    The level will be represented as a 2D grid matrix (array of arrays or a flat array with width/height) inside a JSON file. 
    *Legend for the grid:*
    *   `0`: Empty space.
    *   `1`: Wall (Cube).
    *   `2`: Normal Pellet (Small Sphere).
    *   `3`: Power Pellet (Medium Sphere).
    *   `4`: Player Spawn Point.
    *   `5`: Ghost Spawn Point.
*   **Level Parser Manager:** 
    A Singleton/Autoload script (`level_manager.gd`) responsible for reading `level_01.json`, parsing the grid, and calculating the exact 3D coordinates (X, Z) based on a defined cell size (e.g., 2.0 meters).

## 3. Physics & World Generation (Primitives Only)
**Objective:** Translate the parsed JSON data into a physical 3D world using only Godot primitive meshes.

*   **Walls (`StaticBody3D`):**
    *   Mesh: `BoxMesh` (Cube).
    *   Collision: `CollisionShape3D` (Box).
    *   Material: Blue color.
*   **Floor (`StaticBody3D`):**
    *   Generated automatically to cover the entire grid size.
    *   Material: Dark gray or black color.
*   **Pellets & Power Pellets (`Area3D`):**
    *   Mesh: `SphereMesh` (Small for normal, slightly larger for power).
    *   Collision: `CollisionShape3D` (Sphere).
    *   Material: Yellow/White color.
    *   Logic: Emits a signal `on_pellet_eaten` when the player enters the area, then queues itself for deletion.

## 4. Player Entity (Pac-Man)
**Objective:** Create the controllable character using physics-based movement.

*   **Node Setup (`CharacterBody3D`):**
    *   Mesh: `SphereMesh` (Yellow color).
    *   Collision: `CollisionShape3D` (Sphere).
*   **Movement Logic:**
    *   Handled via `move_and_slide()` to allow smooth gliding against walls.
    *   Input handling for 4 directions (Up, Down, Left, Right) mapped to the 3D X and Z axes.
    *   Movement constraints to ensure the player aligns reasonably well with the grid structure to avoid getting stuck on corners, utilizing raycasts (`RayCast3D`) to detect valid turns.
*   **State Machine (Basic):** 
    Normal state vs. Invincible state (when eating a Power Pellet).

## 5. Enemy Entities (Ghosts)
**Objective:** Create the enemies using basic AI and primitive capsule shapes.

*   **Node Setup (`CharacterBody3D`):**
    *   Mesh: `CapsuleMesh` (Different colors: Red, Pink, Cyan, Orange).
    *   Collision: `CollisionShape3D` (Capsule).
    *   Detection: `Area3D` to detect collision with the Player.
*   **AI Movement Logic:**
    *   Since it's Phase 1, Ghosts will use a grid-based pseudo-random movement or basic A* pathfinding (using Godot's `AStarGrid2D` mapped to the 3D X/Z coordinates).
    *   They will constantly move forward and pick a new valid direction at every intersection.
*   **Ghost States:**
    *   `CHASE`: Normal state, chasing or wandering.
    *   `FRIGHTENED`: Triggered by a Power Pellet. Movement slows down, color changes to Blue, runs away from the player.
    *   `EATEN`: Returns to the spawn point.

## 6. Game Loop & UI (HUD)
**Objective:** Connect the elements into a fully playable game loop.

*   **Game Manager (`game_manager.gd`):** Autoload script handling the global state.
*   **Win/Loss Conditions:**
    *   Win: Keep track of total pellets generated vs. eaten. When the count reaches 0, trigger Victory.
    *   Loss: If a Ghost touches the player in `CHASE` state, lose a life. If lives reach 0, trigger Game Over.
*   **UI (`Control` nodes):**
    *   Score counter.
    *   Lives counter.
    *   Simple "Game Over" and "You Win" text overlay.