## Main scene bootstrap — procedurally generates a facility and drops the player in.
## Replaces the hand-built test room from Sprint 2. Press F5 to generate a new layout.
## Pass a seed via the command-line argument "--seed=<int>" for deterministic runs.

extends Node3D

# ── Constants ──────────────────────────────────────────────────────────────────

const FLOOR_THICKNESS: float = 0.3
const WALL_HEIGHT: float = 4.0
const WALL_THICKNESS: float = 0.3
const FLOOR_COLOR: Color = Color(0.35, 0.35, 0.38)
const WALL_COLOR: Color = Color(0.45, 0.45, 0.50)

# ── XP formula knobs (Mission Debrief System GDD §4.1) ────────────────────────

const _BASE_XP_ACTIVATE    := 80    # base XP for Activate objective type
const _SOLO_DIFFICULTY_MOD := 0.8   # solo difficulty_multiplier
const _OUTCOME_XP_MULT     := {"SUCCEEDED": 1.0, "PARTIAL_SUCCESS": 0.75, "FAILED": 0.25}

# ── Runtime references (set during _setup_facility, used by _trigger_debrief) ─

var _objectives: ObjectiveManager = null

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_facility()

# ── Environment & Lighting ─────────────────────────────────────────────────────

func _setup_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env_node.environment = env
	add_child(env_node)

func _setup_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)

# ── Facility Generation ────────────────────────────────────────────────────────

