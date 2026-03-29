## PressurePlate
## Floor hazard. Activates when the player steps on it; triggers an alarm
## if they stand on it for PLATE_HOLD_ALARM_TIME seconds without relief.
## A physics object resting on the plate prevents the alarm from firing
## (crate trick — GDD §3.4 design intent).
##
## States:
##   INACTIVE — nothing on plate (amber)
##   ACTIVE   — player or object on plate, timer counting (green, depressed)
##   TRIPPED  — hold timer expired, alarm fired (red)
##
## Guards do NOT activate the plate (GDD §3.4.1).
## Call setup(escalation) after adding to scene tree.

class_name PressurePlate
extends StaticBody3D

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired when the plate alarm fires (hold timer expired).
signal plate_alarm_triggered(plate: PressurePlate)

# ── Enum ──────────────────────────────────────────────────────────────────────

enum State { INACTIVE, ACTIVE, TRIPPED }

# ── Tuning knobs ──────────────────────────────────────────────────────────────

@export_group("Plate")
## Seconds the player must stand on the plate before alarm fires. GDD default: 3.0.
@export var hold_alarm_time: float = 3.0
## Size of the pressure plate surface (m). Used for both visual and trigger.
@export var plate_size: Vector2 = Vector2(0.8, 0.8)

# ── State ─────────────────────────────────────────────────────────────────────

var _state: State = State.INACTIVE
var _hold_timer: float = 0.0
var _bodies_on_plate: int = 0  # count of active triggering bodies
var _escalation: EscalationManager = null
var _material: StandardMaterial3D = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_plate()
	_build_trigger_volume()
	_build_visual()
	_set_visual_state(_state)

func _process(delta: float) -> void:
	if _state == State.ACTIVE:
		_hold_timer += delta
		if _hold_timer >= hold_alarm_time:
			_trigger_alarm()

# ── Public setup API ──────────────────────────────────────────────────────────

## Called by Main / ProceduralGenerator after placing the plate.
func setup(escalation: EscalationManager) -> void:
	_escalation = escalation

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_body_entered(body: Node3D) -> void:
	# Guards do not activate the plate (GDD §3.4.1)
	if body is PatrolGuard:
		return
	# Only player and PhysicsObjects trigger the plate
	if not (body.is_in_group("player") or body is CharacterController or body is PhysicsObject):
		return
	_bodies_on_plate += 1
	if _state == State.INACTIVE:
		_transition_to(State.ACTIVE)
		if _escalation != null:
			_escalation.on_hazard_tripped("pressure plate")
		print("[PressurePlate] ACTIVE — body: %s" % body.name)

func _on_body_exited(body: Node3D) -> void:
	if body is PatrolGuard:
		return
	if not (body.is_in_group("player") or body is CharacterController or body is PhysicsObject):
		return
	_bodies_on_plate = max(0, _bodies_on_plate - 1)
	if _bodies_on_plate == 0 and _state == State.ACTIVE:
		_hold_timer = 0.0
		_transition_to(State.INACTIVE)
		print("[PressurePlate] INACTIVE — body left")

# ── Private ───────────────────────────────────────────────────────────────────

func _trigger_alarm() -> void:
	_transition_to(State.TRIPPED)
	plate_alarm_triggered.emit(self)
	if _escalation != null:
		_escalation.on_alarm_triggered("pressure plate alarm")
	print("[PressurePlate] TRIPPED — alarm fired")

func _transition_to(new_state: State) -> void:
	_state = new_state
	_set_visual_state(new_state)

func _set_visual_state(state: State) -> void:
	if _material == null:
		return
	match state:
		State.INACTIVE: _material.albedo_color = Color(0.9, 0.6, 0.1)   # amber
		State.ACTIVE:   _material.albedo_color = Color(0.1, 0.9, 0.3)   # green
		State.TRIPPED:  _material.albedo_color = Color(0.9, 0.1, 0.1)   # red

# ── Node builders ─────────────────────────────────────────────────────────────

func _build_plate() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(plate_size.x, 0.06, plate_size.y)
	col.shape = shape
	col.position = Vector3(0.0, 0.03, 0.0)
	add_child(col)

func _build_trigger_volume() -> void:
	var area := Area3D.new()
	area.name = "TriggerArea"
	area.collision_layer = 0
	area.collision_mask  = 7  # layers 1+2+4: player, physics objects, player body

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(plate_size.x * 0.9, 0.12, plate_size.y * 0.9)
	col.shape = shape
	col.position = Vector3(0.0, 0.06, 0.0)
	area.add_child(col)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _build_visual() -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "PlateVisual"
	var box := BoxMesh.new()
	box.size = Vector3(plate_size.x, 0.06, plate_size.y)
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(0.0, 0.03, 0.0)
	_material = StandardMaterial3D.new()
	mesh_inst.set_surface_override_material(0, _material)
	add_child(mesh_inst)
