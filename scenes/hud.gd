extends CanvasLayer
## HUD — interface provisória (Fase 1A).
##
## Painel de status à esquerda, loja à direita e janela de resumo offline.
## Lê o estado pelo GameController/EventBus e chama ações nele.
## Não contém regras de jogo: preços, desbloqueios e efeitos vêm do GameState.

@export var game_path: NodePath
@export var audio_path: NodePath = NodePath("../AudioDirector")

## Frequência de atualização dos textos e botões da loja (segundos).
const SHOP_REFRESH_INTERVAL := 0.1

@onready var _game: GameController = get_node(game_path)

@onready var _stock_label: Label = %StockLabel
@onready var _production_label: Label = %ProductionLabel
@onready var _tank_label: Label = %TankLabel
@onready var _tank_bar: ProgressBar = %TankBar
@onready var _state_label: Label = %StateLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _speed_hint: Label = %SpeedHint
@onready var _distance_label: Label = %DistanceLabel
@onready var _station_label: Label = %StationLabel
@onready var _station_bar: ProgressBar = %StationBar
@onready var _click_button: Button = %ClickButton
@onready var _message_label: Label = %MessageLabel
@onready var _reset_button: Button = %ResetButton
@onready var _shop_list: VBoxContainer = %ShopList
@onready var _offline_popup: PanelContainer = %OfflinePopup
@onready var _offline_text: Label = %OfflineText
@onready var _offline_ok: Button = %OfflineOk
@onready var _music_button: Button = %MusicButton
@onready var _sfx_button: Button = %SfxButton
@onready var _banner: PanelContainer = %StationBanner
@onready var _banner_text: Label = %BannerText
@onready var _float_layer: Control = %FloatLayer
@onready var _audio: Node = get_node_or_null(audio_path)
@onready var _production_tab: Button = %ProductionTab
@onready var _train_tab: Button = %TrainTab
@onready var _maintenance_bar: ProgressBar = %MaintenanceBar
@onready var _warning_label: Label = %WarningLabel

# Cores do tema steampunk
const C_BRASS := Color(0.85, 0.64, 0.27)
const C_CREAM := Color(0.96, 0.90, 0.78)

var _message_timer: float = 0.0
var _shop_timer: float = 0.0

## Linhas da loja: id do produtor -> { "info": Label, "detail": Label, "button": Button }
var _producer_rows: Dictionary = {}
## Botões de melhoria: id -> Button
var _upgrade_buttons: Dictionary = {}
## Linhas da aba Trem: id da peça -> { "title", "bar", "detail", "repair", "reinforce", "auto" }
var _component_rows: Dictionary = {}
## Aba atual da loja: "producao" ou "trem".
var _tab: String = "producao"
## Assinatura do conteúdo da loja: se mudar, a lista é reconstruída.
var _shop_signature: String = ""


func _ready() -> void:
	EventBus.stock_changed.connect(_on_stock_changed)
	EventBus.tank_changed.connect(_on_tank_changed)
	EventBus.shop_changed.connect(_on_shop_changed)
	EventBus.train_state_changed.connect(_on_train_state_changed)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.distance_changed.connect(_on_distance_changed)
	EventBus.station_reached.connect(_on_station_reached)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.offline_summary.connect(_on_offline_summary)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.component_failed.connect(_on_component_failed)
	EventBus.component_repaired.connect(_on_component_repaired)
	EventBus.component_reinforced.connect(_on_component_reinforced)
	EventBus.maintenance_finished.connect(_on_maintenance_finished)
	_production_tab.pressed.connect(_select_tab.bind("producao"))
	_train_tab.pressed.connect(_select_tab.bind("trem"))

	_click_button.pressed.connect(_on_click_pressed)
	EventBus.producer_bought.connect(_on_producer_bought)
	_music_button.pressed.connect(_on_music_pressed)
	_sfx_button.pressed.connect(_on_sfx_pressed)
	_apply_theme()
	_refresh_sound_buttons()
	_reset_button.pressed.connect(_on_reset_pressed)
	_offline_ok.pressed.connect(func(): _offline_popup.visible = false)
	_speed_hint.text = "A velocidade vem da produção e dos reforços das peças: toda compra acelera o trem."
	_message_label.text = ""
	_add_version_label()


