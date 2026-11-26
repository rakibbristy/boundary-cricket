extends Node3D

var ball: Node3D
var batter: Node3D
var score := 0
var wickets := 0
var balls := 0
var runs_label: Label
var status_label: Label
var bat_ready := true
var delivery_active := false
var hit_done := false
var delivery_timer := 0.0
var shot_power := 0.0
var ball_velocity := Vector3.ZERO
var ball_state := "none"
var ball_bounced := false
var camera: Camera3D
var play_mode := "batting"
var match_started := false
var auto_delivery_timer := 1.2
var bowl_button: Button
var defend_button: Button
var drive_button: Button
var loft_button: Button
var swap_button: Button
var controls_swapped := false
var run_button: Button
var run_in_progress := false
var run_timer := 0.0
var completed_runs_this_ball := 0
var shot_boundary_done := false
var fielder_nodes: Array[Node3D] = []
var fielder_home_positions: Array[Vector3] = []
var active_fielder: Node3D = null
var fielder_chasing := false
var fielder_has_ball := false
var timing_meter: ProgressBar
var delivery_speed := 12.0
var delivery_speed_name := "MEDIUM"
var delivery_full_toss := false
var delivery_bounced := false
var run_start_z := 7.2
var run_target_z := -7.2
const RUN_DURATION := 2.6
const MAX_WICKETS := 10
const MAX_BALLS := 120

func _ready() -> void:
	_build_world()
	_build_hud()
	_update_score()
	_show_status("Choose BAT FIRST or BOWL FIRST")

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.018, 0.045, 0.105)
	sky_material.sky_horizon_color = Color(0.22, 0.31, 0.43)
	sky_material.ground_bottom_color = Color(0.018, 0.028, 0.035)
	sky_material.ground_horizon_color = Color(0.12, 0.17, 0.21)
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.72, 0.88)
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.15, 0.21, 0.29)
	environment.fog_density = 0.006
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48.0
	add_child(sun)

	var ground_mesh := CylinderMesh.new()
	ground_mesh.top_radius = 1.0
	ground_mesh.bottom_radius = 1.0
	ground_mesh.height = 0.5
	ground_mesh.radial_segments = 96
	var ground := MeshInstance3D.new()
	ground.name = "Oval_Ground"
	ground.mesh = ground_mesh
	ground.scale = Vector3(16.0, 1.0, 22.0)
	ground.position = Vector3(0, -0.35, 0)
	add_child(ground)
	ground.material_override = _surface_material(Color(0.13, 0.34, 0.12), 0.18, 18.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Alternating mowing bands give the outfield depth without heavy textures.
	for i in range(8):
		var stripe_color := Color(0.13, 0.39, 0.19) if i % 2 == 0 else Color(0.10, 0.32, 0.15)
		var stripe := _make_box("Mowing_Stripe", Vector3(-13.8 + i * 3.95, -0.085, 0), Vector3(3.9, 0.025, 42.5), stripe_color)
		stripe.material_override = _surface_material(stripe_color, 0.12, 12.0)
	var pitch := _make_box("Pitch", Vector3(0, -0.04, 0), Vector3(3.2, 0.12, 22), Color(0.61, 0.42, 0.25))
	pitch.material_override = _surface_material(Color(0.56, 0.37, 0.22), 0.22, 9.0)
	_make_box("Pitch_Centre", Vector3(0, 0.025, 0), Vector3(2.75, 0.025, 20.5), Color(0.72, 0.55, 0.35))
	for z in [-8.8, 8.8]:
		_make_box("Crease", Vector3(0, 0.07, z), Vector3(3.7, 0.035, 0.12), Color(0.96, 0.94, 0.83))
		_make_box("Return_Crease_L", Vector3(-1.55, 0.07, z), Vector3(0.10, 0.035, 1.25), Color(0.96, 0.94, 0.83))
		_make_box("Return_Crease_R", Vector3(1.55, 0.07, z), Vector3(0.10, 0.035, 1.25), Color(0.96, 0.94, 0.83))
		for x in [-0.35, 0, 0.35]:
			_make_box("Stump", Vector3(x, 0.55, z), Vector3(0.075, 1.05, 0.075), Color(0.94, 0.87, 0.69))
		_make_box("Bail", Vector3(0, 1.10, z), Vector3(0.82, 0.055, 0.075), Color(0.98, 0.91, 0.73))
	_add_oval_boundary()
	_build_stadium()
	_add_stadium_details()
	make_batter()
	make_bowler()
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 6.8, 18.2)
	camera.fov = 54.0
	camera.near = 0.08
	camera.far = 180.0
	camera.look_at(Vector3(0.0, 1.0, -1.0), Vector3.UP)
	camera.current = true
	add_child(camera)


