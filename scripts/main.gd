extends Node2D
## Game entry point and UI. Run project.godot with Godot 4.5.1, or use the included launcher.
const Game = preload("res://scripts/restaurant_game.gd")
const View = preload("res://scripts/restaurant_view.gd")
const Art = preload("res://scripts/original_art.gd")
const PAPER = Color("fff3d5")
const INK = Color("533628")
const RED = Color("a93929")
var game
var view
var hud: Control
var bubbles: Control
var order_panel: PanelContainer
var money_label: Label
var diamond_label: Label
var rank_label: Label
var stock_label: Label
var day_label: Label
var kitchen_label: Label
var toast_label: Label
var overlay: ColorRect
var dialog_kind := ""
var selected := 0
var dirty := true
var timer := 0.0
var save_timer := 0.0
var toast_timer := 0.0
var music: AudioStreamPlayer
var music_enabled := false
var capture := false
var test_mode := false
var display_area := ""
var room_controls: HBoxContainer
var game_stage: Control
var icons: Dictionary
var rank_badge: TextureRect
var menu_query := ""
var menu_category := 0
var menu_page := 0
var menu_known_only := false

func _ready() -> void:
	test_mode = OS.get_cmdline_user_args().has("--test-ui")
	capture = OS.get_cmdline_user_args().has("--capture")
	game = Game.new()
	icons = Game.read_json("res://data/ui_icons.json")
	if not test_mode:
		game.load_game()
	game.changed.connect(func(): dirty = true)
	game.message.connect(notify)
	game.received_money.connect(func(amount, _table): notify("+%d xu! Khách đã thanh toán." % amount))
	view = View.new()
	game_stage = Control.new()
	game_stage.position = Vector2(0, 210)
	game_stage.size = Vector2(720, 735)
	game_stage.clip_contents = true
	game_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_stage)
	view.position = Vector2(360, 360)
	view.scale = Vector2(0.42, 0.42)
	game_stage.add_child(view)
	view.table_clicked.connect(func(index): selected = index; game.act(index); dirty = true)
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	build_hud()
	music = AudioStreamPlayer.new()
	add_child(music)
	if ResourceLoader.exists("res://audio/restaurant.ogg"):
		music.stream = load("res://audio/restaurant.ogg")
		music.volume_db = -18
		music.finished.connect(func():
			if music_enabled: music.play())
	get_window().min_size = Vector2i(360, 640)
	if capture:
		capture_scene.call_deferred()
	if game.state.next_id == 1:
		game.arrive()
	refresh()
	notify("Chạm bàn khách để nấu, phục vụ, thu tiền và dọn bàn nhé!")

func box(color: Color, border := Color("bd8c58"), radius := 13, width := 2) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.2, 0.1, 0.04, 0.18)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	return style

func text(value: String, font_size := 18, color := INK) -> Label:
	var node = Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func button(value: String, action: Callable, primary := false) -> Button:
	var node = Button.new()
	node.text = value
	node.custom_minimum_size = Vector2(100, 46)
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_color_override("font_color", PAPER if primary else INK)
	node.add_theme_color_override("font_hover_color", PAPER if primary else INK)
	node.add_theme_color_override("font_pressed_color", PAPER if primary else INK)
	node.add_theme_stylebox_override("normal", box(RED if primary else PAPER))
	node.add_theme_stylebox_override("hover", box(Color("bd5038") if primary else Color("ffdf9d")))
	node.add_theme_stylebox_override("pressed", box(Color("8c3024") if primary else Color("eac17e")))
	node.add_theme_stylebox_override("disabled", box(Color("d5c5a7")))
	node.pressed.connect(action)
	return node

func panel(pos: Vector2, dimensions: Vector2, parent: Control = hud) -> PanelContainer:
	var node = PanelContainer.new()
	node.position = pos
	node.size = dimensions
	node.add_theme_stylebox_override("panel", box(PAPER))
	parent.add_child(node)
	return node