## Etiqueta no canto inferior direito com a branch/commit em teste.
## Na exportação Web vem de res://build_info.txt (gerado pelo jogar-web.ps1);
## no editor, lê direto o .git/HEAD.
func _add_version_label() -> void:
	var info := ""
	if not OS.has_feature("editor") and FileAccess.file_exists("res://build_info.txt"):
		info = FileAccess.get_file_as_string("res://build_info.txt").strip_edges()
	elif FileAccess.file_exists("res://.git/HEAD"):
		var head := FileAccess.get_file_as_string("res://.git/HEAD").strip_edges()
		info = head.trim_prefix("ref: refs/heads/") if head.begins_with("ref:") else head.left(7)
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var label := Label.new()
	label.text = ("v" + version if version else "") + ("  ·  " + info if info else "")
	if label.text.is_empty():
		return
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(C_CREAM, 0.75))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(label)


func _process(delta: float) -> void:
	_shop_timer += delta
	if _shop_timer >= SHOP_REFRESH_INTERVAL:
		_shop_timer = 0.0
		_refresh_shop()
		_production_label.text = "Produção: %s carvão/s" % NumFormat.rate(_state().total_production())
		_click_button.text = "Gerar carvão (+%s)" % NumFormat.rate(_state().click_value())
		_refresh_maintenance_status()

	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.text = ""


func _state() -> GameState:
	return _game.state


# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------

func _on_stock_changed(amount: float) -> void:
	_stock_label.text = "Estoque: %s carvão" % NumFormat.amount(amount)


func _on_tank_changed(current: float, capacity: float) -> void:
	_tank_label.text = "Reservatório do trem: %s / %s (abastece do estoque)" % [NumFormat.amount(current), NumFormat.amount(capacity)]
	_tank_bar.max_value = capacity
	_tank_bar.value = current


func _on_train_state_changed(state: int) -> void:
	match state:
		TrainMovement.State.CRUISING:
			_state_label.text = "Trem: EM MOVIMENTO"
			_state_label.modulate = Color(0.35, 0.85, 0.35)
		TrainMovement.State.SLOW:
			_state_label.text = "Trem: DEVAGAR (falta carvão no reservatório)"
			_state_label.modulate = Color(0.95, 0.75, 0.3)
		TrainMovement.State.MAINTENANCE:
			_state_label.modulate = Color(1.0, 0.6, 0.3)
			_refresh_maintenance_status()
		_:
			_state_label.text = "Trem: PARADO (reservatório vazio)"
			_state_label.modulate = Color(0.9, 0.4, 0.3)


func _on_speed_changed(speed_mps: float, _target_speed_mps: float, coal_per_second: float) -> void:
	var bonus := _state().reinforce_speed_bonus()
	var extra := " (+%d%% pelas peças)" % roundi(bonus * 100.0) if bonus > 0.0 else ""
	_speed_label.text = "Velocidade: %s%s · consumo %s/s" % [NumFormat.speed(speed_mps), extra, NumFormat.rate(coal_per_second)]


func _on_distance_changed(distance_m: float) -> void:
	_distance_label.text = "Distância: %s" % NumFormat.distance(distance_m)
	_refresh_station(distance_m)


func _refresh_station(distance_m: float) -> void:
	var route := _state().route
	if route.is_complete():
		_station_label.text = "Fim da rota atual (%d estações)!" % route.station_count()
		_station_bar.value = 100.0
		return
	var target := route.target_distance(route.reached_count)
	_station_label.text = "Próxima: %s — faltam %s" % [route.next_station_name(), NumFormat.distance(maxf(0.0, target - distance_m))]
	_station_bar.value = route.progress(distance_m) * 100.0


func _on_station_reached(index: int, station_name: String) -> void:
	var extra := ""
	for c in _state().maintenance.components:
		if c.unlock_station == index:
			extra = " Nova peça na aba Trem: %s." % c.display_name if index > 0 else " Nova aba: Trem (manutenção das peças)."
			break
	if index == _state().config.auto_maintenance_unlock_station:
		extra += " Manutenção automática liberada!"
	_show_message("Você chegou à %s! Veja a loja: há novidades.%s" % [_station_title(station_name), extra])
	_show_banner(_station_title(station_name))


func _on_upgrade_purchased(id: String) -> void:
	if id.begins_with("auto_"):
		var c := _state().component(id.substr(5))
		_show_message("Manutenção automática ativa: %s de %s." % [c.display_name, c.material_name()])
		return
	var entry := _state().upgrades.get_entry(id)
	if not entry.is_empty():
		_show_message("Comprado: %s." % entry["name"])


func _on_game_loaded() -> void:
	_rebuild_shop()
	_refresh_station(_state().train.distance_m)
	_message_label.text = ""
	_message_timer = 0.0
	_offline_popup.visible = false