func _build_stadium() -> void:
	# Curved oval seating bowl made from individually angled stand sections.
	for tier in range(4):
		var rx: float = 18.2 + float(tier) * 1.15
		var rz: float = 24.0 + float(tier) * 1.15
		var y: float = 0.8 + float(tier) * 0.72
		var tier_color: Color = Color(0.07, 0.13, 0.24) if tier % 2 == 0 else Color(0.12, 0.19, 0.31)
		for segment in range(48):
			var angle: float = TAU * float(segment) / 48.0
			var pos := Vector3(cos(angle) * rx, y, sin(angle) * rz)
			var stand := _make_box("Curved_Grandstand", pos, Vector3(3.1, 0.62, 3.4), tier_color)
			stand.rotation.y = -angle
	# Four light towers outside the oval.
	for sx_value in [-1.0, 1.0]:
		for sz_value in [-1.0, 1.0]:
			var sx: float = float(sx_value)
			var sz: float = float(sz_value)
			var mast_pos := Vector3(sx * 20.5, 7.0, sz * 25.0)
			var mast := _make_box("Floodlight_Mast", mast_pos, Vector3(0.22, 14.0, 0.22), Color(0.48, 0.54, 0.62))
			mast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_make_box("Floodlight_Bank", mast_pos + Vector3(0, 6.9, 0), Vector3(1.8, 0.45, 0.65), Color(0.92, 0.94, 1.0))
			var lamp := OmniLight3D.new()
			lamp.position = mast_pos + Vector3(0, 6.3, 0)
			lamp.light_color = Color(0.78, 0.86, 1.0)
			lamp.light_energy = 1.1
			lamp.omni_range = 28.0
			lamp.shadow_enabled = false
			add_child(lamp)


func _add_stadium_details() -> void:
	# Original CRICVERSE visual identity: illuminated score displays and sight screens.
	for side in [-1, 1]:
		var screen := _make_box("CRICVERSE_Score_Display", Vector3(float(side) * 15.2, 5.0, -1.5), Vector3(0.32, 3.0, 5.6), Color(0.012, 0.035, 0.075))
		screen.rotation.y = PI * 0.5 if side < 0 else -PI * 0.5
		var screen_label := Label3D.new()
		screen_label.name = "Score_Display_Text"
		screen_label.text = "CRICVERSE\nYOUR WORLD. YOUR CRICKET."
		screen_label.font_size = 32
		screen_label.pixel_size = 0.012
		screen_label.modulate = Color(0.35, 0.92, 1.0)
		screen_label.position = Vector3(0.0, 0.0, 0.18)
		screen.add_child(screen_label)
	# Sight screens at both ends give the pitch a recognisable broadcast-ground layout.
	for end_sign in [-1, 1]:
		var sight := _make_box("Sight_Screen", Vector3(0, 2.2, float(end_sign) * 18.7), Vector3(7.0, 4.2, 0.42), Color(0.82, 0.84, 0.82))
		sight.material_override = _mat(Color(0.82, 0.84, 0.82), 0.0, 0.95)
	# Low-profile LED fascia around the near-side boundary.
	for side in [-1, 1]:
		var fascia := _make_box("LED_Boundary_Fascia", Vector3(float(side) * 15.4, 0.55, 0), Vector3(0.18, 0.72, 35.0), Color(0.015, 0.12, 0.19))
		fascia.material_override = _mat(Color(0.015, 0.12, 0.19), 0.15, 0.38)
		for z in range(-16, 17, 4):
			_make_box("LED_Fascia_Light", Vector3(float(side) * 15.29, 0.58, float(z)), Vector3(0.035, 0.12, 2.2), Color(0.08, 0.72, 0.92))

func _add_oval_boundary() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.985
	ring.outer_radius = 1.0
	ring.rings = 96
	ring.ring_segments = 12
	var line := MeshInstance3D.new()
	line.name = "Oval_Boundary_Rope"
	line.mesh = ring
	line.scale = Vector3(15.7, 0.12, 21.0)
	line.position.y = 0.07
	line.material_override = _mat(Color(0.96, 0.96, 0.88))
	add_child(line)

