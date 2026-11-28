class_name GameState
extends RefCounted
## GameState — toda a economia e a viagem do jogo, sem interface.
##
## Recebe a configuração (o Balance) no construtor, então funciona tanto no
## jogo quanto nos testes automatizados. Não emite sinais: devolve o que
## aconteceu e o GameController repassa para a interface pelo EventBus.

const SAVE_VERSION := 6
## Trechos da rota até o save v5 (v0.8.1). No v6 os trechos mudaram (curva
## x1,6): saves antigos têm a distância convertida para a mesma posição
## relativa dentro do mesmo trecho.
const LEGACY_STATION_LENGTHS := [3500.0, 7000.0, 14000.0, 28000.0, 56000.0,
	1300000.0, 6500000.0, 28000000.0, 113000000.0, 350000000.0]

var config  # o Balance (ou um objeto com os mesmos campos)

var stock: CoalStock
var producers: Array[CoalProducer] = []
var upgrades: Upgrades
var train: TrainMovement
var route: StationTracker
var maintenance: Maintenance

## Multiplicadores derivados das melhorias compradas.
var global_multiplier: float = 1.0
var click_multiplier: float = 1.0

## Pressão da caldeira atiçada pelos cliques (0 a 1): dá velocidade extra.
var stoke: float = 0.0
## Carvão/s que está entrando pelos cliques (média móvel de alguns segundos;
## só para mostrar no contador, não é salvo).
var click_income_rate: float = 0.0
## Segundos da média móvel do carvão dos cliques.
const CLICK_RATE_SECONDS := 2.5
var _click_income_pending: float = 0.0
## Preferência do jogador: parar na plataforma de cada estação (com cutscene).
var stop_at_stations: bool = true
## Segundos que faltam parado na estação atual (0 = não está parado).
var station_stop_left: float = 0.0
## Preferência do jogador: partir sozinho depois da parada (desligada = o trem
## espera o jogador mandar partir com depart()).
var auto_depart: bool = false
## Parado na estação esperando o jogador mandar partir.
var waiting_departure: bool = false
## Quantas estações o jogador já alcançou na viagem mais longa (salvo; um
## futuro reset volta o trem, mas não esquece as estações conhecidas).
var best_station_count: int = 0
## Regra da região atual (Balance.region_effects): multiplicador de produção.
var region_production: float = 1.0
## Peça -> multiplicador de desgaste vindo das melhorias (wear_mult).
var _wear_upgrades: Dictionary = {}

var _producer_by_id: Dictionary = {}


func _init(p_config) -> void:
	config = p_config
	stock = CoalStock.new(config.initial_stock)
	for data in config.producers:
		var p := CoalProducer.new(data, config.producer_cost_growth, config.milestone_levels, config.milestone_multiplier)
		producers.append(p)
		_producer_by_id[p.id] = p
	upgrades = Upgrades.new(config.upgrades)
	train = TrainMovement.new(config.train_base_speed, config.train_speed_factor, config.train_speed_exponent)
	train.soft_knee = config.train_speed_soft_knee
	train.soft_exponent = config.train_speed_soft_exponent
	train.accel_seconds = config.train_accel_seconds
	train.brake_seconds = config.train_brake_seconds
	train.station_brake_seconds = config.train_station_brake_seconds
	route = StationTracker.new(config.stations)
	maintenance = Maintenance.new(config.components, config.reinforce_life_multiplier, config.reinforce_cost_growth,
		config.maintenance_seconds, config.repair_seconds_of_production, config.auto_repair_threshold)
	_recalculate_multipliers()
	train.target_speed = train.speed_for_production(total_production())


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

func producer(id: String) -> CoalProducer:
	return _producer_by_id.get(id)


## Produção total (carvão/s) com todos os multiplicadores.
func total_production() -> float:
	var total := 0.0
	for p in producers:
		total += p.output_per_second()
	return total * global_multiplier * region_production


## Produção de um produtor com o multiplicador global (para a loja).
func producer_production(id: String) -> float:
	return producer(id).output_per_second() * global_multiplier * region_production


## Carvão por clique: parte fixa + fração da produção, vezes as pás.
func click_value() -> float:
	return (config.coal_per_click + total_production() * config.click_production_fraction) * click_multiplier


## Velocidade extra da caldeira atiçada (0.24 = +24%).
func stoke_bonus() -> float:
	return stoke * config.stoke_max_speed_bonus


## Velocidade de cruzeiro agora (produção, reforços e caldeira).
func cruise_speed() -> float:
	return train.speed_for_production(total_production()) * (1.0 + stoke_bonus())


