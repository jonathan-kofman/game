## Unit tests for PatrolGuard state machine.
## Covers tool-driven state transitions, stun refresh, time slow, and signal
## emissions. Detection transitions (PATROL → ALERT → PURSUE) require a live
## RayCast3D physics step and are not covered here — see playtest checklist.
##
## Run via GUT: res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/ai/test_patrol_guard.gd

extends GutTest

# ── Stubs ──────────────────────────────────────────────────────────────────────

class EscalationStub extends Node:
	var alerted_count := 0
	func on_enemy_alerted() -> void:
		alerted_count += 1

# ── Setup ──────────────────────────────────────────────────────────────────────

var _guard: PatrolGuard
var _escalation: EscalationStub
var _player: Node3D

func before_each() -> void:
	_guard = PatrolGuard.new()
	_escalation = EscalationStub.new()
	_player = Node3D.new()
	add_child(_guard)
	add_child(_escalation)
	add_child(_player)
	_guard.setup(_player, _escalation)

func after_each() -> void:
	_guard.queue_free()
	_escalation.queue_free()
	_player.queue_free()

# ── Initial state ──────────────────────────────────────────────────────────────

func test_initial_state_is_patrol() -> void:
	# Arrange/Act: guard freshly constructed
	# Assert
	assert_eq(_guard._state, PatrolGuard.State.PATROL)

func test_initial_time_slow_flag_is_false() -> void:
	assert_false(_guard._is_time_slowed)

# ── setup() API ───────────────────────────────────────────────────────────────

func test_setup_stores_player_reference() -> void:
	assert_eq(_guard._player, _player)

func test_setup_stores_escalation_reference() -> void:
	assert_eq(_guard._escalation, _escalation)

# ── GravityFlipTool interaction ────────────────────────────────────────────────

func test_apply_gravity_flip_enters_stunned_state() -> void:
	# Arrange: guard is in default PATROL state
	# Act
	_guard.apply_gravity_flip()
	# Assert
	assert_eq(_guard._state, PatrolGuard.State.STUNNED)

func test_apply_gravity_flip_sets_gravity_flip_stun_duration() -> void:
	# Arrange
	var expected := _guard.gravity_flip_stun_duration
	# Act
	_guard.apply_gravity_flip()
	# Assert
	assert_eq(_guard._stun_duration, expected)

func test_apply_gravity_flip_emits_guard_stunned_signal() -> void:
	# Arrange
	watch_signals(_guard)
	# Act
	_guard.apply_gravity_flip()
	# Assert
	assert_signal_emitted(_guard, "guard_stunned")

func test_apply_gravity_flip_resets_state_timer() -> void:
	# Arrange: pre-advance timer to simulate mid-state
	_guard._state_timer = 99.0
	# Act
	_guard.apply_gravity_flip()
	# Assert: transition resets timer
	assert_eq(_guard._state_timer, 0.0)

# ── ForcePushTool interaction ──────────────────────────────────────────────────

func test_apply_force_push_enters_stunned_state() -> void:
	# Act
	_guard.apply_force_push(Vector3.FORWARD, 10.0)
	# Assert
	assert_eq(_guard._state, PatrolGuard.State.STUNNED)

func test_apply_force_push_sets_force_push_stun_duration() -> void:
	# Arrange
	var expected := _guard.force_push_stun_duration
	# Act
	_guard.apply_force_push(Vector3.FORWARD, 10.0)
	# Assert
	assert_eq(_guard._stun_duration, expected)

func test_apply_force_push_emits_guard_stunned_signal() -> void:
	# Arrange
	watch_signals(_guard)
	# Act
	_guard.apply_force_push(Vector3.FORWARD, 10.0)
	# Assert
	assert_signal_emitted(_guard, "guard_stunned")

func test_apply_force_push_sets_push_velocity() -> void:
	# Act
	_guard.apply_force_push(Vector3.FORWARD, 10.0)
	# Assert: push velocity is non-zero (exact magnitude varies by GUARD_PUSH_SCALE)
	assert_false(_guard._push_velocity.is_zero_approx(),
		"Push velocity must be non-zero after force push")

# ── Stun refresh (GDD §5 edge case 2) ─────────────────────────────────────────

func test_stun_refresh_resets_timer_and_does_not_stack_duration() -> void:
	# Arrange: stun via gravity flip, advance timer halfway
	_guard.apply_gravity_flip()
	_guard._state_timer = _guard.gravity_flip_stun_duration * 0.5

	# Act: stun again with force push (shorter duration)
	_guard.apply_force_push(Vector3.FORWARD, 10.0)

	# Assert: timer reset, duration is the NEW stun's value (not additive)
	assert_eq(_guard._state_timer, 0.0, "Timer must reset on stun refresh")
	assert_eq(_guard._stun_duration, _guard.force_push_stun_duration,
		"Duration must be replaced, not stacked")

func test_stun_refresh_still_in_stunned_state() -> void:
	# Arrange
	_guard.apply_gravity_flip()
	# Act: second stun while already stunned
	_guard.apply_force_push(Vector3.FORWARD, 10.0)
	# Assert: still STUNNED
	assert_eq(_guard._state, PatrolGuard.State.STUNNED)

# ── TimeSlowTool interaction ───────────────────────────────────────────────────

func test_apply_time_slow_sets_slowed_flag() -> void:
	# Act
	_guard.apply_time_slow()
	# Assert
	assert_true(_guard._is_time_slowed)

func test_remove_time_slow_clears_slowed_flag() -> void:
	# Arrange
	_guard.apply_time_slow()
	# Act
	_guard.remove_time_slow()
	# Assert
	assert_false(_guard._is_time_slowed)

func test_time_slow_does_not_change_state() -> void:
	# Arrange: guard in PATROL
	# Act
	_guard.apply_time_slow()
	# Assert: state unchanged
	assert_eq(_guard._state, PatrolGuard.State.PATROL)
