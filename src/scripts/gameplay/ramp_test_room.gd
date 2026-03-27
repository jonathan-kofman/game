## RampTestRoom
## S5-07: Time Slow validation scene.
## Spawns a ramp with PhysicsObjects rolling down it so Time Slow (T) can be
## tested against moving bodies. Addresses prototype failure (Jolt sleep made
## velocity scaling invisible on resting objects) and resolves risk R-07.
##
## Controls: WASD move, mouse look, G = gravity flip, T = time slow, F = force push
## Expected: pressing T visibly slows boxes/spheres mid-roll down the ramp.

extends Node3D

const FLOOR_COLOR   := Color(0.30, 0.32, 0.35)
const RAMP_COLOR    := Color(0.50, 0.45, 0.35)
const WALL_COLOR    := Color(0.40, 0.42, 0.45)

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_build_room()
	_spawn_physics_objects()
	_spawn_player()

# ── Environment ────────────────────────────────────────────────────────────────

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
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)

# ── Room Geometry ──────────────────────────────────────────────────────────────

func _build_room() -> void:
	# Floor — 20m x 20m
	_add_static_box(Vector3(0.0, -0.15, 0.0), Vector3(20.0, 0.3, 20.0), FLOOR_COLOR)

	# Walls (low, so the camera can see the ramp clearly)
	_add_static_box(Vector3(  0.0, 1.5, -10.0), Vector3(20.0, 3.0, 0.3), WALL_COLOR)  # north
	_add_static_box(Vector3(  0.0, 1.5,  10.0), Vector3(20.0, 3.0, 0.3), WALL_COLOR)  # south
	_add_static_box(Vector3(-10.0, 1.5,   0.0), Vector3(0.3, 3.0, 20.0), WALL_COLOR)  # west
	_add_static_box(Vector3( 10.0, 1.5,   0.0), Vector3(0.3, 3.0, 20.0), WALL_COLOR)  # east

	# Ramp — 6m wide, 5m long, rises 3m. Tilted ~31° around X axis.
	# Positioned so boxes placed at the top roll toward the player spawn.
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 1
	ramp.collision_mask = 0
	# Tilt: atan(3/5) ≈ 31°
	ramp.rotation_degrees.x = -31.0
	ramp.position = Vector3(0.0, 1.5, 2.0)

	var ramp_col := CollisionShape3D.new()
	var ramp_shape := BoxShape3D.new()
	ramp_shape.size = Vector3(6.0, 0.3, 5.83)  # 5.83 ≈ hypotenuse of 3/5 rise/run
	ramp_col.shape = ramp_shape
	ramp.add_child(ramp_col)

	var ramp_mesh := MeshInstance3D.new()
	var ramp_box := BoxMesh.new()
	ramp_box.size = Vector3(6.0, 0.3, 5.83)
	ramp_mesh.mesh = ramp_box
	var ramp_mat := StandardMaterial3D.new()
	ramp_mat.albedo_color = RAMP_COLOR
	ramp_mesh.material_override = ramp_mat
	ramp.add_child(ramp_mesh)

	add_child(ramp)

	# Lip at the top of the ramp to hold the spawned boxes briefly
	_add_static_box(Vector3(0.0, 3.2, -0.8), Vector3(6.2, 0.3, 0.3), RAMP_COLOR)

# ── Physics Objects ────────────────────────────────────────────────────────────

func _spawn_physics_objects() -> void:
	# Boxes lined up at the top of the ramp — already in motion when the scene loads.
	# Staggered positions so they don't all arrive at once.
	var colors := [
		Color(0.9, 0.2, 0.2),  # red
		Color(0.2, 0.8, 0.2),  # green
		Color(0.2, 0.4, 0.9),  # blue
		Color(1.0, 0.8, 0.1),  # yellow
		Color(0.9, 0.4, 0.1),  # orange
	]
	for i in colors.size():
		var x := -2.0 + i * 1.0
		_add_physics_box(Vector3(x, 3.5, -0.5), colors[i])

	# Spheres — roll faster than boxes, useful for testing timing
	_add_physics_sphere(Vector3(-1.5, 3.5, -0.3), Color(1.0, 1.0, 1.0))
	_add_physics_sphere(Vector3( 1.5, 3.5, -0.3), Color(0.8, 0.2, 0.8))

# ── Player ─────────────────────────────────────────────────────────────────────

func _spawn_player() -> void:
	var player_scene := load("res://scenes/gameplay/Player.tscn") as PackedScene
	if player_scene == null:
		push_error("RampTestRoom: could not load Player.tscn")
		return
	var player := player_scene.instantiate()
	# Spawn at the bottom of the ramp, facing up the slope
	player.position = Vector3(0.0, 1.0, 7.0)
	player.rotation_degrees.y = 180.0  # face the ramp
	add_child(player)

# ── Static helpers ─────────────────────────────────────────────────────────────

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

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)

	add_child(body)

func _add_physics_box(pos: Vector3, color: Color) -> void:
	var body := PhysicsObject.new()
	body.position = pos
	body.collision_layer = 2
	body.collision_mask = 1

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.7, 0.7)
	col.shape = shape
	body.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.7, 0.7)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)

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

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)

	add_child(body)
