extends Node2D
class_name Enemy

const PixelArt := preload("res://scripts/PixelArt.gd")

signal defeated(enemy, reward: String)

const TILE_SIZE := 32
const GRAVITY := 1200.0

var world
var player
var kind := "plains"
var velocity := Vector2.ZERO
var direction := 1
var hp := 1
var max_hp := 1
var attack := 1
var speed := 70.0
var stompable := true
var active_radius_px := 40 * TILE_SIZE
var hit_timer := 0.0
var jump_timer := 0.0
var body_size := Vector2(24, 20)
var textures := {}


func setup(world_ref, player_ref, enemy_kind: String, difficulty: int) -> void:
	world = world_ref
	player = player_ref
	kind = enemy_kind
	textures = PixelArt.make_enemy_textures()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	direction = -1 if randf() < 0.5 else 1

	match kind:
		"forest":
			max_hp = 1 + difficulty / 2
			attack = 1 + difficulty / 3
			speed = 82.0
			body_size = Vector2(24, 22)
		"cave":
			max_hp = 2 + difficulty
			attack = 2 + difficulty / 2
			speed = 54.0
			body_size = Vector2(25, 25)
			stompable = difficulty < 3
		_:
			max_hp = 1 + difficulty / 3
			attack = 1 + difficulty / 4
			speed = 68.0
			body_size = Vector2(24, 19)

	hp = max_hp
	jump_timer = randf_range(0.4, 1.6)


func _physics_process(delta: float) -> void:
	if world == null or player == null:
		return

	if global_position.distance_to(player.global_position) > float(active_radius_px):
		queue_redraw()
		return

	hit_timer = maxf(0.0, hit_timer - delta)
	jump_timer = maxf(0.0, jump_timer - delta)

	var to_player: float = player.global_position.x - global_position.x
	if absf(to_player) < 420.0:
		direction = 1 if to_player > 0.0 else -1

	match kind:
		"forest":
			velocity.x = move_toward(velocity.x, float(direction) * speed, 700.0 * delta)
			velocity.y += GRAVITY * 0.42 * delta
			if jump_timer <= 0.0:
				velocity.y = -260.0
				jump_timer = randf_range(0.9, 1.8)
		"cave":
			velocity.x = move_toward(velocity.x, float(direction) * speed, 500.0 * delta)
			velocity.y += GRAVITY * delta
		_:
			velocity.x = move_toward(velocity.x, float(direction) * speed, 800.0 * delta)
			velocity.y += GRAVITY * delta

	if velocity.y > 680.0:
		velocity.y = 680.0

	_move_axis(Vector2(velocity.x * delta, 0.0))
	_move_axis(Vector2(0.0, velocity.y * delta))

	if _edge_ahead() and kind != "forest":
		direction *= -1
		velocity.x = float(direction) * speed

	queue_redraw()


func _draw() -> void:
	var key := "%s_%s" % [kind, "hit" if hit_timer > 0.0 else "idle"]
	var tex: Texture2D = textures.get(key)
	if tex == null:
		return
	var rect := Rect2(-tex.get_size() * 0.5, tex.get_size())
	if direction < 0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		draw_texture_rect(tex, rect, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(tex, rect, false)

	if hp < max_hp:
		var w := 24.0
		draw_rect(Rect2(Vector2(-w * 0.5, -24), Vector2(w, 3)), Color8(35, 26, 31, 210))
		draw_rect(Rect2(Vector2(-w * 0.5, -24), Vector2(w * float(hp) / float(max_hp), 3)), Color8(94, 223, 114))


func get_body_rect() -> Rect2:
	return Rect2(global_position - body_size * 0.5, body_size)


func take_hit(amount: int, stomp := false) -> void:
	hp -= amount
	hit_timer = 0.22
	velocity.x = -float(direction) * 120.0
	velocity.y = -120.0
	if hp <= 0:
		var reward := "plant"
		match kind:
			"cave":
				reward = "ore"
			"forest":
				reward = "wood"
		emit_signal("defeated", self, reward)
		queue_free()
	elif stomp:
		direction *= -1
	queue_redraw()


func _move_axis(offset: Vector2) -> void:
	var length := offset.length()
	if length <= 0.001:
		return
	var steps := maxi(1, ceili(length / 3.0))
	var step := offset / float(steps)
	for _i in range(steps):
		global_position += step
		if _body_collides():
			global_position -= step
			if absf(step.x) > 0.0:
				velocity.x = 0.0
				direction *= -1
			if absf(step.y) > 0.0:
				velocity.y = 0.0
			break


func _body_collides() -> bool:
	var rect := get_body_rect()
	var points := [
		rect.position + Vector2(1, 1),
		rect.position + Vector2(rect.size.x - 1, 1),
		rect.position + Vector2(1, rect.size.y - 1),
		rect.position + rect.size - Vector2.ONE,
	]
	for point in points:
		if world.is_solid_at_pixel(point):
			return true
	return false


func _edge_ahead() -> bool:
	var foot := global_position + Vector2(float(direction) * body_size.x * 0.55, body_size.y * 0.65)
	return not world.is_solid_at_pixel(foot + Vector2(0, 8))
