## InteractableTerminal
## A hackable console the player interacts with to complete Activate-type objectives.
## Attach to a StaticBody3D. The CharacterController's aim ray detects it;
## pressing "interact" fires the interacted signal.
##
## Visual states:
##   IDLE     — inactive, waiting
##   HIGHLIGHT — player is aiming at it (driven externally by ToolManager / interaction system)
##   USED     — already interacted; cannot interact again

class_name InteractableTerminal
extends StaticBody3D

# ── Signals ───────────────────────────────────────────────────────────────────

## Fired once when a player successfully interacts with this terminal.
## interactor is the CharacterBody3D (player node) that triggered it.
signal interacted(terminal: InteractableTerminal, interactor: Node)

# ── Exports ───────────────────────────────────────────────────────────────────

@export_group("Visuals")
## Emission colour when idle.
@export var color_idle: Color = Color(0.1, 0.4, 0.8)
## Emission colour when the player is aiming at this terminal.
@export var color_highlight: Color = Color(0.3, 0.9, 1.0)
## Emission colour once used.
@export var color_used: Color = Color(0.1, 0.6, 0.1)

@export_group("Interaction")
## Interaction range in metres. Player must be within this distance to interact.
@export var interact_range: float = 8.0

# ── State ─────────────────────────────────────────────────────────────────────

var is_used: bool = false
var _is_highlighted: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _material: StandardMaterial3D = _get_or_create_material()

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	collision_layer = 3   # layers 1+2: detectable by player raycast (collision_mask=3)
	collision_mask  = 0
	_refresh_color()

# ── Public API ────────────────────────────────────────────────────────────────

## Called by the interaction system each frame the player is aiming at this terminal.
func set_highlighted(value: bool) -> void:
	if is_used:
		return
	if _is_highlighted == value:
		return
	_is_highlighted = value
	_refresh_color()

## Called by the interaction system when the player presses "interact".
## interactor is the CharacterBody3D of the triggering player.
func try_interact(interactor: Node) -> bool:
	if is_used:
		return false
	var interactor_3d := interactor as Node3D
	if interactor_3d != null:
		var dist := global_position.distance_to(interactor_3d.global_position)
		if dist > interact_range:
			return false
	is_used = true
	_is_highlighted = false
	_refresh_color()
	interacted.emit(self, interactor)
	return true

# ── Private ───────────────────────────────────────────────────────────────────

func _refresh_color() -> void:
	if _material == null:
		return
	if is_used:
		_material.albedo_color = color_used
		_material.emission_enabled = true
		_material.emission = color_used
	elif _is_highlighted:
		_material.albedo_color = color_highlight
		_material.emission_enabled = true
		_material.emission = color_highlight * 0.5
	else:
		_material.albedo_color = color_idle
		_material.emission_enabled = false

func _get_or_create_material() -> StandardMaterial3D:
	if _mesh == null:
		return null
	var mat := _mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		return mat as StandardMaterial3D
	# Create a new material so we don't share it with other instances
	var new_mat := StandardMaterial3D.new()
	new_mat.albedo_color = color_idle
	_mesh.set_surface_override_material(0, new_mat)
	return new_mat
