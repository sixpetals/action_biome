extends Node2D

const WorldScript := preload("res://scripts/World.gd")
const PlayerScript := preload("res://scripts/Player.gd")
const EnemyScript := preload("res://scripts/Enemy.gd")
const PixelArtScript := preload("res://scripts/PixelArt.gd")

const TILE_SIZE := 32
const SAVE_PATH := "user://action_biome_save.json"
const DEFAULT_SEED := 41017
const AUTO_SAVE_INTERVAL := 60.0

var world
var player
var camera: Camera2D
var enemies := []

var inventory := {
	"dirt": 30,
	"stone": 20,
	"wood": 24,
	"ore": 4,
	"plant": 6,
	"workbench": 0,
	"door": 2,
	"chest": 1,
	"bed": 1,
	"table": 1,
	"chair": 2,
	"kitchen": 1,
}

var slots := [
	{"label": "Dirt", "kind": "tile", "item": "dirt", "tile": PixelArtScript.TILE_DIRT},
	{"label": "Stone", "kind": "tile", "item": "stone", "tile": PixelArtScript.TILE_STONE},
	{"label": "Wood", "kind": "tile", "item": "wood", "tile": PixelArtScript.TILE_WOOD},
	{"label": "Bench", "kind": "furniture", "item": "workbench", "id": PixelArtScript.FURNITURE_WORKBENCH},
	{"label": "Door", "kind": "furniture", "item": "door", "id": PixelArtScript.FURNITURE_DOOR},
	{"label": "Chest", "kind": "furniture", "item": "chest", "id": PixelArtScript.FURNITURE_CHEST},
	{"label": "Bed", "kind": "furniture", "item": "bed", "id": PixelArtScript.FURNITURE_BED},
	{"label": "Table", "kind": "furniture", "item": "table", "id": PixelArtScript.FURNITURE_TABLE},
	{"label": "Chair", "kind": "furniture", "item": "chair", "id": PixelArtScript.FURNITURE_CHAIR},
	{"label": "Kitchen", "kind": "furniture", "item": "kitchen", "id": PixelArtScript.FURNITURE_KITCHEN},
]

var selected_slot := 0
var auto_save_timer := AUTO_SAVE_INTERVAL
var heal_timer := 0.0
var room_scan_timer := 0.0
var last_room := {"enclosed": false, "valid": false, "kind": "", "level": 0, "area": 0}
var message_timer := 0.0
var current_message := ""
var debug_mode := false

var hud_label: Label
var hotbar_label: Label
var room_label: Label
var message_label: Label
var craft_panel: PanelContainer
var cockpit_panel: PanelContainer
var pause_block_clicks := false


func _ready() -> void:
	randomize()
	_register_input_actions()
	_boot_world()
	_build_ui()
	_show_message("Action Biome: crashed ship online", 4.0)


func _process(delta: float) -> void:
	_update_enemy_contacts()
	_update_room_effects(delta)
	_update_save_timer(delta)
	_update_messages(delta)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed:
			return
		if _ui_captures_click(mouse_button.position):
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_left_click()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_right_click()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		_handle_key(key_event.keycode)


