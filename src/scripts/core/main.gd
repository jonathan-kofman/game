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

		# Build placeholder floor and walls from the template's AABB metadata
		if room_node is RoomTemplate:
			var template := room_node as RoomTemplate
			_build_room_geometry(template, world_transform)

			# Grab entrance player spawn position
			if i == graph.entrance_index:
				var spawns := template.get_spawn_points("player")
				if not spawns.is_empty():
					entrance_spawn_pos = world_transform * spawns[0].position
					entrance_spawn_pos.y += 0.1  # lift slightly above floor

	# ── Mission loop setup ────────────────────────────────────────────────────

	# Escalation Manager
	var escalation := EscalationManager.new()
	escalation.name = "EscalationManager"
	add_child(escalation)

	# Extraction Zone — placed at exit room's extraction_zone spawn point
	var extraction := _setup_extraction_zone(graph, room_nodes)

	# Objective Manager — places terminals, connects to escalation + extraction
	var objectives := ObjectiveManager.new()
	objectives.name = "ObjectiveManager"
	add_child(objectives)
	objectives.setup(graph, room_nodes)

	# Wire: objective complete → escalation advance + extraction unlock
	objectives.primary_objective_complete.connect(escalation.on_objective_completed)
	if extraction != null:
		objectives.primary_objective_complete.connect(extraction.unlock)

	# Wire: escalation critical → log (HUD will consume in future sprint)
	escalation.escalation_level_changed.connect(func(level: int, name_str: String) -> void:
		print("[Main] Escalation: %s" % name_str))

	# Wire: run outcome signals
	if extraction != null:
		extraction.run_succeeded.connect(func() -> void:
			print("[Main] === RUN SUCCEEDED ==="))
		extraction.run_partial_success.connect(func(ext: int, total: int) -> void:
			print("[Main] === RUN PARTIAL SUCCESS (%d/%d extracted) ===" % [ext, total]))
		extraction.run_failed.connect(func() -> void:
			print("[Main] === RUN FAILED ==="))

	escalation.start()

	# ── Physics test objects + player ────────────────────────────────────────

	var entrance_transform: Transform3D = graph.placed_transforms[graph.entrance_index] \
		if graph.entrance_index >= 0 else Transform3D.IDENTITY
	_spawn_physics_objects(entrance_transform.origin)

	_spawn_player(entrance_spawn_pos)
	generator.queue_free()

func _setup_extraction_zone(graph: FacilityGraph, room_nodes: Array) -> ExtractionZone:
	if graph.exit_index < 0 or graph.exit_index >= room_nodes.size():
		push_warning("Main: no exit room in graph; extraction zone not placed.")
		return null

	var exit_node := room_nodes[graph.exit_index]
	if not (exit_node is RoomTemplate):
		push_warning("Main: exit room node is not a RoomTemplate.")
		return null

	var exit_template := exit_node as RoomTemplate

	# Find extraction_zone spawn point; fall back to room centre
	var zone_pos := exit_template.global_position + Vector3(0.0, 0.1, 0.0)
	var zone_spawns := exit_template.get_spawn_points("extraction")
	if not zone_spawns.is_empty():
		zone_pos = zone_spawns[0].global_position

	# Build the Area3D extraction zone procedurally
	var zone := ExtractionZone.new()
	zone.name = "ExtractionZone"
	zone.total_players = 1  # solo MVP; updated to player_count when networking lands

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 2.4, 3.0)
	col.shape = shape
	zone.add_child(col)

	zone.global_position = zone_pos
	add_child(zone)

	print("[Main] ExtractionZone placed at exit room '%s'" % exit_template.room_id)
	return zone

## Builds a floor plane and four walls for a room based on its AABB half-extents.
## All geometry is world-positioned using world_transform.origin.
func _build_room_geometry(template: RoomTemplate, world_transform: Transform3D) -> void:
	var origin := world_transform.origin
	var hx := template.aabb_half_extents.x
	var hz := template.aabb_half_extents.z

	# Floor
	_add_static_box(
		origin + Vector3(0.0, -FLOOR_THICKNESS * 0.5, 0.0),
		Vector3(hx * 2.0, FLOOR_THICKNESS, hz * 2.0),
		FLOOR_COLOR)

	# Four walls (north, south, east, west) with connector gaps omitted for MVP
	var wall_y := origin.y + WALL_HEIGHT * 0.5
	# North wall
	_add_static_box(
		Vector3(origin.x, wall_y, origin.z - hz),
		Vector3(hx * 2.0, WALL_HEIGHT, WALL_THICKNESS),
		WALL_COLOR)
	# South wall
	_add_static_box(
		Vector3(origin.x, wall_y, origin.z + hz),
		Vector3(hx * 2.0, WALL_HEIGHT, WALL_THICKNESS),
		WALL_COLOR)
	# West wall
	_add_static_box(
		Vector3(origin.x - hx, wall_y, origin.z),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, hz * 2.0),
		WALL_COLOR)
	# East wall
	_add_static_box(
		Vector3(origin.x + hx, wall_y, origin.z),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, hz * 2.0),
		WALL_COLOR)

func _spawn_physics_objects(near_pos: Vector3) -> void:
	_add_physics_box(near_pos + Vector3(-1.5, 0.5,  0.5), Color(0.8, 0.3, 0.3))
	_add_physics_box(near_pos + Vector3( 1.5, 0.5,  0.5), Color(0.3, 0.8, 0.3))
	_add_physics_box(near_pos + Vector3( 0.0, 0.5, -1.5), Color(0.3, 0.3, 0.8))
	_add_physics_sphere(near_pos + Vector3( 1.0, 0.4,  1.5), Color(1.0, 1.0, 1.0))
	_add_physics_sphere(near_pos + Vector3(-1.0, 0.4, -1.5), Color(0.9, 0.5, 0.1))

func _spawn_player(spawn_pos: Vector3) -> void:
	var player_scene := load("res://scenes/gameplay/Player.tscn") as PackedScene
	if player_scene == null:
		push_error("Main: could not load Player.tscn")
		return
	var player := player_scene.instantiate()
	player.position = spawn_pos
	add_child(player)

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
