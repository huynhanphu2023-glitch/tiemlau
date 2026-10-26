extends VBoxContainer
## Paginated catalog: only the current page creates controls and loads thumbnails.
const PAGE_SIZE = 24
var ui
var game
var research := false
var cards: VBoxContainer
var page_label: Label
var previous: Button
var next: Button

func setup(ui_, research_only := false) -> void:
	ui = ui_
	game = ui.game
	research = research_only
	add_theme_constant_override("separation",10)
	var search = LineEdit.new()
	search.name = "RecipeSearch"
	search.placeholder_text = "Tìm món ăn, đồ uống, nước lẩu…"
	search.text = ui.menu_query
	search.custom_minimum_size.y = 46
	search.add_theme_font_size_override("font_size",19)
	search.add_theme_color_override("font_color",ui.INK)
	search.add_theme_color_override("font_placeholder_color",Color("98764e"))
	search.add_theme_stylebox_override("normal",ui.box(Color("fffbeb")))
	search.add_theme_stylebox_override("focus",ui.box(Color("fffbeb"),ui.RED))
	add_child(search)
	search.text_changed.connect(func(value): ui.menu_query = value; ui.menu_page = 0; populate())
	var filters = HBoxContainer.new()
	filters.add_theme_constant_override("separation",10)
	add_child(filters)
	var types = OptionButton.new()
	types.name = "RecipeCategory"
	types.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	types.custom_minimum_size.y = 42
	types.add_theme_font_size_override("font_size",18)
	types.add_theme_color_override("font_color",ui.INK)
	types.add_theme_color_override("font_hover_color",ui.INK)
	types.add_theme_stylebox_override("normal",ui.box(Color("ffebbf")))
	types.add_theme_stylebox_override("hover",ui.box(Color("ffdf9d")))
	for entry in [["Tất cả món",0],["Thịt",1],["Rau & mì",2],["Món ăn kèm",3],["Đồ uống",4],["Hải sản",5],["Nước lẩu",6]]:
		types.add_item(entry[0],entry[1])
	types.select(int(ui.menu_category))
	filters.add_child(types)
	types.item_selected.connect(func(index): ui.menu_category = types.get_item_id(index); ui.menu_page = 0; populate())
	if not research:
		var known = CheckButton.new()
		known.text = "Đã học"
		known.button_pressed = ui.menu_known_only
		known.add_theme_font_size_override("font_size",17)
		known.add_theme_color_override("font_color",ui.INK)
		known.add_theme_color_override("font_hover_color",ui.INK)
		filters.add_child(known)
		known.toggled.connect(func(value): ui.menu_known_only = value; ui.menu_page = 0; populate())
	var pager = HBoxContainer.new()
	add_child(pager)
	previous = ui.button("‹",func(): ui.menu_page -= 1; populate())
	previous.custom_minimum_size.x = 55
	pager.add_child(previous)
	page_label = ui.text("",17)
	page_label.name = "RecipePage"
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pager.add_child(page_label)
	next = ui.button("›",func(): ui.menu_page += 1; populate())
	next.custom_minimum_size.x = 55
	pager.add_child(next)
	cards = VBoxContainer.new()
	cards.name = "RecipeCards"
	cards.add_theme_constant_override("separation",9)
	add_child(cards)
	populate()

func normalized(value: String) -> String:
	var result = value.to_lower()
	var groups = ["àáạảãâầấậẩẫăằắặẳẵ", "èéẹẻẽêềếệểễ", "ìíịỉĩ", "òóọỏõôồốộổỗơờớợởỡ", "ùúụủũưừứựửữ", "ỳýỵỷỹ", "đ"]
	var letters = ["a","e","i","o","u","y","d"]
	for i in groups.size():
		for c in groups[i]: result = result.replace(c,letters[i])
	return result.strip_edges()

func populate() -> void:
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	var query = normalized(ui.menu_query)
	var filtered: Array = []
	for recipe in game.recipes:
		var unlocked = game.state.unlocked.has(int(recipe.id))
		if research and unlocked or not research and ui.menu_known_only and not unlocked: continue
		if ui.menu_category > 0 and int(recipe.get("type",1)) != ui.menu_category: continue
		if query != "" and not str(recipe.get("search",recipe.name.to_lower())).contains(query): continue
		filtered.append(recipe)
	var pages = maxi(1,ceili(filtered.size() / float(PAGE_SIZE)))
	ui.menu_page = clampi(ui.menu_page,0,pages-1)
	page_label.text = "%d món · trang %d/%d" % [filtered.size(),ui.menu_page+1,pages]
	previous.disabled = ui.menu_page == 0
	next.disabled = ui.menu_page == pages-1
	if filtered.is_empty(): cards.add_child(ui.text("Chưa tìm thấy món phù hợp.",18))
	for index in range(ui.menu_page * PAGE_SIZE,mini((ui.menu_page+1) * PAGE_SIZE,filtered.size())):
		var recipe = filtered[index]
		var id = int(recipe.id)
		var unlocked = game.state.unlocked.has(id)
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel",ui.box(Color("f4e0b5"),Color("d4ac76"),10,1))
		cards.add_child(p)
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation",12)
		p.add_child(h)
		h.add_child(ui.image(recipe.icon,72))
		var v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var name_label = ui.text(recipe.name,20,ui.RED)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(name_label)
		var level = int(game.state.recipe_levels.get(str(id),0))
		v.add_child(ui.text("%d xu · %.1f giây · %s" % [game.price(id),recipe.cook_seconds,"★".repeat(level+1)],15))
		if unlocked:
			var actions = VBoxContainer.new()
			h.add_child(actions)
			actions.add_child(ui.button("Nấu món",func():
				if game.cook(id): ui.notify("Đã đưa món vào bếp.")
				ui.dirty = true))
			var upgrade = ui.button("Tăng sao %d xu" % ((level+1)*150),func(): ui.perform(func(): game.upgrade_recipe(id)),true)
			upgrade.disabled = level >= recipe.prices.size()-1
			actions.add_child(upgrade)
		else:
			h.add_child(ui.button("Học %d xu" % recipe.unlock_cost,func(): ui.perform(func(): game.unlock_recipe(id)),true))
