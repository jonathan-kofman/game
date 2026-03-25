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
	var obj := get_physics_object(target)

	if obj == null:
		_fail("aim at a physics object")
		return

	# Push direction: use collision normal if valid, otherwise push away from player
	var push_dir: Vector3
	if normal.length() > 0.1:
		push_dir = normal
	else:
		var player := get_parent().get_parent() as Node3D
		if player != null:
			push_dir = (obj.global_position - player.global_position).normalized()
		else:
			push_dir = Vector3.UP

	obj.apply_push(push_dir, impulse)
	tool_activated.emit(name, obj)
	print("[ForcePushTool] %.0f N on %s" % [impulse, obj.name])

func deactivate() -> void:
	pass  # Instant tool — no hold state
