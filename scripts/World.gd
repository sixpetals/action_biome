extends Node2D
class_name World

const PixelArt := preload("res://scripts/PixelArt.gd")

signal terrain_changed
signal furniture_changed

const TILE_SIZE := 32
const WORLD_WIDTH := 512
const WORLD_HEIGHT := 256
const CENTER_X := 256

const TILE_AIR := PixelArt.TILE_AIR
const TILE_DIRT := PixelArt.TILE_DIRT
const TILE_GRASS := PixelArt.TILE_GRASS
const TILE_STONE := PixelArt.TILE_STONE
const TILE_WOOD := PixelArt.TILE_WOOD
const TILE_ORE := PixelArt.TILE_ORE
const TILE_SHIP_HULL := PixelArt.TILE_SHIP_HULL
const TILE_SHIP_GLASS := PixelArt.TILE_SHIP_GLASS

const FURNITURE_WORKBENCH := PixelArt.FURNITURE_WORKBENCH
const FURNITURE_DOOR := PixelArt.FURNITURE_DOOR
const FURNITURE_CHEST := PixelArt.FURNITURE_CHEST
const FURNITURE_BED := PixelArt.FURNITURE_BED
const FURNITURE_TABLE := PixelArt.FURNITURE_TABLE
const FURNITURE_CHAIR := PixelArt.FURNITURE_CHAIR
const FURNITURE_KITCHEN := PixelArt.FURNITURE_KITCHEN
const FURNITURE_COCKPIT := PixelArt.FURNITURE_COCKPIT
const FURNITURE_SAVE_CORE := PixelArt.FURNITURE_SAVE_CORE

var seed_value := 41017
var surface_heights := PackedInt32Array()
var terrain_overrides := {}
var furniture := {}
var protected_cells := {}
var known_room_cells := {}
var spawn_cell := Vector2i(CENTER_X - 3, 110)

var tile_textures := {}
var furniture_textures := {}
var height_noise := FastNoiseLite.new()
var cave_noise := FastNoiseLite.new()
var ore_noise := FastNoiseLite.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(seed_to_use: int) -> void:
	seed_value = seed_to_use
	tile_textures = PixelArt.make_tile_textures()
	furniture_textures = PixelArt.make_furniture_textures()
	_generate_base_world()
	_build_ship()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	var viewport_size := get_viewport_rect().size
	var view_center := Vector2(WORLD_WIDTH * TILE_SIZE * 0.5, WORLD_HEIGHT * TILE_SIZE * 0.45)
	var zoom := Vector2.ONE
	if camera != null:
		view_center = camera.global_position
		zoom = camera.zoom

	var half_size := viewport_size * zoom * 0.5 + Vector2(96, 96)
	var visible_rect := Rect2(view_center - half_size, half_size * 2.0)
	_draw_background(visible_rect)

	var min_cell := pixel_to_cell(visible_rect.position)
	var max_cell := pixel_to_cell(visible_rect.position + visible_rect.size)
	min_cell.x = clampi(min_cell.x, 0, WORLD_WIDTH - 1)
	max_cell.x = clampi(max_cell.x + 1, 0, WORLD_WIDTH - 1)
	min_cell.y = clampi(min_cell.y, 0, WORLD_HEIGHT - 1)
	max_cell.y = clampi(max_cell.y + 1, 0, WORLD_HEIGHT - 1)

	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var tile := get_tile(Vector2i(x, y))
			if tile == TILE_AIR:
				continue
			var tex: Texture2D = tile_textures.get(tile)
			if tex != null:
				draw_texture_rect(tex, Rect2(Vector2(x, y) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE)), false)

	for key in furniture.keys():
		var cell := key_to_cell(key)
		if not Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE).has_point(cell):
			continue
		var item: Dictionary = furniture[key]
		var furniture_id := int(item.get("id", 0))
		var tex: Texture2D
		if furniture_id == FURNITURE_DOOR and bool(item.get("open", false)):
			tex = furniture_textures.get("door_open")
		else:
			tex = furniture_textures.get(furniture_id)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(cell) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE)), false)