## O trem vai parar na PRÓXIMA estação? A primeira sempre (apresentação).
func will_stop_at_next_station() -> bool:
	if route.is_complete():
		return false
	return stop_at_stations or route.reached_count == 0


func is_producer_unlocked(id: String) -> bool:
	var p := producer(id)
	return p.unlock_station < 0 or route.is_reached(p.unlock_station)


func can_buy_producer(id: String) -> bool:
	return is_producer_unlocked(id) and stock.can_afford(producer(id).next_level_cost())


## Produção total se o produtor `id` subir um nível (para a loja).
func production_after_level_up(id: String) -> float:
	var p := producer(id)
	return total_production() + (p.output_at_level(p.level + 1) - p.output_per_second()) * global_multiplier * region_production


## A condição "requires" da melhoria foi cumprida? (aparece na loja)
func is_upgrade_available(id: String) -> bool:
	var entry := upgrades.get_entry(id)
	if entry.is_empty() or entry["purchased"]:
		return false
	var req: Dictionary = entry.get("requires", {})
	if req.has("producer") and not producer(req["producer"]).is_owned():
		return false
	if req.has("upgrade") and not upgrades.is_purchased(req["upgrade"]):
		return false
	if req.has("station") and not route.is_reached(int(req["station"])):
		return false
	return true


func can_buy_upgrade(id: String) -> bool:
	return is_upgrade_available(id) and stock.can_afford(upgrades.cost(id))


## Ids das melhorias que aparecem na loja agora, na ordem do Balance.
func available_upgrade_ids() -> Array[String]:
	var result: Array[String] = []
	for id in upgrades.ids():
		if is_upgrade_available(id):
			result.append(id)
	return result


func component(id: String) -> TrainComponent:
	return maintenance.component(id)


func is_component_active(id: String) -> bool:
	return maintenance.is_active(component(id), route)


## A aba "Trem" aparece quando a primeira peça é liberada.
func has_active_components() -> bool:
	return not maintenance.active_components(route).is_empty()


func repair_cost(id: String) -> float:
	return maintenance.repair_cost(component(id), total_production())


func can_repair(id: String) -> bool:
	var c := component(id)
	return is_component_active(id) and c.integrity < 1.0 and stock.can_afford(repair_cost(id))


func can_reinforce(id: String) -> bool:
	return is_component_active(id) and stock.can_afford(component(id).reinforce_cost())


func is_auto_maintenance_unlocked() -> bool:
	return route.is_reached(config.auto_maintenance_unlock_station)


func is_auto_available(id: String) -> bool:
	return is_component_active(id) and is_auto_maintenance_unlocked() and not component(id).has_auto()


func can_buy_auto(id: String) -> bool:
	return is_auto_available(id) and stock.can_afford(component(id).auto_cost())


# ---------------------------------------------------------------------------
# Ações do jogador
# ---------------------------------------------------------------------------

func click() -> void:
	var gained := click_value()
	stock.add(gained)
	_click_income_pending += gained
	stoke = minf(1.0, stoke + config.stoke_per_click)


func buy_producer(id: String) -> bool:
	if not is_producer_unlocked(id):
		return false
	var p := producer(id)
	if not stock.try_spend(p.next_level_cost()):
		return false
	p.level_up()
	return true


func buy_upgrade(id: String) -> bool:
	if not is_upgrade_available(id):
		return false
	if not stock.try_spend(upgrades.cost(id)):
		return false
	upgrades.mark_purchased(id)
	_recalculate_multipliers()
	return true


## Reparo preventivo: paga e leva a peça a 100%.
func repair_component(id: String) -> bool:
	if not can_repair(id):
		return false
	stock.try_spend(repair_cost(id))
	component(id).integrity = 1.0
	return true


func reinforce_component(id: String) -> bool:
	if not can_reinforce(id):
		return false
	var c := component(id)
	stock.try_spend(c.reinforce_cost())
	c.level += 1
	_recalculate_multipliers()
	return true


## Bônus total de velocidade dos reforços (0.12 = +12%).
func reinforce_speed_bonus() -> float:
	var levels := 0
	for c in maintenance.components:
		levels += c.level
	return levels * float(config.reinforce_speed_bonus)


## Compra a manutenção automática para o material ATUAL da peça.
func buy_auto_maintenance(id: String) -> bool:
	if not can_buy_auto(id):
		return false
	var c := component(id)
	stock.try_spend(c.auto_cost())
	c.auto_material = c.material()["id"]
	return true


