extends Node2D
class_name Player

const PixelArt := preload("res://scripts/PixelArt.gd")
const WorldScript := preload("res://scripts/World.gd")

signal died
signal health_changed(hp: int, max_hp: int)

const TILE_SIZE := 32
const MOVE_SPEED := 220.0
const JUMP_SPEED := 420.0
const GRAVITY := 1200.0
const COYOTE_TIME := 0.10
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.45

var world
var velocity := Vector2.ZERO
var max_hp := 5
var hp := 5
var dash_level := 0
var jump_level := 0
var mining_level := 0
var facing := 1
var on_floor := false
var coyote_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var hurt_timer := 0.0
var attack_timer := 0.0
var invincible_timer := 0.0
var textures := {}
var body_size := Vector2(22, 30)


func setup(world_ref) -> void:
	world = world_ref
	textures = PixelArt.make_player_textures()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hp = max_hp
	emit_signal("health_changed", hp, max_hp)


func _physics_process(delta: float) -> void:
	if world == null:
		return

	var input_dir := Input.get_axis("move_left", "move_right")
	if absf(input_dir) > 0.01:
		facing = 1 if input_dir > 0.0 else -1

	if dash_timer <= 0.0:
		var target_speed := input_dir * MOVE_SPEED * (1.0 + float(dash_level) * 0.08)
		velocity.x = move_toward(velocity.x, target_speed, 2200.0 * delta)

	velocity.y += GRAVITY * delta
	if velocity.y > 760.0:
		velocity.y = 760.0

	if on_floor:
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	if Input.is_action_just_pressed("jump") and coyote_timer > 0.0:
		velocity.y = -(JUMP_SPEED + float(jump_level) * 45.0)
		coyote_timer = 0.0
		on_floor = false

	if Input.is_action_just_released("jump") and velocity.y < -150.0:
		velocity.y *= 0.45

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		var dash_speed := 420.0 + float(dash_level) * 60.0
		velocity.x = float(facing) * dash_speed
		dash_timer = DASH_TIME + float(dash_level) * 0.03
		dash_cooldown_timer = DASH_COOLDOWN

	if dash_timer > 0.0:
		dash_timer -= delta
		velocity.y *= 0.82
	else:
		dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)

	hurt_timer = maxf(0.0, hurt_timer - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	invincible_timer = maxf(0.0, invincible_timer - delta)

	on_floor = false
	_move_axis(Vector2(velocity.x * delta, 0.0))
	_move_axis(Vector2(0.0, velocity.y * delta))

	if global_position.y > float(WorldScript.WORLD_HEIGHT * TILE_SIZE + 240):
		take_damage(max_hp)

	queue_redraw()


func _draw() -> void:
	var key := "idle"
	if hurt_timer > 0.0:
		key = "hit"
	elif absf(velocity.x) > 40.0 and on_floor:
		key = "run"
	var tex: Texture2D = textures.get(key)
	if tex != null:
		var rect := Rect2(Vector2(-12, -18), Vector2(24, 32))
		if facing < 0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
			draw_texture_rect(tex, rect, false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(tex, rect, false)

	if attack_timer > 0.0:
		var slash_color := Color8(255, 234, 122, 190)
		var slash_x := 12.0 * float(facing)
		draw_arc(Vector2(slash_x, -4), 17.0, -0.9, 0.9, 10, slash_color, 3.0)


func attack() -> void:
	attack_timer = 0.18
	queue_redraw()


func take_damage(amount: int) -> void:
	if invincible_timer > 0.0:
		return
	hp -= amount
	hurt_timer = 0.35
	invincible_timer = 0.9
	velocity.x = -float(facing) * 160.0
	velocity.y = -220.0
	if hp <= 0:
		hp = 0
		emit_signal("health_changed", hp, max_hp)
		emit_signal("died")
		return
	emit_signal("health_changed", hp, max_hp)


func heal(amount: int) -> void:
	var old_hp := hp
	hp = mini(max_hp, hp + amount)
	if hp != old_hp:
		emit_signal("health_changed", hp, max_hp)


func respawn(world_position: Vector2) -> void:
	global_position = world_position
	velocity = Vector2.ZERO
	hp = max_hp
	invincible_timer = 1.2
	hurt_timer = 0.0
	emit_signal("health_changed", hp, max_hp)
	queue_redraw()


func bounce() -> void:
	velocity.y = -330.0
	on_floor = false


func get_body_rect() -> Rect2:
	return Rect2(global_position - body_size * 0.5, body_size)


func get_attack_rect(target_position: Vector2) -> Rect2:
	var origin := global_position + Vector2(float(facing) * 10.0, -3.0)
	var reach := minf(128.0, origin.distance_to(target_position))
	var center := origin + (target_position - origin).normalized() * reach * 0.5
	return Rect2(center - Vector2(42, 30), Vector2(84, 60))


func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"hp": hp,
		"max_hp": max_hp,
		"dash_level": dash_level,
		"jump_level": jump_level,
		"mining_level": mining_level,
	}


func load_save_data(data: Dictionary) -> void:
	var pos: Array = data.get("position", [global_position.x, global_position.y])
	if pos.size() >= 2:
		global_position = Vector2(float(pos[0]), float(pos[1]))
	max_hp = int(data.get("max_hp", max_hp))
	hp = clampi(int(data.get("hp", max_hp)), 1, max_hp)
	dash_level = int(data.get("dash_level", 0))
	jump_level = int(data.get("jump_level", 0))
	mining_level = int(data.get("mining_level", 0))
	emit_signal("health_changed", hp, max_hp)


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
			if absf(step.y) > 0.0:
				if step.y > 0.0:
					on_floor = true
				velocity.y = 0.0
			break


func _body_collides() -> bool:
	var rect := get_body_rect()
	var sample_points := [
		rect.position + Vector2(1, 1),
		rect.position + Vector2(rect.size.x - 1, 1),
		rect.position + Vector2(1, rect.size.y - 1),
		rect.position + rect.size - Vector2.ONE,
		rect.position + Vector2(rect.size.x * 0.5, 1),
		rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 1),
	]
	for point in sample_points:
		if world.is_solid_at_pixel(point):
			return true
	return false
