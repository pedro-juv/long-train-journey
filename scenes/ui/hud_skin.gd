class_name HudSkin
extends RefCounted
## HudSkin — visual ferroviário da interface e a "pele" de cada estação do ano.
##
## Uma só HUD; o que muda por região é o acento de cor e a decoração desenhada
## nos painéis (engrenagens, flores, sol, folhas, geada). Usado pela HUD e pelo
## menu de opções. Só apresentação.

const INK := Color(0.13, 0.07, 0.07)
const CREAM := Color(0.98, 0.92, 0.78)
const CREAM_DARK := Color(0.86, 0.76, 0.58)
const WOOD := Color(0.42, 0.26, 0.14)
const WOOD_LIGHT := Color(0.58, 0.37, 0.20)
const WINE := Color(0.52, 0.11, 0.14)
const WINE_LIGHT := Color(0.74, 0.22, 0.22)
const BRASS := Color(0.92, 0.70, 0.30)
const BRASS_DARK := Color(0.62, 0.43, 0.17)
const CHARCOAL := Color(0.17, 0.15, 0.16)
const METAL := Color(0.60, 0.59, 0.58)

## Peles por tema de região (scenes/season_themes.gd).
##   accent  cor de destaque (bordas internas, barras, abas)
##   panel   madeira dos painéis (levemente tingida pela estação)
##   deco    decoração desenhada nos cantos
##   stamp   texto do carimbo no bilhete
const SKINS := {
	"inicio": {"accent": Color(0.92, 0.70, 0.30), "panel": Color(0.40, 0.25, 0.14), "deco": "gears", "stamp": "PARTIDA"},
	"primavera": {"accent": Color(0.55, 0.82, 0.38), "panel": Color(0.38, 0.26, 0.15), "deco": "flowers", "stamp": "PRIMAVERA"},
	"verao": {"accent": Color(1.0, 0.74, 0.22), "panel": Color(0.45, 0.27, 0.13), "deco": "sun", "stamp": "VERÃO"},
	"outono": {"accent": Color(0.97, 0.52, 0.18), "panel": Color(0.41, 0.21, 0.12), "deco": "leaves", "stamp": "OUTONO"},
	"inverno": {"accent": Color(0.66, 0.86, 1.0), "panel": Color(0.30, 0.25, 0.27), "deco": "frost", "stamp": "INVERNO"},
}


static func skin(theme_id: String) -> Dictionary:
	return SKINS.get(theme_id, SKINS["inicio"])


# ---------------------------------------------------------------------------
# Estilos (StyleBoxFlat): madeira, bilhete, placa esmaltada, botões de latão
# ---------------------------------------------------------------------------

static func box(bg: Color, border: Color, width: int, radius: int, margin: float = 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb


static func panel_style(theme_id: String) -> StyleBoxFlat:
	var sb := box(skin(theme_id)["panel"], INK, 4, 12, 16.0)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func ticket_style() -> StyleBoxFlat:
	var sb := box(CREAM, INK, 3, 6, 12.0)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func plate_style(bg: Color = WINE) -> StyleBoxFlat:
	var sb := box(bg, INK, 4, 12, 12.0)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	return sb


## Botão "gordinho" de desenho: borda de baixo mais grossa faz o relevo.
static func button_style(bg: Color, pressed: bool = false) -> StyleBoxFlat:
	var sb := box(bg, INK, 3, 9, 8.0)
	sb.border_width_bottom = 3 if pressed else 7
	sb.content_margin_top = 8.0 if pressed else 5.0
	sb.content_margin_bottom = 4.0
	return sb


## Tema completo da HUD para um acento (botões, abas, barras, textos).
static func make_theme(theme_id: String) -> Theme:
	var accent: Color = skin(theme_id)["accent"]
	var t := Theme.new()
	t.set_stylebox("normal", "Button", button_style(WOOD_LIGHT))
	t.set_stylebox("hover", "Button", button_style(WOOD_LIGHT.lightened(0.12)))
	t.set_stylebox("pressed", "Button", button_style(accent.darkened(0.15), true))
	t.set_stylebox("hover_pressed", "Button", button_style(accent, true))
	t.set_stylebox("disabled", "Button", button_style(Color(0.36, 0.31, 0.28)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.96, 0.84))
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.66, 0.60, 0.54))
	t.set_color("font_outline_color", "Button", INK)
	t.set_constant("outline_size", "Button", 3)
	var bar_bg := box(Color(0.10, 0.07, 0.06), INK, 2, 6, 0.0)
	var bar_fill := box(accent, INK, 2, 6, 0.0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", INK)
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(INK, 0.9))
	t.set_constant("outline_size", "Label", 0)
	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(0, 0, 0, 0.25)
	scroll.set_corner_radius_all(4)
	var grab := box(accent.darkened(0.1), INK, 1, 4, 0.0)
	t.set_stylebox("scroll", "VScrollBar", scroll)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(accent, INK, 1, 4, 0.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(accent.lightened(0.2), INK, 1, 4, 0.0))
	t.set_stylebox("panel", "TooltipPanel", box(CREAM, INK, 2, 6, 8.0))
	t.set_color("font_color", "TooltipLabel", INK)
	return t