func _setup_facility() -> void:
	# Read optional seed from command line: --seed=12345
	var seed_value: int = 0
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--seed="):
			seed_value = arg.substr(7).to_int()

	var generator := ProceduralGenerator.new()
	add_child(generator)

	var graph := generator.generate(seed_value)
	if graph == null:
		push_error("Main: ProceduralGenerator returned null graph.")
		return

	print("[Main] Facility seed=%d  rooms=%d" % [graph.facility_seed, graph.room_count()])

	# Instantiate every room and build its floor/walls
	var entrance_spawn_pos := Vector3(0.0, 1.1, 0.0)
	var room_nodes: Array = []

	for i in graph.room_count():
		var scene_path: String = graph.placed_rooms[i]
		var world_transform: Transform3D = graph.placed_transforms[i]

		var packed := load(scene_path) as PackedScene
		if packed == null:
			push_warning("Main: could not load room scene '%s'" % scene_path)
			room_nodes.append(null)
			continue

		var room_node := packed.instantiate()
		room_node.transform = world_transform
		add_child(room_node)
		room_nodes.append(room_node)

		if room_node is RoomTemplate:
			var template := room_node as RoomTemplate
			_build_room_geometry(template, world_transform)

			if i == graph.entrance_index:
				var spawns := template.get_spawn_points("player")
				if not spawns.is_empty():
					entrance_spawn_pos = world_transform * spawns[0].position
					entrance_spawn_pos.y += 0.1

	# ── HUD ───────────────────────────────────────────────────────────────────
	# Created before managers so it is connected before their first signals fire.

	var hud_packed := load("res://scenes/ui/HUD.tscn") as PackedScene
	var hud: HUD = hud_packed.instantiate() as HUD
	add_child(hud)

	# ── Mission loop setup ────────────────────────────────────────────────────

	var escalation := EscalationManager.new()
	escalation.name = "EscalationManager"
	add_child(escalation)

	var extraction := _setup_extraction_zone(graph, room_nodes)

	var objectives := ObjectiveManager.new()
	objectives.name = "ObjectiveManager"
	add_child(objectives)
	_objectives = objectives  # store for use in _trigger_debrief

	# Wire HUD before any signal fires
	escalation.escalation_level_changed.connect(hud.on_escalation_changed)
	objectives.objective_state_changed.connect(hud.on_objective_state_changed)

	# Wire gameplay → gameplay
	objectives.primary_objective_complete.connect(escalation.on_objective_completed)
	if extraction != null:
		objectives.primary_objective_complete.connect(extraction.unlock)

	# Wire run outcomes → debrief
	if extraction != null:
		extraction.run_succeeded.connect(func() -> void:
			_trigger_debrief("SUCCEEDED"))
		extraction.run_partial_success.connect(func(_ext: int, _total: int) -> void:
			_trigger_debrief("PARTIAL_SUCCESS"))
		extraction.run_failed.connect(func() -> void:
			_trigger_debrief("FAILED"))

	# setup() emits objective_state_changed — HUD already connected above
	objectives.setup(graph, room_nodes)
	escalation.start()

	# ── Physics test objects + player ────────────────────────────────────────

	var entrance_transform: Transform3D = graph.placed_transforms[graph.entrance_index] \
		if graph.entrance_index >= 0 else Transform3D.IDENTITY
	_spawn_physics_objects(entrance_transform.origin)

	var player := _spawn_player(entrance_spawn_pos)

	_setup_enemies_and_hazards(room_nodes, player, escalation)

	if player != null:
		var health_comp := player.get_node("HealthComponent") as HealthComponent
		if health_comp != null:
			health_comp.health_changed.connect(hud.on_health_changed)
			hud.on_health_changed(health_comp.current_hp, health_comp.max_hp)

		# ── Camera Controller ─────────────────────────────────────────────────
		var cam_ctrl := player.get_node_or_null("CameraMount/CameraController") as CameraController
		if cam_ctrl != null:
			cam_ctrl.connect_to_player(player as CharacterController)
			var tool_mgr_for_cam := player.get_node_or_null("ToolManager") as ToolManager
			if tool_mgr_for_cam != null:
				var cam_tools: Array[BaseTool] = []
				for tn in ["GravityFlipTool", "TimeSlowTool", "ForcePushTool"]:
					var t := tool_mgr_for_cam.get_node_or_null(tn) as BaseTool
					if t != null:
						cam_tools.append(t)
				cam_ctrl.connect_to_tools(cam_tools)

	# ── Tool Selection UI ─────────────────────────────────────────────────────
	# Instantiated after player so ToolManager nodes exist before connecting.

	var tool_ui_packed := load("res://scenes/ui/ToolSelectionUI.tscn") as PackedScene
	if tool_ui_packed != null:
		var tool_ui := tool_ui_packed.instantiate() as ToolSelectionUI
		add_child(tool_ui)
		if player != null:
			var tool_mgr := player.get_node_or_null("ToolManager") as ToolManager
			if tool_mgr != null:
				for tool_node in [
					tool_mgr.get_node_or_null("GravityFlipTool"),
					tool_mgr.get_node_or_null("TimeSlowTool"),
					tool_mgr.get_node_or_null("ForcePushTool"),
				]:
					if tool_node is BaseTool:
						var bt := tool_node as BaseTool
						bt.tool_activated.connect(tool_ui.on_tool_activated)
						bt.tool_deactivated.connect(tool_ui.on_tool_deactivated)
						bt.tool_failed.connect(tool_ui.on_tool_failed)
	else:
		push_error("Main: could not load ToolSelectionUI.tscn")

	generator.queue_free()

	_setup_kill_zone(entrance_spawn_pos)

# ── Kill Zone (void goo) ───────────────────────────────────────────────────────

var _spawn_pos: Vector3 = Vector3.ZERO

## Large Area3D below the map — kills the player and teleports them back to spawn.
func _setup_kill_zone(spawn_pos: Vector3) -> void:
	_spawn_pos = spawn_pos

	var area := Area3D.new()
	area.name = "KillZone"
	area.collision_layer = 0
	area.collision_mask = 4  # player layer

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2000.0, 2.0, 2000.0)
	col.shape = shape
	area.add_child(col)
	area.position = Vector3(0.0, -30.0, 0.0)

	area.body_entered.connect(_on_kill_zone_entered)
	add_child(area)

