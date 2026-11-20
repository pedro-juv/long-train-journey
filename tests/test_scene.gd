extends Node
## Teste de integração: abre a cena principal de verdade e confere a interface.
## Rodar: godot --headless --path . res://tests/test_scene.tscn
## (roda como cena normal para os autoloads Balance/EventBus/SaveManager existirem)
##
## Faz backup do save do jogador e o restaura no fim.

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save_backup_teste.json"

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


func _run() -> void:
	print("== Teste da cena principal (Fase 1A + 1B) ==")
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))

	var now := Time.get_unix_time_from_system()

	# --- 1. Save v3 com 2 horas fora -----------------------------------------
	_write_save({"save_version": 3, "saved_at": now - 7200.0, "stock": 500.0, "tank": 100.0,
		"producers": {"foguista": 12, "carvoaria": 3, "mina": 0},
		"upgrades_purchased": ["click_1"], "distance_m": 4000.0})
	await _open_game()
	var g := _game()
	var hud := _hud()
	print("Carregamento e offline (2 h fora)")
	_check(g.state.producer("foguista").level == 12 and g.state.producer("carvoaria").level == 3, "níveis carregados")
	_check(g.state.stock.amount > 500.0 + 50000.0, "estoque ganhou a produção offline (%s)" % NumFormat.amount(g.state.stock.amount))
	_check(hud.get_node("%OfflinePopup").visible, "resumo offline aparece")
	var text: String = hud.get_node("%OfflineText").text
	_check(text.contains("Tempo fora: 2 h"), "resumo mostra o tempo fora")
	_check(text.contains("Estações alcançadas: Primavera"), "resumo lista a estação alcançada offline")
	_check(hud.get_node("%MessageLabel").text.contains("Primavera"), "chegada da estação alcançada offline aparece ao abrir (caminho B)")
	_check(text.contains("esperou você"), "resumo avisa que o trem esperou na estação")
	_check(g.state.train.distance_m >= 10500.0 and g.state.train.distance_m < 10520.0, "offline parou na Primavera e o trem segue ao abrir (%.0f m)" % g.state.train.distance_m)
	var view := _main.get_node("TrainView")
	var audio := _main.get_node("AudioDirector")
	_check(view._theme_id == "primavera", "cenário no tema da Primavera (%s)" % view._theme_id)
	_check(audio.current_music_theme() == "primavera", "música na variação da Primavera (%s)" % audio.current_music_theme())
	g.state.train.distance_m = g.state.route.target_distance(2) - 1.0
	await get_tree().create_timer(0.3).timeout
	_check(view._theme_id == "verao" and view._prev_theme_id == "primavera" and view._blend < 1.0, "chegar ao Verão inicia a transição de tema")
	_check(audio.current_music_theme() == "verao", "música troca para a variação do Verão")
	hud.get_node("%OfflineOk").pressed.emit()
	_check(not hud.get_node("%OfflinePopup").visible, "botão fecha o resumo")

	print("Loja")
	var rows: Dictionary = hud._producer_rows
	_check(rows.size() == 3, "três linhas de produtores")
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
	hud.get_node("%ClickButton").pressed.emit()
	_check(is_equal_approx(g.state.stock.amount - clicks_before, 2.0), "clique vale 2 com a 1ª melhoria")

	print("Save")
	g.save_now()
	var saved: Dictionary = SaveManager.load_game()
	_check(int(saved.get("save_version", 0)) == 4 and saved.has("saved_at") and saved.has("components"), "save v4 com horário e componentes")
	_check(int(saved["producers"]["carvoaria"]) == 4, "save guarda os níveis")

	print("Aba Trem")
	var train_tab: Button = hud.get_node("%TrainTab")
	_check(train_tab.visible, "aba Trem visível depois da Estação Inicial")
	train_tab.pressed.emit()
	var crow: Dictionary = hud._component_rows
	_check(crow.size() == 6, "seis peças listadas")
	_check(crow["rodas"]["title"].text.contains("Rodas de ferro fundido"), "rodas de ferro fundido (%s)" % crow["rodas"]["title"].text)
	_check(crow["chamine"]["title"].text.contains("bloqueado"), "Chaminé bloqueada até o Outono")
	_check(not crow["rodas"]["auto"].visible, "manutenção automática escondida antes do Outono")
	g.state.component("rodas").integrity = 0.2
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	_check(hud.get_node("%WarningLabel").visible and hud.get_node("%WarningLabel").text.contains("Rodas"), "aviso de peça gasta no painel")
	crow["rodas"]["repair"].pressed.emit()
	_check(is_equal_approx(g.state.component("rodas").integrity, 1.0), "botão Reparar leva a 100%")
	crow["rodas"]["reinforce"].pressed.emit()
	_check(g.state.component("rodas").level == 1, "botão Reforçar sobe o nível")
	g.state.component("pistoes").integrity = 0.000001
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	_check(g.state.maintenance.is_stopped(), "peça a 0%: trem em manutenção")
	_check(hud.get_node("%StateLabel").text.contains("EM MANUTENÇÃO (Pistões)"), "estado mostra a manutenção (%s)" % hud.get_node("%StateLabel").text)
	_check(hud.get_node("%MaintenanceBar").visible, "barra de manutenção visível")
	hud.get_node("%ProductionTab").pressed.emit()
	_check(hud._producer_rows.size() == 3, "volta para a aba Produção")

	# --- 2. Três dias fora: limite de 24 h -----------------------------------
	_write_save({"save_version": 3, "saved_at": now - 3 * 86400.0, "stock": 0.0, "tank": 100.0,
		"producers": {"foguista": 5}, "upgrades_purchased": [], "distance_m": 0.0})
	await _open_game()
	print("Limite de 24 h")
	text = _hud().get_node("%OfflineText").text
	_check(text.contains("contamos até 24 h"), "resumo avisa que contou só 24 h (%s)" % text.get_slice("\n", 0))

	# --- 2b. Outono: manutenção automática e resumo de paradas ---------------
	_write_save({"save_version": 4, "saved_at": now - 3600.0, "stock": 1e9, "tank": 100.0,
		"producers": {"foguista": 30, "carvoaria": 20}, "upgrades_purchased": [], "distance_m": 60000.0,
		"components": {}})
	await _open_game()
	print("Outono: manutenção automática")
	_check(_main.get_node("TrainView")._theme_id == "inverno", "1 h fora a partir do Outono: chega ao Inverno (tema %s)" % _main.get_node("TrainView")._theme_id)
	text = _hud().get_node("%OfflineText").text
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
	_hud().get_node("%ResetButton").pressed.emit()
	_check(_game().state.producer("foguista").level == 0 and _game().state.train.distance_m == 0.0, "reiniciar zera a partida")

	# Restaura o save original do jogador.
	if had_save:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("== %d falha(s) ==" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
