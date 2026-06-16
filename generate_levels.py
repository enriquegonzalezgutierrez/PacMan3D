# ==============================================================================
# Description: Procedural Pac-Man Level Generator (V7.1 - Multi-Style)
#              Generates braided symmetric mazes. Features an automated BFS 
#              flood-fill self-healing pass to guarantee 100% connectivity.
#              Updates: 
#              - Randomly chooses and embeds a "rendering_style" ("pipes", 
#                "blocks", or "pillars") directly into the JSON level data.
# Author: Enrique González Gutiérrez
# ==============================================================================
import json
import random
import os
import sys

# Map Constants (Must be odd numbers for perfect maze generation)
W, H = 31, 31

# Vibrant Neon Colors for the pipes (Yellow blacklisted to avoid Pac-Man conflict)
NEON_COLORS = [
    "#FF0000", # Neon Red
    "#00FF00", # Neon Green
    "#00FFFF", # Neon Cyan
    "#FF00FF", # Neon Magenta
    "#FF8800", # Neon Orange
    "#8800FF"  # Neon Purple
]

# Randomly selected visual themes for the level walls
ART_STYLES = [
    "pipes",   # Connected double-deck pipeline rails
    "blocks",  # Standard solid neon arcade cubes
    "pillars"  # Futuristic pillars topped with glowing spheres
]

def is_foso(x, y):
    """Surgical mask: Returns True only if coordinates belong to the Ghost House."""
    # Foso sits exactly between rows 12-16 and cols 12-15 on the left half
    return 12 <= y <= 16 and 12 <= x <= 15

def is_portal_wall(x, y):
    """Surgical mask: Returns True only if coordinates belong to the portal tubes."""
    # Portal tubes sit on rows 13 and 15, from col 0 to 4
    return (y == 13 or y == 15) and x < 5

def creates_plaza(grid, x, y):
    """Checks if carving a path at (x, y) would create an illegal 2x2 open plaza."""
    grid[y][x] = 0
    plaza_found = False
    
    for dy in [0, -1]:
        for dx in [0, -1]:
            if 0 <= y+dy < H-1 and 0 <= x+dx < W-1:
                if (grid[y+dy][x+dx] == 0 and 
                    grid[y+dy][x+dx+1] == 0 and 
                    grid[y+dy+1][x+dx] == 0 and 
                    grid[y+dy+1][x+dx+1] == 0):
                    plaza_found = True
                    
    grid[y][x] = 1
    return plaza_found

