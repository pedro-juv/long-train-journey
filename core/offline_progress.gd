class_name OfflineProgress
extends RefCounted
## OfflineProgress — calcula o que aconteceu enquanto o jogo estava fechado.
##
## Offline não há compras, então produção e velocidade são constantes e o
## cálculo é exato, por eventos (cada falha ou conserto automático é um evento),
## sem simular frame a frame. Mesmo 24 horas são calculadas instantaneamente.
##
## Regras:
## - Produção e movimento reduzidos (Balance.offline_production_efficiency e
##   offline_movement_efficiency); limite em Balance.offline_max_seconds.
## - O trem não chega em estação nova offline: para antes dela e espera o
##   jogador; a produção continua mesmo com o trem esperando.
## - Peças desgastam e quebram como online (parada + conserto automático);
##   com manutenção automática, o conserto é pago e o trem não para.

const MAX_EVENTS := 500000


## Segundos que contam como offline: nunca negativo (relógio voltou no tempo
## = 0) e no máximo `max_seconds`.
static func clamp_elapsed(elapsed_seconds: float, max_seconds: float) -> float:
	return clampf(elapsed_seconds, 0.0, max_seconds)


## Simula `seconds` offline. Altera a integridade das peças e a parada em
## andamento em `maint`. Retorna:
## { "coal_delta", "distance", "failures", "auto_repairs", "auto_cost",
##   "downtime", "waiting_at_station" }
## `coal_rate` é o carvão ganho por segundo simulado (padrão: a produção);
## a velocidade sempre vem da produção real.
static func simulate(seconds: float, production: float, stock_available: float, train: TrainMovement,
		maint: Maintenance, route: StationTracker, max_distance: float, coal_rate: float = -1.0) -> Dictionary:
	var out := {"coal_delta": 0.0, "distance": 0.0, "failures": 0, "auto_repairs": 0,
		"auto_cost": 0.0, "downtime": 0.0, "waiting_at_station": false}
	if seconds <= 0.0:
		return out
	if coal_rate < 0.0:
		coal_rate = production

	var speed := train.speed_for_production(production)
	var t := 0.0
	var coal := stock_available

	# Termina uma parada que estava em andamento quando o jogo fechou.
	if maint.stop_left > 0.0:
		var d := minf(maint.stop_left, seconds)
		maint.stop_left -= d
		if maint.stop_left <= 0.0:
			maint.stop_left = 0.0
			maint.stop_component_id = ""
		t += d
		out["downtime"] += d
		coal += coal_rate * d

	var comps := maint.active_components(route)
	var auto_cost := maint.auto_repair_cost(production)
	var skip_auto := {}  # peças cujo conserto automático não pôde ser pago neste ciclo
	var dist := 0.0
	var events := 0
	while t < seconds and events < MAX_EVENTS:
		if dist >= max_distance - 1e-6:
			out["waiting_at_station"] = true
			break
		var step := minf(seconds - t, (max_distance - dist) / speed)
		var event: TrainComponent = null
		for c in comps:
			var rate := c.wear_rate(speed)
			var target := maint.auto_threshold() if (c.has_auto() and not skip_auto.has(c.id)) else 0.0
			var until := maxf(0.0, (c.integrity - target) / rate)
			if until < step:
				step = until
				event = c
		for c in comps:
			c.integrity -= c.wear_rate(speed) * step
		dist += speed * step
		t += step
		coal += coal_rate * step
		if event == null:
			continue
		events += 1
		if event.has_auto() and not skip_auto.has(event.id):
			if coal >= auto_cost:
				coal -= auto_cost
				out["auto_cost"] += auto_cost
				out["auto_repairs"] += 1
				event.auto_repairs += 1
				event.integrity = 1.0
			else:
				skip_auto[event.id] = true  # segue até 0% e quebra
			continue
		skip_auto.erase(event.id)
		event.integrity = 1.0
		event.failures += 1
		out["failures"] += 1
		var stop := minf(maint.stop_seconds(), seconds - t)
		t += stop
		out["downtime"] += stop
		coal += coal_rate * stop
		# Inércia: frear e arrancar de novo custam ~metade do tempo de cada fase.
		var inertia := minf((train.brake_seconds + train.accel_seconds) * 0.5, seconds - t)
		t += inertia
		coal += coal_rate * inertia

	# Esperando na estação (ou fim do tempo): a produção continua.
	if t < seconds:
		coal += coal_rate * (seconds - t)
	out["distance"] = dist
	out["coal_delta"] = coal - stock_available
	return out

