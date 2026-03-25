## ExtractionZone
## Area3D placed in the exit room. Locked until the primary objective is complete.
## When unlocked, any CharacterBody3D (player) that enters and stays for
## EXTRACTION_CHANNEL_TIME seconds is marked extracted.
## When all alive players have extracted, run_succeeded is emitted.

class_name ExtractionZone
extends Area3D

# ── Signals ───────────────────────────────────────────────────────────────────

signal run_succeeded
signal run_partial_success(extracted_count: int, total_count: int)
signal run_failed

signal extraction_zone_unlocked
signal extraction_channel_started(player: Node, remaining_time: float)
signal extraction_channel_cancelled(player: Node)
signal player_extracted(player: Node)

# ── Exports ───────────────────────────────────────────────────────────────────

@export var channel_time: float = 4.0
## Expected total player count. Set by Main after spawning the player.
@export var total_players: int = 1

# ── State ─────────────────────────────────────────────────────────────────────

var is_unlocked: bool = false
var _extracted_players: Array[Node] = []
var _channelling: Dictionary = {}  # Node → float (remaining channel time)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_visual()

func _process(delta: float) -> void:
	if not is_unlocked or _channelling.is_empty():
		return

	var completed: Array[Node] = []
	for player in _channelling.keys():
		_channelling[player] -= delta
		if _channelling[player] <= 0.0:
			completed.append(player)

	for player in completed:
		_channelling.erase(player)
		_mark_extracted(player)

# ── Public API ────────────────────────────────────────────────────────────────

## Called by ObjectiveManager (via signal) when primary objective completes.
func unlock() -> void:
	if is_unlocked:
		return
	is_unlocked = true
	_refresh_visual()
	extraction_zone_unlocked.emit()
	print("[ExtractionZone] Unlocked — extraction available")

	# Any players already standing in the zone when it unlocks begin channelling
	for body in get_overlapping_bodies():
		if body is CharacterBody3D and body not in _extracted_players:
			_start_channel(body)

## Called by EscalationManager overtime (future) or external kill volume.
func force_fail() -> void:
	if not _extracted_players.is_empty():
		run_partial_success.emit(_extracted_players.size(), total_players)
	else:
		run_failed.emit()
	print("[ExtractionZone] Run FAILED")

# ── Private ───────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if not is_unlocked:
		return
	if body is CharacterBody3D and body not in _extracted_players:
		_start_channel(body)

func _on_body_exited(body: Node) -> void:
	if _channelling.has(body):
		_channelling.erase(body)
		extraction_channel_cancelled.emit(body)
		print("[ExtractionZone] Channel cancelled for '%s'" % body.name)

func _start_channel(player: Node) -> void:
	if _channelling.has(player):
		return
	_channelling[player] = channel_time
	extraction_channel_started.emit(player, channel_time)
	print("[ExtractionZone] Channel started for '%s' (%.1fs)" % [player.name, channel_time])

func _mark_extracted(player: Node) -> void:
	_extracted_players.append(player)
	player_extracted.emit(player)
	print("[ExtractionZone] '%s' extracted (%d / %d)" \
		% [player.name, _extracted_players.size(), total_players])

	if _extracted_players.size() >= total_players:
		run_succeeded.emit()
		print("[ExtractionZone] Run SUCCEEDED")
	# else: wait for remaining players (or run_failed from EscalationManager overtime)

func _refresh_visual() -> void:
	# Drive the CollisionShape child's debug color — real VFX handled by
	# Visual Effects system (future sprint). For now, print state.
	pass  # placeholder — HUD and VFX systems will consume signals instead
