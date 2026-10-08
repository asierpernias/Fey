extends Node2D

var speed = 100
var direction = Vector2(1, 0)
var screen_size = Vector2()
var window_size = Vector2(32, 32)

@onready var sprite = $AnimatedSprite2D
@onready var area = $Area2D

var idle_timer = 0.0
var is_idling = false
var is_dragged = false
var drag_offset = Vector2()

func _on_area_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragged = true
		drag_offset = get_global_mouse_position() - position

func _input(event):
	if not is_dragged:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed:
		is_dragged = false
	elif event is InputEventMouseMotion:
		position = get_global_mouse_position() - drag_offset
		position.x = clamp(position.x, 0, screen_size.x - window_size.x)
		position.y = clamp(position.y, 0, screen_size.y - window_size.y)
	
func _ready() -> void:
	var win = get_window()
	win.borderless = true
	win.always_on_top = true
	win.transparent = true
	get_viewport().transparent_bg = true
	win.position = Vector2i.ZERO
	var s = DisplayServer.screen_get_size()
	win.size = Vector2i(s.x, s.y - 1)
	await get_tree().process_frame  
	screen_size = get_viewport_rect().size  
	sprite.play("walk")
	area.input_event.connect(_on_area_input)

func _physics_process(delta: float) -> void:
	if is_dragged: 
		return
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
	position.x = clamp(position.x, 0, screen_size.x - window_size.x)
	position.y = clamp(position.y, 0, screen_size.y - window_size.y)
	if position.x <= 0 or position.x >= screen_size.x - window_size.x:
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
			position + Vector2(h.x, h.y), position + Vector2(-h.x, -h.y),
		])
	get_window().mouse_passthrough_polygon = poly
	
		
func idling():
	if randf() < 0.3:
		await get_tree().create_timer(randf_range(1.5, 5)).timeout
		is_idling = true
		idle_timer = randf_range(2.0, 4.0)
		var r = randi() % 3
		if r == 0:
			sprite.play("idle")
			speed = 0
