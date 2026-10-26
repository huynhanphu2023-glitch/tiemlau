extends Node2D
## Plays baked vertex poses from the APK's original Spine 3.8.95 animations.
## The source skeletons and C# conversion tool are included in source-art/ and tools/.
const Art = preload("res://scripts/original_art.gd")
static var libraries: Dictionary = {}
static var mesh_cache: Dictionary = {}
static var geometries: Dictionary = {}
var actor_name := "customer01"
var animation := "idle"
var elapsed := 0.0
var frame_index := -1
var frames: Array = []
var facing := 1.0
var fps := 10.0

func setup(name_: String) -> void:
	actor_name = name_
	if not libraries.has(actor_name):
		var file := FileAccess.open("res://data/actors/" + actor_name + ".json", FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
			libraries[actor_name] = data.animations
			geometries[actor_name] = data.get("geometry",[])
	play("idle")

func play(name_: String) -> void:
	if not libraries.has(actor_name):
		return
	var lib: Dictionary = libraries[actor_name]
	if not lib.has(name_):
		name_ = "idle" if lib.has("idle") else str(lib.keys()[0])
	if animation == name_ and not frames.is_empty():
		return
	animation = name_
	frames = lib[animation].frames
	fps = float(lib[animation].get("fps",10))
	elapsed = 0
	frame_index = -1

func _process(delta: float) -> void:
	if frames.is_empty() or not is_visible_in_tree():
		return
	elapsed += delta
	var index := int(elapsed * fps) % frames.size()
	if index != frame_index:
		frame_index = index
		queue_redraw()

func _draw() -> void:
	if frame_index < 0 or frames.is_empty():
		return
	var key := actor_name + "/" + animation + "/" + str(frame_index)
	if not mesh_cache.has(key):
		var meshes: Array = []
		for part in frames[frame_index]:
			var geometry: Dictionary = geometries[actor_name][int(part.g)] if part.has("g") else part
			var vertices := PackedVector2Array()
			var uv := PackedVector2Array()
			for i in range(0, part.xy.size(), 2):
				vertices.append(Vector2(part.xy[i], part.xy[i + 1]))
				uv.append(Vector2(geometry.uv[i], geometry.uv[i + 1]))
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_TEX_UV] = uv
			arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(geometry.tri)
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			meshes.append({"mesh": mesh, "texture": Art.texture("art/actors/" + actor_name + "/" + geometry.texture), "color": Color(part.color[0], part.color[1], part.color[2], part.color[3])})
		mesh_cache[key] = meshes
	for part in mesh_cache[key]:
		draw_mesh(part.mesh, part.texture, Transform2D.IDENTITY, part.color)
