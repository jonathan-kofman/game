## AlarmLaser
## Stationary tripwire hazard. Player entry triggers immediate escalation pressure.
## Guards and physics objects pass through silently.
##
## States: ARMED (steady) → ARMED_TRIGGERED (flashing) → back to ARMED after cooldown.
## Cannot be disarmed in Vertical Slice.
##
## Node structure built in _ready():
##   AlarmLaser (StaticBody3D)
##   ├── CollisionShape3D   — physical mount (laser emitter body)
##   ├── TriggerVolume (Area3D)
##   │   └── CollisionShape3D  — 15% wider than visual for forgiving detection
##   └── LaserVisual (MeshInstance3D)  — colour-coded beam
##
## Call setup(escalation) after adding to scene tree.

class_name AlarmLaser
extends StaticBody3D

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired when the player breaks the beam. EscalationManager consumes this.
signal laser_triggered(laser: AlarmLaser)

# ── Enum ──────────────────────────────────────────────────────────────────────

enum State { ARMED, ARMED_TRIGGERED, DISARMED }

# ── Tuning knobs ──────────────────────────────────────────────────────────────

@export_group("Laser")
## Length of the beam in metres.
@export var beam_length: float = 4.0
## Width of the beam visual (m).
@export var beam_width: float = 0.04
## Duration of the triggered flash state (s). GDD default: 8.0.
@export var alarm_duration: float = 8.0
## Flash frequency (Hz) during ARMED_TRIGGERED.
@export var flash_hz: float = 4.0


# ── State ─────────────────────────────────────────────────────────────────────

var _state: State = State.ARMED
var _state_timer: float = 0.0
var _escalation: EscalationManager = null
var _material: StandardMaterial3D = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_mount()
	_build_trigger_volume()
	_build_laser_visual()
	_set_visual_state(_state)

func _process(delta: float) -> void:
	if _state == State.ARMED_TRIGGERED:
		_state_timer += delta
		# Flash: toggle emission on/off at flash_hz
		var flash_on := fmod(_state_timer * flash_hz, 1.0) < 0.5
		if _material != null:
			_material.emission_enabled = flash_on
		if _state_timer >= alarm_duration:
			_transition_to(State.ARMED)

# ── Public setup API ──────────────────────────────────────────────────────────

## Called by Main / ProceduralGenerator after placing the laser.
func setup(escalation: EscalationManager) -> void:
	_escalation = escalation

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_trigger_volume_body_entered(body: Node3D) -> void:
	if _state != State.ARMED:
		return
	# Only player triggers — guards and physics objects pass through silently
	if not (body.is_in_group("player") or body is CharacterController):
		return
	_trigger()

# ── Private ───────────────────────────────────────────────────────────────────

func _trigger() -> void:
	_transition_to(State.ARMED_TRIGGERED)
	laser_triggered.emit(self)
	if _escalation != null:
		_escalation.on_alarm_triggered("alarm laser")
	print("[AlarmLaser] triggered")

func _transition_to(new_state: State) -> void:
	_state = new_state
	_state_timer = 0.0
	if new_state == State.ARMED:
		_set_visual_state(State.ARMED)

func _set_visual_state(state: State) -> void:
	if _material == null:
		return
	match state:
		State.ARMED:
			_material.albedo_color    = Color(0.9, 0.1, 0.1)
			_material.emission        = Color(0.9, 0.1, 0.1)
			_material.emission_enabled = true
		State.ARMED_TRIGGERED:
			_material.albedo_color    = Color(1.0, 0.4, 0.0)
			_material.emission        = Color(1.0, 0.4, 0.0)
			_material.emission_enabled = true
		State.DISARMED:
			_material.albedo_color    = Color(0.3, 0.3, 0.3)
			_material.emission_enabled = false

# ── Node builders ─────────────────────────────────────────────────────────────

func _build_mount() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.1, 0.1, 0.1)
	col.shape = shape
	add_child(col)

func _build_trigger_volume() -> void:
	var area := Area3D.new()
	area.name = "TriggerVolume"
	area.collision_layer = 0
	area.collision_mask  = 4  # player layer

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	# Flat crossing-plane: player walks through Z-face (GDD §3.3.2)
	# 0.3 m deep x 2.0 m tall x beam_length wide so any height triggers
	shape.size = Vector3(0.3, 2.0, beam_length * 1.15)
	col.shape = shape
	col.position = Vector3(0.0, 1.0, beam_length * 0.5)
	area.add_child(col)

	area.body_entered.connect(_on_trigger_volume_body_entered)
	add_child(area)

func _build_laser_visual() -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "LaserVisual"
	var box := BoxMesh.new()
	box.size = Vector3(beam_width, beam_width, beam_length)
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(0.0, 0.0, beam_length * 0.5)

	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(0.9, 0.1, 0.1, 0.85)
	_material.emission_enabled = true
	_material.emission = Color(0.9, 0.1, 0.1)
	_material.emission_energy_multiplier = 3.0
	mesh_inst.set_surface_override_material(0, _material)
	add_child(mesh_inst)