# ---------------------------------------------------------------------------
# Decoração desenhada (no sinal draw do painel: por cima do fundo, por baixo do conteúdo)
# ---------------------------------------------------------------------------

static func round_rect_points(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [[r.position + Vector2(r.size.x - rad, rad), -PI / 2.0], [r.end - Vector2(rad, rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI / 2.0], [r.position + Vector2(rad, rad), PI]]
	for c in corners:
		for i in 5:
			var a: float = c[1] + i * (PI / 2.0) / 4.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	return pts


# ---------------------------------------------------------------------------
# Desenho em quads (mesma ideia da TrainView): tudo vira draw_primitive de 4
# pontos com a mesma textura de círculo, para a GPU desenhar em poucos lotes.
# ---------------------------------------------------------------------------

static var _dot: ImageTexture
static var UV_FULL := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
static var UV_FILL := PackedVector2Array([Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5)])


## Círculo branco suavizado (128 px, com mipmaps), gerado uma vez e compartilhado.
static func dot_texture() -> Texture2D:
	if _dot == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var half := n / 2.0
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - half, y + 0.5 - half).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(half - 1.0 - d, 0.0, 1.0)))
		img.generate_mipmaps()
		_dot = ImageTexture.create_from_image(img)
	return _dot


static func quad(ci: CanvasItem, p: PackedVector2Array, col: Color) -> void:
	ci.draw_primitive(p, PackedColorArray([col, col, col, col]), UV_FILL, dot_texture())


static func rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	quad(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), col)


static func circle(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_primitive(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r)]),
		PackedColorArray([col, col, col, col]), UV_FULL, dot_texture())


static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float = 1.0) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var nrm := d.normalized().orthogonal() * (w * 0.5)
	quad(ci, PackedVector2Array([a + nrm, b + nrm, b - nrm, a - nrm]), col)


static func polyline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float = 1.0) -> void:
	for i in range(pts.size() - 1):
		line(ci, pts[i], pts[i + 1], col, w)
	if w > 2.5:
		for i in range(1, pts.size() - 1):
			circle(ci, pts[i], w * 0.5, col)


static func arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, segs: int, col: Color, w: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in segs + 1:
		var a := a0 + (a1 - a0) * i / segs
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	polyline(ci, pts, col, w)


static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	match pts.size():
		3:
			quad(ci, PackedVector2Array([pts[0], pts[1], pts[2], pts[2]]), col)
		4:
			quad(ci, pts, col)
		_:
			ci.draw_colored_polygon(pts, col)


## Retângulo arredondado: 3 retângulos + 4 círculos.
static func rrect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	rect(ci, Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2.0, r.size.y), col)
	rect(ci, Rect2(r.position.x, r.position.y + rad, rad, r.size.y - rad * 2.0), col)
	rect(ci, Rect2(r.end.x - rad, r.position.y + rad, rad, r.size.y - rad * 2.0), col)
	for c in [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad), r.end - Vector2(rad, rad), Vector2(r.position.x + rad, r.end.y - rad)]:
		circle(ci, c, rad, col)


static func ink_rrect(ci: CanvasItem, r: Rect2, rad: float, fill: Color, w: float = 2.0) -> void:
	rrect(ci, r.grow(w), rad + w, INK)
	rrect(ci, r, rad, fill)


static func ink_circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, w: float = 2.0) -> void:
	circle(ci, c, r + w, INK)
	circle(ci, c, r, fill)


