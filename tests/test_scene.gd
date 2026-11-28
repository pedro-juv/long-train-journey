extends Node
## Teste de integração: abre a cena principal de verdade e confere a interface.
## Rodar: godot --headless --path . res://tests/test_scene.tscn
## (roda como cena normal para os autoloads Balance/EventBus/SaveManager existirem)
##
## Faz backup do save do jogador e o restaura no fim.

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save_backup_teste.json"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings_backup_teste.cfg"

var _fails := 0
var _main: Node


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		_fails += 1
		print("  FAIL ", msg)


func _ready() -> void:
	_run.call_deferred()


func _write_save(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _open_game() -> void:
	if _main:
		remove_child(_main)
		_main.free()
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	for i in 4:
		await get_tree().process_frame


func _hud() -> Node:
	return _main.get_node("HUD")


func _game() -> GameController:
	return _main.get_node("Game")


func _menu() -> Node:
	return _main.get_node("OptionsMenu")


func _press_esc() -> void:
	var ev := InputEventAction.new()
	ev.action = "toggle_options"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


## Aperta e solta uma tecla física (echo = repetição de tecla segurada).
func _press_key(key: Key, echo: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.keycode = key
	ev.pressed = true
	ev.echo = echo
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := ev.duplicate()
	up.pressed = false
	up.echo = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _run() -> void:
	print("== Teste da cena principal (Fase 1A + 1B) ==")
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	var had_settings := FileAccess.file_exists(SETTINGS_PATH)
	if had_settings:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SETTINGS_PATH), ProjectSettings.globalize_path(SETTINGS_BACKUP))
	PatchNotes.mark_seen()   # as notas da versão só abrem no teste delas

	var now := Time.get_unix_time_from_system()

	# --- 1. Save v3 com 10 horas fora ----------------------------------------
	_write_save({"save_version": 3, "saved_at": now - 36000.0, "stock": 500.0, "tank": 100.0,
		"producers": {"foguista": 12, "carvoaria": 3, "mina": 0},
		"upgrades_purchased": ["click_1"], "distance_m": 4000.0})
	await _open_game()
	var g := _game()
	var hud := _hud()
	print("Carregamento e offline (10 h fora)")
	_check(g.state.producer("foguista").level == 12 and g.state.producer("carvoaria").level == 3, "níveis carregados")
	_check(g.state.stock.amount > 500.0 + 50000.0, "estoque ganhou a produção offline (%s)" % NumFormat.amount(g.state.stock.amount))
	_check(hud.get_node("%OfflinePopup").visible, "resumo offline aparece")
	var text: String = hud.get_node("%OfflineText").text
	_check(text.contains("Tempo fora: 10 h"), "resumo mostra o tempo fora")
	_check(not text.contains("Estações alcançadas"), "offline não alcança estação nova")
	_check(text.contains("parou antes da Estação Cidade Tomada"), "resumo avisa que o trem esperou antes da estação nova")
	var wait_at: float = g.state.route.target_distance(1) - Balance.offline_wait_distance_m
	_check(absf(g.state.train.distance_m - wait_at) < 30.0, "offline parou antes da Cidade Tomada e segue ao abrir (%.0f m)" % g.state.train.distance_m)
	_check(g.state.train.state != TrainMovement.State.AT_STATION, "ao abrir, o trem segue viagem")
	var view := _main.get_node("TrainView")
	var audio := _main.get_node("AudioDirector")
	_check(view._theme_id == "tomada", "o trecho até a Cidade Tomada já é a região dela (%s)" % view._theme_id)
	# A chegada na estação nova acontece com o jogador presente
	g.state.train.distance_m = g.state.route.target_distance(1) - 0.2
	g.state.train.current_speed = 2.0
	await get_tree().create_timer(1.0).timeout
	_check(hud.get_node("%MessageLabel").text.contains("Cidade Tomada"), "chegada na Cidade Tomada aparece ao vivo")
	_check(view._theme_id == "tomada", "cenário no tema da Cidade Tomada (%s)" % view._theme_id)
	_check(audio.current_music_theme() == "tomada", "música na variação da Cidade Tomada (%s)" % audio.current_music_theme())
	_check(g.state.train.state == TrainMovement.State.AT_STATION and g.state.station_stop_left > 0.0, "o trem para na plataforma da Cidade Tomada")
	_check(hud.get_node("%StateLabel").visible and hud.get_node("%StateLabel").text.contains("Parado em Cidade Tomada"), "estado mostra a parada na estação")
	_check(hud._depart_button.visible and hud.get_node("%StateLabel").text.contains("Partir"), "botão Partir aparece na parada (Partir sozinho desligado por padrão)")
	hud._depart_button.pressed.emit()
	await get_tree().process_frame
	_check(not g.state.is_at_station() and not hud._depart_button.visible, "botão Partir: o trem sai da estação e o botão some")
	g.set_stop_at_stations(false)
	_check(not _menu().get_node("%StopSwitch").on, "chave Parada automática do menu acompanha a preferência")
	g.state.station_stop_left = 0.0
	g.state.train.distance_m = g.state.route.target_distance(2) - 1.0
	g.state.train.current_speed = g.state.cruise_speed()
	await get_tree().create_timer(0.3).timeout
	_check(g.state.train.state != TrainMovement.State.AT_STATION, "com o botão desligado o trem passa direto pelo Deserto de Ferrugem")
	_check(view._theme_id == "ruinas" and view._prev_theme_id == "deserto" and view._blend < 1.0, "passar pelo Deserto de Ferrugem entra na região das Ruínas Brancas (%s)" % view._theme_id)
	_check(audio.current_music_theme() == "ruinas", "música troca para a variação das Ruínas Brancas")
	hud.get_node("%OfflineOk").pressed.emit()
	_check(not hud.get_node("%OfflinePopup").visible, "botão fecha o resumo")

	print("Indicador da rota")
	var strip := RouteStrip.new()
	add_child(strip)
	strip.size = Vector2(500, 44)
	var snames := PackedStringArray(["A", "B", "C", "D", "E"])
	strip.set_route(snames, 1, 0.0)
	for i in 100:
		strip.set_route(snames, 1, i * 0.001)   # andando devagar: menos de meio pixel por quadro
	_check(strip._drawn_pos > 1.09, "movimento lento acumula e o trenzinho anda no indicador (%.3f)" % strip._drawn_pos)
	strip.set_route(snames, 2, 0.0)
	_check(is_equal_approx(strip._drawn_pos, 2.0), "chegar na estação redesenha na hora")
	strip.queue_free()

	print("Porta da caldeira (estoque)")
	var door: Control = hud.get_node("Ticket")
	var door_w := door.size.x
	var stock_keep: float = g.state.stock.amount
	for big in [15.52e6, 999.99e15, 999.99e33, 1.23e40]:
		g.state.stock.amount = big
		await get_tree().process_frame
		await get_tree().process_frame
		_check(hud.get_node("%StockLabel").text == NumFormat.amount(g.state.stock.amount) and is_equal_approx(door.size.x, door_w), "porta não estica com %s (%.0f px)" % [hud.get_node("%StockLabel").text, door.size.x])
	g.state.stock.amount = stock_keep
	await get_tree().process_frame
	_check(hud.get_node("%ClickRateLabel").text == "Cliques: —", "sem clicar: linha dos cliques vazia (%s)" % hud.get_node("%ClickRateLabel").text)
	for i in 12:
		hud._on_click_pressed()
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.15).timeout
	_check(hud.get_node("%ClickRateLabel").text.begins_with("Cliques: +") and g.state.click_income_rate > 0.0, "clicando: porta mostra o carvão/s dos cliques (%s)" % hud.get_node("%ClickRateLabel").text)
	_check(hud.get_node("%ProductionLabel").text.begins_with("Produção: ") and g.state.effective_production() > g.state.total_production(), "produção mostrada soma os cliques (%s)" % hud.get_node("%ProductionLabel").text)

	print("Loja")
	var rows: Dictionary = hud._producer_rows
	_check(rows.size() == 8, "oito linhas de produtores")
	_check(not rows["mina"]["button"].disabled or g.state.stock.amount < 4000.0, "Mina liberada (1ª estação já alcançada)")
	_check(rows["foguista"]["info"].text.contains("nv 12"), "linha do Foguista mostra o nível (%s)" % rows["foguista"]["info"].text)
	_check(rows["foguista"]["detail"].text.contains("Nível 25"), "mostra o próximo marco (%s)" % rows["foguista"]["detail"].text)
	_check(hud._upgrade_buttons.has("station_0") and hud._upgrade_buttons.has("station_1"), "melhorias das estações 1 e 2 na loja")
	_check(hud._upgrade_buttons.has("eq_foguista") and hud._upgrade_buttons.has("click_2"), "equipamento e próxima melhoria de clique na loja")
	_check(not hud._upgrade_buttons.has("click_1"), "melhoria já comprada não aparece")

	print("Compras pela interface")
	g.state.stock.add(1e7)
	rows["carvoaria"]["button"].pressed.emit()
	_check(g.state.producer("carvoaria").level == 4, "botão compra nível da Carvoaria")
	var prod_before := g.state.total_production()
	hud._upgrade_buttons["station_0"].pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(g.state.upgrades.is_purchased("station_0"), "botão compra a Caldeira reforçada")
	_check(is_equal_approx(g.state.total_production(), prod_before * 1.5), "produção total +50%")
	_check(not hud._upgrade_buttons.has("station_0"), "loja reconstruída sem a melhoria comprada")
	var clicks_before := g.state.stock.amount
	var expected_click := (1.0 + g.state.total_production() * 0.02) * 2.0
	var stoke_before := g.state.stoke
	hud.get_node("%ClickButton").pressed.emit()
	_check(absf(g.state.stock.amount - clicks_before - expected_click) < 0.01 * expected_click + 1.0, "clique = (1 + 2%% da produção) x2 com a 1ª melhoria (%.1f)" % expected_click)
	_check(g.state.stoke > stoke_before, "clique atiça a caldeira")

	print("Atalho da caldeira (teclado)")
	var key_saved := Hotkeys.stoke_key
	var clicks := [0]
	var count_click := func(): clicks[0] += 1
	EventBus.coal_clicked.connect(count_click)
	Hotkeys.set_stoke_key(KEY_SPACE)
	await _press_key(KEY_SPACE)
	_check(clicks[0] == 1, "Espaço atiça a caldeira (padrão)")
	await _press_key(KEY_SPACE, true)
	_check(clicks[0] == 1, "segurar a tecla não repete o clique")
	_check(hud.get_node("%SpeedHint").text.contains("Espaço"), "dica mostra o atalho (%s)" % hud.get_node("%SpeedHint").text)
	var m := _menu()
	m.open()
	var hk: Button = m.get_node("%Root").find_child("HotkeyButton", true, false)
	_check(hk != null and hk.text == "Espaço", "menu mostra o atalho atual")
	hk.pressed.emit()
	await _press_key(KEY_F)
	_check(Hotkeys.stoke_key == KEY_F and hk.text == "F" and m.is_open, "menu troca o atalho para F sem fechar")
	hk.pressed.emit()
	await _press_key(KEY_ESCAPE)
	_check(Hotkeys.stoke_key == KEY_F and m.is_open, "ESC cancela a troca sem fechar o menu")
	_check(clicks[0] == 1, "com o menu aberto o atalho não atiça")
	m.close(true)
	await _press_key(KEY_SPACE)
	_check(clicks[0] == 1, "Espaço deixa de atiçar")
	await _press_key(KEY_F)
	_check(clicks[0] == 2, "F atiça a caldeira")
	_check(hud.get_node("%SpeedHint").text.contains("Clique ou F"), "dica atualizada")
	EventBus.coal_clicked.disconnect(count_click)
	Hotkeys.set_stoke_key(key_saved)
	hud._refresh_stoke_hint()

	print("Save")
	g.save_now()
	var saved: Dictionary = SaveManager.load_game()
	_check(int(saved.get("save_version", 0)) == 6 and saved.has("saved_at") and saved.has("components") and saved.has("stop_at_stations"), "save v6 com horário, componentes e preferência de parada")
	_check(int(saved["producers"]["carvoaria"]) == 4, "save guarda os níveis")

	print("Aba Trem")
	var train_tab: Button = hud.get_node("%TrainTab")
	_check(train_tab.visible, "aba Trem visível depois da Estação Inicial")
	train_tab.pressed.emit()
	var crow: Dictionary = hud._component_rows
	_check(crow.size() == 8, "oito peças listadas")
	_check(crow["rodas"]["title"].text.contains("Rodas de ferro fundido"), "rodas de ferro fundido (%s)" % crow["rodas"]["title"].text)
	_check(crow["chamine"]["title"].text.contains("bloqueado"), "Chaminé bloqueada até o Ruínas Brancas")
	_check(not crow["rodas"]["auto"].visible, "manutenção automática escondida antes do Ruínas Brancas")
	g.state.component("rodas").integrity = 0.2
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	_check(hud.get_node("%WarningLabel").visible and hud.get_node("%WarningLabel").text.contains("Rodas"), "aviso de peça gasta no painel")
	crow["rodas"]["repair"].pressed.emit()
	_check(is_equal_approx(g.state.component("rodas").integrity, 1.0), "botão Reparar leva a 100%")
	crow["rodas"]["reinforce"].pressed.emit()
	_check(g.state.component("rodas").level == 1, "botão Reforçar sobe o nível")
	g.state.station_stop_left = 0.0
	g.state.train.current_speed = g.state.cruise_speed()
	g.state.component("pistoes").integrity = 0.000001
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	_check(g.state.maintenance.is_stopped(), "peça a 0%: trem vai parar para manutenção")
	_check(g.state.train.state == TrainMovement.State.BRAKING and g.state.train.current_speed > 0.0, "freia aos poucos em vez de parar na hora")
	_check(hud.get_node("%StateLabel").text.contains("Pistões"), "estado mostra a falha (%s)" % hud.get_node("%StateLabel").text)
	await get_tree().create_timer(3.5).timeout
	_check(g.state.train.state == TrainMovement.State.MAINTENANCE, "depois de frear, para em manutenção")
	_check(hud.get_node("%StateLabel").text.contains("Em manutenção (Pistões)"), "estado mostra a manutenção (%s)" % hud.get_node("%StateLabel").text)
	_check(hud.get_node("%MaintenanceBar").visible, "barra de manutenção visível")
	hud.get_node("%ProductionTab").pressed.emit()
	_check(hud._producer_rows.size() == 8, "volta para a aba Produção")

	# --- 2. Três dias fora: limite de 24 h -----------------------------------
	_write_save({"save_version": 3, "saved_at": now - 3 * 86400.0, "stock": 0.0, "tank": 100.0,
		"producers": {"foguista": 5}, "upgrades_purchased": [], "distance_m": 0.0})
	await _open_game()
	print("Limite de 24 h")
	text = _hud().get_node("%OfflineText").text
	_check(text.contains("contamos até 24 h"), "resumo avisa que contou só 24 h (%s)" % text.get_slice("\n", 0))

	# --- 2b. Ruínas Brancas: manutenção automática e resumo de paradas ---------------
	_write_save({"save_version": 4, "saved_at": now - 86400.0, "stock": 1e9, "tank": 100.0,
		"producers": {"foguista": 30, "carvoaria": 20}, "upgrades_purchased": [], "distance_m": 100000.0,
		"components": {}})
	await _open_game()
	print("Ruínas Brancas: manutenção automática")
	text = _hud().get_node("%OfflineText").text
	_check(_main.get_node("TrainView")._theme_id == "inverno" and text.contains("parou antes da Estação Ermo Gelado"), "24 h fora depois das Ruínas Brancas: espera antes do Ermo Gelado, na região dele (tema %s)" % _main.get_node("TrainView")._theme_id)
	_check(text.contains("paradas para manutenção"), "resumo offline mostra as paradas (%s)" % text.get_slice("\n", 3))
	_hud().get_node("%TrainTab").pressed.emit()
	var arow: Dictionary = _hud()._component_rows
	_check(arow["rodas"]["auto"].visible and not arow["rodas"]["auto"].disabled, "botão de manutenção automática disponível")
	arow["rodas"]["auto"].pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_game().state.component("rodas").has_auto(), "manutenção automática comprada pela interface")
	_check(_hud()._component_rows["rodas"]["auto"].text.contains("ativa"), "botão mostra 'ativa'")

	# --- 3. Relógio voltando no tempo ----------------------------------------
	_write_save({"save_version": 3, "saved_at": now + 5000.0, "stock": 10.0, "tank": 100.0,
		"producers": {"foguista": 1}, "upgrades_purchased": [], "distance_m": 0.0})
	await _open_game()
	print("Relógio voltando")
	_check(not _hud().get_node("%OfflinePopup").visible, "sem resumo quando o horário do save está no futuro")
	_check(_game().state.stock.amount >= 9.0, "estoque não é perdido")

	# --- 4. Save da Fase 0 e reinício ----------------------------------------
	_write_save({"save_version": 2, "stock": 77.0, "tank": 100.0, "producer_level": 4,
		"distance_m": 100.0, "station_reached": false, "upgrades_purchased": []})
	await _open_game()
	print("Save da Fase 0 e reinício")
	_check(_game().state.producer("foguista").level == 4, "save da Fase 0 abre com o Foguista nv 4")
	_check(not _hud().get_node("%OfflinePopup").visible, "save antigo sem horário não mostra resumo")

	# --- 5. Menu de opções (ESC) ---------------------------------------------
	print("Menu de opções")
	var menu := _menu()
	var game := _game()
	var audio2 := _main.get_node("AudioDirector")
	_check(not _hud().has_node("%MusicButton") and not _hud().has_node("%SfxButton"), "controles de áudio saíram da HUD")
	game.state.station_stop_left = 0.0
	await get_tree().create_timer(0.2).timeout
	await _press_esc()
	_check(menu.is_open and menu.get_node("%Root").visible, "ESC abre o menu de opções")
	_check(get_tree().paused, "menu pausa o jogo")
	var dist_paused := game.state.train.distance_m
	var stock_paused := game.state.stock.amount
	await get_tree().create_timer(0.4).timeout
	_check(game.state.train.distance_m == dist_paused and game.state.stock.amount == stock_paused, "com o menu aberto a partida não avança (%.2f m)" % dist_paused)
	var music_before: bool = audio2.music_enabled
	menu.get_node("%MusicSwitch").toggle()
	_check(audio2.music_enabled == not music_before, "chave Música alterna a música")
	var sfx_before: bool = audio2.sfx_enabled
	menu.get_node("%SfxSwitch").toggle()
	_check(audio2.sfx_enabled == not sfx_before, "chave Efeitos alterna os efeitos")
	var stop_before: bool = game.state.stop_at_stations
	menu.get_node("%StopSwitch").toggle()
	_check(game.state.stop_at_stations == not stop_before, "chave Parada automática alterna a preferência")
	var depart_before: bool = game.state.auto_depart
	menu._depart_switch.toggle()
	_check(game.state.auto_depart == not depart_before, "chave Partir sozinho alterna a preferência")
	await _press_esc()
	_check(not menu.is_open and not get_tree().paused, "ESC fecha o menu e retoma o jogo")
	await get_tree().create_timer(0.3).timeout
	_check(game.state.train.distance_m > dist_paused, "depois de fechar, o trem volta a andar")
	menu.open()
	menu.get_node("%BackButton").pressed.emit()
	_check(not menu.is_open and not get_tree().paused, "botão Voltar ao jogo fecha e retoma")
	var stop_now: bool = game.state.stop_at_stations
	var depart_now: bool = game.state.auto_depart
	# reabrir o jogo: tudo continua como o jogador deixou
	await _open_game()
	_check(_main.get_node("AudioDirector").music_enabled == not music_before and _main.get_node("AudioDirector").sfx_enabled == not sfx_before, "música e efeitos persistem ao reabrir o jogo")
	_check(_game().state.stop_at_stations == stop_now and _menu().get_node("%StopSwitch").on == stop_now, "parada automática persiste ao reabrir o jogo")
	_check(_game().state.auto_depart == depart_now and _menu()._depart_switch.on == depart_now, "Partir sozinho persiste ao reabrir o jogo")
	# reiniciar partida pelo menu: pede confirmação e mantém as preferências
	_menu().open()
	_menu().get_node("%ResetButton").pressed.emit()
	_check(_game().state.producer("foguista").level == 4, "1º clique em Reiniciar só pede confirmação")
	_menu().get_node("%ResetButton").pressed.emit()
	_check(_game().state.producer("foguista").level == 0 and _game().state.train.distance_m == 0.0, "reiniciar zera a partida")
	_check(_game().state.stop_at_stations == stop_now, "reiniciar mantém a parada automática")
	_check(_game().state.auto_depart == depart_now, "reiniciar mantém Partir sozinho")
	_check(not get_tree().paused and not _menu().is_open, "reiniciar fecha o menu e despausa")
	_check(_hud().get_node("%MessageLabel").text.contains("reiniciada"), "aviso de partida reiniciada")

	# --- 5b. Notas da versão ---------------------------------------------------
	print("Notas da versão")
	var ncfg := ConfigFile.new()
	ncfg.load(SETTINGS_PATH)
	ncfg.set_value("patch_notes", "last_seen", "0.0.0")
	ncfg.save(SETTINGS_PATH)
	await _open_game()
	var pn: PatchNotes = _main.get_node("PatchNotes")
	_check(pn.is_open and pn.get_node("Root").visible, "versão nova: as notas abrem sozinhas")
	var ntext := pn._text.get_parsed_text()
	_check(ntext.contains("Versão %s" % PatchNotes.current_version()) and ntext.contains("Versão 0.1.0"), "notas têm a versão atual e todas as anteriores")
	_check(PatchNotesData.NOTES[0]["version"] == PatchNotes.current_version(), "a 1ª nota é a versão do projeto (%s)" % PatchNotes.current_version())
	_check(PatchNotes.last_seen_version() == PatchNotes.current_version(), "versão fica marcada como vista")
	_check(Hotkeys.stoke_key != KEY_NONE, "atalho continua salvo junto das notas")
	await _press_esc()
	_check(not pn.is_open and not _menu().is_open, "ESC fecha as notas (sem abrir o menu)")
	await _open_game()
	_check(not _main.get_node("PatchNotes").is_open, "não abre de novo na mesma versão")
	_menu().open()
	_menu().get_node("Root/Board/Margin/VBox/ExtraRow/NotesButton").pressed.emit()
	_check(_main.get_node("PatchNotes").is_open and _menu().is_open, "botão Notas da versão no menu abre as notas por cima")
	await _press_esc()
	_check(not _main.get_node("PatchNotes").is_open and _menu().is_open, "ESC fecha as notas e volta ao menu")
	_main.get_node("PatchNotes").get_node("Root").visible = true
	_main.get_node("PatchNotes").is_open = true
	_main.get_node("PatchNotes")._close_button.pressed.emit()
	_check(not _main.get_node("PatchNotes").is_open, "botão Fechar fecha as notas")
	_menu().close()

	# --- 6. Modo trem flutuante (desktop) --------------------------------------
	print("Modo trem flutuante")
	g = _game()
	hud = _hud()
	view = _main.get_node("TrainView")
	var fm: FloatMode = _main.get_node("FloatMode")
	_check(FloatMode.supported(), "modo flutuante disponível no desktop")
	_check(hud.get_node_or_null("FloatButton") != null, "botão FLUTUAR na HUD")
	_check(_menu().get_node_or_null("Root/Board/Margin/VBox/ExtraRow/FloatButton") != null, "opção Trem flutuante no menu")
	g.state.stock.add(5000.0)
	var state_before: GameState = g.state
	var dist_before: float = g.state.train.distance_m
	hud.get_node("FloatButton").pressed.emit()
	for i in 20:
		await get_tree().process_frame
	_check(fm.active and view.floating, "botão FLUTUAR liga o modo flutuante")
	_check(g.state == state_before, "mesma partida em memória (nada recarregado)")
	_check(g.state.train.distance_m > dist_before, "o trem continua andando na janelinha")
	_check(not view._layers["SkyGradient"].visible and not view._layers["Mountains"].visible and not view._layers["Darkness"].visible, "céu, montanhas e escuridão somem (desktop por trás)")
	_check(view._layers["Trees"].visible and view._layers["Poles"].visible and view._layers["LocoBody"].visible and view._layers["Rail"].visible, "trem, trilho, árvores e postes ficam")
	# trem esperando na estação dentro da janelinha: botão Partir na barra
	var f_dep: Button = fm.get_node("FloatBar/Coal/DepartButton")
	var f_auto: bool = g.state.auto_depart
	g.set_auto_depart(false)
	_check(not f_dep.visible, "janelinha: Partir escondido com o trem andando")
	g.state.station_stop_left = 2.0
	g.state.train.state = TrainMovement.State.AT_STATION
	EventBus.train_state_changed.emit(g.state.train.state)
	_check(f_dep.visible, "janelinha: Partir aparece com o trem na estação")
	f_dep.pressed.emit()
	await get_tree().process_frame
	_check(not g.state.is_at_station() and not f_dep.visible, "janelinha: Partir faz o trem sair")
	g.set_auto_depart(f_auto)
	var has_window := DisplayServer.get_name() != "headless"   # headless ignora a janela
	if has_window:
		_check(get_window().transparent_bg and get_window().borderless and get_window().always_on_top, "janela sem borda, fundo transparente e sempre no topo")
	else:
		print("  --   janela real não testada aqui (headless): ver tests/float_check.tscn")
	_check(not hud.get_node("Ticket").visible and not hud.get_node("Dashboard").visible and not hud.get_node("ShopPanel").visible, "HUD completa escondida")
	var coal_label: Label = fm.get_node("FloatBar").find_child("CoalLabel", true, false)
	_check(fm.get_node("FloatBar").visible and coal_label.text == NumFormat.amount(g.state.stock.amount), "indicador de carvão mostra o estoque (%s)" % coal_label.text)
	fm.get_node("FloatBar").find_child("ShopButton", true, false).pressed.emit()
	await get_tree().process_frame
	_check(fm.shop_open and hud.get_node("ShopPanel").visible, "botão + abre a loja compacta")
	var lvl: int = g.state.producer("foguista").level
	var stock_before: float = g.state.stock.amount
	hud._producer_rows["foguista"]["button"].pressed.emit()
	await get_tree().process_frame
	_check(g.state.producer("foguista").level == lvl + 1 and g.state.stock.amount < stock_before, "compra na loja compacta usa a mesma loja (Foguista nv %d)" % (lvl + 1))
	_check(coal_label.text == NumFormat.amount(g.state.stock.amount), "indicador atualiza depois da compra")
	var audio_node := _main.get_node("AudioDirector")
	var music_was: bool = audio_node.music_enabled
	var sfx_was: bool = audio_node.sfx_enabled
	fm.get_node("FloatBar").find_child("MusicButton", true, false).pressed.emit()
	fm.get_node("FloatBar").find_child("SfxButton", true, false).pressed.emit()
	_check(audio_node.music_enabled == not music_was and audio_node.sfx_enabled == not sfx_was, "botões pequenos ligam/desligam música e efeitos")
	fm.get_node("FloatBar").find_child("MusicButton", true, false).pressed.emit()
	fm.get_node("FloatBar").find_child("SfxButton", true, false).pressed.emit()
	_check(audio_node.music_enabled == music_was and audio_node.sfx_enabled == sfx_was, "e voltam ao estado anterior")
	g.save_now()
	var float_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_check(int(float_save["producers"]["foguista"]) == lvl + 1, "compra feita na janelinha está no mesmo save")
	await _press_esc()
	_check(fm.active and not fm.shop_open and not hud.get_node("ShopPanel").visible, "ESC fecha primeiro a loja")
	await _press_esc()
	for i in 4:
		await get_tree().process_frame
	_check(not fm.active and not view.floating and not _menu().is_open and not get_tree().paused, "ESC volta à janela normal (sem abrir o menu)")
	_check(hud.get_node("Ticket").visible and hud.get_node("ShopPanel").visible and view._layers["SkyGradient"].visible, "HUD e cenário completos de volta")
	if has_window:
		_check(not get_window().transparent_bg and not get_window().always_on_top and not get_window().borderless, "janela normal restaurada")
	_check(g.state.producer("foguista").level == lvl + 1 and hud.get_node("%StockLabel").text == NumFormat.amount(g.state.stock.amount), "modo normal mostra a compra e o carvão atualizados")
	# menu aberto -> trem flutuante -> volta -> ESC: a placa abre no lugar certo
	var board: Control = _menu().get_node("%Board")
	_menu().open()
	await get_tree().create_timer(1.6, true).timeout   # a placa termina de balançar
	var board_home: Vector2 = board.position
	_menu().get_node("Root/Board/Margin/VBox/ExtraRow/FloatButton").pressed.emit()
	await get_tree().process_frame
	_check(fm.active and not _menu().is_open and not get_tree().paused, "opção do menu liga o modo flutuante e despausa")
	await _press_esc()
	await _press_esc()
	await get_tree().create_timer(1.6, true).timeout
	_check(not fm.active and _menu().is_open, "depois de voltar, ESC abre o menu")
	_check(board.position.distance_to(board_home) < 1.0 and board.rotation == 0.0, "placa do menu no lugar certo (%s, esperado %s)" % [board.position, board_home])
	_menu().close(true)

	# Restaura o save original do jogador.
	if had_save:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if had_settings:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SETTINGS_BACKUP), ProjectSettings.globalize_path(SETTINGS_PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_BACKUP))
	elif FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	print("== %d falha(s) ==" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
