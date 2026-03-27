## Unit tests for GravityFlipTool state logic.
## Uses a stub PhysicsObject (plain Node) to avoid requiring a physics scene.
## Tests: toggle on/off, one-flip-per-player rule, invalid target rejection.
##
## Run via GUT: res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/tools/test_gravity_flip_tool.gd

extends GutTest

# ── Stub ──────────────────────────────────────────────────────────────────────
## Minimal PhysicsObject stand-in that records what was called on it.

class PhysicsObjectStub extends Node:
	var flip_called := false
	var restore_called := false
	var original_gravity_scale := 1.0
	var is_gravity_flipped := false

	func flip_gravity() -> void:
		flip_called = true
		is_gravity_flipped = true

	func restore_gravity() -> void:
		restore_called = true
		is_gravity_flipped = false

# ── Setup ─────────────────────────────────────────────────────────────────────

var _tool: GravityFlipTool
var _obj_a: PhysicsObjectStub
var _obj_b: PhysicsObjectStub

func before_each() -> void:
	_tool = GravityFlipTool.new()
	add_child(_tool)
	_obj_a = PhysicsObjectStub.new()
	add_child(_obj_a)
	_obj_b = PhysicsObjectStub.new()
	add_child(_obj_b)

func after_each() -> void:
	_tool.queue_free()
	_obj_a.queue_free()
	_obj_b.queue_free()

# ── Tests ─────────────────────────────────────────────────────────────────────

func test_activate_on_valid_object_calls_flip() -> void:
	_tool.activate(_obj_a, Vector3.ZERO)
	assert_true(_obj_a.flip_called, "flip_gravity should be called on target")

func test_activate_sets_is_active() -> void:
	_tool.activate(_obj_a, Vector3.ZERO)
	assert_true(_tool.is_active)

func test_activate_emits_tool_activated() -> void:
	watch_signals(_tool)
	_tool.activate(_obj_a, Vector3.ZERO)
	assert_signal_emitted(_tool, "tool_activated")

func test_toggle_off_same_object_calls_restore() -> void:
	_tool.activate(_obj_a, Vector3.ZERO)
	_tool.activate(_obj_a, Vector3.ZERO)  # second press = toggle off
	assert_true(_obj_a.restore_called)

func test_toggle_off_clears_is_active() -> void:
	_tool.activate(_obj_a, Vector3.ZERO)
	_tool.activate(_obj_a, Vector3.ZERO)
	assert_false(_tool.is_active)

func test_toggle_off_emits_tool_deactivated() -> void:
	_tool.activate(_obj_a, Vector3.ZERO)
	watch_signals(_tool)
	_tool.activate(_obj_a, Vector3.ZERO)
	assert_signal_emitted(_tool, "tool_deactivated")

func test_one_flip_per_player_restores_previous() -> void:
	_tool.activate(_obj_a, Vector3.ZERO)
	_tool.activate(_obj_b, Vector3.ZERO)  # flip B — A should be restored
	assert_true(_obj_a.restore_called, "Previous object must be restored when flipping a new one")
	assert_true(_obj_b.flip_called)

func test_null_target_emits_tool_failed() -> void:
	watch_signals(_tool)
	_tool.activate(null, Vector3.ZERO)
	assert_signal_emitted(_tool, "tool_failed")

func test_null_target_does_not_set_is_active() -> void:
	_tool.activate(null, Vector3.ZERO)
	assert_false(_tool.is_active)

func test_non_physics_object_emits_tool_failed() -> void:
	var plain_node := Node.new()
	add_child(plain_node)
	watch_signals(_tool)
	_tool.activate(plain_node, Vector3.ZERO)
	assert_signal_emitted(_tool, "tool_failed")
	plain_node.queue_free()
