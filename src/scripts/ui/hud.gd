## HUD
## Signal-driven heads-up display overlay.
## Subscribes to gameplay signals — never polls game state directly.
## Displays: health bar, escalation level indicator, objective tracker.

class_name HUD
extends CanvasLayer

# ── Constants ─────────────────────────────────────────────────────────────────

const HEALTH_ANIM_DURATION := 0.2
const PULSE_PERIOD          := 0.5  # seconds per pulse cycle

## Maps escalation level (0–3) to bar colour. Index with clampi(level, 0, 3).
const _ESCALATION_COLORS := [
	Color(0.0,  1.0,  0.0),   # 0 CALM     — green
	Color(1.0,  1.0,  0.0),   # 1 ALERT    — yellow
	Color(1.0,  0.65, 0.0),   # 2 HOSTILE  — orange
	Color(1.0,  0.0,  0.0),   # 3 CRITICAL — red
]

# ── Node references ───────────────────────────────────────────────────────────

@onready var _health_bar:       ProgressBar = $Control/HealthContainer/HealthBar
@onready var _health_label:     Label       = $Control/HealthContainer/HealthLabel
@onready var _escalation_bar:   ProgressBar = $Control/EscalationContainer/EscalationBar
@onready var _escalation_label: Label       = $Control/EscalationContainer/EscalationLabel
@onready var _objective_label:  Label       = $Control/ObjectiveLabel

# ── State ─────────────────────────────────────────────────────────────────────

var _is_critical:  bool  = false
var _esc_color:    Color = Color.GREEN
var _health_tween: Tween = null

# ── Signal handlers ───────────────────────────────────────────────────────────

## Wire to HealthComponent.health_changed(new_hp, max_hp).
func on_health_changed(new_hp: int, max_hp: int) -> void:
	var fill := clamp(float(new_hp) / float(max(max_hp, 1)), 0.0, 1.0)
	var target_color := Color.GREEN
	if fill < 0.25:
		target_color = Color.RED
	elif fill < 0.75:
		target_color = Color.YELLOW

	if _health_tween:
		_health_tween.kill()
	_health_tween = create_tween().set_parallel(true)
	_health_tween.tween_property(_health_bar, "value",    fill * 100.0,    HEALTH_ANIM_DURATION)
	_health_tween.tween_property(_health_bar, "modulate", target_color,    HEALTH_ANIM_DURATION)

	_health_label.text = "%d / %d" % [new_hp, max_hp]

## Wire to EscalationManager.escalation_level_changed(new_level, level_name).
func on_escalation_changed(new_level: int, level_name: String) -> void:
	const TOTAL_LEVELS := 4
	_escalation_bar.value = float(new_level + 1) / float(TOTAL_LEVELS + 1) * 100.0

	_esc_color = _ESCALATION_COLORS[clampi(new_level, 0, _ESCALATION_COLORS.size() - 1)]
	_escalation_bar.modulate  = _esc_color
	_escalation_label.text    = level_name
	_is_critical = new_level >= 3
	if not _is_critical:
		_escalation_bar.modulate.a = 1.0

## Wire to ObjectiveManager.objective_state_changed(objective_id, new_state).
## Note: ObjectiveManager currently emits (id, state_string) not (id, name, progress_dict).
## Progress counter display is deferred until ObjectiveManager emits richer data.
func on_objective_state_changed(objective_id: String, new_state: String) -> void:
	match new_state:
		"ACTIVE":
			_objective_label.text    = "Primary Objective: Activate Terminal"
			_objective_label.visible = true
		"COMPLETE":
			_objective_label.text    = "Primary Objective: COMPLETE"
			_objective_label.visible = true
		_:
			_objective_label.visible = false

# ── Critical pulse (drives escalation bar opacity at CRITICAL level) ───────────

func _process(_delta: float) -> void:
	if not _is_critical:
		return
	var t := fmod(Time.get_ticks_msec() / 1000.0, PULSE_PERIOD) / PULSE_PERIOD
	_escalation_bar.modulate = Color(
		_esc_color.r, _esc_color.g, _esc_color.b,
		0.6 + 0.4 * sin(t * PI))
