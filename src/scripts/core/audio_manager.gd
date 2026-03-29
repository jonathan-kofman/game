## AudioManager
## Autoload singleton. Owns the audio bus layout and provides stub play/stop methods.
## Registered in project.godot as AudioManager autoload.
##
## Bus layout (all children of Master):
##   Master  — final output; never muted
##   Music   — looping ambient / mission tracks
##   SFX     — positional sound effects (tools, physics, hazards)
##   UI      — non-diegetic UI feedback sounds
##   Voice   — character callouts / future VO
##
## Volume helpers use dB (0 dB = full volume; -80 dB ≈ silence).
## Stub note: play_sfx / play_music do nothing until AudioStreamPlayer nodes and
## actual audio streams are wired up (Sprint 9+). Bus layout is functional now so
## volume sliders and mix balance can be validated before audio assets arrive.

extends Node

# ── Bus name constants ─────────────────────────────────────────────────────────

const BUS_MASTER := "Master"
const BUS_MUSIC  := "Music"
const BUS_SFX    := "SFX"
const BUS_UI     := "UI"
const BUS_VOICE  := "Voice"

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_ensure_bus_layout()

# ── Public stub API ────────────────────────────────────────────────────────────

## Play a one-shot SFX at a world position. STUB — no-op until Sprint 9.
func play_sfx(_stream: AudioStream, _world_position: Vector3 = Vector3.ZERO) -> void:
	pass

## Start a looping music track. Crossfade not yet implemented. STUB.
func play_music(_stream: AudioStream) -> void:
	pass

## Stop currently playing music. STUB.
func stop_music() -> void:
	pass

## Set the volume of a named bus in dB. Clamps to [-80, 6].
func set_bus_volume_db(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("AudioManager: unknown bus '%s'" % bus_name)
		return
	AudioServer.set_bus_volume_db(idx, clampf(db, -80.0, 6.0))

## Mute or unmute a named bus.
func set_bus_mute(bus_name: String, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("AudioManager: unknown bus '%s'" % bus_name)
		return
	AudioServer.set_bus_mute(idx, muted)

# ── Private ────────────────────────────────────────────────────────────────────

## Ensures all project buses exist with correct parent routing.
## Idempotent — safe to call multiple times (won't duplicate buses).
func _ensure_bus_layout() -> void:
	var layout: Array[Dictionary] = [
		{ "name": BUS_MUSIC,  "send": BUS_MASTER },
		{ "name": BUS_SFX,    "send": BUS_MASTER },
		{ "name": BUS_UI,     "send": BUS_MASTER },
		{ "name": BUS_VOICE,  "send": BUS_MASTER },
	]

	for entry in layout:
		var bus_name: String = entry["name"]
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue  # already exists
		var idx := AudioServer.get_bus_count()
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, entry["send"])
		print("[AudioManager] created bus '%s' → '%s'" % [bus_name, entry["send"]])
