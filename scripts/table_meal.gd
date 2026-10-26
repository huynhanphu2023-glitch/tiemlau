extends Node2D
const Art = preload("res://scripts/original_art.gd")
var customer: Dictionary = {}
var game
var pot
var elapsed := 0.0
const PLATES = [Vector2(-63, -40), Vector2(68, -40), Vector2(-60, 28), Vector2(71, 31)]
func setup(game_) -> void:
	game = game_
	pot = Art.new()
	add_child(pot)
	pot.setup(JSON.parse_string(FileAccess.get_file_as_string("res://data/table_pot.json")))
func set_customer(c: Dictionary) -> void:
	customer = c
	visible = not c.is_empty() and c.phase in ["waiting", "eating", "bill", "dirty"]
	queue_redraw()
func _process(delta: float) -> void:
	if visible:
		elapsed += delta
		queue_redraw()
func _draw() -> void:
	if customer.is_empty(): return
	if customer.phase in ["eating", "bill", "dirty"]:
		for i in mini(4, customer.order.size()):
			var recipe = game.by_id[int(customer.order[i].recipe)]
			if recipe.scene != "":
				draw_texture_rect(Art.texture(recipe.scene), Rect2(PLATES[i] - Vector2(31, 18), Vector2(62, 36)), false)
	if customer.phase in ["waiting", "eating"]:
		for i in 3:
			var t = fmod(elapsed * 0.4 + i * 0.33, 1.0)
			draw_circle(Vector2(-12 + i * 12 + sin(elapsed * 2 + i) * 4, -18 - t * 40), 3 + t * 6, Color(1, 0.96, 0.85, (1 - t) * 0.35))