func _make_box(label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	node.material_override = mat
	add_child(node)
	return node

func _surface_material(base_color: Color, noise_amount: float, uv_scale: float) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.055
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.48
	var noise_image := noise.get_image(256, 256)
	var texture := ImageTexture.create_from_image(noise_image)
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.albedo_texture = texture
	material.roughness = 0.94
	material.metallic = 0.0
	material.uv1_scale = Vector3(uv_scale, uv_scale, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material

func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _part(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _part(parent, mesh, pos, color)

func _capsule(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _part(parent, mesh, pos, color, rot)

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return _part(parent, mesh, pos, color)

func _load_rigged_character(asset_path: String, parent: Node3D) -> bool:
	if not ResourceLoader.exists(asset_path):
		return false
	var packed_scene := load(asset_path) as PackedScene
	if packed_scene == null:
		push_warning("Character asset could not be loaded: " + asset_path)
		return false
	var model := packed_scene.instantiate() as Node3D
	if model == null:
		push_warning("Character asset root must be Node3D: " + asset_path)
		return false
	parent.add_child(model)
	model.position = Vector3.ZERO
	for player_node in model.find_children("*", "AnimationPlayer", true, false):
		var animation_player := player_node as AnimationPlayer
		var clips := animation_player.get_animation_list()
		for preferred in ["Idle", "idle", "Armature|Idle", "mixamo.com"]:
			if clips.has(preferred):
				animation_player.play(preferred)
				return true
		if clips.size() > 0:
			animation_player.play(clips[0])
	return true


func _add_batter_details(parent: Node3D) -> void:
	# Helmet grille, shirt piping, belt and boot details on the original player mesh.
	var grille := Color(0.78, 0.84, 0.91)
	for x in [-0.105, -0.035, 0.035, 0.105]:
		_capsule(parent, Vector3(x, 1.94, -0.205), 0.012, 0.30, grille)
	for y in [1.84, 1.92, 2.00, 2.08]:
		_capsule(parent, Vector3(0, y, -0.21), 0.012, 0.28, grille, Vector3(0, 0, 90))
	_capsule(parent, Vector3(0, 0.98, 0.0), 0.035, 0.58, Color(0.92, 0.72, 0.22), Vector3(0, 0, 90))
	for side in [-1.0, 1.0]:
		_capsule(parent, Vector3(side * 0.285, 1.42, -0.005), 0.018, 0.46, Color(0.92, 0.76, 0.28), Vector3(0, 0, side * 90.0))
		_capsule(parent, Vector3(side * 0.17, 0.12, 0.02), 0.035, 0.32, Color(0.035, 0.045, 0.06), Vector3(90, 0, 0))

func _add_bowler_details(parent: Node3D) -> void:
	var trim := Color(0.98, 0.72, 0.18)
	_capsule(parent, Vector3(0, 1.62, -0.19), 0.025, 0.48, trim, Vector3(0, 0, 90))
	_capsule(parent, Vector3(0, 0.98, 0.0), 0.035, 0.56, Color(0.08, 0.08, 0.1), Vector3(0, 0, 90))
	for side in [-1.0, 1.0]:
		_capsule(parent, Vector3(side * 0.29, 1.4, -0.02), 0.018, 0.42, trim, Vector3(0, 0, side * 90.0))
		_sphere(parent, Vector3(side * 0.13, 0.12, 0.0), 0.065, Color(0.025, 0.03, 0.04))

func _add_fielder_details(parent: Node3D, shirt: Color) -> void:
	var trim := Color(0.96, 0.82, 0.35)
	_capsule(parent, Vector3(0, 1.47, -0.16), 0.018, 0.32, trim, Vector3(0, 0, 90))
	_capsule(parent, Vector3(0, 0.91, 0.0), 0.03, 0.42, Color(0.07, 0.08, 0.1), Vector3(0, 0, 90))
	for side in [-1.0, 1.0]:
		_capsule(parent, Vector3(side * 0.28, 1.25, -0.01), 0.014, 0.34, trim, Vector3(0, 0, side * 90.0))
		_sphere(parent, Vector3(side * 0.13, 0.12, 0.0), 0.055, Color(0.025, 0.03, 0.04))

func make_batter() -> void:
	batter = Node3D.new()
	batter.name = "Batter_3D"
	batter.position = Vector3(0.75, 0, 7.2)
	add_child(batter)
	if _load_rigged_character("res://assets/players/quaternius_superhero_male.glb", batter):
		_add_batter_details(batter)
		return
	var skin := Color(0.62, 0.38, 0.25)
	var shirt := Color(0.08, 0.22, 0.72)
	var trousers := Color(0.88, 0.89, 0.92)
	# torso, neck and detailed head
	_capsule(batter, Vector3(0, 1.18, 0), 0.29, 0.92, shirt)
	_cylinder(batter, Vector3(0, 1.68, 0), 0.09, 0.16, skin)
	_sphere(batter, Vector3(0, 1.91, 0), 0.22, skin)
	# helmet shell and face grille
	_sphere(batter, Vector3(0, 2.04, -0.015), 0.235, Color(0.04, 0.08, 0.16))
	_capsule(batter, Vector3(0.17, 1.91, -0.13), 0.018, 0.28, Color(0.78, 0.82, 0.88), Vector3(0, 0, 90))
	# legs and white pads
	_capsule(batter, Vector3(-0.16, 0.52, 0.02), 0.105, 0.82, trousers, Vector3(0, 0, -5))
	_capsule(batter, Vector3(0.16, 0.52, 0.02), 0.105, 0.82, trousers, Vector3(0, 0, 5))
	_capsule(batter, Vector3(-0.16, 0.55, -0.105), 0.115, 0.52, Color(0.96, 0.96, 0.94))
	_capsule(batter, Vector3(0.16, 0.55, -0.105), 0.115, 0.52, Color(0.96, 0.96, 0.94))
	# arms, gloves and bat
	_capsule(batter, Vector3(-0.34, 1.32, -0.02), 0.09, 0.58, shirt, Vector3(0, 0, -25))
	_capsule(batter, Vector3(0.34, 1.32, -0.06), 0.09, 0.58, shirt, Vector3(0, 0, 25))
	_sphere(batter, Vector3(0.43, 1.06, -0.22), 0.105, Color(0.94, 0.94, 0.88))
	_sphere(batter, Vector3(0.34, 1.12, -0.35), 0.09, Color(0.94, 0.94, 0.88))
	_capsule(batter, Vector3(0.48, 0.69, -0.62), 0.055, 1.0, Color(0.72, 0.48, 0.22), Vector3(0, 0, -12))
	_make_box("Bat_Blade", Vector3(0, 0, 0), Vector3(0.18, 0.72, 0.055), Color(0.86, 0.68, 0.39)).reparent(batter)
	batter.get_node("Bat_Blade").position = Vector3(0.48, 0.32, -0.62)
	batter.get_node("Bat_Blade").rotation_degrees = Vector3(0, 0, -12)

func make_bowler() -> void:
	var bowler := Node3D.new()
	bowler.name = "Bowler_3D"
	bowler.position = Vector3(0, 0, -7.5)
	add_child(bowler)
	if _load_rigged_character("res://assets/players/quaternius_superhero_male.glb", bowler):
		_add_bowler_details(bowler)
		_add_fielder(Vector3(-9, 0, -5), Color(0.9, 0.58, 0.08))
		_add_fielder(Vector3(8, 0, -4), Color(0.9, 0.58, 0.08))
		_add_fielder(Vector3(-10, 0, 7), Color(0.9, 0.58, 0.08))
		_add_fielder(Vector3(10, 0, 8), Color(0.9, 0.58, 0.08))
		return
	var skin := Color(0.55, 0.32, 0.22)
	_capsule(bowler, Vector3(0, 1.2, 0), 0.27, 0.9, Color(0.82, 0.12, 0.1))
	_sphere(bowler, Vector3(0, 1.88, 0), 0.21, skin)
	_sphere(bowler, Vector3(0, 2.0, 0), 0.22, Color(0.12, 0.12, 0.14))
	_capsule(bowler, Vector3(-0.16, 0.48, 0), 0.09, 0.85, Color(0.08, 0.08, 0.1), Vector3(0, 0, -4))
	_capsule(bowler, Vector3(0.16, 0.48, 0), 0.09, 0.85, Color(0.08, 0.08, 0.1), Vector3(0, 0, 4))
	_capsule(bowler, Vector3(-0.34, 1.4, 0), 0.075, 0.62, Color(0.82, 0.12, 0.1), Vector3(0, 0, -25))
	_capsule(bowler, Vector3(0.34, 1.46, -0.1), 0.075, 0.68, Color(0.82, 0.12, 0.1), Vector3(0, 0, 25))
	_sphere(bowler, Vector3(0.48, 1.72, -0.26), 0.075, skin)
	_add_fielder(Vector3(-9, 0, -5), Color(0.9, 0.58, 0.08))
	_add_fielder(Vector3(8, 0, -4), Color(0.9, 0.58, 0.08))
	_add_fielder(Vector3(-10, 0, 7), Color(0.9, 0.58, 0.08))
	_add_fielder(Vector3(10, 0, 8), Color(0.9, 0.58, 0.08))

func _add_fielder(pos: Vector3, shirt: Color) -> void:
	var fielder := Node3D.new()
	fielder.position = pos
	add_child(fielder)
	fielder_nodes.append(fielder)
	fielder_home_positions.append(pos)
	if _load_rigged_character("res://assets/players/quaternius_superhero_male.glb", fielder):
		_add_fielder_details(fielder, shirt)
		return
	_capsule(fielder, Vector3(0, 1.0, 0), 0.2, 0.68, shirt)
	_sphere(fielder, Vector3(0, 1.52, 0), 0.16, Color(0.55, 0.34, 0.23))
	_capsule(fielder, Vector3(-0.12, 0.42, 0), 0.065, 0.65, Color(0.12, 0.12, 0.15))
	_capsule(fielder, Vector3(0.12, 0.42, 0), 0.065, 0.65, Color(0.12, 0.12, 0.15))
	_capsule(fielder, Vector3(-0.25, 1.0, 0), 0.055, 0.48, shirt, Vector3(0, 0, -20))
	_capsule(fielder, Vector3(0.25, 1.0, 0), 0.055, 0.48, shirt, Vector3(0, 0, 20))

func _add_stadium() -> void:
	# Four-sided stadium bowl with tiered seating and original team-colour crowd.
	var crowd_colors := [Color(0.92, 0.92, 0.96), Color(0.95, 0.28, 0.16), Color(0.12, 0.48, 0.88), Color(0.96, 0.72, 0.12), Color(0.12, 0.68, 0.40)]
	for side in [-1, 1]:
		_make_box("Stand_Base", Vector3(side * 16.0, 1.25, 0), Vector3(3.0, 2.5, 37), Color(0.055, 0.075, 0.13))
		for row in range(5):
			var seat_color: Color = [Color(0.08, 0.27, 0.62), Color(0.78, 0.13, 0.16), Color(0.91, 0.68, 0.12), Color(0.08, 0.48, 0.32), Color(0.18, 0.22, 0.34)][row]
			_make_box("Stand_Tier", Vector3(side * (14.1 + row * 0.55), 2.15 + row * 0.48, 0), Vector3(1.0, 0.20, 35), seat_color)
			for seat in range(22):
				var zpos := -16.2 + seat * 1.52
				var person := _sphere(self, Vector3(side * (14.0 + row * 0.55), 2.48 + row * 0.48, zpos), 0.13, crowd_colors[(seat + row * 3) % crowd_colors.size()])
				person.scale = Vector3(0.82, 1.15, 0.82)
	# End stands frame the far side of the ground.
	for end_sign in [-1, 1]:
		_make_box("End_Stand", Vector3(0, 1.1, end_sign * 22.0), Vector3(29, 2.2, 2.0), Color(0.055, 0.075, 0.13))
		for row in range(4):
			_make_box("End_Seat_Tier", Vector3(0, 2.0 + row * 0.48, end_sign * (20.9 + row * 0.42)), Vector3(27, 0.20, 0.8), crowd_colors[row])
			for seat in range(18):
				_sphere(self, Vector3(-12.5 + seat * 1.45, 2.35 + row * 0.48, end_sign * (20.7 + row * 0.42)), 0.12, crowd_colors[(seat + row) % crowd_colors.size()])
	# Floodlight towers now cast actual light onto the field.
	for x in [-14.5, 14.5]:
		for z in [-15, 15]:
			_make_box("Floodlight_Pole", Vector3(x, 8, z), Vector3(0.22, 16, 0.22), Color(0.34, 0.39, 0.48))
			_make_box("Floodlight_Array", Vector3(x, 16.1, z), Vector3(1.8, 0.45, 0.8), Color(0.94, 0.97, 1.0))
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x * 0.82, 14.8, z * 0.82)
			lamp.light_color = Color(0.78, 0.86, 1.0)
			lamp.light_energy = 1.4
			lamp.omni_range = 23.0
			lamp.omni_attenuation = 1.4
			add_child(lamp)
	# Sponsor-style boundary fascia with contrasting panels.
	for z in [-19.5, 19.5]:
		_make_box("Boundary_Board", Vector3(0, 0.42, z), Vector3(30, 0.8, 0.25), Color(0.025, 0.12, 0.22))
		for i in range(6):
			_make_box("Boundary_Panel", Vector3(-12.5 + i * 5.0, 0.44, z - 0.14), Vector3(4.7, 0.58, 0.035), [Color(0.02,0.48,0.72), Color(0.82,0.12,0.16), Color(0.08,0.48,0.30)][i % 3])
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.size = Vector2(340, 100)
	var panel_skin := StyleBoxFlat.new()
	panel_skin.bg_color = Color(0.012, 0.035, 0.075, 0.92)
	panel_skin.set_corner_radius_all(14)
	panel_skin.set_border_width_all(2)
	panel_skin.border_color = Color(0.08, 0.68, 0.88, 0.9)
	panel_skin.content_margin_left = 14
	panel_skin.content_margin_right = 14
	panel_skin.content_margin_top = 8
	panel_skin.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_skin)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	runs_label = Label.new()
	runs_label.add_theme_font_size_override("font_size", 22)
	v.add_child(runs_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	v.add_child(status_label)
	timing_meter = ProgressBar.new()
	timing_meter.min_value = 0.0
	timing_meter.max_value = 100.0
	timing_meter.value = 0.0
	timing_meter.show_percentage = false
	timing_meter.custom_minimum_size = Vector2(300, 14)
	v.add_child(timing_meter)
	var bat_mode := Button.new()
	bat_mode.text = "BAT FIRST (AI BOWLS)"
	bat_mode.position = Vector2(15, 120)
	bat_mode.size = Vector2(320, 54)
	bat_mode.pressed.connect(func(): _start_match("batting"))
	layer.add_child(bat_mode)
	var bowl_mode := Button.new()
	bowl_mode.text = "BOWL FIRST (AI BATS)"
	bowl_mode.position = Vector2(15, 180)
	bowl_mode.size = Vector2(320, 54)
	bowl_mode.pressed.connect(func(): _start_match("bowling"))
	layer.add_child(bowl_mode)
	bowl_button = Button.new()
	bowl_button.text = "BOWL"
	bowl_button.anchor_top = 1.0
	bowl_button.anchor_bottom = 1.0
	bowl_button.position = Vector2(16, -184)
	bowl_button.size = Vector2(150, 64)
	bowl_button.pressed.connect(_bowl)
	layer.add_child(bowl_button)
	defend_button = Button.new()
	defend_button.text = "DEFEND"
	defend_button.anchor_top = 1.0
	defend_button.anchor_bottom = 1.0
	defend_button.position = Vector2(175, -184)
	defend_button.size = Vector2(150, 64)
	defend_button.pressed.connect(func(): _play_shot(0.35))
	layer.add_child(defend_button)
	drive_button = Button.new()
	drive_button.text = "DRIVE"
	drive_button.anchor_top = 1.0
	drive_button.anchor_bottom = 1.0
	drive_button.position = Vector2(16, -108)
	drive_button.size = Vector2(150, 64)
	drive_button.pressed.connect(func(): _play_shot(1.0))
	layer.add_child(drive_button)
	loft_button = Button.new()
	loft_button.text = "LOFT"
	loft_button.anchor_top = 1.0
	loft_button.anchor_bottom = 1.0
	loft_button.position = Vector2(175, -108)
	loft_button.size = Vector2(150, 64)
	loft_button.pressed.connect(func(): _play_shot(1.35))
	layer.add_child(loft_button)
	swap_button = Button.new()
	swap_button.text = "⇄ MOVE CONTROLS"
	swap_button.anchor_left = 1.0
	swap_button.anchor_right = 1.0
	swap_button.anchor_top = 1.0
	swap_button.anchor_bottom = 1.0
	swap_button.position = Vector2(-190, -58)
	swap_button.size = Vector2(174, 44)
	swap_button.pressed.connect(_swap_controls)
	layer.add_child(swap_button)
	run_button = Button.new()
	run_button.text = "RUN +1"
	run_button.anchor_left = 1.0
	run_button.anchor_right = 1.0
	run_button.anchor_top = 1.0
	run_button.anchor_bottom = 1.0
	run_button.position = Vector2(-190, -184)
	run_button.size = Vector2(174, 64)
	run_button.pressed.connect(_attempt_run)
	layer.add_child(run_button)
	_style_hud()
	_set_controls()

func _style_one_button(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.075, 0.13)
	normal.set_corner_radius_all(16)
	normal.set_border_width_all(2)
	normal.border_color = accent
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.07, 0.16, 0.23)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.45)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	button.add_theme_font_size_override("font_size", 16)

func _style_hud() -> void:
	_style_one_button(bowl_button, Color(0.1, 0.68, 0.88))
	_style_one_button(defend_button, Color(0.1, 0.68, 0.88))
	_style_one_button(drive_button, Color(0.1, 0.68, 0.88))
	_style_one_button(loft_button, Color(0.1, 0.68, 0.88))
	_style_one_button(swap_button, Color(0.58, 0.62, 0.72))
	_style_one_button(run_button, Color(0.2, 0.88, 0.45))

func _start_match(mode: String) -> void:
	play_mode = mode
	match_started = true
	score = 0
	wickets = 0
	balls = 0
	delivery_active = false
	auto_delivery_timer = 1.2
	completed_runs_this_ball = 0
	shot_boundary_done = false
	run_in_progress = false
	if is_instance_valid(run_button):
		run_button.disabled = true
	_reset_batter_to_crease()
	_reset_fielders()
	_set_controls()
	_update_score()
	_show_status("YOU BAT • AI BOWLS AUTOMATICALLY" if mode == "batting" else "YOU BOWL • AI BATTER PLAYS AUTOMATICALLY")

func _set_controls() -> void:
	if not is_instance_valid(bowl_button):
		return
	bowl_button.visible = match_started and play_mode == "bowling"
	defend_button.visible = match_started and play_mode == "batting"
	drive_button.visible = match_started and play_mode == "batting"
	loft_button.visible = match_started and play_mode == "batting"
	swap_button.visible = match_started
	_apply_control_layout()

func _attempt_run() -> void:
	if not match_started or play_mode != "batting" or not delivery_active or ball_state != "shot" or shot_boundary_done:
		_show_status("RUN only after you play a shot")
		return
	if run_in_progress:
		return
	if completed_runs_this_ball >= 3:
		_show_status("Maximum runs reached for this shot")
		return
	run_in_progress = true
	run_timer = 0.0
	run_start_z = batter.position.z if is_instance_valid(batter) else 7.2
	run_target_z = -7.2 if run_start_z > 0.0 else 7.2
	run_button.disabled = true
	_show_status("RUNNING! Tap again after reaching the crease")

func _swap_controls() -> void:
	controls_swapped = not controls_swapped
	_apply_control_layout()
	_show_status("Controls position changed")

func _apply_control_layout() -> void:
	if not is_instance_valid(defend_button):
		return
	var left_x := 16.0 if not controls_swapped else 390.0
	var right_x := 175.0 if not controls_swapped else 549.0
	bowl_button.position.x = left_x
	defend_button.position.x = left_x
	drive_button.position.x = right_x
	loft_button.position.x = right_x

func _bowl() -> void:
	if not match_started or play_mode != "bowling":
		_show_status("Choose BOWL FIRST. In batting mode, AI bowls automatically.")
		return
	if delivery_active:
		return
	if balls >= 6:
		balls = 0
		_show_status("New over started")
	_update_score()
	_spawn_ball()
	delivery_active = true
	hit_done = false
	delivery_timer = 0.0
	_show_status("Your delivery! AI batter will play automatically.")
func _spawn_ball() -> void:
	if is_instance_valid(ball):
		ball.queue_free()
	ball = Node3D.new()
	ball.name = "CricketBall"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.06, 0.045)
	mat.roughness = 0.32
	mat.metallic = 0.05
	mesh.material_override = mat
	ball.add_child(mesh)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.12, 0.08)
	glow.light_energy = 0.12
	glow.omni_range = 0.7
	ball.add_child(glow)
	delivery_full_toss = randf() < 0.18
	delivery_bounced = false
	_reset_batter_to_crease()
	_reset_fielders()
	var speed_roll: float = randf()
	if speed_roll < 0.12:
		delivery_speed = randf_range(17.0, 19.5)
		delivery_speed_name = "EXPRESS"
	elif speed_roll < 0.38:
		delivery_speed = randf_range(14.0, 16.5)
		delivery_speed_name = "FAST"
	elif speed_roll < 0.82:
		delivery_speed = randf_range(10.8, 13.2)
		delivery_speed_name = "MEDIUM"
	else:
		delivery_speed = randf_range(8.0, 10.0)
		delivery_speed_name = "SLOW"
	ball.position = Vector3(randf_range(-0.12, 0.12), 2.0, -8.2)
	add_child(ball)
	ball_velocity = Vector3(randf_range(-0.12, 0.12), 4.8 if delivery_full_toss else -0.8, delivery_speed)
	_show_status("%s DELIVERY%s" % [delivery_speed_name, " • FULL TOSS" if delivery_full_toss else ""])
	ball_state = "delivery"
	ball_bounced = false
	active_fielder = null
	fielder_chasing = false
	fielder_has_ball = false
	delivery_timer = 0.0
	completed_runs_this_ball = 0
	shot_boundary_done = false
	run_in_progress = false
	if is_instance_valid(run_button):
		run_button.disabled = true