func _boot_world() -> void:
	var save = _read_save_data()
	var seed_to_use := DEFAULT_SEED
	if not save.is_empty():
		seed_to_use = int(save.get("seed", DEFAULT_SEED))

	world = WorldScript.new()
	add_child(world)
	world.setup(seed_to_use)

	player = PlayerScript.new()
	add_child(player)
	player.setup(world)
	_apply_debug_mode_to_player()
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)

	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WorldScript.WORLD_WIDTH * TILE_SIZE
	camera.limit_bottom = WorldScript.WORLD_HEIGHT * TILE_SIZE
	player.add_child(camera)

	if save.is_empty():
		player.global_position = world.get_spawn_position()
	else:
		_apply_save_data(save)

	_spawn_initial_enemies()


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	hud_label = Label.new()
	hud_label.position = Vector2(8, 6)
	hud_label.add_theme_color_override("font_color", Color8(245, 250, 232))
	hud_label.add_theme_color_override("font_shadow_color", Color8(20, 24, 31))
	hud_label.add_theme_constant_override("shadow_offset_x", 1)
	hud_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(hud_label)

	room_label = Label.new()
	room_label.position = Vector2(8, 48)
	room_label.add_theme_color_override("font_color", Color8(218, 246, 224))
	room_label.add_theme_color_override("font_shadow_color", Color8(20, 24, 31))
	room_label.add_theme_constant_override("shadow_offset_x", 1)
	room_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(room_label)

	message_label = Label.new()
	message_label.position = Vector2(8, 320)
	message_label.size = Vector2(520, 32)
	message_label.add_theme_color_override("font_color", Color8(255, 238, 166))
	message_label.add_theme_color_override("font_shadow_color", Color8(20, 24, 31))
	message_label.add_theme_constant_override("shadow_offset_x", 1)
	message_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(message_label)

	hotbar_label = Label.new()
	hotbar_label.position = Vector2(8, 342)
	hotbar_label.add_theme_color_override("font_color", Color8(235, 241, 224))
	hotbar_label.add_theme_color_override("font_shadow_color", Color8(20, 24, 31))
	hotbar_label.add_theme_constant_override("shadow_offset_x", 1)
	hotbar_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(hotbar_label)

	craft_panel = _make_panel(Vector2(396, 30), Vector2(226, 250), "Workbench")
	canvas.add_child(craft_panel)
	craft_panel.visible = false
	_populate_craft_panel()

	cockpit_panel = _make_panel(Vector2(372, 58), Vector2(250, 150), "Cockpit")
	canvas.add_child(cockpit_panel)
	cockpit_panel.visible = false
	_populate_cockpit_panel()


func _make_panel(pos: Vector2, panel_size: Vector2, title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color8(22, 28, 42, 225)
	style.border_color = Color8(120, 172, 190)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "Rows"
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color8(242, 247, 226))
	vbox.add_child(label)
	return panel


func _populate_craft_panel() -> void:
	var rows := craft_panel.get_node("MarginContainer/Rows") as VBoxContainer
	for child in rows.get_children():
		if child is Button:
			child.queue_free()

	var recipes := [
		{"label": "Workbench 4W 2S", "item": "workbench", "cost": {"wood": 4, "stone": 2}},
		{"label": "Door 2W", "item": "door", "cost": {"wood": 2}},
		{"label": "Chest 3W", "item": "chest", "cost": {"wood": 3}},
		{"label": "Bed 3W 2P", "item": "bed", "cost": {"wood": 3, "plant": 2}},
		{"label": "Table 2W", "item": "table", "cost": {"wood": 2}},
		{"label": "Chair 1W", "item": "chair", "cost": {"wood": 1}},
		{"label": "Kitchen 3S 2W", "item": "kitchen", "cost": {"stone": 3, "wood": 2}},
		{"label": "Dash+ 3O 2P", "upgrade": "dash", "cost": {"ore": 3, "plant": 2}},
		{"label": "Jump+ 2O 4P", "upgrade": "jump", "cost": {"ore": 2, "plant": 4}},
		{"label": "Mine+ 4O 4S", "upgrade": "mine", "cost": {"ore": 4, "stone": 4}},
	]

	for recipe in recipes:
		var button := Button.new()
		button.text = str(recipe["label"])
		button.custom_minimum_size = Vector2(190, 20)
		button.pressed.connect(func() -> void: _craft(recipe))
		rows.add_child(button)


func _populate_cockpit_panel() -> void:
	var rows := cockpit_panel.get_node("MarginContainer/Rows") as VBoxContainer
	var seed_label := Label.new()
	seed_label.text = "Main seed: %d" % world.seed_value
	seed_label.add_theme_color_override("font_color", Color8(223, 246, 242))
	rows.add_child(seed_label)
	var sub_label := Label.new()
	sub_label.text = "Subworld jump: later build\nStored seeds: empty\nCockpit is the entrance."
	sub_label.add_theme_color_override("font_color", Color8(190, 220, 226))
	rows.add_child(sub_label)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: cockpit_panel.visible = false)
	rows.add_child(close)


