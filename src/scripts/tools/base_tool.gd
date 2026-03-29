## BaseTool
## Abstract base class for all physics tools.
## Extend this class for each tool. Override activate() and deactivate().
## Emit signals so Audio/VFX systems can react without being coupled to tool logic.

class_name BaseTool
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired when the tool successfully activates. VFX and Audio subscribe here.
## Emitted by subclasses — declared here so callers can connect without casting.
@warning_ignore("unused_signal")
signal tool_activated(tool_name: String, target: Node)

## Fired when a toggle tool deactivates (e.g. time slow released).
@warning_ignore("unused_signal")
signal tool_deactivated(tool_name: String)

## Fired when activation is rejected — wrong target, already active, etc.
@warning_ignore("unused_signal")
signal tool_failed(tool_name: String, reason: String)

# ── State ─────────────────────────────────────────────────────────────────────

## True while this tool has an ongoing effect (toggle tools only).
var is_active: bool = false

# ── Interface (override in subclass) ─────────────────────────────────────────

## Called when the tool action is pressed.
## target: the RayCast3D collider — may be null if ray hits nothing.
## normal: get_collision_normal() from the RayCast3D.
func activate(_target: Node, _normal: Vector3) -> void:
	pass

## Called when the tool action is released (toggle tools). No-op for instant tools.
func deactivate() -> void:
	pass

# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns the PhysicsObject script on a node, or null if not a physics object.
func get_physics_object(node: Node) -> PhysicsObject:
	if node == null:
		return null
	if node is PhysicsObject:
		return node as PhysicsObject
	return null

## Emit tool_failed and print a debug line. Call this instead of returning silently.
func _fail(reason: String) -> void:
	tool_failed.emit(name, reason)
	print("[%s] failed: %s" % [name, reason])
