## Unit tests for TimeSlowTool state logic.
## NOTE: The physics query (_begin_time_slow → intersect_shape) cannot run in
## unit tests without a full physics scene. These tests cover toggle state,
## signal emission, deactivate-before-activate guard, and the objects-already-
## captured path via direct injection.
##
## Integration test for actual slow effect: run RampTestRoom.tscn manually (S5-07).
##
## Run via GUT: res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/tools/test_time_slow_tool.gd

extends GutTest

# ── Stub ──────────────────────────────────────────────────────────────────────

class PhysicsObjectStub extends Node:
	var time_slow_applied := false
	var time_slow_removed := false

	func apply_time_slow(_factor: float, _damp: float) -> void:
		time_slow_applied = true

	func remove_time_slow() -> void:
		time_slow_removed = true

# ── Setup ─────────────────────────────────────────────────────────────────────

var _tool: TimeSlowTool

func before_each() -> void:
	_tool = TimeSlowTool.new()
	add_child(_tool)

func after_each() -> void:
	_tool.queue_free()

# ── Tests ─────────────────────────────────────────────────────────────────────

func test_starts_inactive() -> void:
	assert_false(_tool.is_active)

func test_deactivate_when_already_inactive_does_nothing() -> void:
	# Should not crash or emit spurious signals
	watch_signals(_tool)
	_tool.deactivate()
	assert_signal_not_emitted(_tool, "tool_deactivated")

func test_activate_twice_does_not_double_activate() -> void:
	# Simulate is_active guard: second activate call while active is a no-op.
	# We can't run the physics query here, but we can set is_active manually
	# to test the guard path.
	_tool.is_active = true
	watch_signals(_tool)
	_tool.activate(null, Vector3.ZERO)
	assert_signal_not_emitted(_tool, "tool_activated")

func test_deactivate_removes_slow_from_captured_objects() -> void:
	# Inject a slowed object directly to test the release path.
	var obj := PhysicsObjectStub.new()
	add_child(obj)
	_tool._slowed_objects.append(obj)
	_tool.is_active = true

	_tool.deactivate()

	assert_true(obj.time_slow_removed, "remove_time_slow must be called on all captured objects")
	obj.queue_free()

func test_deactivate_clears_slowed_objects_list() -> void:
	var obj := PhysicsObjectStub.new()
	add_child(obj)
	_tool._slowed_objects.append(obj)
	_tool.is_active = true

	_tool.deactivate()

	assert_eq(_tool._slowed_objects.size(), 0)
	obj.queue_free()

func test_deactivate_sets_is_active_false() -> void:
	var obj := PhysicsObjectStub.new()
	add_child(obj)
	_tool._slowed_objects.append(obj)
	_tool.is_active = true

	_tool.deactivate()

	assert_false(_tool.is_active)
	obj.queue_free()

func test_deactivate_emits_tool_deactivated() -> void:
	_tool.is_active = true
	watch_signals(_tool)
	_tool.deactivate()
	assert_signal_emitted(_tool, "tool_deactivated")

func test_default_slow_factor() -> void:
	assert_eq(_tool.time_slow_factor, 0.15)

func test_default_damp_value() -> void:
	assert_eq(_tool.high_damp_value, 8.0)

func test_default_radius() -> void:
	assert_eq(_tool.radius, 6.0)
