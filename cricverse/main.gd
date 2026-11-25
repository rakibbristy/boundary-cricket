extends Node3D

var ball: RigidBody3D
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

func _ready() -> void:
	_build_world()
	_build_hud()
	_update_score()
	_show_status("Choose BAT FIRST or BOWL FIRST")

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.9)
	environment.ambient_light_energy = 0.7
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48.0
	add_child(sun)

	var ground := _make_box("Ground", Vector3(0, -0.35, 0), Vector3(32, 0.5, 44), Color(0.10, 0.34, 0.16))
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
	_make_box("Boundary North", Vector3(0, 0.05, -20), Vector3(32, 0.1, 0.18), Color.WHITE)
	_make_box("Boundary South", Vector3(0, 0.05, 20), Vector3(32, 0.1, 0.18), Color.WHITE)
	make_batter()
	make_bowler()
	camera = Camera3D.new()
	camera.position = Vector3(0, 8.2, 16.5)
	camera.rotation_degrees = Vector3(-19, 0, 0)
	camera.current = true
	add_child(camera)

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

func make_batter() -> void:
	batter = Node3D.new()
	batter.name = "Batter_3D"
	batter.position = Vector3(0.75, 0, 7.2)
	add_child(batter)
	if _load_rigged_character("res://assets/players/batter.gltf", batter):
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
	if _load_rigged_character("res://assets/players/bowler.gltf", bowler):
		_add_fielder(Vector3(-9, 0, -5), Color(0.9, 0.58, 0.08))
		_add_fielder(Vector3(8, 0, -4), Color(0.9, 0.58, 0.08))
		_add_fielder(Vector3(-10, 0, 7), Color(0.9, 0.58, 0.08))
		_add_fielder(Vector3(10, 0, 8), Color(0.9, 0.58, 0.08))
		_add_stadium()
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
	_add_stadium()

func _add_fielder(pos: Vector3, shirt: Color) -> void:
	var fielder := Node3D.new()
	fielder.position = pos
	add_child(fielder)
	if _load_rigged_character("res://assets/players/fielder.gltf", fielder):
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
	panel.size = Vector2(340, 92)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	runs_label = Label.new()
	runs_label.add_theme_font_size_override("font_size", 22)
	v.add_child(runs_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	v.add_child(status_label)
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
	_set_controls()

func _start_match(mode: String) -> void:
	play_mode = mode
	match_started = true
	score = 0
	wickets = 0
	balls = 0
	delivery_active = false
	auto_delivery_timer = 1.2
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
	ball = RigidBody3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.08, 0.07)
	mesh.material_override = mat
	ball.add_child(mesh)
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.12
	shape.shape = sphere_shape
	ball.add_child(shape)
	ball.position = Vector3(randf_range(-0.35, 0.35), 1.05, -8.2)
	ball.gravity_scale = 0.18
	add_child(ball)
	ball.linear_velocity = Vector3(randf_range(-0.22, 0.22), -0.05, 6.2)

func _play_shot(power: float) -> void:
	if not match_started or play_mode != "batting":
		_show_status("Batting controls are available in BAT FIRST mode")
		return
	if not delivery_active or hit_done or not is_instance_valid(ball):
		_show_status("Wait for the ball, then play your shot")
		return
	var distance_to_contact: float = absf(ball.position.z - 5.7)
	if distance_to_contact <= 3.15:
		hit_done = true
		var timing_quality: float = clampf(1.0 - distance_to_contact / 3.15, 0.0, 1.0)
		var runs := 0
		if power > 1.2:
			if timing_quality > 0.72:
				runs = 6 if randf() < 0.48 else 4
			elif timing_quality > 0.35:
				runs = 4 if randf() < 0.42 else 2
			else:
				runs = 1 if randf() < 0.55 else 0
		elif power > 0.8:
			if timing_quality > 0.65:
				runs = 4 if randf() < 0.48 else 2
			elif timing_quality > 0.25:
				runs = 2 if randf() < 0.55 else 1
			else:
				runs = 0 if randf() < 0.35 else 1
		else:
			runs = 1 if timing_quality > 0.25 and randf() < 0.8 else 0
		score += runs
		_show_status(("PERFECT TIMING! " if timing_quality > 0.72 else "SHOT PLAYED! ") + "+%d RUNS" % runs)
		ball.freeze = true
		ball.linear_velocity = Vector3(randf_range(-4.5, 4.5), 3.0 + 3.0 * power, -randf_range(5.0, 10.0))
	else:
		hit_done = true
		_show_status("Too early/late — dot ball, try again!")
		if distance_to_contact < 4.2 and randf() < 0.06:
			wickets += 1
			_show_status("BOWLED! WICKET")
	_update_score()
	delivery_active = false
	balls += 1
	auto_delivery_timer = 1.8

func _process(delta: float) -> void:
	if not match_started:
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
			delivery_timer = 0.0
			_show_status("AI bowling! Choose DEFEND, DRIVE or LOFT")
	if delivery_active:
		delivery_timer += delta
		if is_instance_valid(ball):
			if play_mode == "bowling" and not hit_done and ball.position.z > 4.8:
				hit_done = true
				var ai_runs: int = [0, 1, 2, 4, 6][randi_range(0, 4)]
				if ai_runs == 0 and randf() < 0.4:
					wickets += 1
					_show_status("AI BATTER OUT!")
				else:
					score += ai_runs
					_show_status("AI scored %d runs" % ai_runs)
				ball.freeze = true
				_update_score()
			if ball.position.z > 10 or ball.position.y < -2 or delivery_timer > 4.5:
				delivery_active = false
				balls += 1
				if not hit_done:
					balls += 1
					_show_status("DOT BALL — no wicket")
				_update_score()
				if play_mode == "batting":
					auto_delivery_timer = 1.8
func _update_score() -> void:
	if is_instance_valid(runs_label):
		runs_label.text = "CRICVERSE   %d/%d   •   %d.%d overs" % [score, wickets, int(balls / 6), balls % 6]

func _show_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