func _draw_background(visible_rect: Rect2) -> void:
	var top_color := Color8(82, 172, 221)
	var bottom_color := Color8(158, 216, 225)
	var band_h := maxf(16.0, visible_rect.size.y / 8.0)
	for i in range(8):
		var t := float(i) / 7.0
		draw_rect(
			Rect2(visible_rect.position.x, visible_rect.position.y + band_h * i, visible_rect.size.x, band_h + 1.0),
			top_color.lerp(bottom_color, t),
			true
		)

	var far_y := float(_average_surface_height(CENTER_X - 40, CENTER_X + 40)) * TILE_SIZE - 120.0
	for i in range(9):
		var x := visible_rect.position.x + float(i) * 280.0 - fmod(visible_rect.position.x * 0.18, 280.0)
		draw_circle(Vector2(x, far_y + sin(float(i)) * 24.0), 46.0, Color8(97, 159, 130, 120))


func _generate_base_world() -> void:
	surface_heights.resize(WORLD_WIDTH)

	height_noise.seed = seed_value
	height_noise.frequency = 0.018
	cave_noise.seed = seed_value + 7919
	cave_noise.frequency = 0.062
	ore_noise.seed = seed_value + 15485863
	ore_noise.frequency = 0.13

	for x in range(WORLD_WIDTH):
		var center_distance := absf(float(x - CENTER_X)) / float(CENTER_X)
		var h := 121.0
		h += height_noise.get_noise_1d(float(x)) * 20.0
		h += sin(float(x) * 0.035 + float(seed_value % 97)) * 6.0
		h += center_distance * 12.0
		if abs(x - CENTER_X) < 34:
			h = lerpf(h, 122.0, 0.74)
		surface_heights[x] = clampi(int(round(h)), 76, WORLD_HEIGHT - 45)

	for _pass in range(3):
		var copy := PackedInt32Array(surface_heights)
		for x in range(1, WORLD_WIDTH - 1):
			surface_heights[x] = int(round(float(copy[x - 1] + copy[x] + copy[x + 1]) / 3.0))

	terrain_overrides.clear()
	furniture.clear()
	protected_cells.clear()
	known_room_cells.clear()


func _build_ship() -> void:
	var floor_y := surface_heights[CENTER_X] - 1
	var roof_y := floor_y - 6
	var left_x := CENTER_X - 12
	var right_x := CENTER_X + 13
	spawn_cell = Vector2i(CENTER_X - 4, floor_y - 1)

	for y in range(roof_y, floor_y + 1):
		for x in range(left_x, right_x + 1):
			var cell := Vector2i(x, y)
			var hull := y == roof_y or y == floor_y or x == left_x or x == right_x
			var nose := (x == right_x - 1 and y in [roof_y + 1, floor_y - 1])
			if hull or nose:
				_set_tile_override(cell, TILE_SHIP_HULL, true)
			else:
				_set_tile_override(cell, TILE_AIR, false)

	for x in range(right_x - 6, right_x - 1):
		_set_tile_override(Vector2i(x, roof_y + 1), TILE_SHIP_GLASS, true)
		_set_tile_override(Vector2i(x, roof_y + 2), TILE_SHIP_GLASS, true)

	var left_door := Vector2i(left_x, floor_y - 1)
	var right_door := Vector2i(right_x, floor_y - 1)
	_set_tile_override(left_door, TILE_AIR, false)
	_set_tile_override(right_door, TILE_AIR, false)
	_set_furniture(left_door, FURNITURE_DOOR, {"open": false, "ship": true})
	_set_furniture(right_door, FURNITURE_DOOR, {"open": false, "ship": true})

	_set_furniture(Vector2i(CENTER_X - 9, floor_y - 1), FURNITURE_BED, {"ship": true})
	_set_furniture(Vector2i(CENTER_X - 6, floor_y - 1), FURNITURE_CHEST, {"ship": true})
	_set_furniture(Vector2i(CENTER_X - 1, floor_y - 1), FURNITURE_WORKBENCH, {"ship": true})
	_set_furniture(Vector2i(CENTER_X + 5, floor_y - 1), FURNITURE_SAVE_CORE, {"ship": true})
	_set_furniture(Vector2i(CENTER_X + 9, floor_y - 1), FURNITURE_COCKPIT, {"ship": true})


func get_tile(cell: Vector2i) -> int:
	var key := cell_key(cell)
	if terrain_overrides.has(key):
		return int(terrain_overrides[key])
	return _base_tile_at(cell)


func _base_tile_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= WORLD_WIDTH or cell.y >= WORLD_HEIGHT:
		return TILE_STONE
	if cell.y < 0:
		return TILE_AIR

	var surface: int = surface_heights[cell.x]
	if cell.y < surface:
		return TILE_AIR

	var depth := cell.y - surface
	if depth > 8 and cave_noise.get_noise_2d(float(cell.x), float(cell.y)) > 0.37:
		return TILE_AIR
	if cell.y == surface:
		return TILE_GRASS
	if depth < 5:
		return TILE_DIRT
	if depth > 10 and ore_noise.get_noise_2d(float(cell.x), float(cell.y)) > 0.56:
		return TILE_ORE
	return TILE_STONE