func _on_kill_zone_entered(body: Node3D) -> void:
	if body is CharacterController:
		var player := body as CharacterController
		player.velocity = Vector3.ZERO
		player.global_position = _spawn_pos

# ── Debrief ────────────────────────────────────────────────────────────────────

## Computes XP and objective list, then shows the MissionDebriefUI.
## outcome: "SUCCEEDED", "PARTIAL_SUCCESS", or "FAILED"
func _trigger_debrief(outcome: String) -> void:
	print("[Main] === RUN %s ===" % outcome)

	# Build objectives list from ObjectiveManager state
	var objectives_list: Array[Dictionary] = []
	if _objectives != null and _objectives.primary_objective != null:
		objectives_list.append({
			"name":        "Activate Terminal",
			"is_complete": _objectives.primary_objective.is_complete(),
		})

	# XP formula: base_xp[Activate] × outcome_multiplier × solo_difficulty
	var outcome_mult: float = _OUTCOME_XP_MULT.get(outcome, 0.25)
	var xp_earned := int(_BASE_XP_ACTIVATE * outcome_mult * _SOLO_DIFFICULTY_MOD)

	var debrief_packed := load("res://scenes/ui/MissionDebriefUI.tscn") as PackedScene
	if debrief_packed == null:
		push_error("Main: could not load MissionDebriefUI.tscn")
		return

	var debrief := debrief_packed.instantiate() as MissionDebriefUI
	add_child(debrief)
	debrief.show_debrief(outcome, objectives_list, xp_earned)

func _setup_extraction_zone(graph: FacilityGraph, room_nodes: Array) -> ExtractionZone:
	if graph.exit_index < 0 or graph.exit_index >= room_nodes.size():
		push_warning("Main: no exit room in graph; extraction zone not placed.")
		return null

	var exit_node: Node = room_nodes[graph.exit_index]
	if not (exit_node is RoomTemplate):
		push_warning("Main: exit room node is not a RoomTemplate.")
		return null

	var exit_template := exit_node as RoomTemplate

	var zone_pos := exit_template.global_position + Vector3(0.0, 0.1, 0.0)
	var zone_spawns := exit_template.get_spawn_points("extraction")
	if not zone_spawns.is_empty():
		zone_pos = zone_spawns[0].global_position

	var zone := ExtractionZone.new()
	zone.name = "ExtractionZone"
	zone.total_players = 1

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 2.4, 3.0)
	col.shape = shape
	zone.add_child(col)

	# Visible marker — green glowing pillar so the player can locate the zone
	var mesh_inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius    = 1.2
	mesh.bottom_radius = 1.2
	mesh.height        = 0.15
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color      = Color(0.0, 1.0, 0.4, 0.8)
	mat.emission_enabled  = true
	mat.emission          = Color(0.0, 1.0, 0.4)
	mat.emission_energy_multiplier = 2.0
	mat.transparency      = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.set_surface_override_material(0, mat)
	zone.add_child(mesh_inst)

	add_child(zone)
	zone.global_position = zone_pos

	print("[Main] ExtractionZone at %s (exit room '%s')" % [zone_pos, exit_template.room_id])
	return zone

## Builds a floor plane and four walls for a room based on its AABB half-extents.
func _build_room_geometry(template: RoomTemplate, world_transform: Transform3D) -> void:
	var origin := world_transform.origin
	var hx := template.aabb_half_extents.x
	var hz := template.aabb_half_extents.z

	_add_static_box(
		origin + Vector3(0.0, -FLOOR_THICKNESS * 0.5, 0.0),
		Vector3(hx * 2.0, FLOOR_THICKNESS, hz * 2.0),
		FLOOR_COLOR)

	# Walls omitted for playtest — connector-aware door cutting not yet implemented.
	# Rooms are open-air so the player can walk between all generated rooms.

