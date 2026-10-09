extends Node2D

var speed = 100
var direction = Vector2(1, 0)
var screen_size = Vector2()
var window_size = Vector2(140, 140)
var is_falling = false

var fish: Window = null
var fish_pos = Vector2()

@export var fish_texture: Texture2D
@export var heart_texture: Texture2D
var fish_fall = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var area = $Area2D

var idle_timer =0.0
var is_idling = false
var is_dragged = false
var drag_offset = Vector2()
var sleep_timer = 150.0
var is_sleeping = false
var inactivity = 0.0

var fall_speed = 0.0
var gravity = 1500.0
var floor_y = -20.0


func _on_area_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		inactivity = 0.0
		if is_sleeping:
			is_sleeping = false
			speed = 100.0
			sprite.play("walk")
			return
		is_dragged = true
		is_idling = false
		speed = 100
		sprite.stop()
		drag_offset = get_global_mouse_position() - position

func _input(event):
	if event is InputEventKey and not event.echo and event.pressed  and event.keycode == KEY_F:
		spawn_fish()
		return
	if not is_dragged:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragged = false
		inactivity = 0.0
		sprite.play("fall")
	elif event is InputEventMouseMotion:
		position = get_global_mouse_position() - drag_offset
		var h = window_size / 2
		position.x = clamp(position.x, h.x, screen_size.x - h.x)
		position.y = clamp(position.y, h.y, floor_y)
		sprite.rotation = clamp(event.relative.x * 0.05, -0.5, 0.5)
		
func _ready() -> void:
	get_viewport().gui_embed_subwindows = false
	floor_y = DisplayServer.screen_get_usable_rect().end.y - window_size.y / 2
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
	sprite.play("walk")
	
	await get_tree().process_frame
	win.always_on_top = true
	
	
func _physics_process(delta: float) -> void:
	if fish != null:
		var fish_floor = floor_y + window_size.y / 2 - 20
		if fish_pos.y < fish_floor:
			fish_fall += gravity * delta
			fish_pos.y = min(fish_pos.y + fish_fall * delta, fish_floor)
			fish.position = Vector2i(fish_pos - Vector2(fish.size)/2)
	if is_dragged: 
		return
	if position.y < floor_y:
		if sprite.animation != "fall":
			sprite.play("fall")
		fall_speed += gravity * delta
		position.y = min(position.y + fall_speed * delta, floor_y)
		return
	if sprite.animation == "fall":
		sprite.play("walk")
	fall_speed = 0.0
	if is_sleeping: 
		return
	inactivity += delta
	if inactivity >= sleep_timer:
		is_sleeping = true
		is_idling = false
		speed = 0
		sprite.play("sleep")
		return
	if is_idling:
		idle_timer -= delta
		if idle_timer <= 0:
			is_idling = false
			speed = 100
			sprite.play("walk")
		return
	if fish != null:
		var dx = fish_pos.x - position.x
		if abs(dx) < 40 and fish_pos.y > floor_y:
			spawn_hearts(fish_pos)
			fish.queue_free()
			fish = null
		else:
			direction.x = sign(dx)
			sprite.flip_h = direction.x < 0
	position += direction * speed * delta
	var h = window_size / 2
	position.x = clamp(position.x, h.x, screen_size.x - h.x)
	position.y = clamp(position.y, h.y, floor_y)
	if position.x <= h.x or position.x >= screen_size.x - h.x:
		direction.x *= -1
		sprite.flip_h = direction.x < 0
		idling()

func _process(delta: float) -> void:
	sprite.rotation = lerp(sprite.rotation, 0.0, 10 * delta)
	if screen_size == Vector2.ZERO:
		return
	var poly: PackedVector2Array
	if is_dragged:
		poly = PackedVector2Array([Vector2.ZERO, Vector2(screen_size.x, 0), screen_size, Vector2(0, screen_size.y)])
	else:
		var h = window_size / 2
		poly = PackedVector2Array([
			position + Vector2(-h.x, -h.y), position + Vector2(h.x, -h.y),
			position + Vector2(h.x, h.y), position + Vector2(-h.x, h.y),
		])
	get_window().mouse_passthrough_polygon = poly
	
		
func idling():
	if randf() < 0.3:
		await get_tree().create_timer(randf_range(1.5, 5)).timeout
		if is_dragged or is_sleeping or fish != null:
			return
		is_idling = true
		idle_timer = randf_range(2.0, 4.0)
		sprite.play("idle")
		speed = 0
		
func spawn_hearts(pos: Vector2):
	for i in randi_range(4, 8):
		var start = pos + Vector2(randf_range(-30, 30), -40)
		var w = make_fx_window(heart_texture, 3.0, start)
		var y0 = float(w.position.y)
		var t = create_tween().set_parallel(true)
		t.tween_method(func(v): w.position.y = int(v), y0, y0 - randf_range(120, 200), 1.5)
		t.tween_property(w.get_child(0), "modulate:a", 0.0, 1.5)
		t.finished.connect(w.queue_free)
		await get_tree().create_timer(0.1).timeout
	
func make_fx_window(tex: Texture2D, scale_f: float, center: Vector2) -> Window:
	var w = Window.new()
	w.borderless = true
	w.transparent = true
	w.transparent_bg = true
	w.always_on_top = true
	w.unfocusable = true
	w.size = Vector2i(tex.get_size() * scale_f)
	w.position = Vector2i(center - Vector2(w.size) / 2)
	w.mouse_passthrough= false
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
	is_sleeping = false
	is_idling = false
	inactivity = 0.0
	speed = 100
	sprite.play("walk")
