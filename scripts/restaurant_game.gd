extends RefCounted
## Replacement gameplay. Original appearance/data are kept separately in art/ and data/original/.
## This class has no UI dependencies and can be exercised by headless Godot.
signal changed
signal message(text: String)
signal received_money(amount: int, table: int)
var balance: Dictionary
var recipes: Array
var tasks: Array
var rooms: Dictionary
var ranks: Array
var by_id: Dictionary = {}
var state: Dictionary
var auto_timer := 0.0
var paused := false
var customer_names = ["Cô Lan", "Anh Minh", "Chị Mai", "Chú Bảy", "Bạn Linh", "Cô Hạnh", "Anh Nam", "Chị Thảo"]

func _init() -> void:
	balance = read_json("res://data/balance.json")
	recipes = read_json("res://data/recipes.json")
	tasks = read_json("res://data/tasks.json")
	rooms = read_json("res://data/rooms.json")
	for key in rooms: rooms[key].indices = rooms[key].indices.map(func(i): return int(i))
	ranks = read_json("res://data/ranks.json")
	for recipe in recipes:
		by_id[int(recipe.id)] = recipe
	new_game()

static func read_json(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var parser = JSON.new()
	return parser.data if parser.parse(file.get_as_text().trim_prefix("\ufeff")) == OK else null

func new_game() -> void:
	state = {"version": 5, "money": int(balance.starting_money), "stock": int(balance.starting_stock), "elapsed": 0.0, "served": 0, "lost": 0, "income": 0, "next_id": 1, "spawn_in": 1.0, "table_count": 2, "stoves": 1, "speed": 0, "goal": 0, "unlocked": balance.starting_recipes.duplicate(), "recipe_levels": {}, "staff": {"chef": false, "waiter": false, "cashier": false, "cleaner": false}, "styles": {"tables": 1, "floor": 1, "wall": 1, "counter": 1, "decoration": 1}, "tables": [{}, {}, {}, {}], "queue": [], "jobs": [], "ready": {}, "journal": ["Mở cửa một tiệm lẩu nhỏ. Nấu một bữa ngon để bắt đầu nhé!"], "rescue_day": 0}
	state.unlocked = state.unlocked.map(func(id): return int(id))
	state.areas = {"private": false, "theatre": false, "buffet": false}
	state.staff_levels = {"chef": 0, "waiter": 0, "cashier": 0, "cleaner": 0}
	state.daily_day = 0
	state.daily_streak = 0
	state.last_saved_at = 0
	state.offline_claim = 0
	state.tasks_claimed = []
	state.task_actions = {"called":0,"dishes_served":0,"cooked":0}
	while state.tables.size() < 15: state.tables.append({})

func day() -> int:
	return int(state.elapsed / balance.day_seconds) + 1

func calendar_day() -> int:
	return int(Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system()) / 86400)

func rank() -> String:
	return str(ranks[rank_id() - 1].label)

func rank_id() -> int:
	var score = ratings()
	var current = 1
	for r in ranks:
		if score.facility >= int(r.facilityRating) and score.service >= int(r.serviceScore) and score.food >= int(r.foodScore):
			current = int(r.id)
	return current

func task_progress(task: Dictionary) -> int:
	match str(task.kind):
		"served": return int(state.served)
		"learned": return maxi(0,state.unlocked.size() - balance.starting_recipes.size())
		"upgrades":
			var total := 0
			for level in state.recipe_levels.values(): total += int(level)
			return total
		"facility": return int(ratings().facility)
		"service": return int(ratings().service)
		"food": return int(ratings().food)
		"rank": return rank_id()
		"called": return int(state.task_actions.called)
		"dishes_served": return int(state.task_actions.dishes_served)
		"cooked": return int(state.task_actions.cooked)
	return 0

func can_claim_task(task: Dictionary) -> bool:
	return not state.tasks_claimed.has(int(task.id)) and task_progress(task) >= int(task.target)

func claim_task(task_id: int) -> bool:
	var task: Dictionary = {}
	for entry in tasks:
		if int(entry.id) == task_id: task = entry; break
	if task.is_empty() or not can_claim_task(task): return false
	state.tasks_claimed.append(task_id)
	state.money += int(task.reward)
	log_event(task.name + " · nhận %d xu." % task.reward)
	message.emit("Hoàn thành nhiệm vụ! +%d xu." % task.reward)
	changed.emit()
	return true

