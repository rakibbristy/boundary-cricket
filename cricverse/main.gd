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
	add_child(sun)

	_make_box("Ground", Vector3(0, -0.35, 0), Vector3(32, 0.5, 44), Color(0.12, 0.38, 0.19))
	_make_box("Pitch", Vector3(0, -0.04, 0), Vector3(3.2, 0.12, 22), Color(0.67, 0.48, 0.29))
	for z in [-8.8, 8.8]:
		_make_box("Crease", Vector3(0, 0.04, z), Vector3(3.4, 0.035, 0.12), Color.WHITE)
		for x in [-0.35, 0, 0.35]:
			_make_box("Stump", Vector3(x, 0.55, z), Vector3(0.09, 1.05, 0.09), Color(0.92, 0.86, 0.68))
	_make_box("Boundary North", Vector3(0, 0.05, -20), Vector3(32, 0.1, 0.18), Color.WHITE)
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

func make_batter() -> void:
	batter = Node3D.new()
	batter.name = "Batter_3D"
	batter.position = Vector3(0.75, 0, 7.2)
	add_child(batter)
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
	_capsule(fielder, Vector3(0, 1.0, 0), 0.2, 0.68, shirt)
	_sphere(fielder, Vector3(0, 1.52, 0), 0.16, Color(0.55, 0.34, 0.23))
	_capsule(fielder, Vector3(-0.12, 0.42, 0), 0.065, 0.65, Color(0.12, 0.12, 0.15))
	_capsule(fielder, Vector3(0.12, 0.42, 0), 0.065, 0.65, Color(0.12, 0.12, 0.15))
	_capsule(fielder, Vector3(-0.25, 1.0, 0), 0.055, 0.48, shirt, Vector3(0, 0, -20))
	_capsule(fielder, Vector3(0.25, 1.0, 0), 0.055, 0.48, shirt, Vector3(0, 0, 20))

func _add_stadium() -> void:
	# Curved-feel seating banks, boundary boards and floodlight towers
	for side in [-1, 1]:
		_make_box("Stand_Base", Vector3(side * 15.0, 1.2, 0), Vector3(2.2, 2.4, 35), Color(0.12, 0.16, 0.24))
		for row in range(4):
			_make_box("Stand_Seat", Vector3(side * (14.0 + row * 0.45), 2.1 + row * 0.55, 0), Vector3(1.2, 0.22, 34), [Color(0.12,0.32,0.72), Color(0.9,0.2,0.16), Color(0.92,0.78,0.18), Color(0.12,0.55,0.32)][row])
	for x in [-14.5, 14.5]:
		for z in [-15, 15]:
			_make_box("Floodlight_Pole", Vector3(x, 8, z), Vector3(0.22, 16, 0.22), Color(0.38, 0.42, 0.48))
			_make_box("Floodlight_Array", Vector3(x, 16.1, z), Vector3(1.8, 0.45, 0.8), Color(0.92, 0.95, 1.0))
	for z in [-19.5, 19.5]:
		_make_box("Boundary_Board", Vector3(0, 0.42, z), Vector3(30, 0.8, 0.25), Color(0.04, 0.25, 0.38))

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
	bowl_button.position = Vector2(15, 250)
	bowl_button.size = Vector2(150, 64)
	bowl_button.pressed.connect(_bowl)
	layer.add_child(bowl_button)
	defend_button = Button.new()
	defend_button.text = "DEFEND"
	defend_button.position = Vector2(175, 250)
	defend_button.size = Vector2(150, 64)
	defend_button.pressed.connect(func(): _play_shot(0.35))
	layer.add_child(defend_button)
	drive_button = Button.new()
	drive_button.text = "DRIVE"
	drive_button.position = Vector2(15, 324)
	drive_button.size = Vector2(150, 64)
	drive_button.pressed.connect(func(): _play_shot(1.0))
	layer.add_child(drive_button)
	loft_button = Button.new()
	loft_button.text = "LOFT"
	loft_button.position = Vector2(175, 324)
	loft_button.size = Vector2(150, 64)
	loft_button.pressed.connect(func(): _play_shot(1.35))
	layer.add_child(loft_button)
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
	ball.position = Vector3(randf_range(-0.55, 0.55), 1.1, -8.2)
	ball.gravity_scale = 0.35
	add_child(ball)
	ball.linear_velocity = Vector3(randf_range(-0.4, 0.4), -0.1, 8.5)

func _play_shot(power: float) -> void:
	if not match_started or play_mode != "batting":
		_show_status("Batting controls are available in BAT FIRST mode")
		return
	if not delivery_active or hit_done or not is_instance_valid(ball):
		_show_status("Wait for the delivery, then choose your shot")
		return
	var timing: float = absf(ball.position.z - 5.6)
	hit_done = true
	if timing < 1.8:
		var runs := 0
		if power > 1.2:
			runs = 6 if randf() > 0.35 else 4
		elif power > 0.8:
			runs = 4 if randf() > 0.3 else 2
		else:
			runs = 1 if randf() > 0.5 else 0
		score += runs
		_show_status("GOOD SHOT! +%d RUNS" % runs)
		ball.freeze = true
		ball.linear_velocity = Vector3(randf_range(-5, 5), 5.0 * power, -randf_range(7, 12))
	else:
		_show_status("Missed timing")
		if timing > 3.0:
			wickets += 1
			_show_status("OUT! Wicket lost")
	_update_score()
	delivery_active = false
	balls += 1
	auto_delivery_timer = 1.4
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
			if ball.position.z > 10 or ball.position.y < -2 or delivery_timer > 4.0:
				delivery_active = false
				balls += 1
				if not hit_done:
					_show_status("DOT BALL")
				_update_score()
				if play_mode == "batting":
					auto_delivery_timer = 1.4
func _update_score() -> void:
	if is_instance_valid(runs_label):
		runs_label.text = "CRICVERSE   %d/%d   •   %d.%d overs" % [score, wickets, int(balls / 6), balls % 6]

func _show_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