func _play_shot(power: float) -> void:
	if not match_started or play_mode != "batting":
		_show_status("Batting controls are available in BAT FIRST mode")
		return
	if not delivery_active or hit_done or not is_instance_valid(ball) or ball_state != "delivery":
		_show_status("Wait for the incoming ball")
		return
	var contact_z := 5.95
	var timing_error: float = absf(ball.position.z - contact_z)
	if timing_error > 2.55:
		_show_status("Too early — watch the ball and tap near the batter")
		return
	hit_done = true
	var timing_quality: float = clampf(1.0 - timing_error / 2.55, 0.0, 1.0)
	shot_power = power
	ball_state = "shot"
	completed_runs_this_ball = 0
	shot_boundary_done = false
	if is_instance_valid(run_button):
		run_button.disabled = false
	var hit_direction := -1.0 if randf() < 0.72 else 1.0
	ball_velocity = Vector3(randf_range(-5.0, 5.0), 4.0 + power * 3.0, hit_direction * (8.0 + power * 3.0))
	if timing_quality > 0.78:
		_show_status("PERFECT CONTACT! RUN OR WATCH THE BOUNDARY")
	elif timing_quality > 0.45:
		_show_status("GOOD SHOT! RUN OR WATCH THE BOUNDARY")
	else:
		_show_status("EDGED! BALL IN PLAY")
	_animate_bat_swing()
	_update_score()