func image(path: String, dimension := 60) -> TextureRect:
	var node = TextureRect.new()
	node.texture = Art.texture(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(dimension, dimension)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func art_button(caption: String, action: Callable, path: String, dimensions: Vector2) -> Button:
	var node = button(caption,action)
	node.tooltip_text = caption.capitalize()
	node.custom_minimum_size = dimensions
	for key in ["normal","hover","pressed","disabled"]:
		node.add_theme_stylebox_override(key,StyleBoxEmpty.new())
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		node.add_theme_color_override(key,Color.TRANSPARENT)
	var art = image(path,1)
	node.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 3
	art.offset_right = -3
	node.mouse_entered.connect(func(): art.modulate = Color(1.15,1.15,1.15))
	node.mouse_exited.connect(func(): art.modulate = Color.WHITE)
	return node

func build_hud() -> void:
	var head = panel(Vector2(12, 12), Vector2(696, 86))
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	head.add_child(h)
	rank_badge = image(icons.get("rank_qt",""),58)
	h.add_child(rank_badge)
	var brand = VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(brand)
	brand.add_child(text("TIỆM LẨU", 27, RED))
	rank_label = text("Đồng I · Ngày 1", 14)
	brand.add_child(rank_label)
	var cash = VBoxContainer.new()
	h.add_child(cash)
	cash.add_child(text("TIỀN QUÁN", 12, Color("98764e")))
	var money_row = HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 3)
	cash.add_child(money_row)
	money_row.add_child(image(icons.money, 24))
	money_label = text("800 xu", 21, RED)
	money_row.add_child(money_label)
	var gems = VBoxContainer.new()
	h.add_child(gems)
	gems.add_child(text("KIM CƯƠNG", 12, Color("98764e")))
	var gem_row = HBoxContainer.new()
	gem_row.add_theme_constant_override("separation", 3)
	gems.add_child(gem_row)
	gem_row.add_child(image(icons.diamond, 24))
	diamond_label = text("0", 21, Color("3d91a8"))
	gem_row.add_child(diamond_label)
	var stock = VBoxContainer.new()
	h.add_child(stock)
	stock.add_child(text("NGUYÊN LIỆU", 12, Color("98764e")))
	stock_label = text("50 phần", 22, Color("54734b"))
	stock.add_child(stock_label)
	var tabs = HBoxContainer.new()
	tabs.position = Vector2(12, 108)
	tabs.add_theme_constant_override("separation", 9)
	hud.add_child(tabs)
	for entry in [["ĐẠI SẢNH", "hall"], ["NHÀ BẾP", "kitchen"], ["NGOÀI QUÁN", "outside"]]:
		var key: String = entry[1]
		var tab = button(entry[0], func(): view.area = key; dirty = true)
		tab.custom_minimum_size = Vector2(226, 43)
		tabs.add_child(tab)
	day_label = text("Ngày 1 · Quán đang mở cửa", 15, Color("fff9e8"))
	day_label.position = Vector2(218, 172)
	day_label.add_theme_color_override("font_shadow_color", Color("513b28"))
	day_label.add_theme_constant_override("shadow_outline_size", 5)
	hud.add_child(day_label)
	var controls = HBoxContainer.new()
	controls.position = Vector2(436, 162)
	controls.add_theme_constant_override("separation", 6)
	hud.add_child(controls)
	for entry in [["Ⅱ", "pause"], ["♪", "sound"], ["Lưu", "save"], ["?", "help"]]:
		var key: String = entry[1]
		var b = button(entry[0], func(): control_action(key))
		b.custom_minimum_size = Vector2(65, 39)
		controls.add_child(b)
	room_controls = HBoxContainer.new()
	room_controls.position = Vector2(12,161)
	room_controls.add_theme_constant_override("separation",4)
	hud.add_child(room_controls)
	var areas_button = button("KHU VỰC",func(): open_dialog("areas"))
	areas_button.custom_minimum_size.x = 105
	room_controls.add_child(areas_button)
	room_controls.add_child(button("−",func(): zoom_room(0.85)))
	room_controls.add_child(button("+",func(): zoom_room(1.15)))
	for i in [1,2]:
		room_controls.get_child(i).custom_minimum_size = Vector2(40,40)
	bubbles = Control.new()
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bubbles)
	order_panel = panel(Vector2(12, 959), Vector2(696, 205))
	var bottom = panel(Vector2(12, 1178), Vector2(696, 89))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	bottom.add_child(row)
	for entry in [["NỘI THẤT", "decor"], ["KHO", "storage"], ["THỰC ĐƠN", "menu"], ["NHÂN VIÊN", "staff"], ["NGHIÊN CỨU", "research"], ["ĐI CHỢ", "market"], ["NHIỆM VỤ", "goals"], ["SỔ QUÁN", "journal"]]:
		var key: String = entry[1]
		var b = art_button(entry[0],func(): open_dialog(key),icons.get(key,icons.task if key == "goals" else icons.journal),Vector2(80,68))
		row.add_child(b)
	toast_label = text("", 18, PAPER)
	toast_label.position = Vector2(25, 885)
	toast_label.size = Vector2(670, 66)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_color_override("font_shadow_color", Color("533527"))
	toast_label.add_theme_constant_override("shadow_outline_size", 8)
	hud.add_child(toast_label)

