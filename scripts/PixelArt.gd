extends RefCounted
class_name PixelArt

const TILE_AIR := 0
const TILE_DIRT := 1
const TILE_GRASS := 2
const TILE_STONE := 3
const TILE_WOOD := 4
const TILE_ORE := 5
const TILE_SHIP_HULL := 6
const TILE_SHIP_GLASS := 7

const FURNITURE_WORKBENCH := 1
const FURNITURE_DOOR := 2
const FURNITURE_CHEST := 3
const FURNITURE_BED := 4
const FURNITURE_TABLE := 5
const FURNITURE_CHAIR := 6
const FURNITURE_KITCHEN := 7
const FURNITURE_COCKPIT := 8
const FURNITURE_SAVE_CORE := 9

static func make_tile_textures() -> Dictionary:
	return {
		TILE_DIRT: _make_dirt_tile(),
		TILE_GRASS: _make_grass_tile(),
		TILE_STONE: _make_stone_tile(),
		TILE_WOOD: _make_wood_tile(),
		TILE_ORE: _make_ore_tile(),
		TILE_SHIP_HULL: _make_ship_hull_tile(),
		TILE_SHIP_GLASS: _make_ship_glass_tile(),
	}


static func make_furniture_textures() -> Dictionary:
	return {
		FURNITURE_WORKBENCH: _make_workbench(),
		FURNITURE_DOOR: _make_door(false),
		"door_open": _make_door(true),
		FURNITURE_CHEST: _make_chest(),
		FURNITURE_BED: _make_bed(),
		FURNITURE_TABLE: _make_table(),
		FURNITURE_CHAIR: _make_chair(),
		FURNITURE_KITCHEN: _make_kitchen(),
		FURNITURE_COCKPIT: _make_cockpit(),
		FURNITURE_SAVE_CORE: _make_save_core(),
	}


static func make_player_textures() -> Dictionary:
	return {
		"idle": _make_player(false, false),
		"run": _make_player(true, false),
		"hit": _make_player(false, true),
	}


static func make_enemy_textures() -> Dictionary:
	return {
		"plains_idle": _make_plains_enemy(false),
		"plains_hit": _make_plains_enemy(true),
		"forest_idle": _make_forest_enemy(false),
		"forest_hit": _make_forest_enemy(true),
		"cave_idle": _make_cave_enemy(false),
		"cave_hit": _make_cave_enemy(true),
	}


static func _new_image(width: int, height: int, fill: Color = Color(0, 0, 0, 0)) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return img