func _on_reset_pressed() -> void:
	_game.reset_game()
	_show_message("Partida reiniciada.")


# ---------------------------------------------------------------------------
# Resumo offline
# ---------------------------------------------------------------------------

func _on_offline_summary(summary: Dictionary) -> void:
	var lines: Array[String] = []
	var seconds := float(summary["seconds"])
	var real := float(summary.get("elapsed_real", seconds))
	if real > seconds + 1.0:
		lines.append("Tempo fora: %s (contamos até %s)" % [NumFormat.duration(real), NumFormat.duration(seconds)])
	else:
		lines.append("Tempo fora: %s" % NumFormat.duration(seconds))
	var delta := float(summary["stock_delta"])
	lines.append("%s%s carvão no estoque" % ["+" if delta >= 0.0 else "", NumFormat.amount(delta)])
	lines.append("+%s percorridos" % NumFormat.distance(float(summary["distance"])))
	var names: Array[String] = []
	for index in summary["stations"]:
		names.append(_state().route.station_name(int(index)))
	if not names.is_empty():
		lines.append("Estações alcançadas: %s" % ", ".join(names))
	if int(summary.get("failures", 0)) > 0:
		lines.append("%d paradas para manutenção (%s)" % [int(summary["failures"]), NumFormat.duration(float(summary["downtime"]))])
	if int(summary.get("auto_repairs", 0)) > 0:
		lines.append("%d consertos automáticos (%s carvão)" % [int(summary["auto_repairs"]), NumFormat.amount(float(summary["auto_cost"]))])
	if summary.get("waiting_at_station", false) and not names.is_empty():
		lines.append("O trem chegou à %s e esperou você para seguir viagem." % _station_title(names[-1]))
	_offline_text.text = "\n".join(lines)
	_offline_popup.visible = true


# ---------------------------------------------------------------------------
# Loja
# ---------------------------------------------------------------------------

## Só reconstrói se o conjunto de itens mudou (ex.: melhoria nova liberada);
## senão basta atualizar os textos. Sempre adiado para fora do clique.
func _on_shop_changed() -> void:
	if _compute_signature() != _shop_signature:
		_rebuild_shop.call_deferred()
	else:
		_refresh_shop()


func _compute_signature() -> String:
	var s := _state()
	var active: Array[String] = []
	for c in s.maintenance.active_components(s.route):
		active.append(c.id + ("A" if c.has_auto() else ""))
	return "%s|%s|%s|%s" % [_tab, s.available_upgrade_ids(), active, s.is_auto_maintenance_unlocked()]


func _select_tab(tab: String) -> void:
	_tab = tab
	_production_tab.set_pressed_no_signal(tab == "producao")
	_train_tab.set_pressed_no_signal(tab == "trem")
	_rebuild_shop()


## Reconstrói a lista inteira.
func _rebuild_shop() -> void:
	for child in _shop_list.get_children():
		_shop_list.remove_child(child)
		child.queue_free()
	_producer_rows.clear()
	_upgrade_buttons.clear()
	_component_rows.clear()
	_train_tab.visible = _state().has_active_components()
	if not _train_tab.visible and _tab == "trem":
		_tab = "producao"
	_production_tab.set_pressed_no_signal(_tab == "producao")
	_train_tab.set_pressed_no_signal(_tab == "trem")
	_shop_signature = _compute_signature()

	if _tab == "trem":
		_build_train_tab()
		_refresh_shop()
		return

	_add_section_title("Produtores")
	for p in _state().producers:
		_add_producer_row(p)

	var available := _state().available_upgrade_ids()
	if not available.is_empty():
		_add_section_title("Melhorias")
		for id in available:
			_add_upgrade_button(id)
	_refresh_shop()


func _add_section_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_shop_list.add_child(label)


func _add_producer_row(p: CoalProducer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 15)
	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 34)
	var id := p.id
	button.pressed.connect(func(): _game.buy_producer(id))
	box.add_child(info)
	box.add_child(detail)
	box.add_child(button)
	_shop_list.add_child(box)
	_producer_rows[p.id] = {"info": info, "detail": detail, "button": button}


func _add_upgrade_button(id: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 46)
	button.pressed.connect(func(): _game.buy_upgrade(id))
	_shop_list.add_child(button)
	_upgrade_buttons[id] = button


