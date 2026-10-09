extends Node2D

var speed = 100
var direction = Vector2(1, 0)
var screen_size = Vector2()
var window_size = Vector2(140, 140)
var is_falling = false

@export var fish_texture: Texture2D
@export var heart_texture: Texture2D
var fish: Sprite2D = null

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
	if event is InputEventKey and not event.echo and event.pressed and event.ctrl_pressed and event.keycode == KEY_F:
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
		var dx = fish.global_position.x - position.x
		if abs(dx) < 40:
			spawn_hearts(fish.global_position)
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
		if is_dragged or is_sleeping:
			return
		is_idling = true
		idle_timer = randf_range(2.0, 4.0)
		sprite.play("idle")
		speed = 0
		
func spawn_hearts(pos: Vector2):
	for i in randf_range(4, 8):
		var heart = Sprite2D.new()
		heart.texture = heart_texture
		heart.top_level = true
		add_child(heart)
		heart.global_position = pos + Vector2(randf_range(-30, 30), -40)
		var t = create_tween().set_parallel(true)
		t.tween_property(heart, "global_position:y", heart.global_position.y - randf_range(120, 200), 1.5)
		t.tween_property(heart, "modulate:a", 0.0, 1.5)
		t.finished.connect(heart.queue_free)
		await get_tree().create_timer(0.1).timeout
	
func spawn_fish():
	if fish != null:
		return
	fish = Sprite2D.new()
	fish.texture = fish_texture
	fish.top_level = true
	add_child(fish)
	var p = get_global_mouse_position()
	var h = window_size / 2
	p.x = clamp(p.x, h.x + 40, screen_size.x - h.x - 40)
	fish.global_position = p
	is_sleeping = false
	is_idling = false
	inactivity = 0.0
	speed = 100
	sprite.play("walk")
	