static func _texture(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		if yy < 0 or yy >= img.get_height():
			continue
		for xx in range(x, x + w):
			if xx >= 0 and xx < img.get_width():
				img.set_pixel(xx, yy, color)


static func _pixel(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, color)


static func _outline_rect(img: Image, x: int, y: int, w: int, h: int, fill: Color, outline: Color) -> void:
	_rect(img, x, y, w, h, outline)
	_rect(img, x + 1, y + 1, w - 2, h - 2, fill)


static func _make_dirt_tile() -> ImageTexture:
	var img := _new_image(16, 16, Color8(88, 55, 38))
	for i in range(22):
		var x := (i * 5 + 3) % 16
		var y := (i * 7 + 1) % 16
		_pixel(img, x, y, Color8(122, 76, 49))
		if y + 1 < 16:
			_pixel(img, (x + 1) % 16, y + 1, Color8(63, 39, 32))
	return _texture(img)


static func _make_grass_tile() -> ImageTexture:
	var img := _new_image(16, 16, Color8(95, 62, 42))
	_rect(img, 0, 0, 16, 4, Color8(62, 166, 70))
	_rect(img, 0, 4, 16, 2, Color8(44, 124, 58))
	for x in range(0, 16, 2):
		var tip := 1 + ((x * 3) % 3)
		_rect(img, x, 0, 1, tip, Color8(123, 215, 85))
	for i in range(18):
		_pixel(img, (i * 7) % 16, 6 + ((i * 5) % 10), Color8(119, 78, 49))
	return _texture(img)


static func _make_stone_tile() -> ImageTexture:
	var img := _new_image(16, 16, Color8(80, 84, 90))
	_rect(img, 0, 0, 16, 1, Color8(111, 117, 124))
	_rect(img, 0, 15, 16, 1, Color8(48, 51, 59))
	for i in range(20):
		var x := (i * 9 + 2) % 16
		var y := (i * 4 + 5) % 16
		_pixel(img, x, y, Color8(117, 123, 132))
		_pixel(img, (x + 1) % 16, y, Color8(56, 60, 68))
	return _texture(img)


static func _make_wood_tile() -> ImageTexture:
	var img := _new_image(16, 16, Color8(122, 76, 39))
	for x in range(0, 16, 4):
		_rect(img, x, 0, 1, 16, Color8(74, 46, 31))
		_rect(img, x + 1, 0, 1, 16, Color8(171, 111, 54))
	for y in range(3, 16, 6):
		_rect(img, 0, y, 16, 1, Color8(89, 54, 31))
	return _texture(img)


static func _make_ore_tile() -> ImageTexture:
	var img := _make_stone_tile().get_image()
	for p in [Vector2i(4, 4), Vector2i(10, 5), Vector2i(6, 11), Vector2i(12, 12)]:
		_rect(img, p.x, p.y, 2, 2, Color8(91, 211, 222))
		_pixel(img, p.x, p.y, Color8(210, 251, 255))
	return _texture(img)


static func _make_ship_hull_tile() -> ImageTexture:
	var img := _new_image(16, 16, Color8(38, 47, 69))
	_rect(img, 0, 0, 16, 2, Color8(108, 125, 154))
	_rect(img, 0, 14, 16, 2, Color8(18, 24, 38))
	_rect(img, 0, 0, 2, 16, Color8(21, 28, 44))
	_rect(img, 14, 0, 2, 16, Color8(21, 28, 44))
	_rect(img, 3, 4, 10, 2, Color8(73, 86, 116))
	_rect(img, 4, 9, 8, 1, Color8(159, 80, 70))
	_pixel(img, 12, 12, Color8(237, 178, 80))
	return _texture(img)


static func _make_ship_glass_tile() -> ImageTexture:
	var img := _new_image(16, 16, Color8(16, 34, 57))
	_rect(img, 1, 1, 14, 14, Color8(29, 88, 121))
	_rect(img, 3, 2, 6, 2, Color8(136, 223, 224))
	_rect(img, 10, 5, 2, 5, Color8(74, 157, 177))
	_rect(img, 0, 0, 16, 1, Color8(142, 162, 189))
	_rect(img, 0, 15, 16, 1, Color8(10, 18, 31))
	return _texture(img)


static func _make_player(running: bool, hit: bool) -> ImageTexture:
	var img := _new_image(24, 32)
	var outline := Color8(16, 19, 31)
	var suit := Color8(220, 228, 216) if not hit else Color8(255, 160, 136)
	var shadow := Color8(119, 137, 140)
	var accent := Color8(237, 178, 80)
	var visor := Color8(42, 132, 177)
	_outline_rect(img, 8, 2, 9, 8, suit, outline)
	_rect(img, 10, 4, 5, 3, visor)
	_pixel(img, 11, 4, Color8(191, 245, 255))
	_outline_rect(img, 6, 10, 13, 13, suit, outline)
	_rect(img, 7, 20, 11, 2, shadow)
	_rect(img, 8, 12, 3, 9, Color8(162, 197, 191))
	_rect(img, 16, 12, 3, 8, accent)
	_rect(img, 4, 12, 3, 8, outline)
	_rect(img, 19, 12, 3, 8, outline)
	if running:
		_rect(img, 7, 23, 4, 7, outline)
		_rect(img, 14, 22, 4, 6, outline)
	else:
		_rect(img, 7, 23, 4, 7, outline)
		_rect(img, 14, 23, 4, 7, outline)
	_rect(img, 2, 28, 8, 2, Color8(58, 70, 90))
	_rect(img, 14, 28, 8, 2, Color8(58, 70, 90))
	_rect(img, 5, 8, 4, 4, Color8(72, 92, 115))
	return _texture(img)


static func _make_plains_enemy(hit: bool) -> ImageTexture:
	var img := _new_image(24, 20)
	var outline := Color8(20, 24, 31)
	var body := Color8(80, 196, 112) if not hit else Color8(250, 122, 110)
	_outline_rect(img, 3, 6, 18, 9, body, outline)
	_rect(img, 5, 4, 5, 3, Color8(55, 145, 84))
	_rect(img, 14, 4, 5, 3, Color8(55, 145, 84))
	_pixel(img, 8, 10, Color8(255, 255, 232))
	_pixel(img, 16, 10, Color8(255, 255, 232))
	_rect(img, 5, 15, 4, 3, outline)
	_rect(img, 15, 15, 4, 3, outline)
	return _texture(img)


static func _make_forest_enemy(hit: bool) -> ImageTexture:
	var img := _new_image(26, 22)
	var outline := Color8(22, 26, 35)
	var body := Color8(203, 102, 226) if not hit else Color8(255, 138, 111)
	_outline_rect(img, 5, 6, 16, 11, body, outline)
	_rect(img, 3, 9, 4, 3, Color8(120, 217, 179))
	_rect(img, 19, 9, 4, 3, Color8(120, 217, 179))
	_rect(img, 8, 4, 10, 3, Color8(119, 64, 184))
	_pixel(img, 10, 11, Color8(255, 247, 206))
	_pixel(img, 16, 11, Color8(255, 247, 206))
	_rect(img, 11, 16, 5, 2, Color8(79, 35, 120))
	return _texture(img)


static func _make_cave_enemy(hit: bool) -> ImageTexture:
	var img := _new_image(26, 26)
	var outline := Color8(16, 19, 31)
	var metal := Color8(100, 112, 128) if not hit else Color8(244, 116, 104)
	_outline_rect(img, 5, 5, 16, 15, metal, outline)
	_rect(img, 8, 8, 4, 4, Color8(88, 236, 220))
	_rect(img, 15, 8, 4, 4, Color8(88, 236, 220))
	_rect(img, 9, 16, 9, 2, Color8(38, 45, 61))
	_rect(img, 3, 10, 3, 6, outline)
	_rect(img, 20, 10, 3, 6, outline)
	_rect(img, 6, 20, 4, 4, outline)
	_rect(img, 16, 20, 4, 4, outline)
	_pixel(img, 20, 4, Color8(245, 207, 84))
	return _texture(img)


static func _make_workbench() -> ImageTexture:
	var img := _new_image(32, 32)
	_outline_rect(img, 4, 13, 24, 7, Color8(137, 86, 43), Color8(35, 25, 20))
	_rect(img, 6, 10, 8, 3, Color8(196, 130, 64))
	_rect(img, 18, 10, 8, 3, Color8(196, 130, 64))
	_rect(img, 7, 20, 4, 10, Color8(66, 42, 28))
	_rect(img, 21, 20, 4, 10, Color8(66, 42, 28))
	_rect(img, 10, 8, 5, 2, Color8(91, 216, 219))
	return _texture(img)


static func _make_door(open: bool) -> ImageTexture:
	var img := _new_image(32, 32)
	if open:
		_outline_rect(img, 16, 3, 8, 27, Color8(118, 73, 40), Color8(34, 24, 20))
		_rect(img, 6, 3, 3, 27, Color8(38, 47, 69))
		_rect(img, 12, 14, 2, 2, Color8(238, 180, 77))
	else:
		_outline_rect(img, 10, 3, 12, 27, Color8(145, 84, 43), Color8(34, 24, 20))
		_rect(img, 12, 6, 8, 7, Color8(174, 111, 57))
		_rect(img, 12, 17, 8, 9, Color8(102, 60, 34))
		_pixel(img, 19, 15, Color8(238, 180, 77))
	return _texture(img)


static func _make_chest() -> ImageTexture:
	var img := _new_image(32, 32)
	_outline_rect(img, 5, 13, 22, 12, Color8(137, 78, 38), Color8(32, 22, 17))
	_rect(img, 7, 11, 18, 4, Color8(190, 120, 49))
	_rect(img, 15, 14, 3, 5, Color8(239, 187, 80))
	_rect(img, 6, 23, 20, 2, Color8(74, 43, 28))
	return _texture(img)


static func _make_bed() -> ImageTexture:
	var img := _new_image(32, 32)
	_outline_rect(img, 3, 17, 26, 8, Color8(183, 61, 78), Color8(32, 22, 27))
	_rect(img, 5, 13, 8, 5, Color8(231, 223, 194))
	_rect(img, 5, 24, 22, 3, Color8(72, 47, 39))
	_rect(img, 20, 18, 7, 4, Color8(225, 101, 91))
	return _texture(img)


static func _make_table() -> ImageTexture:
	var img := _new_image(32, 32)
	_outline_rect(img, 5, 14, 22, 5, Color8(157, 97, 47), Color8(32, 22, 17))
	_rect(img, 8, 19, 4, 10, Color8(86, 55, 34))
	_rect(img, 20, 19, 4, 10, Color8(86, 55, 34))
	return _texture(img)


static func _make_chair() -> ImageTexture:
	var img := _new_image(32, 32)
	_outline_rect(img, 10, 9, 10, 12, Color8(151, 88, 46), Color8(32, 22, 17))
	_rect(img, 8, 20, 16, 4, Color8(184, 112, 54))
	_rect(img, 9, 24, 3, 6, Color8(67, 43, 30))
	_rect(img, 20, 24, 3, 6, Color8(67, 43, 30))
	return _texture(img)


static func _make_kitchen() -> ImageTexture:
	var img := _new_image(32, 32)
	_outline_rect(img, 5, 12, 22, 15, Color8(91, 103, 116), Color8(27, 31, 39))
	_rect(img, 8, 15, 7, 5, Color8(43, 47, 57))
	_rect(img, 18, 14, 6, 4, Color8(227, 231, 211))
	_pixel(img, 21, 10, Color8(250, 184, 70))
	_pixel(img, 22, 9, Color8(255, 223, 102))
	_rect(img, 9, 23, 14, 2, Color8(56, 65, 79))
	return _texture(img)


static func _make_cockpit() -> ImageTexture:
	var img := _new_image(32, 32)
	_outline_rect(img, 5, 7, 22, 19, Color8(45, 61, 88), Color8(16, 19, 31))
	_rect(img, 8, 10, 16, 7, Color8(38, 137, 175))
	_rect(img, 10, 11, 7, 2, Color8(164, 240, 241))
	_rect(img, 9, 20, 4, 3, Color8(231, 80, 86))
	_rect(img, 15, 20, 4, 3, Color8(238, 183, 78))
	_rect(img, 21, 20, 3, 3, Color8(91, 218, 123))
	return _texture(img)


static func _make_save_core() -> ImageTexture:
	var img := _new_image(32, 32)
	_outline_rect(img, 9, 7, 14, 20, Color8(56, 69, 96), Color8(16, 19, 31))
	_rect(img, 12, 10, 8, 8, Color8(78, 231, 220))
	_rect(img, 13, 11, 3, 2, Color8(218, 255, 255))
	_rect(img, 11, 21, 10, 2, Color8(239, 184, 78))
	return _texture(img)

