## ToolManager
## Reads tool input actions and routes them to the correct BaseTool child node.
## Contains no physics logic — it only delegates. All logic lives in tool scripts.
## Must be a child of a node that has a CharacterController (or exposes get_aim_ray()).

class_name ToolManager
extends Node

# ── Node references ───────────────────────────────────────────────────────────

@onready var _gravity_flip: BaseTool = $GravityFlipTool
@onready var _time_slow: BaseTool    = $TimeSlowTool
@onready var _force_push: BaseTool   = $ForcePushTool

# ── Private helpers ───────────────────────────────────────────────────────────

func _get_ray() -> RayCast3D:
	var controller := get_parent() as CharacterController
	if controller == null:
		push_error("ToolManager parent must be a CharacterController")
		return null
	return controller.get_aim_ray()

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	var ray := _get_ray()
	if ray == null:
		return

	var target := ray.get_collider() as Node
	var normal := ray.get_collision_normal()

	# Gravity Flip — press to toggle
	if event.is_action_pressed("tool_gravity"):
		_gravity_flip.activate(target, normal)

	# Time Slow — hold to slow, release to restore
	elif event.is_action_pressed("tool_time_slow"):
		_time_slow.activate(null, Vector3.ZERO)
	elif event.is_action_released("tool_time_slow"):
		_time_slow.deactivate()

	# Force Push — press for instant impulse
	elif event.is_action_pressed("tool_force_push"):
		_force_push.activate(target, normal)
