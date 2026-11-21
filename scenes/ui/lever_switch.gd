class_name LeverSwitch
extends Control
## Chave de alavanca ferroviária (LIGADO/DESLIGADO) para o menu de opções.
## Clique (ou Enter/Espaço com foco) vira a alavanca com uma animação de mola.
## Funciona com o jogo pausado (o menu roda em PROCESS_MODE_ALWAYS).

signal toggled(on: bool)

var on: bool = false
var accent: Color = HudSkin.BRASS
## 0 = desligado (alavanca à esquerda), 1 = ligado (à direita). Animado.
var _pos: float = 0.0
var _tween: Tween
var _font: Font
var _hover: bool = false


func _ready() -> void:
	_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(170, 64)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_pos = 1.0 if on else 0.0


func _set_hover(value: bool) -> void:
	_hover = value
	queue_redraw()


## Muda o estado sem emitir sinal (sincronizar com a configuração salva).
func set_on_no_signal(value: bool, animate: bool = false) -> void:
	on = value
	_animate_to(1.0 if on else 0.0, animate)


func toggle() -> void:
	on = not on
	_animate_to(1.0 if on else 0.0, true)
	toggled.emit(on)


func _animate_to(target: float, animate: bool) -> void:
	if _tween:
		_tween.kill()
	if not animate or not is_inside_tree():
		_pos = target
		queue_redraw()
		return
	_tween = create_tween()
	_tween.tween_method(_set_pos, _pos, target, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_pos(v: float) -> void:
	_pos = v
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		toggle()
		accept_event()


func _draw() -> void:
	var ink := HudSkin.INK
	var r := Rect2(Vector2.ZERO, size)
	# placa de metal com rebites
	var plate := r.grow(-3)
	HudSkin.ink_rrect(self, plate, 10.0, HudSkin.CHARCOAL.lightened(0.1), 3.0)
	HudSkin.rect(self, Rect2(plate.position + Vector2(8, 4), Vector2(plate.size.x - 16, 3)), Color(1, 1, 1, 0.12))
	for p in [plate.position + Vector2(8, 8), Vector2(plate.end.x - 8, plate.position.y + 8), plate.position + Vector2(8, plate.size.y - 8), plate.end - Vector2(8, 8)]:
		HudSkin.ink_circle(self, p, 2.5, HudSkin.METAL, 1.2)
	# lâmpadas DESL (vermelha) e LIG (verde)
	var off_c := Vector2(30, size.y * 0.42)
	var on_c := Vector2(size.x - 30, size.y * 0.42)
	HudSkin.ink_circle(self, off_c, 8.0, Color(0.95, 0.25, 0.2) if not on else Color(0.35, 0.16, 0.14), 2.0)
	HudSkin.ink_circle(self, on_c, 8.0, Color(0.45, 0.95, 0.4) if on else Color(0.16, 0.28, 0.15), 2.0)
	if not on:
		HudSkin.circle(self, off_c, 15.0, Color(1.0, 0.3, 0.2, 0.25))
	else:
		HudSkin.circle(self, on_c, 15.0, Color(0.5, 1.0, 0.4, 0.25))
	draw_string(_font, Vector2(off_c.x - 22, size.y - 9), "DESL", HORIZONTAL_ALIGNMENT_CENTER, 44, 11, HudSkin.CREAM)
	draw_string(_font, Vector2(on_c.x - 22, size.y - 9), "LIG", HORIZONTAL_ALIGNMENT_CENTER, 44, 11, HudSkin.CREAM)
	# trilho da alavanca (arco) e a alavanca
	var pivot := Vector2(size.x / 2.0, size.y - 12.0)
	HudSkin.arc(self, pivot, 30.0, PI * 1.22, PI * 1.78, 14, ink, 8.0)
	HudSkin.arc(self, pivot, 30.0, PI * 1.22, PI * 1.78, 14, Color(0.08, 0.06, 0.06), 4.0)
	var ang := lerpf(PI * 1.25, PI * 1.75, _pos)
	var tip := pivot + Vector2(cos(ang), sin(ang)) * 40.0
	HudSkin.line(self, pivot, tip, ink, 9.0)
	HudSkin.line(self, pivot, tip, HudSkin.METAL, 5.0)
	var knob := (HudSkin.WINE_LIGHT if not on else accent).lerp(Color.WHITE, 0.15 if _hover else 0.0)
	HudSkin.ink_circle(self, tip, 9.0, knob, 3.0)
	HudSkin.circle(self, tip + Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.5))
	HudSkin.ink_circle(self, pivot, 7.0, HudSkin.BRASS, 2.5)
	if has_focus():
		HudSkin.polyline(self, HudSkin.round_rect_points(r.grow(-1), 12.0), Color(accent, 0.9), 2.0)
