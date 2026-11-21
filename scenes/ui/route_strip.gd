class_name RouteStrip
extends Control
## Faixa da rota: um trilho com as estações marcadas e o trenzinho andando.
## Lê só os dados que a HUD passa (nomes, alcançadas, progresso do trecho).

var station_names: PackedStringArray = []
var reached: int = 0
## Progresso dentro do trecho atual (0 a 1).
var progress: float = 0.0
var accent: Color = HudSkin.BRASS

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	custom_minimum_size.y = 44.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_route(names: PackedStringArray, reached_count: int, segment_progress: float) -> void:
	# só redesenha quando o trenzinho anda pelo menos meio pixel
	var changed := names != station_names or reached_count != reached or absf(segment_progress - progress) * size.x / maxf(1.0, names.size()) > 0.5
	station_names = names
	reached = reached_count
	progress = clampf(segment_progress, 0.0, 1.0)
	if changed:
		queue_redraw()


func set_accent(c: Color) -> void:
	accent = c
	queue_redraw()


func _x_of(pos: float) -> float:
	var n := maxf(1.0, station_names.size())
	return 16.0 + (size.x - 32.0) * pos / n


func _draw() -> void:
	var ink := HudSkin.INK
	var y := 14.0
	var n := station_names.size()
	# trilho: dormentes e dois trilhos
	var x := 16.0
	while x < size.x - 16.0:
		HudSkin.rect(self, Rect2(x, y - 5, 5, 10), Color(0.20, 0.19, 0.19))
		x += 12.0
	HudSkin.line(self, Vector2(16, y - 3), Vector2(size.x - 16, y - 3), HudSkin.METAL, 2.0)
	HudSkin.line(self, Vector2(16, y + 3), Vector2(size.x - 16, y + 3), HudSkin.METAL, 2.0)
	# trecho já percorrido
	var pos := minf(float(reached) + progress, float(n))
	HudSkin.line(self, Vector2(16, y), Vector2(_x_of(pos), y), accent, 4.0)
	# partida
	HudSkin.ink_circle(self, Vector2(16, y), 5.0, HudSkin.CREAM, 2.0)
	for i in n:
		var p := Vector2(_x_of(i + 1.0), y)
		var done := i < reached
		HudSkin.ink_circle(self, p, 7.0, accent if done else HudSkin.CREAM, 2.5)
		if done:
			HudSkin.line(self, p + Vector2(-3, 0), p + Vector2(-1, 3), ink, 2.0)
			HudSkin.line(self, p + Vector2(-1, 3), p + Vector2(4, -3), ink, 2.0)
		var label := station_names[i]
		var w := 90.0
		var col := HudSkin.CREAM if done or i == reached else Color(HudSkin.CREAM, 0.6)
		if _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= w - 4.0:
			draw_string(_font, Vector2(p.x - w / 2.0, y + 26.0), label, HORIZONTAL_ALIGNMENT_CENTER, w, 11, col)
		else:   # nome comprido ("Deserto de Ferrugem"): quebra em duas linhas
			var words := label.split(" ")
			var half := ceili(words.size() / 2.0)
			var l1 := " ".join(words.slice(0, half))
			var l2 := " ".join(words.slice(half))
			draw_string(_font, Vector2(p.x - w / 2.0, y + 22.0), l1, HORIZONTAL_ALIGNMENT_CENTER, w, 10, col)
			draw_string(_font, Vector2(p.x - w / 2.0, y + 33.0), l2, HORIZONTAL_ALIGNMENT_CENTER, w, 10, col)
	# trenzinho
	var tx := _x_of(pos)
	var body := Rect2(tx - 12, y - 14, 20, 10)
	HudSkin.rect(self, body.grow(2), ink)
	HudSkin.rect(self, body, HudSkin.WINE_LIGHT)
	HudSkin.rect(self, Rect2(tx + 2, y - 20, 5, 7).grow(1.5), ink)
	HudSkin.rect(self, Rect2(tx + 2, y - 20, 5, 7), HudSkin.CHARCOAL)
	HudSkin.rect(self, Rect2(tx - 12, y - 18, 8, 6).grow(1.5), ink)
	HudSkin.rect(self, Rect2(tx - 12, y - 18, 8, 6), HudSkin.WINE)
	HudSkin.ink_circle(self, Vector2(tx - 7, y - 3), 3.0, HudSkin.BRASS, 1.5)
	HudSkin.ink_circle(self, Vector2(tx + 4, y - 3), 3.0, HudSkin.BRASS, 1.5)
