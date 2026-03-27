## Unit tests for HealthComponent.
## Covers: take_damage, heal, kill, is_alive, death signal, edge cases.
## Does NOT test fall damage (requires CharacterController integration test).
##
## Run via GUT: res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_health_component.gd

extends GutTest

var _hc: HealthComponent

func before_each() -> void:
	_hc = HealthComponent.new()
	# Parent must be a plain Node so the CharacterController cast returns null
	# and _ready() skips the fall-damage connection safely.
	add_child(_hc)

func after_each() -> void:
	_hc.queue_free()
	_hc = null

# ── Initial state ──────────────────────────────────────────────────────────────

func test_starts_at_max_hp() -> void:
	assert_eq(_hc.current_hp, _hc.max_hp, "HP should start at max")

func test_is_alive_at_start() -> void:
	assert_true(_hc.is_alive(), "Should be alive at start")

# ── take_damage ────────────────────────────────────────────────────────────────

func test_take_damage_reduces_hp() -> void:
	_hc.take_damage(30)
	assert_eq(_hc.current_hp, 70)

func test_take_damage_clamps_to_zero() -> void:
	_hc.take_damage(200)
	assert_eq(_hc.current_hp, 0)

func test_take_damage_zero_is_ignored() -> void:
	_hc.take_damage(0)
	assert_eq(_hc.current_hp, _hc.max_hp)

func test_take_damage_negative_is_ignored() -> void:
	_hc.take_damage(-10)
	assert_eq(_hc.current_hp, _hc.max_hp)

func test_take_damage_emits_health_changed() -> void:
	watch_signals(_hc)
	_hc.take_damage(20)
	assert_signal_emitted_with_parameters(_hc, "health_changed", [80, 100])

func test_take_damage_triggers_died_at_zero() -> void:
	watch_signals(_hc)
	_hc.take_damage(100)
	assert_signal_emitted(_hc, "died")

func test_take_damage_after_death_is_ignored() -> void:
	_hc.take_damage(100)  # kill
	watch_signals(_hc)
	_hc.take_damage(10)   # should be ignored
	assert_signal_not_emitted(_hc, "died")
	assert_eq(_hc.current_hp, 0)

# ── heal ──────────────────────────────────────────────────────────────────────

func test_heal_increases_hp() -> void:
	_hc.take_damage(50)
	_hc.heal(20)
	assert_eq(_hc.current_hp, 70)

func test_heal_clamps_to_max() -> void:
	_hc.take_damage(10)
	_hc.heal(999)
	assert_eq(_hc.current_hp, _hc.max_hp)

func test_heal_zero_is_ignored() -> void:
	_hc.take_damage(20)
	var hp_before := _hc.current_hp
	_hc.heal(0)
	assert_eq(_hc.current_hp, hp_before)

func test_heal_after_death_is_ignored() -> void:
	_hc.take_damage(100)
	_hc.heal(50)
	assert_eq(_hc.current_hp, 0, "Dead player cannot be healed")

func test_heal_emits_health_changed() -> void:
	_hc.take_damage(40)
	watch_signals(_hc)
	_hc.heal(10)
	assert_signal_emitted_with_parameters(_hc, "health_changed", [70, 100])

# ── kill ──────────────────────────────────────────────────────────────────────

func test_kill_sets_hp_to_zero() -> void:
	_hc.kill()
	assert_eq(_hc.current_hp, 0)

func test_kill_emits_died() -> void:
	watch_signals(_hc)
	_hc.kill()
	assert_signal_emitted(_hc, "died")

func test_kill_when_already_dead_does_nothing() -> void:
	_hc.kill()
	watch_signals(_hc)
	_hc.kill()
	assert_signal_not_emitted(_hc, "died")

# ── is_alive ──────────────────────────────────────────────────────────────────

func test_is_alive_false_after_death() -> void:
	_hc.take_damage(100)
	assert_false(_hc.is_alive())

func test_is_alive_true_at_one_hp() -> void:
	_hc.take_damage(99)
	assert_true(_hc.is_alive())
