extends Node2D

var save_timer = 0.0
var save_path = "user://pet.cfg"

var fade_tween: Tween
@onready var cartel = $Cartel
var hovering = false
var tag_tween: Tween

var light_timer = 0.0
@onready var light = $AnimatedSprite2D/PointLight2D

var speed = 100
var direction = Vector2(1, 0)
var screen_size = Vector2()
var window_size = Vector2(140, 250)


enum State {WALK, IDLE, SLEEP, CHASE, FISH, DRAGGED, FALL}
var state = State.WALK

var fish: Window = null
var fish_pos = Vector2()

@export var fish_texture: Texture2D
@export var heart_texture: Texture2D
var fish_fall = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var area = $Area2D

var menu: PopupMenu
@export var menu_font: Font

var idle_timer =0.0
var drag_offset = Vector2()
var sleep_timer = 150.0
var inactivity = 0.0

var fall_speed = 0.0
var gravity = 1500.0
var floor_y = 0.0

var chase_cooldown = randf_range(10.0, 25.0)

@onready var meow = $AudioStreamPlayer2D
var press_pos = Vector2()

func _on_area_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if state != State.DRAGGED:
			inactivity = 0.0
			open_menu()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		inactivity = 0.0
		if state == State.SLEEP:
			change_state(State.WALK)
			return
		if state == State.DRAGGED:
			return
		drag_offset = get_global_mouse_position() - position
		press_pos = get_global_mouse_position()
		change_state(State.DRAGGED)

func _input(event):
	if event is InputEventKey and not event.echo and event.pressed  and event.keycode == KEY_F:
		spawn_fish()
		return
	if state != State.DRAGGED:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		inactivity = 0.0
		if get_global_mouse_position().distance_to(press_pos) < 15:
			play_meow()
			spawn_hearts(get_global_mouse_position())
		change_state(State.FALL)
	elif event is InputEventMouseMotion:
		position = get_global_mouse_position() - drag_offset
		var h = window_size / 2
		position.x = clamp(position.x, h.x, screen_size.x - h.x)
		position.y = clamp(position.y, h.y, floor_y)
		sprite.rotation = clamp(event.relative.x * 0.05, -0.5, 0.5)
		
func _ready() -> void:
	setup_menu()
	get_viewport().gui_embed_subwindows = false
	floor_y = DisplayServer.screen_get_usable_rect().end.y - window_size.y / 2 + 65
	var win = get_window()
	area.input_event.connect(_on_area_input)
	win.borderless = true
	win.transparent = true
	get_viewport().transparent_bg = true
	win.position = Vector2i.ZERO
	position = Vector2(300, 300)
	var s = DisplayServer.screen_get_size()
	win.size = Vector2i(s.x, s.y - 1)
	await get_tree().process_frame  
	screen_size = get_viewport_rect().size  
	load_data()
	update_light()
	position.y = floor_y
	change_state(State.SLEEP)
	await get_tree().process_frame
	win.always_on_top = true
	area.mouse_entered.connect(_on_hover.bind(true))
	area.mouse_exited.connect(_on_hover.bind(false))
	
	
func _physics_process(delta: float) -> void:
	if screen_size == Vector2.ZERO:
		return
	var fish_floor = floor_y + window_size.y / 2 -80
	if fish != null and fish_pos.y < fish_floor:
		fish_fall += gravity * delta
		fish_pos.y = min(fish_pos.y + fish_fall * delta, fish_floor)
		fish.position = Vector2i(fish_pos - Vector2(fish.size)/2)
	
	match state:
		State.WALK, State.CHASE, State.IDLE:
			inactivity += delta
			if inactivity >= sleep_timer:
				change_state(State.SLEEP)
				return
			if fish != null:
				change_state(State.FISH)
				return
			if state == State.IDLE:
				idle_timer -= delta
				if idle_timer <= 0:
					change_state(State.WALK)
			elif state == State.CHASE:
				var dx = get_global_mouse_position().x - position.x
				if abs(dx) < 6 or abs(dx) > 800:
					end_chase()
					return
				face(sign(dx))
				if move_x(delta):
					end_chase()
			else:
				chase_cooldown -= delta
				if chase_cooldown <= 0:
					change_state(State.CHASE)
					return
				if move_x(delta):
					face(-direction.x)
					change_state(State.IDLE if randf() < 0.5 else State.WALK)
				
		State.FISH:
			if fish == null:
				change_state(State.WALK)
				return
			var dx = fish_pos.x - position.x
			if abs(dx) < 40 and fish_pos.y >= floor_y + window_size.y / 2 -21:
				spawn_hearts(fish_pos)
				fish.queue_free()
				fish = null
				inactivity = 0.0
				change_state(State.IDLE)
				return
			face(sign(dx))
			move_x(delta)

		State.FALL:
			fall_speed += gravity * delta
			position.y = min(position.y + fall_speed * delta, floor_y)
			if position.y >= floor_y:
				change_state(State.FISH if fish != null else State.WALK)

