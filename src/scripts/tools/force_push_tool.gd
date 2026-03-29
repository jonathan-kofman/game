## ForcePushTool
## Single-frame impulse on targeted PhysicsObject.
## Direction: collision normal from RayCast3D (falls back to away-from-player).
## 12N is the starting impulse — prototype found 18N too strong for 1kg objects.

class_name ForcePushTool
extends BaseTool

# ── Tuning knobs ─────────────────────────────────────────────────────────────

## Impulse in Newtons. For a 1kg object: 12N → ~12 m/s initial velocity.
@export var impulse: float = 12.0

# ── BaseTool interface ────────────────────────────────────────────────────────

func activate(target: Node, normal: Vector3) -> void:
	var player := get_parent().get_parent() as Node3D

	# PatrolGuard: stun with lateral velocity kick
	if target is PatrolGuard:
		var guard := target as PatrolGuard
		var push_dir: Vector3
		if player != null:
			push_dir = (guard.global_position - player.global_position).normalized()
		else:
			push_dir = Vector3.FORWARD
		guard.apply_force_push(push_dir, impulse)
		tool_activated.emit(name, guard)
		return

	var obj := get_physics_object(target)

	if obj == null:
		_fail("aim at a physics object")
		return

	# Push direction: always away from player — collision normal is unreliable
	# (hitting the top face of a box gives UP regardless of intended direction).
	var push_dir: Vector3
	if player != null:
		push_dir = (obj.global_position - player.global_position).normalized()
	else:
		push_dir = Vector3.FORWARD

	obj.apply_push(push_dir, impulse)
	tool_activated.emit(name, obj)
	print("[ForcePushTool] %.0f N on %s" % [impulse, obj.name])

func deactivate() -> void:
	pass  # Instant tool — no hold state