func _handle_key(keycode: int) -> void:
	if keycode >= KEY_1 and keycode <= KEY_9:
		selected_slot = keycode - KEY_1
	elif keycode == KEY_0:
		selected_slot = 9
	elif keycode == KEY_E:
		_interact()
	elif keycode == KEY_F3:
		_set_debug_mode(not debug_mode)
	elif keycode == KEY_F5:
		_save_game(true)
	elif keycode == KEY_F9:
		_new_world_without_deleting_save()

	selected_slot = clampi(selected_slot, 0, slots.size() - 1)


func _left_click() -> void:
	var target = get_global_mouse_position()
	if player.global_position.distance_to(target) > 4.0 * TILE_SIZE:
		_show_message("Out of range", 1.2)
		return

	player.attack()
	var attack_rect: Rect2 = player.get_attack_rect(target)
	var hit_enemy = _find_enemy_in_rect(attack_rect, target)
	if hit_enemy != null:
		hit_enemy.take_hit(1 + player.mining_level)
		return

	var cell: Vector2i = world.pixel_to_cell(target)
	var material: String = world.mine_cell(cell, 1 + player.mining_level)
	if material != "":
		inventory[material] = int(inventory.get(material, 0)) + 1
		_show_message("+%s" % material, 0.9)
	else:
		_show_message("Nothing mined", 0.8)


func _right_click() -> void:
	var target = get_global_mouse_position()
	if player.global_position.distance_to(target) > 4.0 * TILE_SIZE:
		_show_message("Out of range", 1.2)
		return

	var slot: Dictionary = slots[selected_slot]
	var item := str(slot["item"])
	if int(inventory.get(item, 0)) <= 0:
		_show_message("Need %s" % item, 1.1)
		return

	var cell: Vector2i = world.pixel_to_cell(target)
	var cell_rect := Rect2(Vector2(cell) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
	if player.get_body_rect().intersects(cell_rect):
		_show_message("Blocked by suit", 1.1)
		return

	var placed := false
	if str(slot["kind"]) == "tile":
		placed = world.place_tile(cell, int(slot["tile"]))
	else:
		placed = world.place_furniture(cell, int(slot["id"]))

	if placed:
		inventory[item] = int(inventory.get(item, 0)) - 1
		_refresh_room_status(true)
	else:
		_show_message("Cannot place there", 1.0)


func _interact() -> void:
	if craft_panel.visible:
		craft_panel.visible = false
		return
	if cockpit_panel.visible:
		cockpit_panel.visible = false
		return

	if world.toggle_door_near(player.global_position, 2):
		_show_message("Door toggled", 0.8)
		return

	if not world.find_furniture_near(player.global_position, [PixelArtScript.FURNITURE_WORKBENCH], 3).is_empty():
		craft_panel.visible = true
		_populate_craft_panel()
		_show_message("Workbench open", 1.0)
		return

	if not world.find_furniture_near(player.global_position, [PixelArtScript.FURNITURE_COCKPIT], 3).is_empty():
		cockpit_panel.visible = true
		_show_message("Cockpit link standby", 1.0)
		return

	if not world.find_furniture_near(player.global_position, [PixelArtScript.FURNITURE_SAVE_CORE], 3).is_empty():
		_save_game(true)
		return

	_refresh_room_status(true)


func _craft(recipe: Dictionary) -> void:
	var cost: Dictionary = recipe.get("cost", {})
	for item in cost.keys():
		if int(inventory.get(item, 0)) < int(cost[item]):
			_show_message("Need material", 1.2)
			return

	for item in cost.keys():
		inventory[item] = int(inventory.get(item, 0)) - int(cost[item])

	if recipe.has("item"):
		var crafted_item := str(recipe["item"])
		inventory[crafted_item] = int(inventory.get(crafted_item, 0)) + 1
		_show_message("Crafted %s" % crafted_item, 1.4)
	elif recipe.has("upgrade"):
		var upgrade := str(recipe["upgrade"])
		match upgrade:
			"dash":
				player.dash_level += 1
			"jump":
				player.jump_level += 1
			"mine":
				player.mining_level += 1
		_show_message("Suit %s upgraded" % upgrade, 1.4)


func _spawn_initial_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()

	var spawn_columns := []
	for x in range(34, WorldScript.WORLD_WIDTH - 34, 16):
		if abs(x - WorldScript.CENTER_X) < 26:
			continue
		spawn_columns.append(x)

	spawn_columns.shuffle()
	var max_spawn := mini(96, spawn_columns.size())
	for i in range(max_spawn):
		var x: int = spawn_columns[i]
		var surface_cell: Vector2i = world.get_surface_cell_near(x)
		var biome: String = world.get_biome_at(surface_cell)
		var enemy_kind: String = biome
		if enemy_kind == "plains":
			enemy_kind = "plains"
		elif enemy_kind == "forest":
			enemy_kind = "forest"
		else:
			enemy_kind = "cave"
		var difficulty := clampi(int(abs(x - WorldScript.CENTER_X) / 82), 0, 4)
		var enemy := EnemyScript.new()
		add_child(enemy)
		enemy.setup(world, player, enemy_kind, difficulty)
		enemy.global_position = world.cell_center(surface_cell) + Vector2(0, -18)
		enemy.defeated.connect(_on_enemy_defeated)
		enemies.append(enemy)

	for i in range(24):
		var x := 28 + i * 19
		if abs(x - WorldScript.CENTER_X) < 36:
			continue
		var surface: Vector2i = world.get_surface_cell_near(x)
		var cave_cell := Vector2i(surface.x, surface.y + 18 + (i % 10))
		if world.get_tile(cave_cell) != PixelArtScript.TILE_AIR:
			continue
		var cave_enemy := EnemyScript.new()
		add_child(cave_enemy)
		var difficulty_cave := clampi(int(abs(x - WorldScript.CENTER_X) / 70), 1, 5)
		cave_enemy.setup(world, player, "cave", difficulty_cave)
		cave_enemy.global_position = world.cell_center(cave_cell)
		cave_enemy.defeated.connect(_on_enemy_defeated)
		enemies.append(cave_enemy)


func _update_enemy_contacts() -> void:
	var player_rect: Rect2 = player.get_body_rect()
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy):
			enemies.erase(enemy)
			continue
		if not player_rect.intersects(enemy.get_body_rect()):
			continue
		var enemy_rect: Rect2 = enemy.get_body_rect()
		var player_bottom: float = player_rect.position.y + player_rect.size.y
		var enemy_top: float = enemy_rect.position.y
		var stomp: bool = player.velocity.y > 80.0 and player_bottom < enemy_top + 13.0 and enemy.stompable
		if stomp:
			enemy.take_hit(99, true)
			player.bounce()
		else:
			player.take_damage(enemy.attack)