## Atualiza textos e botões habilitados (preço e estoque mudam o tempo todo).
func _refresh_shop() -> void:
	var s := _state()
	for p in s.producers:
		if not _producer_rows.has(p.id):
			continue
		var row: Dictionary = _producer_rows[p.id]
		var cost := p.next_level_cost()
		if not s.is_producer_unlocked(p.id):
			row["info"].text = "%s — bloqueado" % p.display_name
			row["detail"].text = "Libera ao chegar na %s." % _station_title(s.route.station_name(p.unlock_station))
			row["button"].text = "Bloqueado"
			row["button"].disabled = true
			continue
		if p.level == 0:
			row["info"].text = "%s — não contratado" % p.display_name
			row["button"].text = "Contratar — %s" % NumFormat.amount(cost)
		else:
			row["info"].text = "%s · nv %d — %s/s" % [p.display_name, p.level, NumFormat.rate(s.producer_production(p.id))]
			row["button"].text = "Melhorar para nv %d — %s" % [p.level + 1, NumFormat.amount(cost)]
		var gain := s.production_after_level_up(p.id) - s.total_production()
		var detail := "Próximo nível: +%s/s" % NumFormat.rate(gain)
		var milestone := p.next_milestone()
		if milestone > 0:
			detail += "  ·  Nível %d: produção x%s" % [milestone, NumFormat.rate(p.milestone_value())]
		row["detail"].text = detail
		row["button"].disabled = not s.can_buy_producer(p.id)

	_refresh_component_rows()

	for id in _upgrade_buttons:
		var button: Button = _upgrade_buttons[id]
		var entry := s.upgrades.get_entry(id)
		button.text = "%s — %s\n%s" % [entry["name"], NumFormat.amount(entry["cost"]), _effect_text(entry)]
		button.disabled = not s.can_buy_upgrade(id)


func _effect_text(entry: Dictionary) -> String:
	var value := float(entry["value"])
	match entry["effect"]:
		"producer_mult":
			return "%s: produção x%s" % [_state().producer(entry["target"]).display_name, NumFormat.rate(value)]
		"global_mult":
			return "Produção total +%d%%" % roundi((value - 1.0) * 100.0)
		"maintenance_time_mult":
			return "Manutenção %d%% mais rápida" % roundi((1.0 - value) * 100.0)
		"click_mult":
			return "Clique x%s (passa a %s)" % [NumFormat.rate(value), NumFormat.rate(_state().click_value() * value)]
	return ""


## "Primavera" -> "Estação Primavera"; "Estação Inicial" continua igual.
func _station_title(station_name: String) -> String:
	return station_name if station_name.begins_with("Estação") else "Estação %s" % station_name


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_timer = 5.0


# ---------------------------------------------------------------------------
# Efeitos e tema (só apresentação)
# ---------------------------------------------------------------------------

func _on_click_pressed() -> void:
	_game.click_coal()
	var origin := _click_button.global_position + Vector2(_click_button.size.x * randf_range(0.3, 0.7), 4)
	_float_text("+%s" % NumFormat.rate(_state().click_value()), origin, C_BRASS)
	_pulse(_click_button)


func _on_producer_bought(id: String, level: int, milestone: bool) -> void:
	if _producer_rows.has(id):
		var row: Dictionary = _producer_rows[id]
		var button: Button = row["button"]
		_pulse(button)
		_float_text("nv %d!" % level, button.global_position + Vector2(button.size.x - 60, 0), C_CREAM)
		var info: Label = row["info"]
		info.modulate = Color(1.6, 1.3, 0.6)
		create_tween().tween_property(info, "modulate", Color.WHITE, 0.6)
	if milestone:
		_show_message("%s chegou ao nível %d: produção x%s!" % [_state().producer(id).display_name, level, NumFormat.rate(_state().producer(id).milestone_value())])
		_show_banner("Marco! %s nível %d" % [_state().producer(id).display_name, level])


func _float_text(text: String, origin: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = origin - _float_layer.global_position
	_float_layer.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


func _pulse(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(1.06, 1.06), 0.06)
	tween.tween_property(control, "scale", Vector2.ONE, 0.12)


func _show_banner(text: String) -> void:
	_banner_text.text = text
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.8, 0.8)
	_banner.pivot_offset = _banner.size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(2.2)
	tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(func(): _banner.visible = false)


func _on_music_pressed() -> void:
	if _audio:
		_audio.set_music_enabled(not _audio.music_enabled)
	_refresh_sound_buttons()


func _on_sfx_pressed() -> void:
	if _audio:
		_audio.set_sfx_enabled(not _audio.sfx_enabled)
	_refresh_sound_buttons()