func ratings() -> Dictionary:
	var facility = state.table_count * 40
	for level in state.styles.values(): facility += (int(level) - 1) * 120
	for key in rooms:
		if state.areas[key]: facility += 200
	var service = 0
	for key in state.staff:
		if state.staff[key]: service += 24 + int(state.staff_levels[key]) * 16
	var food = 0
	for id in state.unlocked:
		food += 9 + int(state.recipe_levels.get(str(id),0)) * 6
	return {"facility": facility, "service": service, "food": food}

func active_tables() -> Array:
	var active: Array = range(int(state.table_count))
	for key in rooms:
		if state.areas[key]:
			for i in rooms[key].indices: active.append(int(i))
	return active

func table_area(index: int) -> String:
	for key in rooms:
		if rooms[key].indices.has(index): return key
	return "hall"

func open_area(key: String) -> bool:
	if not rooms.has(key) or state.areas[key]: return false
	var room = rooms[key]
	if state.served < int(room.served):
		message.emit("Cần phục vụ %d bàn để mở khu này." % room.served)
		return false
	if not purchase(int(room.cost)): return false
	state.areas[key] = true
	state.spawn_in = 0.1
	log_event("Mở cửa " + room.name + ". Quán mình lớn thêm rồi!")
	changed.emit()
	return true

func train_staff(key: String) -> bool:
	if not state.staff.get(key, false) or int(state.staff_levels[key]) >= 5: return false
	var level = int(state.staff_levels[key])
	if not purchase((level + 1) * 350): return false
	state.staff_levels[key] = level + 1
	changed.emit()
	return true

func claim_daily() -> bool:
	var today = calendar_day()
	if state.daily_day == today: return false
	state.daily_streak = mini(7, state.daily_streak + 1) if state.daily_day == today - 1 else 1
	state.daily_day = today
	var amount = 100 + int(state.daily_streak) * 50
	state.money += amount
	state.stock += 10
	message.emit("Quà mở cửa: +%d xu, +10 nguyên liệu!" % amount)
	changed.emit()
	return true

func claim_offline() -> bool:
	if state.offline_claim < 1: return false
	state.money += state.offline_claim
	message.emit("Quán đã kiếm thêm %d xu khi bạn vắng mặt." % state.offline_claim)
	state.offline_claim = 0
	changed.emit()
	return true

func price(id: int) -> int:
	var level = int(state.recipe_levels.get(str(id), 0))
	var prices = by_id[id].prices
	return int(prices[mini(level, prices.size() - 1)])

func tick(dt: float) -> void:
	if paused:
		return
	state.elapsed += dt
	state.spawn_in -= dt
	if state.spawn_in <= 0:
		arrive()
		state.spawn_in = float(balance.arrival_seconds) * randf_range(0.8, 1.2)
	var complete: Array = []
	for i in range(mini(state.stoves, state.jobs.size())):
		state.jobs[i].remaining -= dt
		if state.jobs[i].remaining <= 0:
			complete.append(state.jobs[i])
	for job in complete:
		state.task_actions.cooked += 1
		var key = str(int(job.recipe))
		state.ready[key] = int(state.ready.get(key, 0)) + 1
		state.jobs.erase(job)
	if not complete.is_empty():
		changed.emit()
	var queue_changed := false
	for queue_index in range(state.queue.size() - 1, -1, -1):
		state.queue[queue_index].patience -= dt
		if state.queue[queue_index].patience <= 0:
			var guest: Dictionary = state.queue[queue_index]
			state.queue.remove_at(queue_index)
			state.lost += 1
			message.emit(guest.name + " đợi hết kiên nhẫn và ra về.")
			queue_changed = true
	if queue_changed:
		changed.emit()
	for i in active_tables():
		var c = state.tables[i]
		if c.is_empty():
			continue
		if c.phase == "waiting":
			c.patience -= dt
			if c.patience <= 0:
				c.phase = "leaving"
				c.time = 2.0
				state.lost += 1
				message.emit(c.name + " đã đợi lâu và ra về.")
				changed.emit()
		elif c.phase in ["walking", "eating", "leaving"]:
			c.time -= dt
			if c.time <= 0:
				if c.phase == "walking":
					c.phase = "waiting"
				elif c.phase == "eating":
					c.phase = "bill"
				else:
					state.tables[i] = {}
				changed.emit()
		elif c.phase == "dirty" and state.staff.cleaner:
			c.time -= dt
			if c.time <= 0:
				clean(i)
	seat_queued_guests()
	auto_timer += dt
	if auto_timer > 0.65:
		auto_timer = 0
		for i in active_tables():
			var c = state.tables[i]
			if c.is_empty():
				continue
			if c.phase == "waiting":
				if state.staff.chef:
					cook_order(i, true)
				if state.staff.waiter and can_serve(i):
					serve(i)
			elif c.phase == "bill" and state.staff.cashier:
				collect(i)

