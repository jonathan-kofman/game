## GravityFlipTool
## Toggles gravity inversion on a targeted PhysicsObject.
## Press G on an object to flip it up. Press G again to restore.
## Only one object may be gravity-flipped per player at a time (MVP constraint).

class_name GravityFlipTool
extends BaseTool

# ── State ─────────────────────────────────────────────────────────────────────

var _flipped_object: PhysicsObject = null

# ── BaseTool interface ────────────────────────────────────────────────────────

func activate(target: Node, _normal: Vector3) -> void:
	var obj := get_physics_object(target)

	if obj == null:
		_fail("aim at a physics object")
		return

	if obj == _flipped_object:
		# Toggle off — restore the same object
		obj.restore_gravity()
		_flipped_object = null
		is_active = false
		tool_deactivated.emit(name)
		print("[GravityFlipTool] restored on %s" % obj.name)
	else:
		# Restore previous object first (one flip per player)
		if _flipped_object != null and is_instance_valid(_flipped_object):
			_flipped_object.restore_gravity()

		obj.flip_gravity()
		_flipped_object = obj
		is_active = true
		tool_activated.emit(name, obj)
		print("[GravityFlipTool] flipped on %s" % obj.name)

func deactivate() -> void:
	pass  # Gravity flip is a press-toggle, not a hold tool
