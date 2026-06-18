# ==============================================================================
# Description: Standalone Tournament Leaderboard Manager.
#              Responsible exclusively for loading, saving, and sorting the top 5 
#              local high scores using encrypted binary serialization.
#              SOLID Refactoring:
#              - SRP Compliance: Fully decouples leaderboard mechanics from 
#                GameManager and UI, keeping data operations strictly isolated.
#              - OCP Compliance: Uses highly robust Pascal String binary 
#                serialization to guarantee stable, corruption-free state packing.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
extends RefCounted
class_name LeaderboardManager

const SAVE_PATH : String = "user://leaderboard.dat"
const ENCRYPTION_KEY : String = "PacMan3D_SecureLeaderboardKey_9902"
const MAX_ENTRIES : int = 5

# Returns a calibrated, achievable default cabinet leaderboard (Fix: Lowered targets)
static func get_default_leaderboard() -> Array[Dictionary]:
	return [
		{"name": "ENR", "score": 1000},
		{"name": "PAC", "score": 800},
		{"name": "3D_", "score": 600},
		{"name": "AAA", "score": 400},
		{"name": "GDT", "score": 200}
	]

# Loads and decrypts the leaderboard array from disk
static func load_leaderboard() -> Array[Dictionary]:
	if not FileAccess.file_exists(SAVE_PATH):
		var default_list = get_default_leaderboard()
		save_leaderboard(default_list)
		return default_list
		
	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, ENCRYPTION_KEY)
	if not file:
		return get_default_leaderboard()
		
	var leaderboard : Array[Dictionary] = []
	var count = file.get_32() # Retrieve number of active entries
	
	for i in range(count):
		# --- STABLE PASCAL STRINGS SERIALIZATION ---
		# Fixed: get_pascal_string() reads strings precisely, preventing binary corruption.
		# This completely removes the need for file seek hacks and ternary warnings.
		var entry_name = file.get_pascal_string() 
		var entry_score = file.get_32() 
		
		leaderboard.append({
			"name": entry_name.strip_edges(),
			"score": entry_score
		})
		
	file.close()
	return leaderboard

# Serializes and encrypts the leaderboard array to disk
static func save_leaderboard(leaderboard: Array[Dictionary]) -> void:
	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, ENCRYPTION_KEY)
	if not file:
		return
		
	var active_count = min(leaderboard.size(), MAX_ENTRIES)
	file.store_32(active_count)
	
	for i in range(active_count):
		var entry = leaderboard[i]
		# Store name using Pascal string prefix length and score in contiguous binary
		file.store_pascal_string(entry["name"])
		file.store_32(entry["score"])
		
	file.close()

# Checks if a score qualifies to enter the Top 5
static func qualifies_for_leaderboard(score: int, leaderboard: Array[Dictionary]) -> bool:
	if leaderboard.size() < MAX_ENTRIES:
		return true
	var lowest_entry = leaderboard[leaderboard.size() - 1]
	return score > lowest_entry["score"]

# Inserts a new record, sorts descending, clamps to top 5, and saves on the fly
static func insert_entry(initials: String, score: int, leaderboard: Array[Dictionary]) -> Array[Dictionary]:
	var updated_list = leaderboard.duplicate()
	var clean_initials = initials.substr(0, 3).to_upper()
	
	updated_list.append({
		"name": clean_initials,
		"score": score
	})
	
	updated_list.sort_custom(func(a, b): return a["score"] > b["score"])
	
	if updated_list.size() > MAX_ENTRIES:
		updated_list.resize(MAX_ENTRIES)
		
	save_leaderboard(updated_list)
	return updated_list