## Polígono deslocado para fora (contorno de formas convexas).
static func offset_poly(pts: PackedVector2Array, w: float) -> PackedVector2Array:
	var n := pts.size()
	var area := 0.0
	for i in n:
		area += pts[i].cross(pts[(i + 1) % n])
	var sgn := 1.0 if area > 0.0 else -1.0
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var e1 := (pts[i] - pts[(i - 1 + n) % n]).normalized()
		var e2 := (pts[(i + 1) % n] - pts[i]).normalized()
		if e1 == Vector2.ZERO:
			e1 = e2
		if e2 == Vector2.ZERO:
			e2 = e1
		var n1 := Vector2(e1.y, -e1.x) * sgn
		var nm := (n1 + Vector2(e2.y, -e2.x) * sgn).normalized()
		if nm == Vector2.ZERO:
			nm = n1
		out[i] = pts[i] + nm * (w / maxf(nm.dot(n1), 0.35))
	return out


static func ink_poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = 2.0) -> void:
	poly(ci, offset_poly(pts, w), INK)
	poly(ci, pts, fill)


static func ink_gear(ci: CanvasItem, c: Vector2, r_out: float, r_in: float, teeth: int, rot: float, fill: Color, w: float = 2.0) -> void:
	poly(ci, gear_points(c, r_out + w, r_in + w, teeth, rot), INK)
	poly(ci, gear_points(c, r_out, r_in, teeth, rot), fill)