func _animate_bat_swing() -> void:
	if not is_instance_valid(batter):
		return
	var bat_blade := batter.get_node_or_null("Bat_Blade") as Node3D
	if bat_blade == null:
		return
	var tween := create_tween()
	tween.tween_property(bat_blade, "rotation_degrees", Vector3(0, 0, -82), 0.10)
	tween.tween_property(bat_blade, "rotation_degrees", Vector3(0, 0, -12), 0.22)

func _finish_delivery(message: String = "") -> void:
	delivery_active = false
	run_in_progress = false
	balls += 1
	if message != "":
		_show_status(message)
	_reset_batter_to_crease()
	_reset_fielders()
	if is_instance_valid(ball):
		ball.queue_free()
	auto_delivery_timer = 1.7
	_update_score()

func _reset_batter_to_crease() -> void:
	if is_instance_valid(batter):
		batter.position = Vector3(0.75, 0.0, 7.2)
		batter.rotation = Vector3.ZERO

func _reset_fielders() -> void:
	for i in range(fielder_nodes.size()):
		var fielder: Node3D = fielder_nodes[i]
		if is_instance_valid(fielder) and i < fielder_home_positions.size():
			fielder.position = fielder_home_positions[i]
			fielder.rotation = Vector3.ZERO
	active_fielder = null
	fielder_chasing = false
	fielder_has_ball = false

