extends Node2D
## Original furniture and character art. Scene anchor coordinates come from P03_Scene_Hall.
signal table_clicked(index: int)
const Art = preload("res://scripts/original_art.gd")
const Actor = preload("res://scripts/original_actor.gd")
const TABLE_POS = [Vector2(-180, -46), Vector2(273, -47), Vector2(-180, 426), Vector2(273, 426)]
var furniture: Dictionary
var static_root: Node2D
var table_root: Node2D
var actor_root: Node2D
var actors: Dictionary = {}
var staff_actors: Dictionary = {}
var table_nodes: Array = []
var meals: Array = []
var area := "hall"
var visual_key := ""
var table_count := 2
var selected := 0
var game

func visible_indices() -> Array:
	if area == "hall": return [0,1,2,3]
	if game and game.rooms.has(area): return game.rooms[area].indices.map(func(i): return int(i))
	return []

func table_position(index: int) -> Vector2:
	if index < 4: return TABLE_POS[index]
	var key = game.table_area(index)
	var room = game.rooms[key]
	var entry = room.tables[room.indices.find(index)]
	return Vector2(entry[0],entry[1])

func customer_position(index: int) -> Vector2:
	var offset = Vector2(-137,69)
	if index >= 4:
		var p = game.rooms[game.table_area(index)].seat_offset
		offset = Vector2(p[0],p[1])
	return table_position(index) + offset

func _ready() -> void:
	furniture = JSON.parse_string(FileAccess.get_file_as_string("res://data/furniture.json"))
	static_root = Node2D.new()
	add_child(static_root)
	table_root = Node2D.new()
	add_child(table_root)
	actor_root = Node2D.new()
	add_child(actor_root)

func item(parent: Node2D, name_: String, pos: Vector2, order := 0) -> Node2D:
	if not furniture.has(name_):
		name_ = name_.replace("P02_", "P01_").replace("P03_", "P01_")
	var node = Art.new()
	node.position = pos
	node.z_index = order
	parent.add_child(node)
	if furniture.has(name_):
		node.setup(furniture[name_])
	return node

func build(s: Dictionary) -> void:
	for child in static_root.get_children():
		child.queue_free()
	for child in table_root.get_children():
		child.queue_free()
	table_nodes.clear()
	meals.clear()
	var floor_style = "P%02d_" % int(s.styles.floor)
	var wall_style = "P%02d_" % int(s.styles.wall)
	var table_style = "P%02d_" % int(s.styles.tables)
	var counter_style = "P%02d_" % int(s.styles.counter)
	if area == "hall":
		item(static_root, floor_style + "SItem_Hall_ground_0101", Vector2(-27, -11), -1000)
		item(static_root, wall_style + "SItem_Hall_wall_0101", Vector2(0, -607), -900)
		item(static_root, counter_style + "SItem_Hall_Counter_0401", Vector2(-233, -511), -300)
		item(static_root, counter_style + "SItem_Hall_wine_01", Vector2(-140, -683), -850)
		item(static_root, counter_style + "SItem_Hall_drinks_01", Vector2(-425, -650), -840)
		item(static_root, wall_style + "SItem_Hall_Door_0101", Vector2(341, -594), -820)
		item(static_root, "P01_SItem_Hall_AirConditioner_0101", Vector2(126, -500), -810)
		item(static_root, "P01_SItem_Hall_Counter_0101", Vector2(-532, 143), -700)
		item(static_root, "P%02d_SItem_Hall_Bonsai_0101" % int(s.styles.decoration), Vector2(-446, 581), -600)
		for i in 4:
			var node = item(table_root, table_style + "SItem_Hall_Table_0101", TABLE_POS[i], int(TABLE_POS[i].y))
			node.visible = i < int(s.table_count)
			table_nodes.append(node)
			var meal = preload("res://scripts/table_meal.gd").new()
			meal.position = TABLE_POS[i]
			meal.z_index = int(TABLE_POS[i].y) + 1
			table_root.add_child(meal)
			meal.setup(game)
			meals.append(meal)
	elif area == "kitchen":
		item(static_root, "P01_SItem_kitchen_ground_0101", Vector2(-27, 203), -1000)
		item(static_root, "P01_SItem_kitchen_Wall_0201", Vector2(0, -768), -900)
		item(static_root, "P01_SItem_kitchen_Wall_0101", Vector2(525, 0), -850)
		item(static_root, "P01_SItem_kitchen_RangeHood_0101", Vector2(220, -670), -850)
		item(static_root, "P01_SItem_kitchen_CookingBench_0101", Vector2(277, -626), -800)
		item(static_root, "P01_SItem_kitchen_Refrigerator_0101", Vector2(-187, -558), -810)
		item(static_root, "P01_SItem_kitchen_CookingBench_0301", Vector2(-445, 92), 0)
		item(static_root, "P01_SItem_kitchen_CookingBench_0401", Vector2(7, 795), 700)
		if s.stoves > 1:
			item(static_root, "P01_SItem_kitchen_CookingBench_0201", Vector2(140, 40), -200)
	elif area == "outside":
		item(static_root, "P01_SItem_Outside_Road_02", Vector2(0, 800), -1000)
		item(static_root, "P01_SItem_Outside_ground_0101", Vector2(0, 171), -950)
		item(static_root, "P01_SItem_Outside_building_0101", Vector2(0, -388), -900)
		item(static_root, "P01_SItem_Outside_parasol_0101", Vector2(-370, 110), 10)
		item(static_root, "P01_SItem_Outside_zuozi_0101", Vector2(367, 54), 0)
		item(static_root, "P01_SItem_Outside_chair_0101", Vector2(-180, 400), 400)
		item(static_root, "P01_SItem_Outside_TV_0101", Vector2(217, 89), 50)
	elif game.rooms.has(area):
		var art = Art.new()
		static_root.add_child(art)
		art.setup(game.rooms[area].art)
		for i in visible_indices():
			var meal = preload("res://scripts/table_meal.gd").new()
			meal.position = table_position(i)
			meal.z_index = int(meal.position.y) + 1
			table_root.add_child(meal)
			meal.setup(game)
			meals.append(meal)
	for a in actors.values():
		a.root.visible = game.table_area(a.table) == area
	for a in staff_actors.values():
		a.visible = false
	if area == "hall":
		staff("cashier", "cashier01", Vector2(-280, -400), true).play("idle")
		if s.staff.waiter:
			staff("waiter", "waiter01", Vector2(-380, 50), true).play("idle")
	elif area == "kitchen":
		var chef = staff("chef", "chef01", Vector2(100, -430), true)
		chef.play("work" if not s.jobs.is_empty() else "idle")
		if s.staff.cleaner:
			staff("cleaner", "dishwasher01", Vector2(-120, 690), true).play("idle")
	table_count = int(s.table_count)
	queue_redraw()