# ---------------------------------------------------------------------------
# Simulação
# ---------------------------------------------------------------------------

## Avança `delta` segundos. Retorna:
## { "state_changed": bool, "stations": [índices], "failed": [ids],
##   "auto": [ids], "maintenance_done": bool, "station_stop": bool, "departed": bool }
func tick(delta: float) -> Dictionary:
	var production := total_production()
	stock.add(production * delta)  # a produção continua mesmo parado
	stoke *= exp(-delta / config.stoke_decay_seconds)
	_update_click_income_rate(delta)
	var result := {"state_changed": false, "stations": [] as Array[int], "failed": [] as Array[String],
		"auto": [] as Array[String], "maintenance_done": false, "station_stop": false, "departed": false}
	var previous_state := train.state
	var cruise := cruise_speed()

	# Parado na plataforma (contando a parada ou esperando o jogador).
	if is_at_station():
		train.hold(TrainMovement.State.AT_STATION, cruise)
		if station_stop_left > 0.0:
			station_stop_left -= delta
			if station_stop_left <= 0.0:
				station_stop_left = 0.0
				if auto_depart:
					train.state = TrainMovement.State.ACCELERATING
					result["departed"] = true
				else:
					waiting_departure = true
		result["state_changed"] = train.state != previous_state
		return result

	# Peça quebrada: freia; o conserto só conta com o trem parado.
	var failing := maintenance.is_stopped()
	if failing and train.is_stopped():
		train.hold(TrainMovement.State.MAINTENANCE, cruise)
		result["maintenance_done"] = maintenance.tick_stop(delta)
		if result["maintenance_done"]:
			train.state = TrainMovement.State.ACCELERATING
		result["state_changed"] = train.state != previous_state
		return result

	var stop_at := INF
	if will_stop_at_next_station():
		stop_at = route.target_distance(route.reached_count)
	var meters := train.tick(delta, cruise, failing, stop_at)
	var moving_seconds := delta if meters > 0.0 else 0.0
	var wear := maintenance.wear(meters, moving_seconds, route, stock, production)
	result["failed"] = wear["failed"]
	result["auto"] = wear["auto"]
	if maintenance.is_stopped() and not failing:
		train.state = TrainMovement.State.BRAKING  # começou a frear agora
	result["stations"] = route.update(train.distance_m)
	if not result["stations"].is_empty():
		_apply_region()   # entrou numa região nova
	if not result["stations"].is_empty() and is_finite(stop_at) and train.distance_m >= stop_at:
		station_stop_left = config.station_stop_seconds
		train.hold(TrainMovement.State.AT_STATION, cruise)
		result["station_stop"] = true
	result["state_changed"] = train.state != previous_state
	return result


## Converte uma distância dos trechos antigos (save até v5) para a mesma
## posição relativa (mesmo trecho, mesma fração) na rota atual.
func legacy_distance_to_current(old_distance: float) -> float:
	var old_start := 0.0
	var new_start := 0.0
	var n := mini(LEGACY_STATION_LENGTHS.size(), route.station_count())
	for i in n:
		var old_len: float = LEGACY_STATION_LENGTHS[i]
		var new_len: float = route.target_distance(i) - new_start
		if old_distance < old_start + old_len:
			return new_start + (old_distance - old_start) / old_len * new_len
		old_start += old_len
		new_start += new_len
	return new_start + (old_distance - old_start)   # depois do fim da rota


## Produção dos produtores + carvão/s que está vindo dos cliques.
func effective_production() -> float:
	return total_production() + click_income_rate


func _update_click_income_rate(delta: float) -> void:
	if delta <= 0.0:
		return
	var now_rate := _click_income_pending / delta
	_click_income_pending = 0.0
	click_income_rate += (now_rate - click_income_rate) * (1.0 - exp(-delta / CLICK_RATE_SECONDS))
	if click_income_rate < 1e-3:
		click_income_rate = 0.0


## Parado na plataforma de uma estação (contando a parada ou esperando partir).
func is_at_station() -> bool:
	return station_stop_left > 0.0 or waiting_departure


## O jogador manda partir (com "Partir sozinho" desligado). Pode partir já
## durante a parada. Retorna false se o trem não está parado numa estação.
func depart() -> bool:
	if not is_at_station():
		return false
	station_stop_left = 0.0
	waiting_departure = false
	train.state = TrainMovement.State.ACCELERATING
	return true