func get_biome_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.x >= WORLD_WIDTH:
		return "void"
	var surface := surface_heights[cell.x]
	if cell.y > surface + 12:
		return "cave"
	var forest_weight: int = abs(cell.x - CENTER_X)
	if forest_weight > 76:
		return "forest"
	return "plains"


func mine_cell(cell: Vector2i, mining_power: int = 1) -> String:
	if is_protected(cell):
		return ""
	var tile := get_tile(cell)
	if tile == TILE_AIR or tile == TILE_SHIP_HULL or tile == TILE_SHIP_GLASS:
		return ""
	if furniture.has(cell_key(cell)):
		return ""
	if tile == TILE_ORE and mining_power < 2:
		return ""

	_set_tile_override(cell, TILE_AIR, false)
	emit_signal("terrain_changed")
	queue_redraw()

	match tile:
		TILE_GRASS, TILE_DIRT:
			return "dirt"
		TILE_STONE:
			return "stone"
		TILE_WOOD:
			return "wood"
		TILE_ORE:
			return "ore"
	return "dirt"


func place_tile(cell: Vector2i, tile_id: int) -> bool:
	if is_protected(cell):
		return false
	if cell.x < 0 or cell.x >= WORLD_WIDTH or cell.y < 0 or cell.y >= WORLD_HEIGHT:
		return false
	if get_tile(cell) != TILE_AIR:
		return false
	if furniture.has(cell_key(cell)):
		return false
	_set_tile_override(cell, tile_id, false)
	emit_signal("terrain_changed")
	queue_redraw()
	return true


func place_furniture(cell: Vector2i, furniture_id: int) -> bool:
	if is_protected(cell):
		return false
	if cell.x < 0 or cell.x >= WORLD_WIDTH or cell.y < 0 or cell.y >= WORLD_HEIGHT:
		return false
	if get_tile(cell) != TILE_AIR:
		return false
	if furniture.has(cell_key(cell)):
		return false
	if furniture_id != FURNITURE_DOOR and not is_room_boundary_cell(cell + Vector2i.DOWN):
		return false
	_set_furniture(cell, furniture_id, {"open": false})
	emit_signal("furniture_changed")
	queue_redraw()
	return true


func toggle_door_near(world_position: Vector2, radius_cells: int = 2) -> bool:
	var result := find_furniture_near(world_position, [FURNITURE_DOOR], radius_cells)
	if result.is_empty():
		return false
	var key: String = result["key"]
	furniture[key]["open"] = not bool(furniture[key].get("open", false))
	emit_signal("furniture_changed")
	queue_redraw()
	return true


func find_furniture_near(world_position: Vector2, ids: Array, radius_cells: int = 2) -> Dictionary:
	var origin := pixel_to_cell(world_position)
	var best := {}
	var best_distance := 999999.0
	for key in furniture.keys():
		var item: Dictionary = furniture[key]
		var furniture_id := int(item.get("id", 0))
		if not ids.has(furniture_id):
			continue
		var cell := key_to_cell(key)
		var distance := Vector2(cell - origin).length()
		if distance <= float(radius_cells) and distance < best_distance:
			best_distance = distance
			best = {"key": key, "cell": cell, "item": item}
	return best


func detect_room_from_world_position(world_position: Vector2) -> Dictionary:
	return detect_room_from_cell(pixel_to_cell(world_position))