func staff(key: String, look: String, pos: Vector2, show: bool):
	if not staff_actors.has(key):
		var a = Actor.new()
		actor_root.add_child(a)
		a.setup(look)
		a.scale = Vector2(0.72, 0.72)
		staff_actors[key] = a
	var node = staff_actors[key]
	node.position = pos
	node.z_index = int(pos.y + 20)
	node.visible = show
	return node

func sync(game_, selected_: int) -> void:
	game = game_
	selected = selected_
	var s = game.state
	var key = area + str(s.styles) + str(s.table_count) + str(s.staff) + str(s.stoves) + str(s.areas)
	if key != visual_key:
		visual_key = key
		build(s)
	var present: Dictionary = {}
	var visible_tables = visible_indices()
	for j in meals.size():
		meals[j].set_customer(s.tables[visible_tables[j]])
	for i in game.active_tables():
		var c = s.tables[i]
		if c.is_empty() or c.phase == "dirty":
			continue
		var id = int(c.id)
		present[id] = true
		if not actors.has(id):
			var root = Actor.new()
			actor_root.add_child(root)
			root.setup("customer%02d" % (int(c.look) % 8 + 1))
			root.scale = Vector2(0.68, 0.68)
			root.position = Vector2(330, -540)
			actors[id] = {"root": root, "table": i, "phase": "", "target": Vector2.ZERO}
		var actor = actors[id]
		actor.root.visible = game.table_area(i) == area
		var target = customer_position(i)
		actor.target = target
		actor.phase = c.phase
		if c.phase == "walking":
			actor.root.play("move")
		elif c.phase == "leaving":
			actor.target = Vector2(360, -550)
			actor.root.play("move")
		else:
			actor.root.scale.x = absf(actor.root.scale.x)
			actor.root.position = target
			actor.root.play("eat_LR_01" if c.phase in ["eating", "bill"] else "sitDown_LR")
	if staff_actors.has("chef"):
		staff_actors.chef.play("work" if not s.jobs.is_empty() else "idle")
	for id in actors.keys():
		if not present.has(id):
			actors[id].root.queue_free()
			actors.erase(id)
	queue_redraw()

func _process(delta: float) -> void:
	for a in actors.values():
		if a.phase in ["walking", "leaving"]:
			var direction = a.target - a.root.position
			a.root.position = a.root.position.move_toward(a.target, 340 * delta)
			a.root.scale.x = absf(a.root.scale.x) * (-1 if direction.x < 0 else 1)
			a.root.z_index = int(a.root.position.y + 20)

func _unhandled_input(event: InputEvent) -> void:
	if visible_indices().is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local = get_local_mouse_position()
		for i in visible_indices():
			if Rect2(table_position(i) + Vector2(-190, -150), Vector2(380, 330)).has_point(local):
				table_clicked.emit(i)
				get_viewport().set_input_as_handled()
				return

func _draw() -> void:
	if area == "hall":
		for i in range(table_count, 4):
			var p = TABLE_POS[i]
			draw_circle(p, 65, Color(1, 0.95, 0.73, 0.33))
			draw_line(p + Vector2(-24, 0), p + Vector2(24, 0), Color("f9edc9"), 6, true)
			draw_line(p + Vector2(0, -24), p + Vector2(0, 24), Color("f9edc9"), 6, true)