## Aplica `elapsed_seconds` de progresso offline. Retorna o resumo:
## { "seconds", "stock_delta", "distance", "stations": [índices], "failures",
##   "downtime", "auto_repairs", "auto_cost", "waiting_at_station",
##   "waiting_station" (índice da estação nova esperada, ou -1) }.
## Offline não há inércia: o trem anda em cruzeiro (sem impulso da caldeira).
func apply_offline(elapsed_seconds: float) -> Dictionary:
	var seconds := OfflineProgress.clamp_elapsed(elapsed_seconds, config.offline_max_seconds)
	var stock_before := stock.amount
	# Movimento reduzido: o trem anda só uma fração do tempo fora (o tempo
	# simulado encolhe); a produção, um pouco menor, vale pelo tempo todo.
	var move_frac := clampf(config.offline_movement_efficiency, 0.001, 1.0)
	var coal_rate: float = total_production() * config.offline_production_efficiency / move_frac

	# Estação nova não passa offline: espera um pouco antes dela.
	var max_distance := INF
	var known := known_station_count()
	var waiting_for := -1
	if config.offline_stop_before_new_station and known < route.station_count():
		waiting_for = known
		max_distance = maxf(0.0, route.target_distance(known) - config.offline_wait_distance_m - train.distance_m)
	if waiting_departure:
		max_distance = 0.0   # parado na estação esperando o jogador mandar partir
		waiting_for = -1

	var result := OfflineProgress.simulate(seconds * move_frac, total_production(), stock.amount, train,
		maintenance, route, max_distance, coal_rate)

	stock.amount = maxf(0.0, stock.amount + float(result["coal_delta"]))
	var distance := float(result["distance"])
	if is_finite(max_distance) and distance >= max_distance - 0.001:
		distance = max_distance  # para exatamente no ponto de espera
	train.distance_m += distance
	var reached := route.update(train.distance_m)
	_apply_region()
	# Ao abrir, o trem parte do zero e segue viagem (ou continua esperando na
	# estação o jogador mandar partir).
	train.current_speed = 0.0
	train.state = TrainMovement.State.AT_STATION if waiting_departure else TrainMovement.State.ACCELERATING
	var waiting: bool = result["waiting_at_station"] or (waiting_for >= 0 and is_equal_approx(max_distance, 0.0))
	return {
		"seconds": seconds,
		"stock_delta": stock.amount - stock_before,
		"distance": distance,
		"stations": reached,
		"failures": result["failures"],
		"downtime": result["downtime"],
		"auto_repairs": result["auto_repairs"],
		"auto_cost": result["auto_cost"],
		"waiting_at_station": waiting,
		"waiting_station": waiting_for if waiting else -1,
		"waiting_departure": waiting_departure,
	}


## Estações que o jogador já conhece: a mais longe que ele alcançou em
## qualquer viagem (vale também depois de um futuro reset).
func known_station_count() -> int:
	return maxi(best_station_count, route.reached_count)


# ---------------------------------------------------------------------------
# Efeitos das melhorias
# ---------------------------------------------------------------------------

## Recalcula todos os multiplicadores a partir das melhorias compradas.
## (Recalcular do zero evita erro acumulado e simplifica o carregamento.)
func _recalculate_multipliers() -> void:
	global_multiplier = 1.0
	click_multiplier = 1.0
	maintenance.time_multiplier = 1.0
	_wear_upgrades = {}
	for p in producers:
		p.upgrade_multiplier = 1.0
	for id in upgrades.purchased_ids():
		var entry := upgrades.get_entry(id)
		match entry["effect"]:
			"global_mult":
				global_multiplier *= float(entry["value"])
			"click_mult":
				click_multiplier *= float(entry["value"])
			"maintenance_time_mult":
				maintenance.time_multiplier *= float(entry["value"])
			"producer_mult":
				var target := producer(entry["target"])
				if target:
					target.upgrade_multiplier *= float(entry["value"])
			"wear_mult":
				for cid in entry["target"]:
					_wear_upgrades[cid] = float(_wear_upgrades.get(cid, 1.0)) * float(entry["value"])
			"material":
				var comp := component(entry["target"])
				if comp:
					comp.set_material(str(entry["value"]))
			_:
				push_warning("GameState: efeito desconhecido '%s' em %s" % [entry["effect"], id])
	_apply_region()


## Tema da região em que o trem está (o do trecho até a próxima estação).
func current_region() -> String:
	var count := route.station_count()
	if count == 0:
		return ""
	return str(route.stations[clampi(route.reached_count, 0, count - 1)].get("theme", ""))