static func gear_points(c: Vector2, r_out: float, r_in: float, teeth: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in teeth * 4:
		var a := rot + i * TAU / (teeth * 4)
		pts.append(c + Vector2(cos(a), sin(a)) * (r_out if (i % 4) in [1, 2] else r_in))
	return pts


## Moldura interna, rebites e a decoração da estação nos cantos de um painel de madeira.
static func draw_panel_decor(ci: CanvasItem, size: Vector2, theme_id: String) -> void:
	var sk := skin(theme_id)
	var accent: Color = sk["accent"]
	var r := Rect2(Vector2.ZERO, size)
	polyline(ci, round_rect_points(r.grow(-8), 7.0), Color(accent, 0.75), 2.0)
	# veio da madeira
	var grain := Color(0, 0, 0, 0.10)
	var y := 26.0
	while y < size.y - 14.0:
		line(ci, Vector2(14, y), Vector2(size.x - 14, y + 3.0), grain, 2.0)
		y += 38.0
	for p in [Vector2(14, 14), Vector2(size.x - 14, 14), Vector2(14, size.y - 14), Vector2(size.x - 14, size.y - 14)]:
		ink_circle(ci, p, 3.5, BRASS, 1.5)
	draw_season_ornament(ci, size, theme_id)


## Ornamentos por estação (cantos e borda de cima). Cada pele tem os seus.
static func draw_season_ornament(ci: CanvasItem, size: Vector2, theme_id: String) -> void:
	var accent: Color = skin(theme_id)["accent"]
	match skin(theme_id)["deco"]:
		"gears":
			ink_gear(ci, Vector2(size.x - 6, 6), 17, 12, 9, 0.3, BRASS, 2.0)
			ink_circle(ci, Vector2(size.x - 6, 6), 5.0, BRASS_DARK, 1.5)
			ink_gear(ci, Vector2(size.x - 28, -2), 10, 7, 8, 0.1, METAL, 2.0)
		"flowers":
			for f in [[Vector2(4, 6), 1.0, Color(1.0, 0.62, 0.78)], [Vector2(24, -2), 0.75, Color(1.0, 0.95, 0.98)],
					[Vector2(size.x - 8, size.y - 6), 1.0, Color(1.0, 0.85, 0.30)], [Vector2(size.x - 30, size.y + 1), 0.7, Color(1.0, 0.62, 0.78)]]:
				_flower(ci, f[0], f[1], f[2], accent)
		"sun":
			var c := Vector2(size.x - 10, 8)
			for i in 10:
				var a := i * TAU / 10.0
				var d := Vector2(cos(a), sin(a))
				ink_poly(ci, PackedVector2Array([c + d * 14.0 + d.orthogonal() * 4.0, c + d * 25.0, c + d * 14.0 - d.orthogonal() * 4.0]), accent, 1.5)
			ink_circle(ci, c, 13.0, Color(1.0, 0.88, 0.35), 2.0)
			arc(ci, c + Vector2(0, 2), 6.0, 0.4, PI - 0.4, 6, INK, 2.0)
		"leaves":
			_leaf(ci, Vector2(8, 4), 0.6, Color(0.97, 0.52, 0.18))
			_leaf(ci, Vector2(26, -2), -0.4, Color(0.82, 0.25, 0.12))
			_leaf(ci, Vector2(size.x - 10, size.y - 4), 2.4, Color(0.98, 0.76, 0.22))
		"frost":
			# neve acumulada na borda de cima e pingentes de gelo
			var x := 6.0
			var i := 0
			while x < size.x - 6.0:
				var rr := 7.0 + float((i * 7) % 5)
				circle(ci, Vector2(x, 1), rr + 2.0, Color(0.55, 0.68, 0.85))
				x += rr * 1.5
				i += 1
			x = 6.0
			i = 0
			while x < size.x - 6.0:
				var rr := 7.0 + float((i * 7) % 5)
				circle(ci, Vector2(x, 0), rr, Color(0.96, 0.98, 1.0))
				x += rr * 1.5
				i += 1
			for k in range(1, 6):
				var ix := size.x * k / 6.0
				var length := 10.0 + float((k * 5) % 9)
				ink_poly(ci, PackedVector2Array([Vector2(ix - 4, 5), Vector2(ix + 4, 5), Vector2(ix, 5 + length)]), Color(0.82, 0.93, 1.0), 1.2)


static func _flower(ci: CanvasItem, c: Vector2, sc: float, petal: Color, leaf: Color) -> void:
	ink_poly(ci, PackedVector2Array([c + Vector2(4, 4) * sc, c + Vector2(18, 10) * sc, c + Vector2(8, 14) * sc]), leaf, 1.5)
	for i in 5:
		var a := i * TAU / 5.0 - PI / 2.0
		ink_circle(ci, c + Vector2(cos(a), sin(a)) * 7.0 * sc, 5.0 * sc, petal, 1.5)
	ink_circle(ci, c, 4.0 * sc, Color(1.0, 0.82, 0.25), 1.5)


static func _leaf(ci: CanvasItem, c: Vector2, rot: float, col: Color) -> void:
	var u := Vector2(cos(rot), sin(rot)) * 13.0
	var v := u.orthogonal() * 0.5
	ink_poly(ci, PackedVector2Array([c - u, c - u * 0.2 + v, c + u, c - u * 0.2 - v]), col, 1.5)
	line(ci, c - u, c + u * 0.7, col.darkened(0.35), 1.5)


## Carimbo redondo da estação no bilhete (ícone da estação no meio).
static func draw_stamp(ci: CanvasItem, c: Vector2, theme_id: String, font: Font) -> void:
	var sk := skin(theme_id)
	var col := Color(WINE_LIGHT if theme_id != "inverno" else Color(0.25, 0.42, 0.70), 0.75)
	arc(ci, c, 30.0, 0, TAU, 32, col, 2.5)
	arc(ci, c, 24.0, 0, TAU, 32, col, 1.5)
	var text: String = sk["stamp"]
	ci.draw_string(font, c + Vector2(-30, 21), text, HORIZONTAL_ALIGNMENT_CENTER, 60, 8, col)
	match sk["deco"]:
		"gears":
			poly(ci, gear_points(c + Vector2(0, -3), 11, 8, 8, 0.0), col)
			circle(ci, c + Vector2(0, -3), 3.5, CREAM)
		"flowers":
			for i in 5:
				var a := i * TAU / 5.0 - PI / 2.0
				circle(ci, c + Vector2(0, -3) + Vector2(cos(a), sin(a)) * 6.0, 4.0, col)
			circle(ci, c + Vector2(0, -3), 3.0, CREAM)
		"sun":
			circle(ci, c + Vector2(0, -3), 7.0, col)
			for i in 8:
				var a := i * TAU / 8.0
				line(ci, c + Vector2(0, -3) + Vector2(cos(a), sin(a)) * 9.0, c + Vector2(0, -3) + Vector2(cos(a), sin(a)) * 13.0, col, 2.0)
		"leaves":
			var u := Vector2(0, -11)
			poly(ci, PackedVector2Array([c + Vector2(0, -3) - u, c + Vector2(6, -3), c + Vector2(0, -3) + u, c + Vector2(-6, -3)]), col)
		"frost":
			for i in 3:
				var a := i * PI / 3.0
				var d := Vector2(cos(a), sin(a)) * 11.0
				line(ci, c + Vector2(0, -3) - d, c + Vector2(0, -3) + d, col, 2.0)