func _process(delta: float) -> void:
	if not match_started:
		return
	if wickets >= MAX_WICKETS or balls >= MAX_BALLS:
		match_started = false
		_set_controls()
		_show_status("INNINGS COMPLETE • FINAL SCORE %d/%d" % [score, wickets])
		return
	if play_mode == "batting" and not delivery_active:
		auto_delivery_timer -= delta
		if auto_delivery_timer <= 0.0:
			if balls >= 6:
				balls = 0
				_show_status("New over • AI bowling")
			_spawn_ball()
			delivery_active = true
			hit_done = false
			_show_status("AI bowling! Tap DEFEND, DRIVE or LOFT as the ball reaches you")
	if not delivery_active or not is_instance_valid(ball):
		return

	delivery_timer += delta
	if is_instance_valid(timing_meter):
		timing_meter.visible = play_mode == "batting" and ball_state == "delivery"
		if timing_meter.visible:
			timing_meter.value = clampf((ball.position.z - 2.8) / 4.5 * 100.0, 0.0, 100.0)
	# Manual ball simulation keeps the ball visible and predictable on mobile.
	ball_velocity.y -= 7.2 * delta
	ball.position += ball_velocity * delta
	if run_in_progress:
		run_timer += delta
		var run_progress: float = clampf(run_timer / RUN_DURATION, 0.0, 1.0)
		if is_instance_valid(batter):
			batter.position.z = lerpf(run_start_z, run_target_z, run_progress)
			batter.rotation_degrees.y = 180.0 if run_start_z > 0.0 else 0.0
		if run_progress >= 1.0:
			run_in_progress = false
			completed_runs_this_ball += 1
			score += 1
			_update_score()
			if is_instance_valid(run_button):
				run_button.disabled = false
			_show_status("SAFE! %d run(s) completed — press RUN again" % completed_runs_this_ball)

	# Bowling trajectory: most deliveries pitch once, occasional full tosses do not.
	if ball_state == "delivery" and not delivery_full_toss and not delivery_bounced and ball.position.z >= -1.4 and ball.position.y <= 0.22:
		ball.position.y = 0.16
		ball_velocity.y = 3.35
		ball_velocity.z *= 0.94
		delivery_bounced = true
		ball_bounced = true
	elif ball_state == "delivery" and delivery_bounced and ball.position.y <= 0.13 and ball_velocity.y < 0.0:
		ball.position.y = 0.13
		ball_velocity.y = 0.0

	# AI batter reacts at the same contact point used by the player's bat.
	if play_mode == "bowling" and ball_state == "delivery" and not hit_done and ball.position.z >= 5.65:
		hit_done = true
		if randf() < 0.22:
			wickets += 1
			_show_status("BEATEN! AI BATTER MISSED — WICKET!")
			ball_state = "delivery"
		else:
			var ai_runs: int = [0, 1, 2, 4][randi_range(0, 3)]
			score += ai_runs
			_show_status("AI BATTER SCORES %d" % ai_runs)
			ball_state = "shot"
			ball_velocity = Vector3(randf_range(-4.5, 4.5), 4.0 + randf_range(0.0, 2.5), -randf_range(7.0, 12.0))
		_update_score()

	# If the player misses a straight delivery, the ball reaches the stumps.
	if play_mode == "batting" and ball_state == "delivery" and not hit_done and ball.position.z >= 7.55:
		hit_done = true
		if absf(ball.position.x) < 0.52 and ball.position.y < 1.25:
			wickets += 1
			_show_status("BOWLED! Watch the line and timing.")
		else:
			_show_status("BEATEN! Dot ball.")
		_update_score()

	# One selected fielder attacks the ball, fields it once, then holds possession.
	if ball_state == "shot" and is_instance_valid(ball) and not shot_boundary_done and not fielder_has_ball:
		if not fielder_chasing and fielder_nodes.size() > 0:
			var nearest_distance: float = INF
			for candidate in fielder_nodes:
				if not is_instance_valid(candidate):
					continue
				var d: float = Vector2(candidate.position.x - ball.position.x, candidate.position.z - ball.position.z).length()
				if d < nearest_distance:
					nearest_distance = d
					active_fielder = candidate
			fielder_chasing = active_fielder != null
		if is_instance_valid(active_fielder):
			var horizontal_target := Vector3(ball.position.x, 0.0, ball.position.z)
			var to_ball := horizontal_target - active_fielder.position
			to_ball.y = 0.0
			var distance_to_ball: float = to_ball.length()
			# Catch only when the falling ball is physically within reach.
			var catch_distance: float = Vector3(active_fielder.position.x, active_fielder.position.y + 1.45, active_fielder.position.z).distance_to(ball.position)
			if ball.position.y > 1.0 and ball.position.y < 3.6 and ball_velocity.y < 0.0 and catch_distance < 0.95:
				wickets += 1
				_show_status("CAUGHT! Clean catch by the fielder")
				_finish_delivery()
				return
			if distance_to_ball > 0.8:
				var step: float = minf(7.0 * delta, distance_to_ball - 0.72)
				active_fielder.position += to_ball.normalized() * step
				active_fielder.rotation.y = atan2(to_ball.x, to_ball.z)
			elif ball.position.y <= 0.32:
				# Ball is gathered at ground level; no more chasing or teleporting.
				ball.position.y = 0.16
				ball_velocity = Vector3.ZERO
				fielder_has_ball = true
				_show_status("FIELDING! Ball gathered — fielder has it")

	# Hit ball: one ground contact, then controlled roll.
	if ball_state == "shot":
		if ball.position.y <= 0.14:
			ball.position.y = 0.14
			if ball_velocity.y < -1.0:
				ball_velocity.y = 0.0
			ball_velocity.x *= 0.992
			ball_velocity.z *= 0.992
		if not shot_boundary_done and (pow(ball.position.x / 15.7, 2.0) + pow(ball.position.z / 21.0, 2.0) >= 1.0):
			shot_boundary_done = true
			run_in_progress = false
			# Boundary replaces any runs attempted on the same delivery.
			score = maxi(0, score - completed_runs_this_ball)
			completed_runs_this_ball = 0
			var is_six: bool = ball.position.y > 1.35 and shot_power >= 1.0
			var boundary_runs: int = 6 if is_six else 4
			score += boundary_runs
			_show_status("SIX! +6" if is_six else "FOUR! +4")
			_update_score()
			_finish_delivery()
			return
		if fielder_has_ball or ball_velocity.length() < 1.15 or delivery_timer > 6.0:
			run_in_progress = false
			if is_instance_valid(run_button):
				run_button.disabled = true
			_finish_delivery("BALL STOPPED — %d run(s)" % completed_runs_this_ball)
			return

	if ball_state == "delivery" and (ball.position.z > 9.8 or ball.position.y < -1.0 or delivery_timer > 4.2):
		_finish_delivery("DELIVERY COMPLETE — NEXT BALL")

func _update_score() -> void:
	if is_instance_valid(runs_label):
		runs_label.text = "CRICVERSE   %d/%d   •   %d.%d / 20 overs" % [score, wickets, int(balls / 6), balls % 6]

func _show_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