func arrive() -> void:
	seat_queued_guests()
	var options: Array = state.unlocked.duplicate()
	if options.is_empty():
		return
	options.shuffle()
	var count = 1 if state.served < 2 else mini(options.size(), randi_range(1, 3))
	var order: Array = []
	for j in count:
		order.append({"recipe": int(options[j]), "quantity": 1})
	var serial = state.next_id
	state.next_id += 1
	var guest = {"id": serial, "name": customer_names[(serial - 1) % customer_names.size()], "look": (serial - 1) % 8, "patience": float(balance.customer_wait_seconds), "order": order}
	if state.queue.size() >= int(balance.queue_limit):
		state.lost += 1
		message.emit(guest.name + " không tìm được chỗ chờ và ra về.")
	else:
		state.queue.append(guest)
		seat_queued_guests()
	changed.emit()

func seat_queued_guests() -> void:
	if state.queue.is_empty():
		return
	var changed_state := false
	for index in active_tables():
		if state.queue.is_empty():
			break
		if state.tables[index].is_empty():
			var guest: Dictionary = state.queue.pop_front()
			state.tables[index] = {"id": int(guest.id), "name": str(guest.name), "look": int(guest.look), "phase": "walking", "time": float(balance.walking_seconds), "patience": float(guest.patience), "order": guest.order, "bill": 0}
			changed_state = true
	if changed_state:
		changed.emit()

func cook(id: int, quiet := false) -> bool:
	if not state.unlocked.has(id) or not by_id.has(id):
		return false
	if state.stock < 1:
		if not quiet:
			message.emit("Hết nguyên liệu rồi. Ghé cửa hàng để mua thêm nhé!")
		return false
	if state.jobs.size() >= int(balance.job_limit):
		return false
	var duration = float(by_id[id].cook_seconds) / (1.0 + state.speed * 0.3 + int(state.staff_levels.chef) * 0.08)
	state.stock -= 1
	state.jobs.append({"recipe": id, "duration": duration, "remaining": duration})
	changed.emit()
	return true

func cook_order(index: int, quiet := false) -> void:
	var c = state.tables[index]
	if c.is_empty() or c.phase != "waiting":
		return
	var added = 0
	for item in c.order:
		var id = int(item.recipe)
		var pending = 0
		for job in state.jobs:
			if int(job.recipe) == id:
				pending += 1
		var missing = maxi(0, int(item.quantity) - int(state.ready.get(str(id), 0)) - pending)
		for j in missing:
			if cook(id, quiet):
				added += 1
	if not quiet:
		if added > 0: state.task_actions.called += 1
		message.emit("Đã đưa %d món vào bếp." % added if added else "Món đã sẵn sàng!" if can_serve(index) else "Bếp đang chuẩn bị đơn này.")

func can_serve(index: int) -> bool:
	var c = state.tables[index]
	if c.is_empty() or c.phase != "waiting":
		return false
	for item in c.order:
		if int(state.ready.get(str(int(item.recipe)), 0)) < int(item.quantity):
			return false
	return true