func refresh() -> void:
	dirty = false
	money_label.text = "%s xu" % int(game.state.money)
	diamond_label.text = str(game.state.get("diamonds", 0))
	stock_label.text = "%d phần" % int(game.state.stock)
	var current_rank = game.rank()
	rank_label.text = "%s · %d bàn khách" % [current_rank, game.state.served]
	for r in game.ranks:
		if r.label == current_rank:
			var key = "rank_" + str(r.icon).get_file().trim_prefix("T_UI_Home_").trim_suffix("_01")
			if icons.has(key): rank_badge.texture = Art.texture(icons[key])
	if display_area != view.area:
		display_area = view.area
		view.position = Vector2(360,360)
		var zooms = {"hall":0.48,"kitchen":0.44,"outside":0.48,"private":0.40,"theatre":0.32,"buffet":0.22}
		view.scale = Vector2.ONE * float(zooms.get(view.area,0.42))
		if not view.visible_indices().has(selected):
			selected = int(view.visible_indices()[0]) if not view.visible_indices().is_empty() else 0
	view.sync(game, selected)
	for child in bubbles.get_children():
		child.queue_free()
	if not view.visible_indices().is_empty():
		for i in view.visible_indices():
			var caption = ""
			var active = false
			if i < 4 and i >= game.state.table_count:
				caption = "+ Thêm bàn"
			else:
				var c = game.state.tables[i]
				if c.is_empty():
					continue
				match c.phase:
					"walking": caption = "Khách ghé quán"
					"waiting": caption = "Phục vụ ✓" if game.can_serve(i) else "Gọi %d món" % c.order.size()
					"eating": caption = "Đang ăn ngon…"
					"bill": caption = "Thu %d xu" % c.bill; active = true
					"dirty": caption = "Dọn bàn"
					"leaving": continue
			var index = i
			var b = button(caption, func(): selected = index; game.act(index); dirty = true, active)
			var width = 150 if view.area in ["hall","private"] else 105
			b.custom_minimum_size = Vector2(width, 40)
			b.add_theme_font_size_override("font_size", 15 if width == 150 else 12)
			b.position = game_stage.position + view.position + (view.table_position(i) + Vector2(0, -245)) * view.scale - Vector2(width * 0.5, 0)
			bubbles.add_child(b)
	refresh_order()