## Regra da região atual ({} quando a região não tem regra).
func region_effect() -> Dictionary:
	return config.region_effects.get(current_region(), {})


## Aplica a regra da região: produção, velocidade e desgaste das peças.
func _apply_region() -> void:
	var fx := region_effect()
	region_production = float(fx.get("production", 1.0))
	train.speed_multiplier = (1.0 + reinforce_speed_bonus()) * float(fx.get("speed", 1.0))
	var wear: Dictionary = fx.get("wear", {})
	for c in maintenance.components:
		c.wear_multiplier = float(wear.get(c.id, 1.0)) * float(_wear_upgrades.get(c.id, 1.0))


# ---------------------------------------------------------------------------
# Salvamento
# ---------------------------------------------------------------------------

func to_save(saved_at_unix: float) -> Dictionary:
	var levels := {}
	for p in producers:
		levels[p.id] = p.level
	var comps := {}
	for c in maintenance.components:
		comps[c.id] = {"integrity": c.integrity, "level": c.level, "material": c.material()["id"],
			"auto": c.auto_material, "auto_repairs": c.auto_repairs, "failures": c.failures}
	return {
		"save_version": SAVE_VERSION,
		"saved_at": saved_at_unix,
		"stock": stock.amount,
		"stop_at_stations": stop_at_stations,
		"auto_depart": auto_depart,
		"waiting_departure": waiting_departure or (station_stop_left > 0.0 and not auto_depart),
		"producers": levels,
		"upgrades_purchased": upgrades.purchased_ids(),
		"distance_m": train.distance_m,
		"best_station_count": known_station_count(),
		"components": comps,
		"maintenance_left": maintenance.stop_left,
		"maintenance_component": maintenance.stop_component_id,
	}


## Carrega um save (v1 a v6). Saves sem componentes começam com tudo a 100%. As estações alcançadas são recalculadas
## pela distância, sem disparar eventos.
func load_save(data: Dictionary) -> void:
	var version := int(data.get("save_version", 1))
	train.distance_m = maxf(0.0, float(data.get("distance_m", 0.0)))
	if version < 6:
		train.distance_m = legacy_distance_to_current(train.distance_m)
	route.update(train.distance_m)
	best_station_count = maxi(route.reached_count, int(data.get("best_station_count", 0)))

	if version >= 3:
		var levels: Dictionary = data.get("producers", {})
		for id in levels:
			if producer(id):
				producer(id).level = maxi(0, int(levels[id]))
		for id in data.get("upgrades_purchased", []):
			if upgrades.has(id):
				upgrades.mark_purchased(id)
		stock.amount = maxf(0.0, float(data.get("stock", 0.0)))
	else:
		# Fase 0: só existia o Foguista.
		producer("foguista").level = maxi(0, int(data.get("producer_level", 0)))
		# v2: "Caldeira reforçada" (+50%) era "station_production"; hoje é "station_0".
		if "station_production" in data.get("upgrades_purchased", []):
			upgrades.mark_purchased("station_0")
		if version == 2:
			stock.amount = maxf(0.0, float(data.get("stock", 0.0)))
		else:
			stock.amount = maxf(0.0, float(data.get("coal", 0.0)))
	# v2 a v4 tinham reservatório: o carvão dele volta para o estoque.
	if version < 5:
		stock.amount += maxf(0.0, float(data.get("tank", 0.0)))
	stop_at_stations = bool(data.get("stop_at_stations", true))
	auto_depart = bool(data.get("auto_depart", false))
	waiting_departure = bool(data.get("waiting_departure", false)) and route.reached_count > 0 and not route.is_complete()
	if waiting_departure:
		train.hold(TrainMovement.State.AT_STATION, 0.0)

	if version >= 4:
		var saved: Dictionary = data.get("components", {})
		for id in saved:
			var c := component(id)
			if c == null:
				continue
			var d: Dictionary = saved[id]
			c.integrity = clampf(float(d.get("integrity", 1.0)), 0.0, 1.0)
			c.level = maxi(0, int(d.get("level", 0)))
			for i in c.materials.size():
				if c.materials[i]["id"] == d.get("material", ""):
					c.material_index = i
			c.auto_material = str(d.get("auto", ""))
			c.auto_repairs = int(d.get("auto_repairs", 0))
			c.failures = int(d.get("failures", 0))
		maintenance.stop_left = maxf(0.0, float(data.get("maintenance_left", 0.0)))
		maintenance.stop_component_id = str(data.get("maintenance_component", ""))

	_recalculate_multipliers()
	train.target_speed = train.speed_for_production(total_production())