func _process(delta: float) -> void:
	sprite.rotation = lerp(sprite.rotation, 0.0, 10 * delta)
	if screen_size == Vector2.ZERO:
		return
	save_timer += delta
	if save_timer >= 5.0:
		save_timer = 0.0
		if state != State.DRAGGED:
			save_data()
	light_timer += delta
	if light_timer >= 60.0:
		light_timer = 0.0
		update_light()
	var poly: PackedVector2Array
	if state == State.DRAGGED:
		poly = PackedVector2Array([Vector2.ZERO, Vector2(screen_size.x, 0), screen_size, Vector2(0, screen_size.y)])
	else:
		var h = window_size / 2
		poly = PackedVector2Array([
			position + Vector2(-h.x, -h.y), position + Vector2(h.x, -h.y),
			position + Vector2(h.x, h.y), position + Vector2(-h.x, h.y),
		])
	get_window().mouse_passthrough_polygon = poly


func spawn_hearts(pos: Vector2):
	for i in randi_range(4, 8):
		var start = pos + Vector2(randf_range(-30, 30), -40)
		var w = make_fx_window(heart_texture, 3.0, start)
		if w == null:
			return
		var y0 = float(w.position.y)
		var t = create_tween().set_parallel(true)
		t.tween_method(func(v): w.position.y = int(v), y0, y0 - randf_range(120, 200), 1.5)
		t.tween_property(w.get_child(0), "modulate:a", 0.0, 1.5)
		t.finished.connect(w.queue_free)
		await get_tree().create_timer(0.1).timeout
	
func make_fx_window(tex: Texture2D, scale_f: float, center: Vector2) -> Window:
	if tex == null:
		return null
	var w = Window.new()
	w.borderless = true
	w.transparent = true
	w.transparent_bg = true
	w.always_on_top = true
	w.unfocusable = true
	w.size = Vector2i(tex.get_size() * scale_f)
	w.position = Vector2i(center - Vector2(w.size) / 2)
	w.mouse_passthrough= true
	var s = Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(scale_f, scale_f)
	s.position = Vector2(w.size) / 2
	w.add_child(s)
	add_child(w)
	return w

func spawn_fish():
	if fish != null:
		return
	var p = get_global_mouse_position()
	var h = window_size / 2
	p.x = clamp(p.x, h.x + 40, screen_size.x - h.x - 40)
	if abs(p.x - position.x) < 150:
		var side = 1 if p.x >= position.x else -1
		p.x = clamp(position.x + side * 250, h.x + 40, screen_size.x - h.x - 40)
	fish_pos = p
	fish_fall = 0.0
	fish = make_fx_window(fish_texture, 1.0, p)
	inactivity = 0.0
	if state != State.DRAGGED and state != State.FALL:
		change_state(State.FISH)

func fade_sprite(to: Color, time:= 1.0):
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(sprite, "modulate", to, time)

func play_meow():
	meow.pitch_scale = randf_range(0.9, 1.6)
	meow.volume_db = randf_range(-4.0, 0.0)
	meow.play()
	
func end_chase():
	chase_cooldown = randf_range(10.0, 25.0)
	change_state(State.IDLE)
	
func change_state(new_state):
	if new_state == state:
		return
	if state == State.SLEEP:
		fade_sprite(Color.WHITE, 0.4)
	state = new_state
	match new_state:
		State.WALK:
			speed = randf_range(80, 120)
			sprite.play("walk")
		State.IDLE:
			speed = 0
			idle_timer = randf_range(2.0, 4.0)
			sprite.play("idle")
		State.SLEEP:
			speed = 0
			sprite.play("sleep")
			fade_sprite(Color(0.75, 0.75, 1.0, 0.7))
		State.CHASE:
			speed = 140
			sprite.play("walk")
		State.FISH:
			sprite.play("walk")
			speed = 100
		State.DRAGGED:
			sprite.stop()
			cartel.modulate.a = 0.0
		State.FALL:
			fall_speed = 0.0
			sprite.play("fall")
			
