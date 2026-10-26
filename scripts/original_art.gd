extends Node2D
## Draws original Unity sprite placements, including pivots, tiling, color and transforms.
## All coordinates remain editable in data/furniture.json.
static var textures: Dictionary = {}
var rows: Array = []

static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		var location = "res://" + path
		if ResourceLoader.exists(location):
			textures[path] = load(location)
		elif FileAccess.file_exists(location):
			var raw = Image.load_from_file(location)
			textures[path] = ImageTexture.create_from_image(raw) if raw else null
		else:
			textures[path] = null
	return textures[path]

func setup(data: Dictionary) -> void:
	rows = data.get("sprites", []).duplicate()
	rows.sort_custom(func(a, b): return a.order < b.order)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	queue_redraw()

func _draw() -> void:
	for row in rows:
		var t: Array = row.transform
		var r: Array = row.rect
		var c: Array = row.color
		var tex := texture(row.sprite)
		if not tex:
			continue
		var flip_x: float = -1.0 if row.flip[0] else 1.0
		var flip_y: float = -1.0 if row.flip[1] else 1.0
		draw_set_transform_matrix(Transform2D(Vector2(t[0], t[1]), Vector2(t[2], t[3]), Vector2(t[4], t[5])))
		var rect := Rect2(r[0], r[1], r[2] * flip_x, r[3] * flip_y)
		if flip_x < 0:
			rect.position.x += r[2]
		if flip_y < 0:
			rect.position.y += r[3]
		draw_texture_rect(tex, rect, row.get("tile", false), Color(c[0], c[1], c[2], c[3]))
	draw_set_transform_matrix(Transform2D.IDENTITY)