func serve(index: int) -> bool:
	if not can_serve(index):
		return false
	var c = state.tables[index]
	var bill = 0
	var dishes_served := 0
	for item in c.order:
		var id = int(item.recipe)
		state.ready[str(id)] -= int(item.quantity)
		bill += price(id) * int(item.quantity)
		dishes_served += int(item.quantity)
	state.task_actions.dishes_served += dishes_served
	var multiplier = float(rooms.get(table_area(index), {}).get("tip_multiplier",1.0))
	c.bill = int((bill + int(8 + 12 * c.patience / balance.customer_wait_seconds) + int(state.staff_levels.cashier) * 2) * multiplier)
	c.phase = "eating"
	c.time = float(balance.eating_seconds) / (1.0 + int(state.staff_levels.waiter) * 0.1)
	changed.emit()
	return true

func collect(index: int) -> bool:
	var c = state.tables[index]
	if c.is_empty() or c.phase != "bill":
		return false
	state.money += int(c.bill)
	state.income += int(c.bill)
	state.served += 1
	c.phase = "dirty"
	c.time = 2.8 / (1.0 + int(state.staff_levels.cleaner) * 0.2)
	log_event(c.name + " ăn ngon, gửi lại %d xu." % c.bill)
	received_money.emit(int(c.bill), index)
	changed.emit()
	return true

func clean(index: int) -> void:
	if not state.tables[index].is_empty() and state.tables[index].phase == "dirty":
		state.tables[index] = {}
		state.spawn_in = minf(state.spawn_in, 2.0)
		seat_queued_guests()
		changed.emit()

func act(index: int) -> void:
	if index < 4 and index >= state.table_count:
		buy("table")
		return
	if not active_tables().has(index): return
	var c = state.tables[index]
	if c.is_empty():
		message.emit("Bàn sạch đang chờ đón khách.")
	elif c.phase == "waiting":
		if can_serve(index):
			serve(index)
		else:
			cook_order(index)
	elif c.phase == "bill":
		collect(index)
	elif c.phase == "dirty":
		clean(index)

func purchase(cost: int) -> bool:
	if state.money < cost:
		message.emit("Cần thêm %d xu nữa nhé." % (cost - state.money))
		return false
	state.money -= cost
	return true

func buy(kind: String) -> bool:
	if kind == "stock":
		if not purchase(30 * int(balance.stock_unit_cost)):
			return false
		state.stock += 30
	elif kind == "table":
		if state.table_count >= 4 or not purchase(int(balance.table_costs[state.table_count])):
			return false
		state.table_count += 1
	elif kind == "stove":
		if state.stoves >= 3 or not purchase(state.stoves * 300):
			return false
		state.stoves += 1
	elif kind == "speed":
		if state.speed >= 3 or not purchase((state.speed + 1) * 180):
			return false
		state.speed += 1
	elif balance.staff_costs.has(kind):
		if state.staff[kind] or not purchase(int(balance.staff_costs[kind])):
			return false
		state.staff[kind] = true
	else:
		return false
	message.emit("Đã sẵn sàng! Quán mình lại tốt thêm một chút.")
	changed.emit()
	return true

func unlock_recipe(id: int) -> bool:
	if not by_id.has(id) or state.unlocked.has(id) or not purchase(int(by_id[id].unlock_cost)):
		return false
	state.unlocked.append(id)
	log_event("Học món mới: " + by_id[id].name)
	changed.emit()
	return true

func upgrade_recipe(id: int) -> bool:
	if not state.unlocked.has(id):
		return false
	var key = str(id)
	var level = int(state.recipe_levels.get(key, 0))
	if level >= by_id[id].prices.size() - 1 or not purchase((level + 1) * 150):
		return false
	state.recipe_levels[key] = level + 1
	changed.emit()
	return true

func decorate(category: String) -> bool:
	if not state.styles.has(category):
		return false
	var level = int(state.styles[category])
	if level >= 3 or not purchase(level * 600):
		return false
	state.styles[category] += 1
	changed.emit()
	return true

func claim_goal() -> bool:
	if state.goal >= balance.goals.size():
		return false
	var goal = balance.goals[state.goal]
	if state.served < goal.served:
		return false
	state.money += int(goal.reward)
	state.goal += 1
	message.emit("Hoàn thành nhiệm vụ! +%d xu." % goal.reward)
	changed.emit()
	return true

