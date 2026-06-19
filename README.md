# MartínMan 3D

<!--
==============================================================================
Description: Main documentation file for the MartínMan 3D project.
Author: Enrique González Gutiérrez
Email: enrique.gonzalez.gutierrez@gmail.com
==============================================================================
-->

![MartínMan 3D Main Menu](assets/ui/images/main_menu_bg.png)

## Overview
**MartínMan 3D** is a modern, highly optimized 3D retro-cyberpunk arcade game set in a Menorcan-themed ciber-taberna, built entirely from scratch in **Godot 4** (Compatibility renderer recommended for cross-platform stability). 

This project focuses on robust core mechanics, physics-based movement, procedural level generation, and strict adherence to **SOLID software design principles**. The visual aesthetic relies on custom PBR-textured rigged 3D models paired with vibrant neon lighting, customized reflections, and four procedural architectural styles.

---

## Features (Phases 1 - 5 completed and optimized)
*   **Procedural Level Generator (Python):** Automatically crafts braided, symmetric, 100% connected 3D mazes in under `0.01` seconds with zero dead-ends or 2x2 plazas.
*   **Multi-Style Visual Themes:** Levels are rendered dynamically in one of four procedurally generated themes:
	*   `pipes`: Connected double-deck pipeline rails with brushed satin metallic reflections.
	*   `blocks`: Monolithic neon arcade cubes.
	*   `pillars`: Futuristic columns topped with glowing, emissive floating spheres.
	*   `circuits`: Holographic printed circuit boards with glowing continuous neon data-bus tracks.
*   **Decoupled Diorama Camera:** A standalone camera tracking node utilizing diometric spectator perspectives (`-50º` tilt angle, narrow `42º` FOV for flat isometric toy-board stability), smooth spatial LERP damping, and a procedural drone bobbing.
*   **Arcade-Accurate Ghost AI:** Features coordinate-based pathfinding, behavior strategies (Blinky, Pinky, Inky, Clyde), kinematic foso-exiting logic, and a deterministic "Eaten" state where floating eyes return to their spawn pads to heal.
*   **Automated Level Progression & Scaling:** Seamless level transitions that dynamically scale ghost speeds, music pitch, and reduce power-pellet timers.
*   **Secure Local Persistence:** Encrypted binary save files with AES-256 password protection for cross-platform cheat prevention (PC and Android sandboxes).
*   **Local Tournament Leaderboard (Top 5):** Structured, encrypted scoreboard tracking the 5 highest local scores. Includes automated data migration to import and update legacy single-score saves from older versions seamlessly on startup.
*   **Classic Letter-Wheel Initials UI:** Interactive 3-slot A-Z character cycling wheel in the HUD upon qualifying Game Over states. Designed with dual control mappings, supporting both tactile mobile arrow buttons and PC keyboard navigation.
*   **Menorcan Gin Xoriguer Collectibles:** 100% custom 3D models replacing traditional pellets:
	*   `Standard Pellets`: Realistic 3D green clay Xoriguer bottles with their classic neck handle and Mahón windmill labels.
	*   `Power Pellets`: Massive (1.6x) textured Xoriguer bottles surrounded by a column of glowing golden magic sparks.
	*   `Ice Pellets`: 3D styled Ice Cubes (`ice.fbx`) wrapped in a frozen cyan mist CPU particle emitter.
	*   `Speed Pellets`: 3D Menorcan Lemons (`lemon.fbx`) wrapped in a high-energy electric cyan lightning CPU particle emitter.
