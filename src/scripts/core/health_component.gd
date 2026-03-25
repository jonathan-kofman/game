## HealthComponent
## Tracks hit points, processes damage, and triggers death.
## Attach as a child of CharacterBody3D (Player). Connects to CharacterController
## signals for fall damage detection.

class_name HealthComponent
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired whenever HP changes. Consumed by HUD for health bar updates.
signal health_changed(new_hp: int, max_hp: int)

## Fired exactly once when HP reaches 0. Consumed by Player Spawning & Respawn.
signal died

# ── Tuning knobs ─────────────────────────────────────────────────────────────

@export_group("Health")
## Maximum and starting hit points.
@export var max_hp: int = 100

@export_group("Fall Damage")
## Downward velocity (m/s) below which no fall damage is taken. ≈3.3m fall.
@export var fall_damage_threshold: float = 8.0
## Damage multiplier per m/s above the threshold.
@export var fall_damage_factor: float = 10.0

# ── State ─────────────────────────────────────────────────────────────────────

var current_hp: int = 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	current_hp = max_hp

	# Connect to CharacterController.landed for fall damage
	var controller := get_parent() as CharacterController
	if controller != null:
		controller.landed.connect(_on_landed)

# ── Public API ────────────────────────────────────────────────────────────────

## Reduce HP by amount. Clamps to 0. Triggers death if HP reaches 0.
## Zero-damage calls are silently ignored.
func take_damage(amount: int) -> void:
	if current_hp == 0 or amount <= 0:
		return

	current_hp = max(current_hp - amount, 0)
	health_changed.emit(current_hp, max_hp)

	if current_hp == 0:
		_trigger_death()

## Increase HP by amount. Clamps to max_hp.
func heal(amount: int) -> void:
	if current_hp == 0 or amount <= 0:
		return
	current_hp = min(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)

## Instantly set HP to 0 and trigger death. Used by out-of-bounds kill volumes.
func kill() -> void:
	if current_hp == 0:
		return
	current_hp = 0
	health_changed.emit(current_hp, max_hp)
	_trigger_death()

func is_alive() -> bool:
	return current_hp > 0

# ── Private ───────────────────────────────────────────────────────────────────

func _trigger_death() -> void:
	# Disable movement and physics processing on the parent controller
	var controller := get_parent()
	if controller != null:
		controller.set_process_input(false)
		controller.set_physics_process(false)

	died.emit()
	print("[HealthComponent] died")

func _on_landed() -> void:
	var controller := get_parent() as CharacterController
	if controller == null:
		return

	# velocity.y at the frame of landing is approximately the impact speed.
	# It may already be 0 after move_and_slide resolves the collision, so we
	# read it before move_and_slide in the character controller... except we
	# can't easily do that here. Workaround: use a small cache in CharacterController.
	# For MVP, read the stored impact velocity exposed by the controller.
	var impact_speed: float = abs(controller.last_landing_velocity)
	if impact_speed < fall_damage_threshold:
		return

	var damage := int((impact_speed - fall_damage_threshold) * fall_damage_factor)
	take_damage(damage)
	print("[HealthComponent] fall damage: %d (speed: %.1f m/s)" % [damage, impact_speed])