func detect_room_from_cell(origin: Vector2i) -> Dictionary:
	if is_room_boundary_cell(origin):
		origin += Vector2i.UP
	if origin.x < 0 or origin.x >= WORLD_WIDTH or origin.y < 0 or origin.y >= WORLD_HEIGHT:
		return {"enclosed": false, "valid": false, "kind": "", "level": 0, "area": 0}

	var frontier: Array[Vector2i] = [origin]
	var visited := {}
	var limit := 360
	var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		var key := cell_key(cell)
		if visited.has(key):
			continue
		if cell.x < 0 or cell.x >= WORLD_WIDTH or cell.y < 0 or cell.y >= WORLD_HEIGHT:
			return {"enclosed": false, "valid": false, "kind": "", "level": 0, "area": visited.size()}
		if is_room_boundary_cell(cell):
			continue
		visited[key] = true
		if visited.size() > limit:
			return {"enclosed": false, "valid": false, "kind": "", "level": 0, "area": visited.size()}

		for dir in dirs:
			var next: Vector2i = cell + dir
			if not visited.has(cell_key(next)):
				frontier.push_back(next)

	var furniture_ids := {}
	for key in furniture.keys():
		if visited.has(key):
			var item: Dictionary = furniture[key]
			furniture_ids[int(item.get("id", 0))] = true

	var kind := ""
	if furniture_ids.has(FURNITURE_BED) and furniture_ids.has(FURNITURE_CHEST):
		kind = "Bedroom"
	elif furniture_ids.has(FURNITURE_WORKBENCH) and furniture_ids.has(FURNITURE_CHEST):
		kind = "Workshop"
	elif furniture_ids.has(FURNITURE_KITCHEN) and furniture_ids.has(FURNITURE_TABLE) and furniture_ids.has(FURNITURE_CHAIR):
		kind = "Dining"

	if kind != "":
		known_room_cells = visited.duplicate()

	return {
		"enclosed": true,
		"valid": kind != "",
		"kind": kind,
		"level": 1 if kind != "" else 0,
		"area": visited.size(),
	}


func is_cell_in_known_room(cell: Vector2i) -> bool:
	return known_room_cells.has(cell_key(cell))


func is_room_boundary_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= WORLD_WIDTH or cell.y >= WORLD_HEIGHT:
		return true
	if cell.y < 0:
		return false
	if get_tile(cell) != TILE_AIR:
		return true
	var item = furniture.get(cell_key(cell))
	return item != null and int(item.get("id", 0)) == FURNITURE_DOOR


func is_solid_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= WORLD_WIDTH or cell.y >= WORLD_HEIGHT:
		return true
	if cell.y < 0:
		return false
	if get_tile(cell) != TILE_AIR:
		return true
	var item = furniture.get(cell_key(cell))
	if item != null and int(item.get("id", 0)) == FURNITURE_DOOR:
		return not bool(item.get("open", false))
	return false


func is_solid_at_pixel(world_position: Vector2) -> bool:
	return is_solid_cell(pixel_to_cell(world_position))


func is_protected(cell: Vector2i) -> bool:
	return protected_cells.has(cell_key(cell))


func get_spawn_position() -> Vector2:
	return cell_center(spawn_cell)


func get_surface_cell_near(x: int) -> Vector2i:
	var safe_x := clampi(x, 0, WORLD_WIDTH - 1)
	return Vector2i(safe_x, surface_heights[safe_x] - 1)


func pixel_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * TILE_SIZE + TILE_SIZE * 0.5, float(cell.y) * TILE_SIZE + TILE_SIZE * 0.5)


func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func key_to_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func serialize_overrides() -> Array:
	var rows := []
	for key in terrain_overrides.keys():
		rows.append({"cell": key, "tile": int(terrain_overrides[key])})
	return rows


func load_overrides(rows: Array) -> void:
	terrain_overrides.clear()
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		terrain_overrides[String(row.get("cell", "0,0"))] = int(row.get("tile", TILE_AIR))
	queue_redraw()


func serialize_furniture() -> Array:
	var rows := []
	for key in furniture.keys():
		var item: Dictionary = furniture[key]
		rows.append({
			"cell": key,
			"id": int(item.get("id", 0)),
			"open": bool(item.get("open", false)),
			"ship": bool(item.get("ship", false)),
		})
	return rows


func load_furniture(rows: Array) -> void:
	furniture.clear()
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var key := String(row.get("cell", "0,0"))
		furniture[key] = {
			"id": int(row.get("id", 0)),
			"open": bool(row.get("open", false)),
			"ship": bool(row.get("ship", false)),
		}
	queue_redraw()


func _set_tile_override(cell: Vector2i, tile_id: int, protected := false) -> void:
	var key := cell_key(cell)
	terrain_overrides[key] = tile_id
	if protected:
		protected_cells[key] = true


func _set_furniture(cell: Vector2i, furniture_id: int, extra := {}) -> void:
	var item := {"id": furniture_id, "open": bool(extra.get("open", false)), "ship": bool(extra.get("ship", false))}
	furniture[cell_key(cell)] = item


func _average_surface_height(from_x: int, to_x: int) -> int:
	var total := 0
	var count := 0
	for x in range(clampi(from_x, 0, WORLD_WIDTH - 1), clampi(to_x, 0, WORLD_WIDTH - 1) + 1):
		total += surface_heights[x]
		count += 1
	if count == 0:
		return 120
	return int(total / count)