func _refresh_sound_buttons() -> void:
	if not _audio:
		_music_button.disabled = true
		_sfx_button.disabled = true
		return
	_music_button.text = "Música: %s" % ("ligada" if _audio.music_enabled else "desligada")
	_sfx_button.text = "Efeitos: %s" % ("ligados" if _audio.sfx_enabled else "desligados")


## Tema de latão e cobre para botões e barras (painéis vêm do .tscn).
func _apply_theme() -> void:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _button_style(Color(0.30, 0.19, 0.11), Color(0.62, 0.45, 0.18)))
	theme.set_stylebox("hover", "Button", _button_style(Color(0.42, 0.27, 0.14), Color(0.90, 0.68, 0.30)))
	theme.set_stylebox("pressed", "Button", _button_style(Color(0.22, 0.13, 0.07), Color(0.95, 0.75, 0.35)))
	theme.set_stylebox("disabled", "Button", _button_style(Color(0.17, 0.14, 0.12), Color(0.30, 0.25, 0.20)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", C_CREAM)
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.7))
	theme.set_color("font_pressed_color", "Button", C_BRASS)
	theme.set_color("font_disabled_color", "Button", Color(0.55, 0.50, 0.45))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.06, 0.05, 0.05)
	bar_bg.set_corner_radius_all(4)
	bar_bg.set_border_width_all(1)
	bar_bg.border_color = Color(0.40, 0.30, 0.15)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = C_BRASS
	bar_fill.set_corner_radius_all(4)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	theme.set_color("font_color", "ProgressBar", Color(0.1, 0.07, 0.04))
	theme.set_color("font_color", "Label", C_CREAM)
	for root_control in [$StatusPanel, $ShopPanel, _offline_popup, _banner]:
		root_control.theme = theme


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


# ---------------------------------------------------------------------------
# Aba "Trem": componentes e manutenção (Fase 1B)
# ---------------------------------------------------------------------------

func _build_train_tab() -> void:
	var s := _state()
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.75, 0.72, 0.66))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "Peças a 0%% quebram: o trem para %s e a peça volta a 100%%. Cada reforço faz a peça durar 40%% mais e deixa o trem %d%% mais rápido." % [NumFormat.duration(s.maintenance.stop_seconds()), roundi(float(s.config.reinforce_speed_bonus) * 100.0)]
	_shop_list.add_child(info)
	_add_section_title("Componentes")
	for c in s.maintenance.components:
		_add_component_row(c)


func _add_component_row(c: TrainComponent) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 15)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	bar.max_value = 100.0
	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons := HBoxContainer.new()
	var repair := Button.new()
	repair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repair.custom_minimum_size = Vector2(0, 32)
	var reinforce := Button.new()
	reinforce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reinforce.custom_minimum_size = Vector2(0, 32)
	var auto := Button.new()
	auto.custom_minimum_size = Vector2(0, 32)
	auto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Botões das peças com fonte menor e sem largura mínima pelo texto,
	# para a loja manter a largura fixa de 360 px.
	for b in [repair, reinforce, auto]:
		b.add_theme_font_size_override("font_size", 13)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 40)
	var id := c.id
	repair.pressed.connect(func(): _game.repair_component(id))
	reinforce.pressed.connect(func(): _game.reinforce_component(id))
	auto.pressed.connect(func(): _game.buy_auto_maintenance(id))
	buttons.add_child(repair)
	buttons.add_child(reinforce)
	box.add_child(title)
	box.add_child(bar)
	box.add_child(detail)
	box.add_child(buttons)
	box.add_child(auto)
	_shop_list.add_child(box)
	_component_rows[c.id] = {"title": title, "bar": bar, "detail": detail, "repair": repair,
		"reinforce": reinforce, "auto": auto, "buttons": buttons}