func refresh_order() -> void:
	for child in order_panel.get_children():
		child.queue_free()
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	order_panel.add_child(v)
	var c = game.state.tables[selected] if selected < game.state.table_count else {}
	if game.active_tables().has(selected): c = game.state.tables[selected]
	if game.rooms.has(view.area) and not game.state.areas[view.area]:
		v.add_child(text(game.rooms[view.area].name.to_upper(),21,RED))
		v.add_child(text("Khu mới đang chờ bạn mở cửa đón khách.",17))
		v.add_child(button("Xem điều kiện mở khu",func(): open_dialog("areas"),true))
		return
	if view.area == "kitchen":
		v.add_child(text("BẾP ĐANG ĐỎ LỬA", 20, RED))
		kitchen_label = text(kitchen_status(), 17)
		kitchen_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(kitchen_label)
		var go = button("Xem thực đơn & nấu thêm", func(): open_dialog("menu"), true)
		v.add_child(go)
		return
	if c.is_empty():
		v.add_child(text("MỘT QUÁN NHỎ, NGÀN BỮA NGON", 19, RED))
		v.add_child(text("Nhấp bàn để xem món khách gọi. Thu tiền rồi dọn bàn nhé!", 16))
		var h = HBoxContainer.new()
		v.add_child(h)
		h.add_child(button("Nhiệm vụ hôm nay", func(): open_dialog("goals"), true))
		h.add_child(button("Bếp: %d món đang chờ" % game.state.jobs.size(), func(): view.area = "kitchen"; dirty = true))
		return
	var head = HBoxContainer.new()
	v.add_child(head)
	var title = text("Bàn %d · %s" % [selected + 1, c.name], 21, RED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var status = {"walking": "Đang vào bàn", "waiting": "Đang đợi món", "eating": "Đang thưởng thức", "bill": "Chờ thanh toán", "dirty": "Cần dọn bàn", "leaving": "Đã ra về"}
	head.add_child(text(status.get(c.phase, ""), 15))
	var dishes = HBoxContainer.new()
	dishes.add_theme_constant_override("separation", 12)
	v.add_child(dishes)
	for item in c.order:
		var r = game.by_id[int(item.recipe)]
		var h = HBoxContainer.new()
		h.add_child(image(r.icon, 48))
		var name_label = text(r.name + " ×%d" % int(item.quantity), 15)
		name_label.custom_minimum_size = Vector2(125, 40)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(name_label)
		dishes.add_child(h)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	v.add_child(actions)
	var index = selected
	if c.phase == "waiting":
		actions.add_child(button("Nấu đơn", func(): game.cook_order(index), false))
		var serve_button = button("Phục vụ", func(): game.serve(index), true)
		serve_button.disabled = not game.can_serve(index)
		actions.add_child(serve_button)
		var remaining = text("", 15)
		remaining.name = "WaitTime"
		actions.add_child(remaining)
	elif c.phase == "bill":
		actions.add_child(button("Thu %d xu" % c.bill, func(): game.collect(index), true))
	elif c.phase == "dirty":
		actions.add_child(button("Dọn bàn đón khách mới", func(): game.clean(index), true))
	else:
		actions.add_child(text("Mùi lẩu nóng làm ngày hôm nay dễ thương hơn.", 16))

func kitchen_status() -> String:
	var lines: Array = []
	for j in range(mini(game.state.stoves, game.state.jobs.size())):
		var job = game.state.jobs[j]
		lines.append("%s: %.1f giây" % [game.by_id[int(job.recipe)].name, job.remaining])
	if lines.is_empty():
		return "Bếp đang trống. Nấu đơn tại bàn khách hoặc chọn món trong thực đơn."
	return "  ·  ".join(lines) + "\n%d món còn trong hàng đợi." % maxi(0, game.state.jobs.size() - game.state.stoves)

func _process(delta: float) -> void:
	game.tick(minf(delta, 0.25))
	if dirty:
		refresh()
	timer += delta
	save_timer += delta
	toast_timer = maxf(0, toast_timer - delta)
	toast_label.visible = toast_timer > 0
	if timer > 0.15:
		timer = 0
		day_label.text = "Ngày %d · %s · Chờ %d" % [game.day(), "Tạm nghỉ" if game.paused else "Đang mở", game.state.queue.size()]
		var c = game.state.tables[selected]
		var wait_label = order_panel.find_child("WaitTime", true, false)
		if wait_label and not c.is_empty():
			wait_label.text = "Khách chờ: %ds" % maxi(0, int(c.patience))
		if view.area == "kitchen" and is_instance_valid(kitchen_label):
			kitchen_label.text = kitchen_status()
	if save_timer > 5 and not test_mode:
		save_timer = 0
		game.save_game()

func notify(value: String) -> void:
	if is_instance_valid(toast_label):
		toast_label.text = value
		toast_timer = 3.8

func control_action(key: String) -> void:
	match key:
		"pause": game.paused = not game.paused; notify("Tạm nghỉ một chút." if game.paused else "Mở cửa lại rồi!")
		"save":
			if test_mode or game.save_game(): notify("Đã lưu quán. Lần sau mình chơi tiếp nhé!")
			else: notify("Chưa lưu được. Kiểm tra chỗ trống và quyền ghi thư mục lưu nhé.")
		"sound":
			music_enabled = not music_enabled
			if music_enabled: music.play()
			else: music.stop()
		"help": open_dialog("help")

func perform(action: Callable) -> void:
	action.call()
	dirty = true
	if not test_mode: game.save_game()
	if dialog_kind != "": open_dialog.call_deferred(dialog_kind)

func close_dialog() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	game.paused = false
	dialog_kind = ""

func open_dialog(kind: String) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	dialog_kind = kind
	game.paused = true
	overlay = ColorRect.new()
	overlay.color = Color(0.12, 0.08, 0.04, 0.6)
	overlay.size = Vector2(720, 1280)
	hud.add_child(overlay)
	var p = panel(Vector2(25, 200), Vector2(670, 850), overlay)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var head = HBoxContainer.new()
	v.add_child(head)
	var titles = {"menu": "THỰC ĐƠN", "decor": "CHĂM CHÚT QUÁN", "staff": "NHÂN VIÊN", "market": "NGUYÊN LIỆU & NHÀ BẾP", "journal": "SỔ QUÁN", "goals": "NHIỆM VỤ", "help": "MỘT VÒNG QUANH TIỆM", "reset": "MỞ QUÁN LẠI TỪ ĐẦU?", "areas":"CÁC KHU CỦA QUÁN", "storage":"KHO CỦA QUÁN", "research":"NGHIÊN CỨU MÓN MỚI"}
	var title = text(titles.get(kind, "TIỆM LẨU"), 25, RED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(button("Đóng", close_dialog))
	v.add_child(text("Quỹ quán: %d xu · Đã phục vụ %d bàn" % [game.state.money, game.state.served], 17))
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 650)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 9)
	scroll.add_child(list)
	match kind:
		"areas":
			for key in game.rooms:
				var room = game.rooms[key]
				var area_key: String = key
				card(list,room.name,"%d bàn · thu nhập ×%.2f" % [room.indices.size(),room.tip_multiplier],"Ghé xem",func(): view.area = area_key; close_dialog(); dirty = true)
				if not game.state.areas[key]:
					card(list,"Mở cửa " + room.name,"Phục vụ %d/%d bàn · cần %d xu." % [mini(game.state.served,int(room.served)),room.served,room.cost],"Mở %d xu" % room.cost,func(): perform(func(): game.open_area(area_key)),game.state.served < int(room.served))
		"menu", "research": menu_dialog(list)
		"storage":
			card(list,"Nguyên liệu tươi","Còn %d phần trong kho." % game.state.stock,"Đi chợ",func(): open_dialog.call_deferred("market"))
			var found = false
			for key in game.state.ready:
				var id = int(key)
				if int(game.state.ready[key]) < 1: continue
				found = true
				var r = game.by_id[id]
				card(list,r.name,"Đã nấu xong: %d phần · sẵn sàng phục vụ." % game.state.ready[key],"Nấu thêm",func(): game.cook(id))
			if not found: list.add_child(text("Chưa có món nấu sẵn. Ghé thực đơn hoặc nấu đơn của bàn khách nhé!",17))
		"decor":
			card(list, "Thêm bàn khách", "%d/4 bàn đang phục vụ cùng lúc." % game.state.table_count, "Đã đủ" if game.state.table_count >= 4 else "%d xu" % game.balance.table_costs[game.state.table_count], func(): perform(func(): game.buy("table")), game.state.table_count >= 4)
			for item in [["tables", "Bàn ghế"], ["floor", "Sàn nhà"], ["wall", "Tường quán"], ["counter", "Quầy & tủ"], ["decoration", "Cây cảnh"]]:
				var key: String = item[0]
				var level = int(game.state.styles[key])
				card(list, item[1], "Mẫu %d/3 · nâng cấp để quán thêm đẹp." % level, "Đã đủ" if level >= 3 else "%d xu" % (level * 600), func(): perform(func(): game.decorate(key)), level >= 3)
			card(list,"Mở rộng quán","Thêm phòng riêng, tầng biểu diễn và lẩu băng chuyền.","Xem các khu",func(): open_dialog.call_deferred("areas"))
		"staff":
			for item in [["chef", "Đầu bếp", "Tự nấu các món khách gọi."], ["waiter", "Phục vụ", "Tự mang đủ món ra bàn."], ["cashier", "Thu ngân", "Tự thu tiền sau khi khách ăn xong."], ["cleaner", "Tạp vụ", "Tự dọn bàn để đón khách mới."]]:
				var key: String = item[0]
				card(list, item[1], item[2], "Đã thuê" if game.state.staff[key] else "%d xu" % game.balance.staff_costs[key], func(): perform(func(): game.buy(key)), game.state.staff[key])
				if game.state.staff[key]:
					var level = int(game.state.staff_levels[key])
					card(list,"Đào tạo " + item[1],"Cấp %d/5 · tăng hiệu quả làm việc và điểm phục vụ." % level,"Tối đa" if level >= 5 else "Học %d xu" % ((level + 1) * 350),func(): perform(func(): game.train_staff(key)),level >= 5)
		"market":
			card(list, "Giỏ nguyên liệu tươi", "+30 phần nguyên liệu để nấu ăn.", "%d xu" % (30 * game.balance.stock_unit_cost), func(): perform(func(): game.buy("stock")))
			card(list, "Thêm bếp nấu", "Đang có %d/3 bếp làm món cùng lúc." % game.state.stoves, "Đã đủ" if game.state.stoves >= 3 else "%d xu" % (game.state.stoves * 300), func(): perform(func(): game.buy("stove")), game.state.stoves >= 3)
			card(list, "Chuẩn bị nước dùng", "Cấp %d/3 · nấu món nhanh hơn." % game.state.speed, "Đã đủ" if game.state.speed >= 3 else "%d xu" % ((game.state.speed + 1) * 180), func(): perform(func(): game.buy("speed")), game.state.speed >= 3)
			if game.state.stock < 1 and game.state.money < 120:
				card(list, "Mẹ tiếp tế", "10 phần nguyên liệu khi quán gặp khó.", "Nhận giỏ", func(): perform(func(): game.rescue()), game.state.rescue_day == game.day())
		"goals":
			var task_scores = game.ratings()
			card(list,game.rank(),"Hạng %d/19 · Cơ sở %d · phục vụ %d · món %d" % [game.rank_id(),task_scores.facility,task_scores.service,task_scores.food],"Xem tiệm",func(): open_dialog.call_deferred("journal"))
			for task in game.tasks:
				var progress = mini(game.task_progress(task),int(task.target))
				var done = game.can_claim_task(task)
				var claimed = game.state.tasks_claimed.has(int(task.id))
				var task_id = int(task.id)
				card(list,task.name,"Tiến độ %d/%d · thưởng gốc %d xu." % [progress,task.target,task.reward],"Đã nhận" if claimed else "Nhận %d xu" % task.reward,func(): perform(func(): game.claim_task(task_id)),claimed or not done)
		"journal":
			if game.state.offline_claim > 0:
				card(list,"Quán vẫn đỏ lửa","Nhân viên đã trông quán lúc bạn vắng mặt.","Nhận %d xu" % game.state.offline_claim,func(): perform(func(): game.claim_offline()))
			card(list,"Quà mở cửa mỗi ngày","Chuỗi %d/7 ngày · nhận xu và nguyên liệu." % game.state.daily_streak,"Đã nhận" if game.state.daily_day == game.calendar_day() else "Nhận quà",func(): perform(func(): game.claim_daily()),game.state.daily_day == game.calendar_day())
			var score = game.ratings()
			card(list,game.rank(),"Cơ sở: %d · phục vụ: %d · món ăn: %d" % [score.facility,score.service,score.food],"Mở rộng",func(): open_dialog.call_deferred("areas"))
			card(list, "Thành tích của quán", "%d bàn đã ăn ngon · %d xu đã kiếm được." % [game.state.served, game.state.income], "Nhiệm vụ", func(): open_dialog.call_deferred("goals"))
			for entry in game.state.journal:
				var line = text(str(entry), 17)
				line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				list.add_child(line)
			if not OS.has_feature("web"):
				card(list, "Bản lưu trên máy", "Tự lưu mỗi 5 giây, có giữ bản trước đó.", "Mở thư mục", func(): OS.shell_open(OS.get_user_data_dir()))
			else:
				var save_hint = text("Quán được tự lưu trong trình duyệt bạn đang dùng.",17)
				save_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				list.add_child(save_hint)
			card(list, "Bắt đầu một tiệm mới", "Tiến trình hiện tại sẽ được thay thế khi xác nhận.", "Chơi lại", func(): open_dialog.call_deferred("reset"))
		"reset":
			var description = text("Bạn muốn mở một quán mới? Đóng cửa sổ này để giữ quán hiện tại.", 20)
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			list.add_child(description)
			list.add_child(button("Xác nhận bắt đầu lại", func(): game.new_game(); selected = 0; game.arrive(); close_dialog(); dirty = true; if not test_mode: game.save_game(), true))
		"help":
			var help_text = "1. Chạm bàn khách để xem món được gọi.\n\n2. Nấu đơn, chờ bếp hoàn tất rồi Phục vụ.\n\n3. Khách ăn xong: Thu tiền, sau đó Dọn bàn.\n\n4. Học và nâng cấp món trong Thực đơn; thêm bàn, sàn, tường trong Nội thất.\n\n5. Thuê đầu bếp, phục vụ, thu ngân và tạp vụ để quán tự vận hành.\n\n6. Chuyển giữa Đại sảnh, Nhà bếp và Ngoài quán bằng ba nút phía trên.\n\nQuán được tự lưu. Nhấn dấu cách để tạm nghỉ; Esc để đóng cửa sổ."
			help_text += "\n\n7. Chọn KHU VỰC để ghé phòng riêng, tầng biểu diễn và lẩu băng chuyền. Phục vụ khách và tích xu để mở cửa từng khu.\n\n8. Dùng +/− để nhìn gần hơn; lăn chuột hoặc giữ chuột phải và kéo để di chuyển góc nhìn.\n\n9. Ghé Sổ quán để nhận quà mở cửa, tiền quán kiếm được khi vắng mặt và xem điểm xếp hạng."
			var help_label = text(help_text, 21)
			help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			list.add_child(help_label)