def generate_maze_base():
    """Generates the raw left half of the maze using DFS, avoiding rigid zones."""
    grid = [[1 for _ in range(W)] for _ in range(H)]
    
    # Start at (1, 1)
    stack = [(1, 1)]
    grid[1][1] = 0
    visited = set([(1, 1)])
    
    # --- BOUNDARY AVOIDANCE MASK ---
    # Register Ghost House foso in visited list so DFS never carves into it
    for y in range(12, 17):
        for x in range(12, 16):
            visited.add((x, y))
            
    # Register Left Portal corridor in visited list so DFS never cuts it
    for y in range(13, 16):
        for x in range(0, 6):
            visited.add((x, y))
    
    while stack:
        cx, cy = stack[-1]
        dirs = [(0, -2), (0, 2), (-2, 0), (2, 0)]
        random.shuffle(dirs)
        carved = False
        
        for dx, dy in dirs:
            nx, ny = cx + dx, cy + dy
            if 0 < nx <= W//2 and 0 < ny < H-1 and (nx, ny) not in visited:
                grid[cy + dy//2][cx + dx//2] = 0
                grid[ny][nx] = 0
                visited.add((nx, ny))
                stack.append((nx, ny))
                carved = True
                break
                
        if not carved:
            stack.pop()
            
    return grid

def stamp_features_left_half(grid):
    """Stamps Ghost House walls and Portal tunnels on the left half of the grid."""
    
    # 1. Left side of Ghost House (y: 12 to 16, x: 12 to 15)
    for y in range(12, 17):
        for x in range(12, 16):
            if y == 12 or y == 16 or x == 12:
                grid[y][x] = 1 # Solid foso walls
            else:
                grid[y][x] = 0 # Inner foso floor
                
    # 2. Portal & Safe Enclosed Tunnel (Row 14, Cols 0 to 5)
    for x in range(0, 6):
        grid[14][x] = 0 # Portal path
        
        # Enclose the tunnel in walls up to the entry point (Col 5)
        if x < 5:
            grid[13][x] = 1 # Top wall
            grid[15][x] = 1 # Bottom wall
            
    return grid

def braid_left_half(grid):
    """Self-correcting pass: Detects and resolves ALL dead ends on the left half in a single pass."""
    dead_ends = []
    
    # Gather all current dead-ends on the left half
    for y in range(1, H-1):
        for x in range(1, (W//2)+1):
            if is_foso(x, y):
                continue
            if y == 14 and x < 5:
                continue
                
            if grid[y][x] == 0:
                walkable = 0
                for dx, dy in [(0,-1), (0,1), (-1,0), (1,0)]:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx <= W//2 and 0 <= ny < H:
                        if grid[ny][nx] == 0:
                            walkable += 1
                            
                if walkable <= 1:
                    dead_ends.append((x, y))
                    
    # Resolve gathered dead-ends sequentially
    for x, y in dead_ends:
        # Re-verify if this cell is still a dead-end
        walkable = 0
        for dx, dy in [(0,-1), (0,1), (-1,0), (1,0)]:
            nx, ny = x + dx, y + dy
            if 0 <= nx <= W//2 and 0 <= ny < H:
                if grid[ny][nx] == 0:
                    walkable += 1
        if walkable > 1:
            continue # Already connected! Skip.
            
        dirs = [(0, -1), (0, 1), (-1, 0), (1, 0)]
        random.shuffle(dirs)
        resolved = False
        
        for dx, dy in dirs:
            nx, ny = x + dx, y + dy      # Wall to break
            nnx, nny = x + 2*dx, y + 2*dy # Neighbor on the other side
            
            if 0 < nx <= W//2 and 0 < ny < H-1:
                if is_foso(nx, ny) or is_portal_wall(nx, ny) or ny == 14:
                    continue
                    
                if grid[ny][nx] == 1:
                    if (0 < nnx <= W//2 and grid[nny][nnx] == 0) or nx == W//2:
                        if not creates_plaza(grid, nx, ny):
                            grid[ny][nx] = 0
                            resolved = True
                            break
        
        # Fallback safety: force open a side connection if restricted while respecting creates_plaza
        if not resolved:
            for dx, dy in dirs:
                nx, ny = x + dx, y + dy
                if 0 < nx <= W//2 and 0 < ny < H-1 and grid[ny][nx] == 1:
                    if not is_foso(nx, ny) and not is_portal_wall(nx, ny) and ny != 14:
                        if not creates_plaza(grid, nx, ny):
                            grid[ny][nx] = 0
                            break
                            
    return grid

def mirror_grid(grid):
    """Mirrors the perfectly braided left half to the right half."""
    for y in range(H):
        for x in range(W // 2):
            grid[y][W - 1 - x] = grid[y][x]
    return grid

def ensure_connectivity(grid):
    """Runs a post-generation BFS to heal and connect any isolated walkable segments."""
    start_pos = (15, 23) # Player Spawn Point
    
    # Helper to determine if a cell is walkable
    def is_walkable(x, y):
        return grid[y][x] != 1
        
    # 1. BFS to find all reachable coordinates
    queue = [start_pos]
    reachable = set([start_pos])
    
    while queue:
        cx, cy = queue.pop(0)
        for dx, dy in [(0,-1), (0,1), (-1,0), (1,0)]:
            nx, ny = cx + dx, cy + dy
            # Wrap portals
            if nx < 0: nx = W - 1
            if nx >= W: nx = 0
            if ny < 0: ny = H - 1
            if ny >= H: ny = 0
            
            # Map mirrored right half to left half to simplify coordinates
            if nx > W // 2:
                nx = W - 1 - nx
                
            if is_walkable(nx, ny) and (nx, ny) not in reachable:
                reachable.add((nx, ny))
                queue.append((nx, ny))
                
    # 2. Gather all isolated walkable cells
    isolated = []
    for y in range(1, H-1):
        for x in range(1, (W//2)+1):
            if is_walkable(x, y) and (x, y) not in reachable:
                isolated.append((x, y))
                
    # 3. Heal isolated areas by carving a bridge to the nearest reachable zone
    for ix, iy in isolated:
        if (ix, iy) in reachable:
            continue
            
        healed = False
        dirs = [(0, -1), (0, 1), (-1, 0), (1, 0)]
        random.shuffle(dirs)
        
        for dx, dy in dirs:
            wx, wy = ix + dx, iy + dy     # Intermediate wall
            tx, ty = ix + 2*dx, iy + 2*dy # Destination cell
            
            if 0 < wx <= W//2 and 0 < wy < H-1:
                if (tx, ty) in reachable and grid[wy][wx] == 1:
                    # Never break foso walls, portal corridors, or the portal row
                    if not is_foso(wx, wy) and not is_portal_wall(wx, wy) and wy != 14:
                        if not creates_plaza(grid, wx, wy):
                            grid[wy][wx] = 0 # Bridge carved!
                            reachable.add((wx, wy))
                            reachable.add((ix, iy))
                            healed = True
                            break
                            
        # Direct link fallback: if jumping 2-steps fails, bridge directly to any reachable neighbor
        if not healed:
            for dx, dy in dirs:
                wx, wy = ix + dx, iy + dy
                if 0 < wx <= W//2 and 0 < wy < H-1:
                    if (wx, wy) in reachable:
                        reachable.add((ix, iy))
                        healed = True
                        break
                        
    return grid

def finalize_game_features(grid):
    """Applies global entities, clears spawns, and generates pellets."""
    # Ghost Spawns (Perfect symmetric 2x2 square inside the foso)
    grid[12][15] = 0 # Foso Gate Open
    grid[14][14] = 5 
    grid[14][16] = 5 
    grid[15][14] = 5 
    grid[15][16] = 5 
    
    # Portals (Horizontal & Vertical)
    grid[14][0] = 6 
    grid[14][W-1] = 7 
    grid[0][15] = 8  # Top Portal
    grid[H-1][15] = 9 # Bottom Portal
    
    # Player Spawn
    grid[23][15] = 4
    grid[23][14] = 0
    grid[23][16] = 0

    # Convert paths (0) to standard pellets (2)
    for y in range(1, H-1):
        for x in range(1, W-1):
            if grid[y][x] == 0:
                # Do not place pellets inside the Ghost House foso!
                if 12 <= y <= 16 and 12 <= x <= 18:
                    continue
                grid[y][x] = 2
                
    # Clear paths around doorways and spawns
    for x in range(1, 6):
        grid[14][x] = 0
        grid[14][W-1-x] = 0
    grid[11][15] = 0 # Foso door clearing
    grid[1][15] = 0  # Top portal doorway clearing
    grid[H-2][15] = 0 # Bottom portal doorway clearing
    grid[23][15] = 4 # Ensure player spawn isn't overwritten

    # Place Power Pellets (3) in 4 corners
    corners = [(1, 1), (1, W-2), (H-2, 1), (H-2, W-2)]
    for cy, cx in corners:
        if grid[cy][cx] == 2:
            grid[cy][cx] = 3
            
    return grid

def generate_level_file(level_number):
    """Orchestrates the entire self-correcting map generation pipeline."""
    print(f"\nExecuting surgical self-correcting pipeline for Level {level_number:02d}...")
    
    # 1. Generate DFS Maze with pre-registered boundary masks
    grid = generate_maze_base()
    # 2. Stamp portals and foso
    grid = stamp_features_left_half(grid)
    # 3. Post-Braid (fixes standard dead-ends)
    grid = braid_left_half(grid)
    # 4. Mirror
    grid = mirror_grid(grid)
    # 5. Dynamic Self-Healing Pass (Guarantees 100% map connectivity)
    grid = ensure_connectivity(grid)
    # 6. Mirror again to preserve symmetry after any healing changes
    grid = mirror_grid(grid)
    # 7. Add pellets, players and ghosts
    final_grid = finalize_game_features(grid)
    
    color = random.choice(NEON_COLORS)
    style = random.choice(ART_STYLES)
    
    # Layout formatter (1 row per line)
    layout_lines = []
    for row in final_grid:
        layout_lines.append("    [" + ", ".join(map(str, row)) + "]")
    layout_string = ",\n".join(layout_lines)
    
    json_content = f"""{{
  "_metadata": {{
    "description": "Procedurally Generated Pac-Man Level {level_number:02d}",
    "author": "Python Level Generator",
    "type": "Braided Symmetric Maze"
  }},
  "grid_width": {W},
  "grid_height": {H},
  "wall_color": "{color}",
  "rendering_style": "{style}",
  "layout": [
{layout_string}
  ]
}}"""
    
    filename = f"data/level_{level_number:02d}.json"
    os.makedirs("data", exist_ok=True)
    with open(filename, "w") as f:
        f.write(json_content)
    print(f"Success! Saved: {filename} (Theme: {style.upper()} | Color: {color})")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        try:
            level_to_generate = int(sys.argv[1])
            generate_level_file(level_to_generate)
        except ValueError:
            print("Please enter a valid level number.")
    else:
        print("=== PAC-MAN 3D LEVEL GENERATOR ===")
        user_input = input("Which level number do you want to generate? (e.g. 1, 2, 3...): ")
        try:
            level_to_generate = int(user_input)
            generate_level_file(level_to_generate)
        except ValueError:
            print("Invalid input. Please enter a number.")