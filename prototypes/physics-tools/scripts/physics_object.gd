# PROTOTYPE - NOT FOR PRODUCTION
# Question: Do three physics tools feel satisfying to use in a 3D environment?
# Date: 2026-03-25

# Attach to any RigidBody3D in the test room.
# Gives it a random color on spawn so objects are visually distinct.

extends RigidBody3D

func _ready() -> void:
	# Random color for easy visual tracking during testing
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(randf(), randf(), randf())
		mesh_instance.material_override = mat