func _refresh_component_rows() -> void:
	var s := _state()
	for id in _component_rows:
		var row: Dictionary = _component_rows[id]
		var c := s.component(id)
		if not s.is_component_active(id):
			row["title"].text = "%s — bloqueado" % c.display_name
			row["detail"].text = "Aparece ao chegar na %s." % _station_title(s.route.station_name(c.unlock_station))
			row["bar"].visible = false
			row["buttons"].visible = false
			row["auto"].visible = false
			continue
		row["bar"].visible = true
		row["buttons"].visible = true
		var pct := c.integrity * 100.0
		var lvl := " · reforço nv %d" % c.level if c.level > 0 else ""
		row["title"].text = "%s de %s%s — %d%%" % [c.display_name, c.material_name(), lvl, int(ceil(pct))]
		row["bar"].value = pct
		row["bar"].modulate = _integrity_color(c.integrity)
		var life := NumFormat.distance(c.life()) if c.wear_kind == TrainComponent.Wear.DISTANCE else NumFormat.duration(c.life()) + " andando"
		var next_life: float = c.life() * s.config.reinforce_life_multiplier
		var next_txt := NumFormat.distance(next_life) if c.wear_kind == TrainComponent.Wear.DISTANCE else NumFormat.duration(next_life)
		var bonus_pct := roundi(float(s.config.reinforce_speed_bonus) * 100.0)
		var detail := "Dura %s · bônus +%d%% velocidade\nPróximo reforço: dura %s e +%d%% velocidade" % [life, roundi(c.level * float(s.config.reinforce_speed_bonus) * 100.0), next_txt, bonus_pct]
		if c.has_auto():
			detail += "  ·  Automática: %d consertos" % c.auto_repairs
		row["detail"].text = detail
		row["repair"].text = "Reparar\n%s" % NumFormat.amount(s.repair_cost(id)) if c.integrity < 1.0 else "Peça\na 100%"
		row["repair"].disabled = not s.can_repair(id)
		row["reinforce"].text = "Reforçar nv %d\n%s" % [c.level + 1, NumFormat.amount(c.reinforce_cost())]
		row["reinforce"].disabled = not s.can_reinforce(id)
		var auto: Button = row["auto"]
		if c.has_auto():
			auto.visible = true
			auto.disabled = true
			auto.text = "Manutenção automática ativa (%s)" % c.material_name()
		elif s.is_auto_maintenance_unlocked():
			auto.visible = true
			auto.text = "Manutenção automática (%s) — %s" % [c.material_name(), NumFormat.amount(c.auto_cost())]
			auto.disabled = not s.can_buy_auto(id)
		else:
			auto.visible = false


func _integrity_color(integrity: float) -> Color:
	if integrity < _state().config.component_warning_threshold:
		return Color(1.0, 0.35, 0.25)
	if integrity < 0.5:
		return Color(1.0, 0.85, 0.3)
	return Color.WHITE


## Estado "em manutenção" com contagem regressiva e aviso de peças gastas.
func _refresh_maintenance_status() -> void:
	var s := _state()
	var m := s.maintenance
	if m.is_stopped():
		var c := s.component(m.stop_component_id)
		var comp_name := c.display_name if c else "peça"
		_state_label.text = "Trem: EM MANUTENÇÃO (%s) — %d s" % [comp_name, int(ceil(m.stop_left))]
		_state_label.modulate = Color(1.0, 0.6, 0.3)
		_maintenance_bar.visible = true
		_maintenance_bar.max_value = maxf(m.stop_seconds(), m.stop_left)
		_maintenance_bar.value = _maintenance_bar.max_value - m.stop_left
	else:
		_maintenance_bar.visible = false
	var worn: Array[String] = []
	for c in m.active_components(s.route):
		if c.integrity < s.config.component_warning_threshold and not c.has_auto():
			worn.append("%s a %d%%" % [c.display_name, int(ceil(c.integrity * 100.0))])
	_warning_label.visible = not worn.is_empty()
	if not worn.is_empty():
		_warning_label.text = "Atenção: %s! (aba Trem)" % ", ".join(worn)


func _on_component_failed(_id: String, component_name: String) -> void:
	_show_message("%s quebrou! Manutenção de %s." % [component_name, NumFormat.duration(_state().maintenance.stop_seconds())])
	_refresh_maintenance_status()


func _on_component_repaired(id: String, automatic: bool) -> void:
	if automatic:
		return
	var row: Dictionary = _component_rows.get(id, {})
	if not row.is_empty():
		var button: Button = row["repair"]
		_float_text("100%!", button.global_position + Vector2(10, 0), C_BRASS)
		_pulse(button)


func _on_component_reinforced(id: String, level: int) -> void:
	var row: Dictionary = _component_rows.get(id, {})
	if not row.is_empty():
		var button: Button = row["reinforce"]
		_float_text("nv %d!" % level, button.global_position + Vector2(button.size.x - 60, 0), C_CREAM)
		_pulse(button)


func _on_maintenance_finished() -> void:
	_show_message("Manutenção concluída. Seguindo viagem!")
	_refresh_maintenance_status()