func rescue() -> bool:
	if state.stock < 1 and state.money < int(balance.stock_unit_cost) * 30 and state.rescue_day != day():
		state.stock += 10
		state.rescue_day = day()
		changed.emit()
		return true
	return false

func log_event(text: String) -> void:
	state.journal.push_front(text)
	if state.journal.size() > 40:
		state.journal.resize(40)

func validate(data) -> bool:
	if not data is Dictionary or data.get("version") != 5 or not data.get("tables") is Array or data.tables.size() != 15:
		return false
	for key in state.keys():
		if not data.has(key) or typeof(data[key]) != typeof(state[key]) and not (data[key] is float and state[key] is int) and not (data[key] is int and state[key] is float):
			return false
	for key in ["money", "stock", "elapsed", "served", "lost", "income", "next_id", "spawn_in", "goal", "rescue_day"]:
		if not is_finite(float(data[key])) or float(data[key]) < 0 or float(data[key]) > 1e9:
			return false
	if int(data.table_count) < 2 or int(data.table_count) > 4 or int(data.stoves) < 1 or int(data.stoves) > 3 or int(data.speed) < 0 or int(data.speed) > 3 or int(data.goal) > balance.goals.size():
		return false
	if data.unlocked.size() > recipes.size() or data.jobs.size() > int(balance.job_limit):
		return false
	if not data.queue is Array or data.queue.size() > int(balance.queue_limit): return false
	for guest in data.queue:
		if not guest is Dictionary or not guest.get("name") is String or not guest.get("order") is Array or guest.order.size() > 4:
			return false
		for key in ["id", "look", "patience"]:
			if not (guest.get(key) is int or guest.get(key) is float) or not is_finite(float(guest[key])) or float(guest[key]) < 0 or float(guest[key]) > 1e7:
				return false
		for item in guest.order:
			if not item is Dictionary or not by_id.has(int(item.get("recipe", -1))) or int(item.get("quantity", 0)) < 1 or int(item.get("quantity", 0)) > 5:
				return false
	for id in data.unlocked:
		if not by_id.has(int(id)):
			return false
	for t in data.tables:
		if not t is Dictionary:
			return false
		if t.is_empty():
			continue
		for key in ["id", "look", "phase", "time", "patience", "order", "bill", "name"]:
			if not t.has(key):
				return false
		if not t.phase in ["walking", "waiting", "eating", "bill", "dirty", "leaving"] or not t.order is Array or t.order.size() > 4:
			return false
		for item in t.order:
			if not item is Dictionary or not by_id.has(int(item.get("recipe", -1))) or int(item.get("quantity", 0)) < 1 or int(item.get("quantity", 0)) > 5:
				return false
		for key in ["time", "patience", "bill", "id", "look"]:
			if not (t[key] is float or t[key] is int) or not is_finite(float(t[key])) or absf(float(t[key])) > 1e7:
				return false
	for j in data.jobs:
		if not j is Dictionary or not by_id.has(int(j.get("recipe", -1))) or not j.has("duration") or not j.has("remaining") or float(j.duration) <= 0 or float(j.duration) > 100 or float(j.remaining) < 0 or float(j.remaining) > float(j.duration):
			return false
	for key in state.staff:
		if not data.staff.get(key) is bool:
			return false
	for key in state.styles:
		if int(data.styles.get(key, 0)) < 1 or int(data.styles[key]) > 3:
			return false
	for key in data.ready:
		if not by_id.has(int(key)) or not (data.ready[key] is float or data.ready[key] is int) or float(data.ready[key]) < 0 or float(data.ready[key]) > 999:
			return false
	for key in data.recipe_levels:
		if not by_id.has(int(key)) or int(data.recipe_levels[key]) < 0 or int(data.recipe_levels[key]) > 4:
			return false
	for key in state.areas:
		if not data.areas.get(key) is bool: return false
	for key in state.staff_levels:
		if not (data.staff_levels.get(key) is float or data.staff_levels.get(key) is int) or int(data.staff_levels[key]) < 0 or int(data.staff_levels[key]) > 5: return false
	for key in ["daily_day", "daily_streak", "last_saved_at", "offline_claim"]:
		if not (data[key] is float or data[key] is int) or not is_finite(float(data[key])) or float(data[key]) < 0 or float(data[key]) > 1e12: return false
	if int(data.daily_streak) > 7: return false
	if not data.tasks_claimed is Array or data.tasks_claimed.size() > tasks.size() or not data.task_actions is Dictionary: return false
	for key in ["called","dishes_served","cooked"]:
		if not data.task_actions.get(key) is int and not data.task_actions.get(key) is float: return false
		if int(data.task_actions[key]) < 0 or int(data.task_actions[key]) > 1e9: return false
	for id in data.tasks_claimed:
		if not tasks.any(func(task): return int(task.id) == int(id)): return false
	return true