*   **Perimeter Backlit Billboards:** 4 gigantic vertical spectator-angled signboards (2.6x4.0 meters) standing on steel posts outside the play boundaries. Displays a self-illuminating transparent PNG of the Xoriguer logo with custom neon-cyan framing.
*   **3D Positional Audio Attenuation:** Immersive spatial 3D audio. MartínMan's sound effects (munch and death) and ghost eating sounds automatically pan stereo and attenuate log-distantly based on camera coords, including high-frequency air-absorption low-pass filtering.
*   **Interactive Audio Settings Panel:** Self-contained UI overlay programmatically configuring `"Music"` and `"SFX"` AudioServer buses out-of-the-box, saving decibel volume states to encrypted files.
*   **Smart Laser Gate & Portal Arches:** One-way physical laser barriers (Layer 4) preventing MartínMan from entering the foso, paired with self-aligning holographic portal gateways with shimmering energy curtains.
*   **Energy Motion Trails & Thrusters:** Particle-driven continuous light trails (dynamically color-coded: Yellow, Gold, Cyan), jet-thrust jump spark exhausts, and glowing lightning bolt speed pellets.
*   **Cyber Spawn Pods:** Symmetrical high-tech dark carbon and glowing neon containment pads lining the foso floor underneath each ghost.
*   **Cinematic System Loader:** Dedicated black loading screen ("GENERATING SYSTEM...") with deferred frame rendering and an 800ms minimum pacing delay to ensure seamless transitions on high-end PCs.
*   **Prosthetic Virtual Joystick & Layout:** Programmatic 360-degree floating analog stick (320px base, 130px knob) simulating digital keyboard registries natively, and a giant 220px JUMP button.
*   **Polished Game Juice:** Multi-touch virtual mobile controls, cinematic screen shakes on deaths/bites, post-processing bloom, and vectorized minimap radar.

---

## Technical Optimization Details (High-Performance Overhaul)

To guarantee consistent high-framerate executions on mobile GPUs and eliminate level loading micro-stutters, the following major performance systems have been integrated:

### 1. Offline Level Assembly (RAM Spawning)
Instead of instantiating and appending 930+ dynamic nodes directly to the active SceneTree sequentially (which triggers heavy thread-blocking synchronizations with Godot's servers), the entire level structure is compiled **offline in RAM** under an unparented root `level_holder` node.
*   The spawning loop latency has been reduced from **`3002ms` to exactly `33ms` (a 98.8% performance improvement)**.
*   Once fully assembled and optimized, the branch is attached to the active tree in a single frame.

### 2. Centralized Cache Management & Dependency Injection (DIP)
High-density 3D models (standard/power pellets, ice, lemons, and the four separate ghost models) are pre-loaded and cached as `PackedScene` resources in RAM **exactly once** during the startup initialization phase. 
*   Spawning nodes no longer perform expensive dynamic disk read operations or path existence checks, eliminating runtime I/O bottlenecks.

### 3. Dynamic Visual Mesh Merging
To prevent rendering bottlenecks (thousands of individual Draw Calls), the `LevelBuilder` features a decoulped mesh-merging algorithm. 
*   It recursively scans the 1,400+ procedurally generated pipe visual meshes, groups their geometry arrays by unique `Material` reference, and compiles them into **1 or 2 single unified `ArrayMesh` nodes in under `86ms`**, bringing active Draw Calls down to 1.

### 4. Shared Physics & Single-Body Compound Shape
Instead of registering 487 independent static bodies in the physics server, the system instantiates **exactly 1 static body** (`MapWallsPhysics`) and attaches 487 `CollisionShape3D` nodes referencing a single preloaded `BoxShape3D` resource. This reduces Jolt Physics Server registrations by **99.8%**, accelerating physics compilation.

### 5. Precompiled Animation Libraries
Instead of instantiating, parsing, remapping, and freeing 5 heavy Mixamo FBX animations dynamically during level loads, the system extracts bone tracks and compiles a unified `AnimationLibrary` in RAM **once during startup**. This resolves Godot's skeletal T-pose duplication bugs and cuts runtime character compilation overhead to **`0ms`**.

### 6. Grid-Guided Arcade Movement & Lane Snapping
Overhauled the player input controller to read coordinates directly from the grid layout matrix in RAM (`GameManager.level_layout`).
*   Eliminated physics-based `test_move` checks for straight-line corridor navigation, preventing side-wall clipping or diagonal stuck states.
*   Added automatic lane alignment and corner-cutting tolerance: when a turn is buffered, MartínMan smoothly **snaps to the exact center of the intersection**, sliding around corners with fluid arcade steering.

---

## SOLID Software Architecture
*   **Single Responsibility Principle (SRP):** High-level orchestrators (`LevelManager`) are kept lightweight by delegating rendering/mesh-compilation tasks to `LevelBuilder`, topological map checks to `MapValidator`, and volume configurations to `SettingsPanel`.
*   **Open/Closed Principle (OCP):** New architectural styles and ghost AI classes can be plugged in seamlessly by extending the abstract `WallStyleStrategy` and `GhostBehavior` strategies without modifying the core generation loops.
*   **Liskov Substitution Principle (LSP):** Entities implement polymorphic hooks (such as `get_minimap_color()` and `get_minimap_radius()`) allowing `Minimap2D` to draw any node dynamically without querying private states.
*   **Interface Segregation Principle (ISP):** Communication between modules is handled through focused, lightweight signals (`death_completed`, `eaten`, `score_changed`) instead of heavy, monolithic interfaces.
*   **Dependency Inversion Principle (DIP):** Managers and builders interact with entities through loose callbacks and parameter-driven dependency injections (such as precompiled visual cache variables), separating structural assets from logical loops.

---

## Project Structure
*   `generate_levels.py` - Procedural level generator script (Python).
*   `/assets/` - UI images, icons, sound effects, and background music.
*   `/data/` - JSON level configuration files.
*   `/scripts/core/` - Global GameManager, LevelManager orchestrator, MapValidator, and LevelBuilder assembler.
*   `/scripts/entities/` - Player (MartínMan), Ghosts, behaviors, DioramaCamera, Portals, and Pellets.
*   `/scripts/ui/` - HUD, Settings, procedural Main Menu, credits roll, and 2D Vectorial Minimap.

---

## Installation & Setup

To run and edit this project locally, ensure you meet the following requirements:

### Prerequisites
*   **Godot Engine:** Version `4.6` or higher (Compatibility renderer recommended).
*   **Godot Jolt Physics Plugin:** Installed and enabled (handled automatically via the project settings if Jolt is active in your editor).
*   **Python 3.x:** (Optional) Required only if you want to run `generate_levels.py` to compile custom layouts.

### Opening the Project
1. Clone this repository:
   ```bash
   git clone https://github.com/enriquegonzalezgutierrez/MartinMan3D.git
   ```
2. Open the **Godot Project Manager**.
3. Click **Import**, navigate to the cloned folder, select `project.godot`, and click **Import & Edit**.

---

## How to Export to Android (APK)

To compile and export this project for Android testing, follow this checklist:

### 1. Configure the Android SDK & Keystore
Ensure your computer has the Android development tools configured:
1. Install **OpenJDK 17** (or the version recommended by your Godot release).
2. Download and install **Android Studio** (or Android Command Line Tools) to get the Android SDK.
3. Generate a debug keystore using your terminal:
   ```bash
   keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 365
   ```

### 2. Set Up Godot Editor Paths
1. In the Godot editor, go to **Editor -> Editor Settings...**.
2. Scroll down to **Export -> Android**.
3. Provide the absolute file paths for:
   *   `Android Sdk Path` (e.g., `C:/Users/USERNAME/AppData/Local/Android/Sdk`)
   *   `Debug Keystore` (pointing to the `debug.keystore` file you generated)
   *   `Debug Keystore User`: `androiddebugkey`
   *   `Debug Keystore Pass`: `android`

### 3. Install Export Templates
1. Go to **Editor -> Manage Export Templates...**.
2. Download and install the templates matching your active Godot version.

### 4. Build and Export the APK
1. Go to **Project -> Export...**.
2. Select the **Android** preset from the left panel. (If it is missing, click **Add... -> Android**).
3. Ensure **Custom Build** is disabled unless you need to modify native gradle files.
4. Click **Export Project...** at the bottom.
5. Uncheck **Export With Debug** if you are compiling a release build, select your output folder, and click **Save**.
6. Transfer the generated `.apk` file to your Android device and install it.

---

## Author
*   **Name:** Enrique González Gutiérrez
*   **Email:** enrique.gonzalez.gutierrez@gmail.com