func _spawn_physics_objects(near_pos: Vector3) -> void:
	_add_physics_box(near_pos + Vector3(-1.5, 0.5,  0.5), Color(0.8, 0.3, 0.3))
	_add_physics_box(near_pos + Vector3( 1.5, 0.5,  0.5), Color(0.3, 0.8, 0.3))
	_add_physics_box(near_pos + Vector3( 0.0, 0.5, -1.5), Color(0.3, 0.3, 0.8))
	_add_physics_sphere(near_pos + Vector3( 1.0, 0.4,  1.5), Color(1.0, 1.0, 1.0))
	_add_physics_sphere(near_pos + Vector3(-1.0, 0.4, -1.5), Color(0.9, 0.5, 0.1))

## Spawns the player and returns the node for signal wiring.
func _spawn_player(spawn_pos: Vector3) -> CharacterController:
	var player_scene := load("res://scenes/gameplay/Player.tscn") as PackedScene
	if player_scene == null:
		push_error("Main: could not load Player.tscn")
		return null
	var player := player_scene.instantiate() as CharacterController
	player.position = spawn_pos
	add_child(player)
	return player

# ── Enemy & Hazard Placement ───────────────────────────────────────────────────

## Scans every room for GuardWaypoint / AlarmLaser / PressurePlate spawn markers
## and instantiates the corresponding scene at each marker position.
## Called after the player is in the tree so PatrolGuard.setup() gets a valid ref.
func _setup_enemies_and_hazards(
		room_nodes: Array,
		player: CharacterController,
		escalation: EscalationManager) -> void:

	var guard_scene := load("res://scenes/gameplay/PatrolGuard.tscn") as PackedScene
	var laser_scene := load("res://scenes/gameplay/AlarmLaser.tscn") as PackedScene
	var plate_scene := load("res://scenes/gameplay/PressurePlate.tscn") as PackedScene

	for room_node in room_nodes:
		if not (room_node is RoomTemplate):
			continue
		var template := room_node as RoomTemplate

		# ── Guards ────────────────────────────────────────────────────────────
		if guard_scene != null:
			for marker in template.get_spawn_points("guardwaypoint"):
				var guard := guard_scene.instantiate() as PatrolGuard
				add_child(guard)
				guard.global_position = marker.global_position
				guard.setup(player, escalation)
				print("[Main] PatrolGuard spawned at %s in room '%s'" \
					% [marker.global_position, template.room_id])

		# ── Alarm Lasers ──────────────────────────────────────────────────────
		if laser_scene != null:
			for marker in template.get_spawn_points("alarmlaser"):
				var laser := laser_scene.instantiate() as AlarmLaser
				add_child(laser)
				laser.global_position = marker.global_position
				laser.global_rotation = marker.global_rotation
				laser.setup(escalation)
				print("[Main] AlarmLaser spawned at %s in room '%s'" \
					% [marker.global_position, template.room_id])

		# ── Pressure Plates ───────────────────────────────────────────────────
		if plate_scene != null:
			for marker in template.get_spawn_points("pressureplate"):
				var plate := plate_scene.instantiate() as PressurePlate
				add_child(plate)
				plate.global_position = marker.global_position
				plate.setup(escalation)
				print("[Main] PressurePlate spawned at %s in room '%s'" \
					% [marker.global_position, template.room_id])

# ── Static Helpers ─────────────────────────────────────────────────────────────

func _add_static_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	add_child(body)

func _add_physics_box(pos: Vector3, color: Color) -> void:
	var body := PhysicsObject.new()
	body.position = pos
	body.collision_layer = 2
	body.collision_mask = 1

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.8, 0.8)
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.8, 0.8)
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	add_child(body)

func _add_physics_sphere(pos: Vector3, color: Color) -> void:
	var body := PhysicsObject.new()
	body.position = pos
	body.collision_layer = 2
	body.collision_mask = 1

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.35
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	add_child(body)
