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

This project focuses on robust core mechanics, physics-based movement, procedural level generation, and strict adherence to **SOLID software design principles**. The visual aesthetic relies on Godot's primitive 3D meshes (Spheres, Capsules, and Cubes) paired with vibrant neon lighting and three procedural architectural styles.

## Features (Phase 1 Completed)
*   **Procedural Level Generator (Python):** Automatically crafts braided, symmetric, 100% connected 3D mazes in under `0.01` seconds with zero dead-ends or 2x2 plazas.
*   **Multi-Style Visual Themes:** Levels are rendered dynamically in one of three procedurally generated themes:
    *   `pipes`: Connected double-deck pipeline rails (Pac-Mania style).
    *   `blocks`: Monolithic neon arcade cubes.
    *   `pillars`: Futuristic columns topped with glowing, emissive floating spheres.
*   **Dynamic Level Tinting:** Reads hex color configurations directly from the JSON files to procedurally tint the levels on start.
*   **Decoupled Diorama Camera:** A standalone camera tracking node utilizing steep perspectives, narrow FOVs, and smooth spatial LERP damping to simulate a diorama view.
*   **Arcade-Accurate Ghost AI:** Features coordinate-based pathfinding, behavior strategies (Blinky, Pinky, Inky, Clyde), and hardcoded kinematic foso-exiting logic.
*   **SOLID Software Architecture:** Decoupled interfaces where core nodes interact through signals and public APIs, keeping managers and entities lightweight and single-responsible.

## Project Structure
*   `generate_levels.py` - Procedural level generator script (Python).
*   `/assets/` - UI images, icons, sound effects, and background music.
*   `/data/` - JSON level configuration files.
*   `/scripts/core/` - Global GameManager, LevelManager orchestrator, MapValidator, and LevelBuilder assembler.
*   `/scripts/entities/` - Player, Ghosts, behaviors, DioramaCamera, Portals, and Pellets.
*   `/scripts/ui/` - HUD, procedural Main Menu, and 2D Vectorial Minimap.

## Author
*   **Name:** Enrique González Gutiérrez
*   **Email:** enrique.gonzalez.gutierrez@gmail.com