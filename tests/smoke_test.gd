extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const PixelArtScript := preload("res://scripts/PixelArt.gd")
const WorldScript := preload("res://scripts/World.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists("user://action_biome_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://action_biome_save.json"))

	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	_check(game.world != null, "world exists")
	_check(game.player != null, "player exists")
	if game.world == null or game.player == null:
		_finish()
		return

	_check(game.world.seed_value == 41017, "default seed loaded")
	_check(game.player.hp == game.player.max_hp, "player starts healed")
	_check(game.enemies.size() > 10, "enemies spawned")
	if DisplayServer.get_name() == "headless":
		print("SKIP: viewport pixel check on headless display")
	else:
		_check(_viewport_has_pixels(), "viewport renders nonblank")

	var ship_tile: int = game.world.get_tile(game.world.pixel_to_cell(game.player.global_position + Vector2(0, 32)))
	_check(ship_tile != PixelArtScript.TILE_AIR, "ship/floor under player")

	var mine_cell: Vector2i = _find_mine_cell(game.world)
	var material: String = game.world.mine_cell(mine_cell, 2)
	_check(material != "", "mining yields material")

	var place_cell: Vector2i = _find_air_cell(game.world)
	var placed: bool = game.world.place_tile(place_cell, PixelArtScript.TILE_DIRT)
	_check(placed, "tile placement works")

	var room_cell: Vector2i = _build_test_room(game.world)
	var room: Dictionary = game.world.detect_room_from_cell(room_cell)
	_check(bool(room.get("enclosed", false)), "room enclosed")
	_check(bool(room.get("valid", false)), "room classified")

	_test_craft(game)
	_test_cockpit(game)
	_test_death_respawn(game)
	_test_debug_mode(game)

	game.inventory["dirt"] = 77
	game._save_game(true)
	_check(FileAccess.file_exists("user://action_biome_save.json"), "save file exists")
	await _test_load_from_save(game)

	_finish()


func _find_mine_cell(world) -> Vector2i:
	for dx in range(36, 96):
		var cell: Vector2i = game_safe_surface(world, WorldScript.CENTER_X + dx) + Vector2i(0, 2)
		if world.get_tile(cell) != PixelArtScript.TILE_AIR:
			return cell
	return game_safe_surface(world, WorldScript.CENTER_X + 48) + Vector2i(0, 2)


func _find_air_cell(world) -> Vector2i:
	for dx in range(36, 96):
		var cell: Vector2i = game_safe_surface(world, WorldScript.CENTER_X + dx) + Vector2i(0, -3)
		if world.get_tile(cell) == PixelArtScript.TILE_AIR:
			return cell
	return game_safe_surface(world, WorldScript.CENTER_X + 54) + Vector2i(0, -3)


func game_safe_surface(world, x: int) -> Vector2i:
	return world.get_surface_cell_near(clampi(x, 0, WorldScript.WORLD_WIDTH - 1))


func _build_test_room(world) -> Vector2i:
	var left := WorldScript.CENTER_X + 66
	var right := left + 8
	var floor_y: int = world.surface_heights[left] - 3
	for x in range(left, right + 1):
		floor_y = mini(floor_y, int(world.surface_heights[x]) - 3)
	var roof_y: int = floor_y - 5

	for x in range(left, right + 1):
		world.place_tile(Vector2i(x, floor_y), PixelArtScript.TILE_WOOD)
		world.place_tile(Vector2i(x, roof_y), PixelArtScript.TILE_WOOD)
	for y in range(roof_y + 1, floor_y):
		world.place_tile(Vector2i(left, y), PixelArtScript.TILE_WOOD)
		if y != floor_y - 1:
			world.place_tile(Vector2i(right, y), PixelArtScript.TILE_WOOD)
	world.place_furniture(Vector2i(right, floor_y - 1), PixelArtScript.FURNITURE_DOOR)
	world.place_furniture(Vector2i(left + 2, floor_y - 1), PixelArtScript.FURNITURE_BED)
	world.place_furniture(Vector2i(left + 4, floor_y - 1), PixelArtScript.FURNITURE_CHEST)
	return Vector2i(left + 2, floor_y - 2)


func _test_craft(game) -> void:
	var old_dash: int = game.player.dash_level
	game.inventory["ore"] = int(game.inventory.get("ore", 0)) + 1
	game._craft({"upgrade": "dash", "cost": {"ore": 1}})
	_check(game.player.dash_level == old_dash + 1, "craft upgrade works")


func _test_cockpit(game) -> void:
	var cockpit = game.world.find_furniture_near(
		game.world.cell_center(Vector2i(WorldScript.CENTER_X + 9, game.world.surface_heights[WorldScript.CENTER_X] - 2)),
		[PixelArtScript.FURNITURE_COCKPIT],
		6
	)
	_check(not cockpit.is_empty(), "cockpit exists")
	if cockpit.is_empty():
		return
	game.player.global_position = game.world.cell_center(cockpit["cell"])
	game._interact()
	_check(game.cockpit_panel.visible, "cockpit UI opens")
	game._interact()


func _test_death_respawn(game) -> void:
	game.player.global_position = game.player.global_position + Vector2(600, 400)
	game.player.invincible_timer = 0.0
	game.player.take_damage(99)
	_check(game.player.hp == game.player.max_hp, "death restores HP")
	_check(game.player.global_position.distance_to(game.world.get_spawn_position()) < 2.0, "death respawns at ship")


func _test_debug_mode(game) -> void:
	game.player.invincible_timer = 0.0
	game._handle_key(KEY_F3)
	_check(game.debug_mode, "F3 toggles debug mode on")
	var hp_before: int = game.player.hp
	game.player.take_damage(99)
	_check(game.player.hp == hp_before, "debug mode prevents HP loss")
	game._handle_key(KEY_F3)
	_check(not game.debug_mode, "F3 toggles debug mode off")


func _test_load_from_save(old_game) -> void:
	old_game.queue_free()
	await process_frame
	var loaded_game = MainScene.instantiate()
	root.add_child(loaded_game)
	await process_frame
	_check(int(loaded_game.inventory.get("dirt", 0)) == 77, "save data loads inventory")
	_check(loaded_game.world.seed_value == 41017, "save data loads seed")
	loaded_game.queue_free()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures.append(label)
		push_error("FAIL: " + label)


func _viewport_has_pixels() -> bool:
	var texture := root.get_texture()
	if texture == null:
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	var colored := 0
	for y in range(0, image.get_height(), 24):
		for x in range(0, image.get_width(), 24):
			var c := image.get_pixel(x, y)
			if c.a > 0.5 and (c.r + c.g + c.b) > 0.1:
				colored += 1
	return colored > 6


func _finish() -> void:
	if failures.is_empty():
		print("SMOKE TEST PASS")
		quit(0)
	else:
		print("SMOKE TEST FAIL: " + ", ".join(failures))
		quit(1)