func card(parent: VBoxContainer, title: String, description: String, action_text: String, action: Callable, disabled := false) -> void:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color("f4e0b5"), Color("d4ac76"), 10, 1))
	parent.add_child(p)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_label = text(title, 20, RED)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_label)
	var desc = text(description, 16)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var b = button(action_text, action, true)
	b.custom_minimum_size.x = 125
	b.disabled = disabled
	h.add_child(b)

func menu_dialog(list: VBoxContainer) -> void:
	var catalog = preload("res://scripts/recipe_menu.gd").new()
	list.add_child(catalog)
	catalog.setup(self,dialog_kind == "research")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if dialog_kind != "": close_dialog()
		else: control_action("pause")
	elif event.keycode == KEY_SPACE:
		if dialog_kind == "": control_action("pause")
	elif event.keycode == KEY_M:
		open_dialog("market")
	elif event.keycode == KEY_N:
		open_dialog("decor")

func zoom_room(multiplier: float) -> void:
	view.scale = Vector2.ONE * clampf(view.scale.x * multiplier,0.16,0.9)
	dirty = true

func _unhandled_input(event: InputEvent) -> void:
	if dialog_kind != "": return
	if event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
		view.position += event.relative
		view.position.x = clampf(view.position.x,120,600)
		view.position.y = clampf(view.position.y,0,game_stage.size.y)
		dirty = true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			view.position.y = clampf(view.position.y + (60 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -60),0,game_stage.size.y)
			dirty = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game and not test_mode: game.save_game()
		get_tree().quit()

func capture_scene() -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../../work/native-game.png")
	get_tree().quit()