func _update_room_effects(delta: float) -> void:
	room_scan_timer -= delta
	if room_scan_timer <= 0.0:
		room_scan_timer = 0.7
		_refresh_room_status(false)

	if bool(last_room.get("valid", false)) and str(last_room.get("kind", "")) == "Bedroom":
		heal_timer -= delta
		if heal_timer <= 0.0:
			heal_timer = 2.0
			player.heal(1)
	else:
		heal_timer = 0.4


func _update_save_timer(delta: float) -> void:
	auto_save_timer -= delta
	if auto_save_timer <= 0.0:
		auto_save_timer = AUTO_SAVE_INTERVAL
		_save_game(false)


func _update_messages(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			current_message = ""
			message_label.text = ""


func _update_hud() -> void:
	if hud_label == null:
		return
	var hearts := ""
	for i in range(player.max_hp):
		hearts += "#" if i < player.hp else "-"
	hud_label.text = "HP %s  Dirt:%d Stone:%d Wood:%d Ore:%d Plant:%d  Suit D%d J%d M%d" % [
		hearts,
		int(inventory.get("dirt", 0)),
		int(inventory.get("stone", 0)),
		int(inventory.get("wood", 0)),
		int(inventory.get("ore", 0)),
		int(inventory.get("plant", 0)),
		player.dash_level,
		player.jump_level,
		player.mining_level,
	]
	if debug_mode:
		hud_label.text += "  DEBUG"

	var room_text := "Room: open air"
	if bool(last_room.get("enclosed", false)):
		if bool(last_room.get("valid", false)):
			room_text = "Room: %s Lv.%d" % [str(last_room.get("kind", "")), int(last_room.get("level", 0))]
		else:
			room_text = "Room: enclosed, missing furniture"
	room_label.text = room_text

	var rows := []
	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		var count := int(inventory.get(str(slot["item"]), 0))
		var prefix := "[" if i == selected_slot else " "
		var suffix := "]" if i == selected_slot else " "
		var key_name := "0" if i == 9 else str(i + 1)
		rows.append("%s%s:%s x%d%s" % [prefix, key_name, str(slot["label"]), count, suffix])
	hotbar_label.text = " ".join(rows)


func _refresh_room_status(verbose: bool) -> void:
	last_room = world.detect_room_from_world_position(player.global_position)
	if verbose:
		if bool(last_room.get("valid", false)):
			_show_message("%s Lv.%d room detected" % [str(last_room.get("kind", "")), int(last_room.get("level", 0))], 1.8)
		elif bool(last_room.get("enclosed", false)):
			_show_message("Closed room, furniture missing", 1.5)
		else:
			_show_message("No closed room", 1.2)


func _find_enemy_in_rect(rect: Rect2, target: Vector2):
	var best = null
	var best_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not rect.intersects(enemy.get_body_rect()):
			continue
		var distance: float = enemy.global_position.distance_to(target)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _on_enemy_defeated(enemy, reward: String) -> void:
	enemies.erase(enemy)
	inventory[reward] = int(inventory.get(reward, 0)) + 1
	_show_message("+%s from monster" % reward, 1.0)


func _on_player_died() -> void:
	player.respawn(world.get_spawn_position())
	_show_message("Suit rebooted at ship. Inventory kept.", 2.4)
	_save_game(false)


func _on_player_health_changed(_hp: int, _max_hp: int) -> void:
	_update_hud()


func _set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled
	_apply_debug_mode_to_player()
	_show_message("Debug mode ON: HP locked" if debug_mode else "Debug mode OFF", 1.6)
	_update_hud()


func _apply_debug_mode_to_player() -> void:
	if player != null:
		player.set_debug_mode(debug_mode)


func _show_message(text: String, seconds: float) -> void:
	current_message = text
	message_timer = seconds
	if message_label != null:
		message_label.text = text


func _save_game(manual: bool) -> void:
	var data := {
		"version": 1,
		"seed": world.seed_value,
		"inventory": inventory,
		"player": player.get_save_data(),
		"terrain": world.serialize_overrides(),
		"furniture": world.serialize_furniture(),
		"last_room": last_room,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_show_message("Save failed: %s" % FileAccess.get_open_error(), 2.0)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_show_message("Saved" if manual else "Auto saved", 1.4)


func _read_save_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _apply_save_data(save: Dictionary) -> void:
	inventory = save.get("inventory", inventory)
	world.load_overrides(save.get("terrain", []))
	world.load_furniture(save.get("furniture", []))
	player.global_position = world.get_spawn_position()
	player.load_save_data(save.get("player", {}))
	last_room = save.get("last_room", last_room)


func _new_world_without_deleting_save() -> void:
	var new_seed := randi_range(1000, 999999)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	world.setup(new_seed)
	player.respawn(world.get_spawn_position())
	_spawn_initial_enemies()
	_show_message("New world seed %d. F5 saves it." % new_seed, 2.2)


func _ui_captures_click(screen_position: Vector2) -> bool:
	for panel in [craft_panel, cockpit_panel]:
		if panel != null and panel.visible:
			var rect := Rect2(panel.global_position, panel.size)
			if rect.has_point(screen_position):
				return true
	return false


func _register_input_actions() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_SPACE])
	_add_key_action("dash", [KEY_SHIFT])
	_add_key_action("toggle_debug", [KEY_F3])


func _add_key_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key in keys:
		var exists := false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey and (event as InputEventKey).keycode == key:
				exists = true
				break
		if exists:
			continue
		var input_event := InputEventKey.new()
		input_event.keycode = key
		InputMap.action_add_event(action_name, input_event)