func face(dir):
	if dir == 0:
		return
	direction.x = dir
	sprite.flip_h = dir < 0
	
func move_x(delta) -> bool:
	var h = window_size / 2
	position.x = clamp(position.x + direction.x * speed * delta, h.x, screen_size.x - h.x)
	return position.x <= h.x or position.x >= screen_size.x - h.x

func save_data():
	var cfg = ConfigFile.new()
	cfg.set_value("pet", "x", position.x)
	cfg.save(save_path)
	
func load_data():
	var cfg = ConfigFile.new()
	if cfg.load(save_path) == OK:
		var h = window_size.x / 2
		position.x = clamp(cfg.get_value("pet", "x", position.x), h, screen_size.x - h)

		
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_data()

func update_light():
	var t = Time.get_time_dict_from_system()
	var hour = t.hour + t.minute / 60.0
	var c: Color
	var e: float
	
	if hour < 6.0:
		c = Color(0.4, 0.5, 1.0); e = 0.4
	elif hour < 9.0:
		c = Color(1.0, 0.7, 0.5); e = 0.8
	elif hour < 18.0:
		c = Color(1.0, 0.95, 0.85); e = 0.5
	elif hour < 21.0:
		c = Color(1.0, 0.6, 0.35); e = 0.9
	else:
		c = Color(0.4, 0.5, 1.0); e = 0.4
	var tw = create_tween().set_parallel(true)
	tw.tween_property(light, "color", c, 2.0)
	tw.tween_property(light, "energy", e, 2.0)

func _on_hover(entered: bool):
	hovering = entered
	if state == State.DRAGGED:
		return
	if tag_tween:
		tag_tween.kill()
	tag_tween = create_tween()
	tag_tween.tween_property(cartel, "modulate:a", 1.0 if entered else 0.0, 0.2)
	
func setup_menu():
	menu = PopupMenu.new()
	menu.add_item("Sleep", 0)
	menu.add_item("Mute", 1)
	menu.add_separator()
	menu.add_item("Exit", 2)
	menu.id_pressed.connect(_on_menu_pressed)
	menu.theme = make_menu_theme()
	add_child(menu)
	
func _on_menu_pressed(id: int):
	match id:
		0:
			if state != State.DRAGGED and state != State.FALL:
				change_state(State.SLEEP)
		1:
			var muted = not AudioServer.is_bus_mute(0)
			AudioServer.set_bus_mute(0, muted)
			menu.set_item_text(menu.get_item_index(1), "Activate Sound" if muted else "Mute")
		2:
			save_data()
			get_tree().quit()

func make_menu_theme() -> Theme:
	var border = Color("ffbe8cff")
	var t = Theme.new()

	var panel = StyleBoxFlat.new()
	panel.bg_color = Color("44374fff")
	panel.border_color = border
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(0)
	panel.set_content_margin_all(4)
	panel.anti_aliasing = false

	var hov = StyleBoxFlat.new()
	hov.bg_color = Color("#5a4466")
	hov.anti_aliasing = false

	var sep = StyleBoxLine.new()
	sep.color = border
	sep.thickness = 1
	
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_stylebox("hover", "PopupMenu", hov)
	t.set_stylebox("separator", "PopupMenu", sep)
	t.set_color("font_color", "PopupMenu", Color("f9ebbbff"))
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	if menu_font:
		t.set_font("font", "PopupMenu", menu_font)
	t.set_font_size("font_size", "PopupMenu", 12)
	t.set_constant("v_separation", "PopupMenu", 4)
	t.set_constant("item_start_padding", "PopupMenu", 6)
	t.set_constant("item_end_padding", "PopupMenu", 6)
	
	return t

func open_menu():
	menu.reset_size()
	var gap = 6
	var x = position.x + window_size.x / 2 + gap
	if x + menu.size.x > screen_size.x:
		x = position.x - window_size.x / 2 - gap - menu.size.x
	var y = clamp(position.y - menu.size.y / 2, 0, screen_size.y - menu.size.y)
	menu.popup(Rect2i(Vector2i(x,y), Vector2i.ZERO))
