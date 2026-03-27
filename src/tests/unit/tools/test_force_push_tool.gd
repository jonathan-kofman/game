## Unit tests for ForcePushTool.
## Verifies: signal emission, invalid target rejection, push direction logic.
## Does NOT test the actual physics impulse magnitude (requires physics scene).
##
## Run via GUT: res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/tools/test_force_push_tool.gd

extends GutTest

# ── Stub ──────────────────────────────────────────────────────────────────────

class PhysicsObjectStub extends Node:
	var push_direction: Vector3 = Vector3.ZERO
	var push_force: float = 0.0

	func apply_push(direction: Vector3, force: float) -> void:
		push_direction = direction
		push_force = force

# ── Setup ─────────────────────────────────────────────────────────────────────

var _tool: ForcePushTool
var _obj: PhysicsObjectStub

func before_each() -> void:
	_tool = ForcePushTool.new()
	add_child(_tool)
	_obj = PhysicsObjectStub.new()
	add_child(_obj)

func after_each() -> void:
	_tool.queue_free()
	_obj.queue_free()

# ── Tests ─────────────────────────────────────────────────────────────────────

func test_activate_calls_apply_push() -> void:
	_tool.activate(_obj, Vector3.FORWARD)
	assert_gt(_obj.push_force, 0.0, "apply_push must be called with positive force")

func test_activate_uses_collision_normal_as_direction() -> void:
	var normal := Vector3(0.0, 1.0, 0.0)  # straight up
	_tool.activate(_obj, normal)
	assert_eq(_obj.push_direction, normal)

func test_activate_emits_tool_activated() -> void:
	watch_signals(_tool)
	_tool.activate(_obj, Vector3.FORWARD)
	assert_signal_emitted(_tool, "tool_activated")

func test_activate_does_not_set_is_active() -> void:
	# Force push is instant — is_active should not latch true
	_tool.activate(_obj, Vector3.FORWARD)
	assert_false(_tool.is_active, "Force push is not a toggle — is_active should remain false")

func test_null_target_emits_tool_failed() -> void:
	watch_signals(_tool)
	_tool.activate(null, Vector3.FORWARD)
	assert_signal_emitted(_tool, "tool_failed")

func test_non_physics_object_emits_tool_failed() -> void:
	var plain_node := Node.new()
	add_child(plain_node)
	watch_signals(_tool)
	_tool.activate(plain_node, Vector3.FORWARD)
	assert_signal_emitted(_tool, "tool_failed")
	plain_node.queue_free()

func test_default_impulse_is_12n() -> void:
	assert_eq(_tool.impulse, 12.0, "Default impulse must be 12N (prototype was 18N — too strong)")

func test_impulse_is_applied_at_configured_value() -> void:
	_tool.impulse = 8.0
	_tool.activate(_obj, Vector3.FORWARD)
	assert_eq(_obj.push_force, 8.0)
