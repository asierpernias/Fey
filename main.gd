extends Node2D

var speed = 100
var direction = Vector2(1, 0)
var screen_size = Vector2()
var window_size = Vector2(32, 32)
@onready var sprite = $AnimatedSprite2D

func _ready() -> void:
	var win = get_window()
	win.borderless = true
	win.always_on_top = true
	win.transparent = true
	get_viewport().transparent_bg = true
	win.position = Vector2i.ZERO
	var s = DisplayServer.screen_get_size()
	win.size = Vector2i(s.x, s.y - 1)
	await get_tree().process_frame  # espera a que la ventana tenga su tamaño final
	win.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, true)
	screen_size = get_viewport_rect().size  # tamaño real en coordenadas del juego
	sprite.play("walk")

func _physics_process(delta: float) -> void:
	if screen_size == Vector2.ZERO:
		return  # todavía no se calculó
	position += direction * speed * delta
	position.x = clamp(position.x, 0, screen_size.x - window_size.x)
	position.y = clamp(position.y, 0, screen_size.y - window_size.y)
	if position.x <= 0 or position.x >= screen_size.x - window_size.x:
		direction.x *= -1
		sprite.flip_h = direction.x < 0
