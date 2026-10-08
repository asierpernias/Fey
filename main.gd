extends Node2D

var speed = 100
var direction = Vector2(1, 0)
var screen_size = Vector2()
var window_size = Vector2(140, 140)
var is_falling = false
@onready var sprite = $AnimatedSprite2D
@onready var area = $Area2D

var idle_timer = 0.0
var is_idling = false
var is_dragged = false
var drag_offset = Vector2()

var fall_speed = 0.0
var gravity = 1500.0
var floor_y = -20.0

func _on_area_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragged = true
		drag_offset = get_global_mouse_position() - position

func _input(event):
	if not is_dragged:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragged = false
	elif event is InputEventMouseMotion:
		position = get_global_mouse_position() - drag_offset
		var h = window_size / 2
		position.x = clamp(position.x, h.x, screen_size.x - h.x)
		position.y = clamp(position.y, h.y, screen_size.y - h.y)
	
func _ready() -> void:
	var win = get_window()
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
	area.input_event.connect(_on_area_input)
	win.position = Vector2i.ZERO
	win.size = Vector2i(s.x, s.y - 1)
	await get_tree().process_frame
	win.always_on_top = true
	floor_y = DisplayServer.screen_get_usable_rect().end.y - window_size.y / 2
	
func _physics_process(delta: float) -> void:
	if is_dragged: 
		return
	if position.y < floor_y:
		fall_speed += gravity * delta
		position.y = min(position.y + fall_speed * delta, floor_y)
		is_falling = true
		return
	fall_speed = 0.0
	if is_idling:
		idle_timer -= delta
		if idle_timer <= 0:
			is_idling = false
			speed = 100
			sprite.play("walk")
		return
	if screen_size == Vector2.ZERO:
		return  
	position += direction * speed * delta
	var h = window_size / 2
	position.x = clamp(position.x, h.x, screen_size.x - h.x)
	position.y = clamp(position.y, h.y, floor_y)
	if position.x <= h.x or position.x >= screen_size.x - h.x:
		direction.x *= -1
		sprite.flip_h = direction.x < 0
		idling()

func _process(delta: float) -> void:
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
		is_idling = true
		idle_timer = randf_range(2.0, 4.0)
		sprite.play("idle")
		speed = 0
