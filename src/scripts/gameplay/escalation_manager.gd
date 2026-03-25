## EscalationManager
## Drives the four-level escalation state machine: CALM → ALERT → HOSTILE → CRITICAL.
## Advances via passive timers or event-driven pressure accumulation.
## Attach as a child of the Main scene node.

class_name EscalationManager
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired whenever the escalation level changes.
signal escalation_level_changed(new_level: int, level_name: String)

## Fired when CRITICAL is entered — ExtractionZone listens to this.
signal critical_entered

# ── Enums ─────────────────────────────────────────────────────────────────────

enum Level { CALM = 0, ALERT = 1, HOSTILE = 2, CRITICAL = 3 }

# ── Exports ───────────────────────────────────────────────────────────────────

@export_group("Passive Timers (seconds)")
@export var calm_duration: float    = 60.0
@export var alert_duration: float   = 90.0
@export var hostile_duration: float = 60.0

@export_group("Pressure")
@export var pressure_threshold: float  = 100.0
@export var loud_tool_pressure: float  = 25.0
@export var enemy_alert_pressure: float = 40.0
@export var camera_detect_pressure: float = 60.0

# ── State ─────────────────────────────────────────────────────────────────────

var current_level: Level = Level.CALM
var _pressure: float = 0.0
var _level_timer: float = 0.0
var _is_running: bool = false
var _is_advancing: bool = false  # guard against double-advance on same frame

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func start() -> void:
	current_level = Level.CALM
	_pressure = 0.0
	_level_timer = 0.0
	_is_running = true
	_is_advancing = false
	print("[EscalationManager] Started — CALM (%.0fs timer)" % calm_duration)

func _process(delta: float) -> void:
	if not _is_running or current_level == Level.CRITICAL:
		return

	_level_timer += delta
	var duration := _level_duration(current_level)
	if _level_timer >= duration:
		_advance("timer expired")

# ── Public API ────────────────────────────────────────────────────────────────

## Called by ObjectiveManager when primary objective completes.
func on_objective_completed() -> void:
	_advance("objective completed")

## Called externally when a loud tool is used (force push, large impact).
func on_loud_tool_used() -> void:
	_add_pressure(loud_tool_pressure, "loud tool")

## Called externally when an enemy is alerted.
func on_enemy_alerted() -> void:
	_add_pressure(enemy_alert_pressure, "enemy alerted")

## Called externally when a camera detects the player.
func on_camera_detected() -> void:
	_add_pressure(camera_detect_pressure, "camera detection")

## Returns the current level as a human-readable string.
func level_name() -> String:
	return Level.keys()[current_level]

# ── Private ───────────────────────────────────────────────────────────────────

func _add_pressure(amount: float, source: String) -> void:
	if current_level == Level.CRITICAL:
		return
	_pressure += amount
	print("[EscalationManager] Pressure +%.0f (%s) → %.0f / %.0f" \
		% [amount, source, _pressure, pressure_threshold])
	if _pressure >= pressure_threshold:
		_pressure = 0.0
		_advance("pressure threshold")

func _advance(reason: String) -> void:
	if _is_advancing:
		return
	if current_level == Level.CRITICAL:
		return
	_is_advancing = true

	var next_level := current_level + 1 as Level
	current_level = next_level
	_level_timer = 0.0
	_pressure = 0.0

	var name_str := level_name()
	print("[EscalationManager] → %s (%s)" % [name_str, reason])
	escalation_level_changed.emit(current_level, name_str)

	if current_level == Level.CRITICAL:
		critical_entered.emit()

	_is_advancing = false

func _level_duration(level: Level) -> float:
	match level:
		Level.CALM:    return calm_duration
		Level.ALERT:   return alert_duration
		Level.HOSTILE: return hostile_duration
	return INF
