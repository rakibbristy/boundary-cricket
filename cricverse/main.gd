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

func _ready() -> void:
	_build_world()
	_build_hud()
	_update_score()
	_show_status("CRICVERSE • Tap BOWL to start")

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

func make_batter() -> void:
	batter = Node3D.new()
	batter.position = Vector3(0.75, 0, 7.2)
	add_child(batter)
	_make_character_part(batter, Vector3(0, 1.0, 0), Vector3(0.55, 0.85, 0.32), Color(0.12, 0.25, 0.78))
	_make_character_part(batter, Vector3(0, 1.72, 0), Vector3(0.42, 0.42, 0.38), Color(0.72, 0.48, 0.32))
	_make_character_part(batter, Vector3(0.36, 0.88, -0.08), Vector3(0.12, 0.85, 0.12), Color(0.78, 0.78, 0.8))
	_make_character_part(batter, Vector3(-0.25, 0.88, 0.08), Vector3(0.12, 0.85, 0.12), Color(0.78, 0.78, 0.8))
	_make_character_part(batter, Vector3(0.42, 0.93, -0.48), Vector3(0.13, 0.85, 0.13), Color(0.72, 0.48, 0.32))
	_make_character_part(batter, Vector3(0.52, 0.58, -0.8), Vector3(0.16, 1.15, 0.12), Color(0.72, 0.48, 0.32))

func _make_character_part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	parent.add_child(m)

func make_bowler() -> void:
	var bowler := Node3D.new()
	bowler.position = Vector3(0, 0, -7.5)
	add_child(bowler)
	_make_character_part(bowler, Vector3(0, 1.0, 0), Vector3(0.52, 0.9, 0.32), Color(0.82, 0.18, 0.12))
	_make_character_part(bowler, Vector3(0, 1.72, 0), Vector3(0.4, 0.4, 0.38), Color(0.65, 0.42, 0.28))
	_make_character_part(bowler, Vector3(-0.2, 0.42, 0), Vector3(0.13, 0.8, 0.13), Color(0.15, 0.15, 0.18))
	_make_character_part(bowler, Vector3(0.2, 0.42, 0), Vector3(0.13, 0.8, 0.13), Color(0.15, 0.15, 0.18))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(330, 86)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	runs_label = Label.new()
	runs_label.add_theme_font_size_override("font_size", 22)
	v.add_child(runs_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	v.add_child(status_label)

	var bowl := Button.new()
	bowl.text = "BOWL"
	bowl.position = Vector2(18, 125)
	bowl.size = Vector2(145, 62)
	bowl.add_theme_font_size_override("font_size", 22)
	bowl.pressed.connect(_bowl)
	layer.add_child(bowl)
	var defend := Button.new()
	defend.text = "DEFEND"
	defend.position = Vector2(174, 125)
	defend.size = Vector2(145, 62)
	defend.pressed.connect(func(): _play_shot(0.35))
	layer.add_child(defend)
	var drive := Button.new()
	drive.text = "DRIVE"
	drive.position = Vector2(18, 198)
	drive.size = Vector2(145, 62)
	drive.add_theme_font_size_override("font_size", 20)
	drive.pressed.connect(func(): _play_shot(1.0))
	layer.add_child(drive)
	var loft := Button.new()
	loft.text = "LOFT"
	loft.position = Vector2(174, 198)
	loft.size = Vector2(145, 62)
	loft.add_theme_font_size_override("font_size", 20)
	loft.pressed.connect(func(): _play_shot(1.35))
	layer.add_child(loft)

func _bowl() -> void:
	if delivery_active:
		return
	if balls >= 6:
		_show_status("Over complete! Tap BOWL to start next over")
		balls = 0
	_update_score()
	_spawn_ball()
	delivery_active = true
	hit_done = false
	delivery_timer = 0.0
	_show_status("Ball coming... time your shot!")

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
	if not delivery_active or hit_done or not is_instance_valid(ball):
		_show_status("Tap BOWL first")
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
		_show_status("PERFECT TIMING!  +%d RUNS" % runs)
		ball.freeze = true
		ball.linear_velocity = Vector3(randf_range(-5, 5), 5.0 * power, -randf_range(7, 12))
	else:
		_show_status("Too early / late! Missed the ball")
		if timing > 3.0:
			wickets += 1
			_show_status("OUT! Wicket lost")
	_update_score()
	delivery_active = false
	balls += 1

func _process(delta: float) -> void:
	if delivery_active:
		delivery_timer += delta
		if is_instance_valid(ball):
			if ball.position.z > 10 or ball.position.y < -2 or delivery_timer > 4.0:
				delivery_active = false
				if not hit_done:
					wickets += 1
					balls += 1
					_show_status("WICKET! You missed the delivery")
					_update_score()

func _update_score() -> void:
	if is_instance_valid(runs_label):
		runs_label.text = "CRICVERSE   %d/%d   •   %d.%d overs" % [score, wickets, int(balls / 6), balls % 6]

func _show_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
