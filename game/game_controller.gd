class_name GameController
extends Node
## GameController — liga o GameState (lógica) ao jogo rodando.
##
## Avança o GameState a cada frame, repassa os acontecimentos pelo EventBus,
## aplica o progresso offline ao abrir e cuida do autosave.
## Não contém regras de economia: elas vivem em core/game_state.gd.

var state: GameState

var _autosave_timer: float = 0.0
var _last_emitted_distance: float = -1.0
var _last_emitted_stock: float = -1.0
var _last_emitted_tank: float = -1.0


func _ready() -> void:
	state = GameState.new(Balance)
	var offline_summary := {}
	var data := SaveManager.load_game()
	if not data.is_empty():
		state.load_save(data)
		offline_summary = _apply_offline(data)
	# Adiado para o fim do frame: garante que HUD e TrainView (que ficam depois
	# na árvore) já se conectaram ao EventBus quando o estado for emitido.
	_announce_full_state.call_deferred(offline_summary)


func _process(delta: float) -> void:
	var result := state.tick(delta)
	if result["state_changed"]:
		EventBus.train_state_changed.emit(state.train.state)
	for index in result["stations"]:
		_on_station_reached(index)
	for id in result["failed"]:
		EventBus.component_failed.emit(id, state.component(id).display_name)
	for id in result["auto"]:
		EventBus.component_repaired.emit(id, true)
	if result["maintenance_done"]:
		EventBus.maintenance_finished.emit()
	EventBus.speed_changed.emit(state.train.current_speed, state.train.target_speed, state.train.consumption_per_second())
	if state.train.distance_m != _last_emitted_distance:
		_last_emitted_distance = state.train.distance_m
		EventBus.distance_changed.emit(state.train.distance_m)
	_emit_resources_if_changed()
	_tick_autosave(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
		get_tree().quit()


# ---------------------------------------------------------------------------
# Ações do jogador (chamadas pela HUD)
# ---------------------------------------------------------------------------

func click_coal() -> void:
	state.click()
	_emit_resources_if_changed()
	EventBus.coal_clicked.emit()


func buy_producer(id: String) -> bool:
	if not state.buy_producer(id):
		return false
	var level := state.producer(id).level
	_emit_resources_if_changed()
	EventBus.producer_bought.emit(id, level, level in Balance.milestone_levels)
	EventBus.shop_changed.emit()
	return true


func buy_upgrade(id: String) -> bool:
	if not state.buy_upgrade(id):
		return false
	_emit_resources_if_changed()
	EventBus.upgrade_purchased.emit(id)
	EventBus.shop_changed.emit()
	return true


func repair_component(id: String) -> bool:
	if not state.repair_component(id):
		return false
	_emit_resources_if_changed()
	EventBus.component_repaired.emit(id, false)
	EventBus.shop_changed.emit()
	return true


func reinforce_component(id: String) -> bool:
	if not state.reinforce_component(id):
		return false
	_emit_resources_if_changed()
	EventBus.component_reinforced.emit(id, state.component(id).level)
	EventBus.shop_changed.emit()
	return true


func buy_auto_maintenance(id: String) -> bool:
	if not state.buy_auto_maintenance(id):
		return false
	_emit_resources_if_changed()
	EventBus.upgrade_purchased.emit("auto_" + id)
	EventBus.shop_changed.emit()
	return true


## Apaga o save e recomeça (botão de teste na HUD).
func reset_game() -> void:
	SaveManager.delete_save()
	state = GameState.new(Balance)
	_autosave_timer = 0.0
	_announce_full_state({})


func save_now() -> void:
	SaveManager.save_game(state.to_save(Time.get_unix_time_from_system()))


# ---------------------------------------------------------------------------
# Internos
# ---------------------------------------------------------------------------

func _apply_offline(data: Dictionary) -> Dictionary:
	if not data.has("saved_at"):
		return {}  # saves antigos não sabem quando foram gravados
	var elapsed := Time.get_unix_time_from_system() - float(data["saved_at"])
	var summary := state.apply_offline(elapsed)
	if float(summary["seconds"]) < Balance.offline_min_seconds_for_summary:
		return {}
	summary["elapsed_real"] = maxf(0.0, elapsed)
	return summary


func _on_station_reached(index: int) -> void:
	EventBus.station_reached.emit(index, state.route.station_name(index))
	EventBus.shop_changed.emit()
	save_now()


func _tick_autosave(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= Balance.autosave_interval:
		_autosave_timer = 0.0
		save_now()


func _emit_resources_if_changed() -> void:
	if state.stock.amount != _last_emitted_stock:
		_last_emitted_stock = state.stock.amount
		EventBus.stock_changed.emit(state.stock.amount)
	if state.tank.current != _last_emitted_tank:
		_last_emitted_tank = state.tank.current
		EventBus.tank_changed.emit(state.tank.current, state.tank.capacity)


## Emite todo o estado atual e avisa a interface para se sincronizar.
## Não reemite "estação alcançada"/"melhoria comprada": esses são sinais de
## EVENTO (mostram mensagem); a HUD lê o estado direto em game_loaded.
func _announce_full_state(offline_summary: Dictionary) -> void:
	_last_emitted_stock = -1.0
	_last_emitted_tank = -1.0
	_last_emitted_distance = state.train.distance_m
	_emit_resources_if_changed()
	EventBus.train_state_changed.emit(state.train.state)
	EventBus.speed_changed.emit(state.train.current_speed, state.train.target_speed, state.train.consumption_per_second())
	EventBus.distance_changed.emit(state.train.distance_m)
	EventBus.game_loaded.emit()
	if not offline_summary.is_empty():
		EventBus.offline_summary.emit(offline_summary)
		# Estações alcançadas offline: o jogador vê a chegada ao abrir
		# (placa, faixa, apito), como pede o caminho B.
		for index in offline_summary.get("stations", []):
			EventBus.station_reached.emit(index, state.route.station_name(index))
