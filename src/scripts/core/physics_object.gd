## PhysicsObject
## Base script for all RigidBody3D physics objects that tools can interact with.
## Attach to any RigidBody3D on collision layer 2 (physics_objects).
## Tools MUST use this API — never read/write RigidBody3D physics properties directly.

class_name PhysicsObject
extends RigidBody3D

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired whenever a tool changes this object's physics state.
signal physics_state_changed(body: RigidBody3D)

# ── State (read-only from outside — write via set_ methods below) ─────────────

## Gravity scale at scene load, before any tool touches it.
var original_gravity_scale: float = 1.0

## True while this object's gravity is inverted by GravityFlipTool.
var is_gravity_flipped: bool = false

## True while this object is inside a TimeSlowTool area of effect.
var is_time_slowed: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	original_gravity_scale = gravity_scale

# ── Tool API ──────────────────────────────────────────────────────────────────

## Flip gravity on this object. Negates gravity_scale.
## Called by GravityFlipTool only.
func flip_gravity() -> void:
	is_gravity_flipped = true
	gravity_scale = -abs(original_gravity_scale)
	physics_state_changed.emit(self)

## Restore gravity to original. Called by GravityFlipTool only.
func restore_gravity() -> void:
	is_gravity_flipped = false
	gravity_scale = original_gravity_scale
	physics_state_changed.emit(self)

## Apply time slow effect. Scales gravity down, applies drag to bleed momentum.
## Wakes sleeping bodies via gravity_scale change (Jolt activation path).
## Called by TimeSlowTool only.
func apply_time_slow(slow_factor: float, damp_value: float) -> void:
	is_time_slowed = true
	sleeping = false
	gravity_scale = original_gravity_scale * slow_factor
	linear_damp = damp_value
	physics_state_changed.emit(self)

## Remove time slow effect, restoring gravity and drag.
## Called by TimeSlowTool only.
func remove_time_slow() -> void:
	is_time_slowed = false
	# Preserve gravity flip if still active
	gravity_scale = -abs(original_gravity_scale) if is_gravity_flipped else original_gravity_scale
	linear_damp = 0.0
	physics_state_changed.emit(self)

## Apply a central impulse for force push.
## Called by ForcePushTool only.
func apply_push(direction: Vector3, force: float) -> void:
	sleeping = false
	apply_central_impulse(direction * force)
	physics_state_changed.emit(self)
