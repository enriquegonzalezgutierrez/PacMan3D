# PacMan3D

<!--
==============================================================================
Description: Main documentation file for the PacMan3D project.
Author: Enrique González Gutiérrez
Email: enrique.gonzalez.gutierrez@gmail.com
==============================================================================
-->

![PacMan3D Main Menu](assets/ui/images/main_menu_bg.png)

## Overview
**PacMan3D** is a modern 3D reimagining of the classic arcade game, built entirely from scratch in **Godot 4**. 

This project focuses on robust core mechanics, physics-based movement, procedural level generation, and strict adherence to **SOLID software design principles**. The visual aesthetic relies on Godot's primitive 3D meshes (Spheres, Capsules, and Cubes) paired with vibrant neon lighting, customized satin-metallic PBR reflections, and four procedural architectural styles.

---

## Features (Phases 1, 2, 3, 4 & 5 Completed)
*   **Procedural Level Generator (Python):** Automatically crafts braided, symmetric, 100% connected 3D mazes in under `0.01` seconds with zero dead-ends or 2x2 plazas.
*   **Multi-Style Visual Themes:** Levels are rendered dynamically in one of four procedurally generated themes:
    *   `pipes`: Connected double-deck pipeline rails with brushed satin metallic reflections.
    *   `blocks`: Monolithic neon arcade cubes.
    *   `pillars`: Futuristic columns topped with glowing, emissive floating spheres.
    *   `circuits`: Holographic printed circuit boards with glowing continuous neon data-bus tracks.
*   **Decoupled Diorama Camera:** A standalone camera tracking node utilizing steep perspectives, narrow FOVs, smooth spatial LERP damping, and a procedural drone bobbing.
*   **Arcade-Accurate Ghost AI:** Features coordinate-based pathfinding, behavior strategies (Blinky, Pinky, Inky, Clyde), kinematic foso-exiting logic, and a deterministic "Eaten" state where floating eyes return to their spawn pads to heal.
*   **Automated Level Progression & Scaling:** Seamless level transitions that dynamically scale ghost speeds, music pitch, and reduce power-pellet timers.
*   **Secure Local Persistence:** Encrypted binary save files with AES-256 password protection for cross-platform cheat prevention (PC and Android sandboxes).
*   **Local Tournament Leaderboard (Top 5):** Structured, encrypted scoreboard tracking the 5 highest local scores. Includes automated data migration to import and update legacy single-score saves from older versions seamlessly on startup.
*   **Classic Letter-Wheel Initials UI:** Interactive 3-slot A-Z character cycling wheel in the HUD upon qualifying Game Over states. Designed with dual control mappings, supporting both tactile mobile arrow buttons and PC keyboard navigation.
*   **3D Positional Audio Attenuation:** Immersive spatial 3D audio. Pac-Man's waka-waka and ghost sirens automatically pan stereo and attenuate log-distantly based on camera coords, including high-frequency air-absorption low-pass filtering.
*   **Interactive Audio Settings Panel:** Self-contained UI overlay programmatically configuring `"Music"` and `"SFX"` AudioServer buses out-of-the-box, saving decibel volume states to encrypted files.
*   **Smart Laser Gate & Portal Arches:** One-way physical laser barriers (Layer 4) preventing Pac-Man from cheating, paired with self-aligning holographic portal gateways with shimmering energy curtains.
*   **Energy Motion Trails & Thrusters:** Particle-driven continuous light trails (dynamically color-coded: Yellow, Gold, Cyan), jet-thrust jump spark exhausts, and glowing lightning bolt speed pellets.
*   **Cyber Spawn Pods:** Symmetrical high-tech dark carbon and glowing neon containment pads lining the foso floor underneath each ghost.
*   **Cinematic System Loader:** Dedicated black loading screen ("GENERATING SYSTEM...") with deferred frame rendering and an 800ms minimum pacing delay to ensure seamless transitions on high-end PCs.
*   **Prosthetic Virtual Joystick & Layout:** Programmatic 360-degree floating analog stick (320px base, 130px knob) simulating digital keyboard registries natively, and a giant 220px JUMP button.
*   **Polished Game Juice:** Multi-touch virtual mobile controls, cinematic screen shakes on deaths/bites, post-processing bloom, and vectorized minimap radar.
*   **SOLID Software Architecture:** Decoupled interfaces where core nodes interact through signals and public APIs, keeping managers and entities lightweight and single-responsible.

---

## Project Structure
*   `generate_levels.py` - Procedural level generator script (Python).
*   `/assets/` - UI images, icons, sound effects, and background music.
*   `/data/` - JSON level configuration files.
*   `/scripts/core/` - Global GameManager, LevelManager orchestrator, MapValidator, and LevelBuilder assembler.
*   `/scripts/entities/` - Player, Ghosts, behaviors, DioramaCamera, Portals, and Pellets.
*   `/scripts/ui/` - HUD, Settings, procedural Main Menu, credits roll, and 2D Vectorial Minimap.

---

## Installation & Setup

To run and edit this project locally, ensure you meet the following requirements:

### Prerequisites
*   **Godot Engine:** Version `4.6` or higher (Forward Plus renderer recommended).
*   **Godot Jolt Physics Plugin:** Installed and enabled (handled automatically via the project settings if Jolt is active in your editor).
*   **Python 3.x:** (Optional) Required only if you want to run `generate_levels.py` to compile custom layouts.

### Opening the Project
1. Clone this repository:
   ```bash
   git clone https://github.com/enriquegonzalezgutierrez/PacMan3D.git
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