func migrate(data):
	if data is Dictionary and data.get("version") in [2,3,4] and data.get("tables") is Array and data.tables.size() in [4,15]:
		var old_version = int(data.version)
		var defaults = {"areas":{"private":false,"theatre":false,"buffet":false},"staff_levels":{"chef":0,"waiter":0,"cashier":0,"cleaner":0},"daily_day":0,"daily_streak":0,"last_saved_at":0,"offline_claim":0,"queue":[]}
		for key in defaults:
			if old_version == 2 or not data.has(key): data[key] = defaults[key]
		while data.tables.size() < 15: data.tables.append({})
		if old_version < 4:
			if not data.has("tasks_claimed"): data.tasks_claimed=[]
			if not data.has("task_actions"): data.task_actions={"called":0,"dishes_served":0,"cooked":0}
		data.version=5
	return data

func load_game(path: String = "user://restaurant.json") -> bool:
	var data = migrate(read_json(path))
	if not validate(data):
		data = migrate(read_json(path + ".previous"))
	if not validate(data):
		return false
	state = data
	# JSON numbers arrive as floats; normalize identifiers used as dictionary keys.
	state.unlocked = state.unlocked.map(func(id): return int(id))
	for key in ["money", "stock", "served", "lost", "income", "next_id", "table_count", "stoves", "speed", "goal", "rescue_day", "daily_day", "daily_streak", "last_saved_at", "offline_claim"]:
		state[key] = int(state[key])
	for group in ["styles", "ready", "recipe_levels", "staff_levels"]:
		for key in state[group]:
			state[group][key] = int(state[group][key])
	state.tasks_claimed = state.tasks_claimed.map(func(id): return int(id))
	for key in state.task_actions: state.task_actions[key] = int(state.task_actions[key])
	for guest in state.queue:
		guest.id = int(guest.id)
		guest.look = int(guest.look)
		guest.patience = float(guest.patience)
		for item in guest.order:
			item.recipe = int(item.recipe)
			item.quantity = int(item.quantity)
	for job in state.jobs:
		job.recipe = int(job.recipe)
	for c in state.tables:
		if c.is_empty(): continue
		for key in ["id", "look", "bill"]: c[key] = int(c[key])
		for item in c.order:
			item.recipe = int(item.recipe)
			item.quantity = int(item.quantity)
	var seconds_away = clampf(Time.get_unix_time_from_system() - state.last_saved_at, 0, 10800) if state.last_saved_at > 0 else 0
	if seconds_away >= 60 and state.staff.chef and state.staff.waiter and state.staff.cashier:
		state.offline_claim += mini(3000, int(seconds_away / 30) * active_tables().size() * 6)
	state.last_saved_at = int(Time.get_unix_time_from_system())
	changed.emit()
	return true

func save_game(path: String = "user://restaurant.json") -> bool:
	state.last_saved_at = int(Time.get_unix_time_from_system())
	var temp = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if not temp:
		return false
	temp.store_string(JSON.stringify(state, "\t"))
	temp.close()
	var dir = DirAccess.open(path.get_base_dir())
	var name_ = path.get_file()
	if dir.file_exists(name_):
		# Keep the last valid save while replacing the main file atomically.
		if dir.file_exists(name_ + ".previous"):
			dir.remove(name_ + ".previous")
		if dir.rename(name_, name_ + ".previous") != OK:
			return false
	return dir.rename(name_ + ".tmp", name_) == OK
