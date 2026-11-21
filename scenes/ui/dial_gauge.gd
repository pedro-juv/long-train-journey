class_name DialGauge
extends Control
## Mostrador analógico de painel de locomotiva (velocímetro, manômetro).
## O ponteiro persegue o valor com mola (balança um pouco, estilo desenho).
## Só redesenha enquanto o ponteiro se move.

## Valor alvo (0 a 1).
var value: float = 0.0
## Texto pequeno embaixo (ex.: "m/s", "CALDEIRA").
var caption: String = ""
## Leitura grande no mostrador (ex.: "14,0").
var readout: String = ""
var accent: Color = HudSkin.BRASS
## A partir daqui (0 a 1) a escala fica vermelha.
var red_zone: float = 0.8

var _shown: float = 0.0
var _vel: float = 0.0
var _font: Font

const START_ANGLE := PI * 0.75   # 135°
const SWEEP := PI * 1.5          # 270°


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_reading(v: float, text: String) -> void:
	value = clampf(v, 0.0, 1.0)
	if text != readout:
		readout = text
		queue_redraw()


func set_accent(c: Color) -> void:
	accent = c
	queue_redraw()


func _process(delta: float) -> void:
	# mola amortecida: chega no valor com um leve balanço
	var force := (value - _shown) * 160.0 - _vel * 16.0
	_vel += force * delta
	_shown += _vel * delta
	if absf(_vel) > 0.0005 or absf(value - _shown) > 0.0005:
		queue_redraw()


func _angle(v: float) -> float:
	return START_ANGLE + SWEEP * clampf(v, -0.03, 1.03)


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 4.0
	var ink := HudSkin.INK
	# aro de latão, face creme
	HudSkin.circle(self, c, r + 3.0, ink)
	HudSkin.circle(self, c, r, HudSkin.BRASS)
	HudSkin.arc(self, c, r - 3.0, PI * 1.05, PI * 1.55, 12, HudSkin.BRASS.lightened(0.35), 3.0)
	HudSkin.circle(self, c, r - 8.0, ink)
	HudSkin.circle(self, c, r - 10.0, HudSkin.CREAM)
	# faixa colorida da estação e zona vermelha
	HudSkin.arc(self, c, r - 17.0, _angle(0.0), _angle(red_zone), 24, Color(accent, 0.9), 6.0)
	HudSkin.arc(self, c, r - 17.0, _angle(red_zone), _angle(1.0), 10, HudSkin.WINE_LIGHT, 6.0)
	# marcas
	for i in 11:
		var a := _angle(i / 10.0)
		var d := Vector2(cos(a), sin(a))
		var inner := r - (26.0 if i % 5 == 0 else 22.0)
		HudSkin.line(self, c + d * inner, c + d * (r - 12.0), ink, 3.0 if i % 5 == 0 else 1.5)
	# leitura e legenda
	if readout != "":
		draw_string(_font, Vector2(c.x - r, c.y + r * 0.42), readout, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 0.30), ink)
	if caption != "":
		draw_string(_font, Vector2(c.x - r, c.y + r * 0.66), caption, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 0.17), HudSkin.WINE)
	# ponteiro
	var a := _angle(_shown)
	var d := Vector2(cos(a), sin(a))
	var tip := c + d * (r - 20.0)
	var tail := c - d * 10.0
	var side := d.orthogonal() * 4.5
	var needle := PackedVector2Array([tail + side, tip, tail - side])
	var closed := needle.duplicate()
	closed.append(needle[0])
	HudSkin.polyline(self, closed, ink, 4.0)
	HudSkin.poly(self, needle, HudSkin.WINE_LIGHT)
	HudSkin.circle(self, c, 8.0, ink)
	HudSkin.circle(self, c, 6.0, HudSkin.BRASS)
