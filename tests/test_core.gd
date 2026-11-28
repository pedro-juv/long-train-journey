extends SceneTree
## Teste automatizado do núcleo (sem interface).
## Rodar: godot --headless --path . -s tests/test_core.gd
##
## Usa o GameState com os valores reais do Balance e simula jogadores.

var _fails := 0
var B  # instância do Balance (mesmos valores do jogo)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		_fails += 1
		print("  FAIL ", msg)


func _initialize() -> void:
	B = load("res://autoload/balance.gd").new()
	print("== Teste do núcleo Idle Train (Fase 1A + 1B) ==")
	_test_producers()
	_test_upgrades()
	_test_speed()
	_test_route()
	_test_inertia()
	_test_click_and_stoke()
	_test_components()
	_test_failure_and_maintenance()
	_test_repair_reinforce_tools()
	_test_auto_maintenance_and_materials()
	_test_offline()
	_test_offline_matches_online()
	_test_save_roundtrip_and_migration()
	_test_number_format()
	_test_simulation()
	if not OS.has_environment("SKIP_LONG"):   # rota longa leva alguns minutos
		_test_long_route()
	B.free()
	print("== %d falha(s) ==" % _fails)
	quit(1 if _fails > 0 else 0)


func _new_state() -> GameState:
	return GameState.new(B)


func _test_producers() -> void:
	print("Produtores")
	var s := _new_state()
	_check(s.producers.size() == 8, "oito produtores carregados do Balance")
	_check(s.is_producer_unlocked("foguista") and s.is_producer_unlocked("carvoaria"), "Foguista e Carvoaria liberados desde o início")
	_check(not s.is_producer_unlocked("mina"), "Mina bloqueada até a 1ª estação")
	_check(s.buy_producer("foguista") and s.producer("foguista").level == 1, "compra o Foguista com o estoque inicial")
	_check(is_equal_approx(s.stock.amount, 5.0), "estoque descontado (20 - 15)")
	var f := s.producer("foguista")
	_check(f.next_level_cost() == roundf(15.0 * 1.32), "custo cresce 1,32 por nível (%d)" % f.next_level_cost())
	_check(is_equal_approx(f.output_at_level(9), 9.0), "nível 9 = 9/s (antes do marco)")
	_check(is_equal_approx(f.output_at_level(10), 20.0), "marco no nível 10 dobra (20/s)")
	_check(is_equal_approx(f.output_at_level(25), 100.0), "marco no 25 dobra de novo (25 x 4 = 100/s)")
	_check(f.next_milestone() == 10, "próximo marco = 10")
	s.stock.add(1e9)
	_check(not s.buy_producer("mina"), "não compra a Mina antes da estação")


func _test_upgrades() -> void:
	print("Melhorias")
	var s := _new_state()
	s.stock.add(1e9)
	_check(str(s.available_upgrade_ids()) == str(["click_1"]), "no início só a 1ª melhoria de clique aparece (%s)" % [s.available_upgrade_ids()])
	_check(s.buy_upgrade("click_1") and is_equal_approx(s.click_value(), 2.0), "clique dobra para 2 (sem produção)")
	_check(s.is_upgrade_available("click_2") and not s.is_upgrade_available("click_3"), "melhorias de clique em sequência")
	s.buy_upgrade("click_2"); s.buy_upgrade("click_3")
	_check(is_equal_approx(s.click_value(), 8.0), "três melhorias = clique 8 (sem produção)")
	_check(not s.is_upgrade_available("eq_foguista"), "equipamento exige o produtor")
	s.buy_producer("foguista")
	_check(s.is_upgrade_available("eq_foguista"), "equipamento aparece com o Foguista nível 1")
	var before := s.total_production()
	s.buy_upgrade("eq_foguista")
	_check(is_equal_approx(s.total_production(), before * 2.0), "equipamento dobra o produtor")
	_check(not s.buy_upgrade("eq_foguista"), "não compra duas vezes")
	_check(not s.is_upgrade_available("station_0"), "melhoria da estação exige a estação")
	s.train.distance_m = 3500.0
	s.route.update(s.train.distance_m)
	_check(s.is_upgrade_available("station_0") and s.is_producer_unlocked("mina"), "1ª estação libera Caldeira reforçada e a Mina")
	before = s.total_production()
	s.buy_upgrade("station_0")
	_check(is_equal_approx(s.total_production(), before * 1.5), "Caldeira reforçada: produção total +50%")
	var prod := s.total_production()
	_check(is_equal_approx(s.click_value(), (1.0 + prod * 0.02) * 8.0), "clique = (1 + 2%% da produção) x8 = %.1f" % s.click_value())


func _test_click_and_stoke() -> void:
	print("Clique proporcional e caldeira atiçada")
	var s := _new_state()
	s.stock.add(1e12)
	for i in 40:
		s.buy_producer("carvoaria")
	var prod := s.total_production()
	_check(s.click_value() > prod * 0.019, "clique continua útil com produção alta (%.0f por clique, %.0f/s)" % [s.click_value(), prod])
	var cruise0 := s.cruise_speed()
	s.click()
	_check(s.stoke > 0.0 and s.cruise_speed() > cruise0, "clique atiça a caldeira: velocidade sobe")
	for i in 100:
		s.click()
	_check(is_equal_approx(s.stoke, 1.0) and absf(s.cruise_speed() / cruise0 - (1.0 + B.stoke_max_speed_bonus)) < 0.001, "pressão máxima = +%d%% de velocidade" % roundi(B.stoke_max_speed_bonus * 100.0))
	for i in 200:  # 20 s sem clicar
		s.tick(0.1)
	_check(s.stoke < 0.01, "pressão escoa sozinha sem cliques (%.3f)" % s.stoke)
	var e := _new_state()
	for i in 300:
		if i % 3 == 0:
			e.click()
		e.tick(0.1)
	_check(e.stoke > 0.45 and e.stoke < 0.75, "3 cliques/s: pressão estável em ~0,6 (%.2f)" % e.stoke)
	# contador: carvão/s dos cliques entra na produção mostrada
	var c := _new_state()
	c.stock.add(1e12)
	for i in 40:
		c.buy_producer("carvoaria")
	_check(c.click_income_rate == 0.0 and is_equal_approx(c.effective_production(), c.total_production()), "sem cliques: contador = produção")
	var per_click := c.click_value()
	for i in 400:   # 20 s a 5 cliques/s, quadros de 0,05 s
		if i % 4 == 0:
			c.click()
		c.tick(0.05)
	var expected := 5.0 * per_click
	_check(absf(c.click_income_rate - expected) / expected < 0.1, "5 cliques/s: contador soma ~5 cliques de carvão por segundo (%.0f, esperado %.0f)" % [c.click_income_rate, expected])
	_check(is_equal_approx(c.effective_production(), c.total_production() + c.click_income_rate), "produção mostrada = produtores + cliques")
	for i in 400:   # 20 s sem clicar
		c.tick(0.05)
	_check(c.click_income_rate < expected * 0.01, "parou de clicar: a parte dos cliques some aos poucos (%.1f)" % c.click_income_rate)


func _test_speed() -> void:
	print("Velocidade pela produção")
	var t := TrainMovement.new(4.0, 2.0, 0.35)
	_check(is_equal_approx(t.speed_for_production(0.0), 4.0), "produção 0 = 4 m/s")
	_check(is_equal_approx(t.speed_for_production(1.0), 6.0), "produção 1 = 6 m/s")
	_check(absf(t.speed_for_production(100.0) - 14.0) < 0.05, "produção 100 = ~14 m/s")
	_check(absf(t.speed_for_production(10000.0) - 54.2) < 0.1, "produção 10.000 = ~54,2 m/s")
	var g := _new_state()
	g.stock.add(1e6)
	g.tick(1.0)
	_check(g.stock.amount == 1e6 + 20.0, "trem não gasta carvão: estoque só para compras")


func _test_route() -> void:
	print("Rota de estações")
	var r := StationTracker.new(B.stations)
	_check(r.station_count() == 10, "dez estações")
	_check(r.target_distance(0) == 3500.0 and r.target_distance(3) == 313300.0, "trechos crescem (3,5 / 27,3 / 102,3 / 313,3 km)")
	_check(is_equal_approx(r.progress(1750.0), 0.5), "progresso no 1º trecho")
	var got := r.update(30000.0)
	_check(str(got) == str([0, 1]), "pode alcançar duas estações de uma vez")
	_check(r.next_station_name() == "Deserto de Ferrugem" and is_equal_approx(r.progress(27300.0 + 37500.0), 0.5), "progresso conta a partir da última estação")
	r.update(1e12)
	_check(r.is_complete() and r.next_station_name() == "", "rota completa")


func _test_inertia() -> void:
	print("Inércia: acelera, freia e para na estação")
	var t := TrainMovement.new(4.0, 2.0, 0.35)
	t.current_speed = 0.0
	t.tick(1.0, 10.0, false)
	_check(t.current_speed > 0.0 and t.current_speed < 10.0 and t.state == TrainMovement.State.ACCELERATING, "parte acelerando aos poucos (%.1f m/s)" % t.current_speed)
	for i in 60:
		t.tick(0.1, 10.0, false)
	_check(is_equal_approx(t.current_speed, 10.0) and t.state == TrainMovement.State.CRUISING, "chega ao cruzeiro em ~6 s")
	t.tick(0.1, 10.0, true)
	_check(t.current_speed > 9.0 and t.state == TrainMovement.State.BRAKING, "falha: começa a frear, sem parar na hora")
	var secs := 0.1
	while t.is_moving() and secs < 10.0:
		t.tick(0.1, 10.0, true)
		secs += 0.1
	_check(t.state == TrainMovement.State.MAINTENANCE and absf(secs - 3.0) < 0.3, "para em ~3 s (%.1f s)" % secs)
	var u := TrainMovement.new(4.0, 2.0, 0.35)
	u.current_speed = 20.0
	var stop_at := 200.0
	var approached := false
	var n := 0
	while u.distance_m < stop_at and n < 2000:
		u.tick(0.05, 20.0, false, stop_at)
		approached = approached or u.state == TrainMovement.State.APPROACHING
		n += 1
	_check(approached and is_equal_approx(u.distance_m, 200.0) and u.current_speed == 0.0, "estação: freia e para exatamente na plataforma")
	_check(n * 0.05 > 200.0 / 20.0, "a chegada demora mais que passar direto (%.1f s)" % (n * 0.05))

	var s := _new_state()
	s.train.distance_m = 3400.0
	s.train.current_speed = s.cruise_speed()
	var stopped := false
	var departed := false
	for i in 600:
		var r := s.tick(0.1)
		stopped = stopped or r["station_stop"]
		departed = departed or r["departed"]
	_check(stopped and not departed and s.waiting_departure and s.is_at_station(), "GameState: para na Estação Inicial e espera o jogador (Partir sozinho desligado por padrão)")
	_check(not s.auto_depart and is_equal_approx(s.train.distance_m, 3500.0) and s.train.state == TrainMovement.State.AT_STATION, "esperando: o trem fica parado na plataforma")
	var w_save := s.to_save(0.0)
	var w2 := _new_state()
	w2.load_save(w_save)
	_check(w2.waiting_departure and w2.train.state == TrainMovement.State.AT_STATION, "save guarda o trem esperando na estação")
	var w_off := w2.apply_offline(3600.0)
	_check(w_off["waiting_departure"] and is_equal_approx(w_off["distance"], 0.0) and w2.waiting_departure and w2.train.state == TrainMovement.State.AT_STATION, "offline: continua esperando na estação")
	_check(w_off["stock_delta"] > 0.0 or w2.total_production() == 0.0, "offline: produção continua com o trem esperando")
	_check(s.depart() and not s.is_at_station(), "Partir: o trem sai da estação")
	_check(not s.depart(), "Partir fora da estação não faz nada")
	for i in 100:
		s.tick(0.1)
	_check(s.train.distance_m > 3500.0, "segue viagem depois de partir")
	var ad := _new_state()
	ad.auto_depart = true
	ad.train.distance_m = 3400.0
	ad.train.current_speed = ad.cruise_speed()
	var ad_departed := false
	for i in 600:
		ad_departed = ad.tick(0.1)["departed"] or ad_departed
	_check(ad_departed and not ad.is_at_station() and ad.train.distance_m > 3500.0, "Partir sozinho ligado: parte depois de %.0f s" % B.station_stop_seconds)
	var ad2 := _new_state()
	ad2.load_save(ad.to_save(0.0))
	_check(ad2.auto_depart, "preferência Partir sozinho fica salva")
	_check(not _new_state().auto_depart and not GameState.new(B).waiting_departure, "padrão: Partir sozinho desligado")
	var f := _new_state()
	f.stop_at_stations = false
	_check(f.will_stop_at_next_station(), "1ª estação sempre para, mesmo com a opção desligada")
	_reach(f, 0)
	_check(not f.will_stop_at_next_station(), "opção desligada: não para nas seguintes")


func _test_offline() -> void:
	print("Progresso offline (movimento 10%, produção 80%, para antes de estação nova)")
	_check(OfflineProgress.clamp_elapsed(-500.0, 86400.0) == 0.0, "relógio voltando = 0 s")
	_check(OfflineProgress.clamp_elapsed(3 * 86400.0, 86400.0) == 86400.0, "limite de 24 h")
	var s := _new_state()
	s.stock.add(1e6)
	for i in 12:
		s.buy_producer("foguista")
	var prod := s.total_production()
	var speed := s.train.speed_for_production(prod)
	var stock0 := s.stock.amount
	var res := s.apply_offline(600.0)
	_check(absf(res["distance"] - speed * 60.0) < 0.5, "10 min fora: o trem anda o mesmo que 1 min jogando (%.0f m)" % res["distance"])
	_check(not res["waiting_at_station"] and res["waiting_station"] == -1, "ainda longe da estação: não está esperando")
	_check(absf(s.stock.amount - (stock0 + prod * 600.0 * 0.8)) < 1.0, "produção offline a 80%")
	var res1 := s.apply_offline(86400.0)
	var wait_at: float = 3500.0 - B.offline_wait_distance_m
	_check(is_equal_approx(s.train.distance_m, wait_at), "24 h fora: para %.0f m antes da Estação Inicial (%.1f m)" % [B.offline_wait_distance_m, s.train.distance_m])
	_check(res1["waiting_at_station"] and res1["waiting_station"] == 0 and res1["stations"].is_empty(), "esperando a estação nova, sem alcançá-la")
	_check(s.route.reached_count == 0 and s.train.state == TrainMovement.State.ACCELERATING, "ao voltar, o trem segue para chegar com o jogador")
	var res2 := s.apply_offline(3600.0)
	_check(is_equal_approx(res2["distance"], 0.0) and res2["waiting_station"] == 0, "nova ausência: continua esperando no mesmo lugar")
	_check(res2["stock_delta"] > 0.0, "a produção continua com o trem esperando")

	# Estação já conhecida (como depois de um futuro reset): passa offline
	var k := _new_state()
	k.stock.add(1e9)
	for i in 40:
		k.buy_producer("foguista")
	for i in 30:
		k.buy_producer("carvoaria")
	k.best_station_count = 2
	var rk := k.apply_offline(86400.0)
	_check(str(rk["stations"]) == str([0, 1]), "estações conhecidas passam offline (%s)" % str(rk["stations"]))
	_check(is_equal_approx(k.train.distance_m, k.route.target_distance(2) - B.offline_wait_distance_m) and rk["waiting_station"] == 2, "e o trem espera antes da primeira estação nova")
	var saved := k.to_save(0.0)
	var k2 := _new_state()
	k2.load_save(saved)
	_check(k2.best_station_count == 2, "estações conhecidas ficam salvas")

	var B2 = load("res://autoload/balance.gd").new()
	B2.offline_stop_before_new_station = false
	var free := GameState.new(B2)
	free.stock.add(1e6)
	for i in 12:
		free.buy_producer("foguista")
	var r3 := free.apply_offline(3600.0)
	_check(is_equal_approx(r3["distance"], speed * 360.0), "sem a espera: distância = velocidade x 10% do tempo")
	B2.free()

	var s2 := _new_state()
	var r2 := s2.apply_offline(10 * 86400.0)
	_check(r2["seconds"] == 86400.0, "10 dias fora contam só 24 h")
	_check(s2.stock.amount == 20.0, "sem produtores: estoque intacto (trem não gasta carvão)")
	_check(is_equal_approx(s2.train.distance_m, 3500.0 - B.offline_wait_distance_m), "sem produtores: anda na velocidade base até antes da 1ª estação")

	# Manutenção offline (Estação Inicial alcançada, 3 peças ativas, sem limite de estação)
	var B3 = load("res://autoload/balance.gd").new()
	B3.offline_stop_before_new_station = false
	B3.offline_movement_efficiency = 1.0
	B3.offline_production_efficiency = 1.0
	var m := GameState.new(B3)
	m.stock.add(1e7)
	for i in 30:
		m.buy_producer("foguista")
	m.train.distance_m = 3600.0
	m.route.update(m.train.distance_m)
	var v := m.train.speed_for_production(m.total_production())
	var rm := m.apply_offline(7200.0)
	_check(rm["failures"] > 0, "2 h fora sem reforço: peças quebram (%d falhas)" % rm["failures"])
	_check(is_equal_approx(rm["downtime"], rm["failures"] * 15.0), "cada falha custa 15 s de parada (%.0f s)" % rm["downtime"])
	var inertia_loss: float = rm["failures"] * (B3.train_brake_seconds + B3.train_accel_seconds) * 0.5
	_check(absf(rm["distance"] - v * (7200.0 - rm["downtime"] - inertia_loss)) < 1.0, "distância desconta o tempo parado e a frenagem/arrancada")
	_check(m.stock.amount > 0.0, "produção continua durante as paradas")
	var a := GameState.new(B3)
	a.stock.add(1e9)
	for i in 30:
		a.buy_producer("foguista")
	a.train.distance_m = 320000.0
	a.route.update(a.train.distance_m)
	for id in ["rodas", "caldeira", "pistoes", "freios", "engates", "chamine"]:
		a.buy_auto_maintenance(id)
	var ra := a.apply_offline(7200.0)
	_check(ra["failures"] == 0 and ra["auto_repairs"] > 0, "com manutenção automática: %d consertos pagos, nenhuma parada" % ra["auto_repairs"])
	_check(ra["auto_cost"] > 0.0 and is_equal_approx(ra["downtime"], 0.0), "consertos automáticos custaram %s carvão" % NumFormat.amount(ra["auto_cost"]))
	var p := GameState.new(B3)
	p.maintenance.stop_left = 10.0
	p.apply_offline(4.0)
	_check(is_equal_approx(p.maintenance.stop_left, 6.0), "parada em andamento continua contando offline")
	B3.free()


## O cálculo offline por eventos deve bater com a simulação frame a frame.
func _test_offline_matches_online() -> void:
	print("Offline por eventos = simulação segundo a segundo")
	var B4 = load("res://autoload/balance.gd").new()
	B4.offline_stop_before_new_station = false
	B4.offline_movement_efficiency = 1.0
	B4.offline_production_efficiency = 1.0
	var make := func() -> GameState:
		var g := GameState.new(B4)
		g.stock.add(1e7)
		for i in 30:
			g.buy_producer("foguista")
		for i in 10:
			g.buy_producer("carvoaria")
		g.train.distance_m = 3600.0
		g.route.update(g.train.distance_m)
		g.component("rodas").integrity = 0.3
		g.stop_at_stations = false
		g.train.current_speed = g.cruise_speed()
		return g
	var online: GameState = make.call()
	var offline: GameState = make.call()
	var online_failures := 0
	var steps := 18000  # 30 min a 0,1 s
	for i in steps:
		var r := online.tick(0.1)
		online_failures += r["failed"].size()
	var res := offline.apply_offline(1800.0)
	_check(absi(online_failures - res["failures"]) <= 1, "mesmo número de falhas (%d online, %d offline)" % [online_failures, res["failures"]])
	var d_on := online.train.distance_m
	var d_off := offline.train.distance_m
	_check(absf(d_on - d_off) / d_on < 0.01, "mesma distância (%.0f x %.0f m)" % [d_on, d_off])
	var c_on := online.stock.amount
	var c_off := offline.stock.amount
	_check(absf(c_on - c_off) / c_on < 0.005, "mesmo carvão (%s x %s)" % [NumFormat.amount(c_on), NumFormat.amount(c_off)])
	B4.free()


func _reach(s: GameState, station: int) -> void:
	s.train.distance_m = maxf(s.train.distance_m, s.route.target_distance(station))
	s.route.update(s.train.distance_m)


func _test_components() -> void:
	print("Componentes")
	var s := _new_state()
	_check(s.maintenance.components.size() == 8, "oito componentes carregados do Balance")
	_check(not s.has_active_components(), "nenhuma peça ativa antes da Estação Inicial")
	s.stock.add(1e6)
	s.buy_producer("foguista")
	for i in 600:
		s.tick(0.1)
	_check(is_equal_approx(s.component("rodas").integrity, 1.0), "sem desgaste nos primeiros minutos")
	_reach(s, 0)
	_check(s.is_component_active("rodas") and s.is_component_active("caldeira") and s.is_component_active("pistoes"), "Estação Inicial libera Rodas, Caldeira e Pistões")
	_check(not s.is_component_active("freios"), "Freios só na Cidade Tomada")
	_check(s.component("rodas").material_name() == "ferro fundido", "rodas de ferro fundido (1º material)")
	var st := s.stock
	s.maintenance.wear(1500.0, 10.0, s.route, st, 1.0)
	_check(is_equal_approx(s.component("rodas").integrity, 0.9), "rodas: 1.500 m = -10%")
	_check(is_equal_approx(s.component("caldeira").integrity, 1.0 - 10.0 / 750.0), "caldeira desgasta por tempo em movimento")
	_check(is_equal_approx(s.component("freios").integrity, 1.0), "peça bloqueada não desgasta")


func _test_failure_and_maintenance() -> void:
	print("Falha e manutenção")
	var s := _new_state()
	s.stock.add(1e6)
	for i in 10:
		s.buy_producer("foguista")
	_reach(s, 0)
	s.component("rodas").integrity = 0.000001
	var r := s.tick(0.1)
	_check(str(r["failed"]) == str(["rodas"]), "rodas quebram ao chegar a 0%")
	_check(is_equal_approx(s.component("rodas").integrity, 1.0), "peça volta a 100%")
	_check(s.train.state == TrainMovement.State.BRAKING and is_equal_approx(s.maintenance.stop_left, 15.0), "trem começa a frear; 15 s de manutenção depois de parar")
	var guard := 0
	while s.train.state != TrainMovement.State.MAINTENANCE and guard < 100:
		s.tick(0.1)
		guard += 1
	_check(s.train.state == TrainMovement.State.MAINTENANCE and is_equal_approx(s.maintenance.stop_left, 15.0), "parado: manutenção de 15 s começa a contar")
	var d := s.train.distance_m
	var stock0 := s.stock.amount
	var cal := s.component("caldeira").integrity
	var done := false
	for i in 149:
		done = s.tick(0.1)["maintenance_done"] or done
	_check(s.train.distance_m == d, "não anda durante a manutenção")
	_check(s.stock.amount > stock0, "produção continua durante a manutenção")
	_check(s.component("caldeira").integrity == cal, "nada desgasta durante a manutenção")
	_check(not done, "ainda em manutenção aos 14,9 s")
	_check(s.tick(0.11)["maintenance_done"], "manutenção termina aos 15 s")
	s.tick(0.1)
	_check(s.train.is_moving() and s.train.distance_m > d, "trem volta a andar")
	s.component("rodas").integrity = 0.000001
	s.component("pistoes").integrity = 0.000001
	s.tick(0.1)
	_check(is_equal_approx(s.maintenance.stop_left, 30.0), "duas peças quebrando juntas: 30 s de parada")


func _test_repair_reinforce_tools() -> void:
	print("Reparo, reforço e Kit de ferramentas")
	var s := _new_state()
	s.stock.add(1e8)
	for i in 10:
		s.buy_producer("foguista")
	_reach(s, 0)
	var prod := s.total_production()
	s.component("rodas").integrity = 0.3
	_check(s.repair_cost("rodas") == roundf(20.0 * prod * 0.7), "reparo = 20 s de produção x 70%% que falta (%s)" % NumFormat.amount(s.repair_cost("rodas")))
	var before := s.stock.amount
	_check(s.repair_component("rodas") and is_equal_approx(s.component("rodas").integrity, 1.0), "reparo leva a peça a 100%")
	_check(is_equal_approx(before - s.stock.amount, roundf(20.0 * prod * 0.7)), "reparo cobra do estoque")
	_check(not s.can_repair("rodas"), "peça a 100% não precisa de reparo")
	var c := s.component("rodas")
	_check(c.reinforce_cost() == 2000.0, "1º reforço das rodas custa 2.000")
	s.reinforce_component("rodas")
	_check(is_equal_approx(c.life(), 15000.0 * 1.4) and c.reinforce_cost() == 5000.0, "reforço: vida x1,4 e custo x2,5")
	for i in 2:
		s.reinforce_component("rodas")
	_check(absf(c.life() - 41160.0) < 1.0, "nível 3: ~41 km")
	_check(not s.is_upgrade_available("tools"), "Kit de ferramentas só na Cidade Tomada")
	_reach(s, 1)
	_check(s.buy_upgrade("tools") and is_equal_approx(s.maintenance.stop_seconds(), 9.0), "Kit: parada de 15 s para 9 s")


func _test_auto_maintenance_and_materials() -> void:
	print("Manutenção automática e materiais")
	var s := _new_state()
	s.stock.add(1e9)
	for i in 10:
		s.buy_producer("foguista")
	_reach(s, 2)
	_check(not s.is_auto_available("rodas"), "manutenção automática bloqueada antes do Ruínas Brancas")
	_reach(s, 3)
	_check(s.is_auto_available("rodas"), "Ruínas Brancas libera a manutenção automática")
	_check(s.component("rodas").auto_cost() == 5e6 and s.component("chamine").auto_cost() == 2e7, "custa 5 mi (rodas) a 20 mi (chaminé)")
	_check(s.buy_auto_maintenance("rodas") and s.component("rodas").has_auto(), "comprada para as rodas de ferro fundido")
	_check(not s.is_auto_available("rodas"), "não compra duas vezes para o mesmo material")
	s.component("rodas").integrity = 0.100001
	var before := s.stock.amount
	var r := s.tick(0.1)
	_check(str(r["auto"]) == str(["rodas"]) and r["failed"].is_empty(), "aos 10%: conserto automático, sem parar")
	_check(is_equal_approx(s.component("rodas").integrity, 1.0) and not s.maintenance.is_stopped(), "peça a 100%, trem andando")
	_check(before - s.stock.amount > 0.0, "conserto automático foi pago")
	s.stock.amount = 0.0
	s.component("rodas").integrity = 0.000001
	r = s.tick(0.1)
	_check(str(r["failed"]) == str(["rodas"]), "sem carvão para pagar: falha normal")
	# Material novo exige comprar de novo
	var m := GameState.new(B)
	m.stock.add(1e9)
	_reach(m, 4)
	m.buy_auto_maintenance("rodas")
	var life_before := m.component("rodas").life()
	_check(m.buy_upgrade("mat_rodas"), "compra a melhoria Rodas de aço")
	_check(m.component("rodas").material_name() == "aço" and is_equal_approx(m.component("rodas").life(), life_before * 2.0), "rodas de aço duram o dobro")
	_check(not m.component("rodas").has_auto(), "trocar para rodas de aço: manutenção automática deixa de valer")
	_check(m.is_auto_available("rodas") and m.component("rodas").auto_cost() == 8e7, "precisa recomprar para o aço")

	print("Regras das regiões")
	var g := GameState.new(B)
	_reach(g, 4)
	g._apply_region()
	_check(g.current_region() == "tunel", "depois do Ermo Gelado o trecho é das Galerias de Pedra")
	_check(is_equal_approx(g.component("chamine").wear_multiplier, 2.0), "galerias: chaminé gasta o dobro")
	g.stock.add(1e8)
	g.buy_upgrade("exaustor")
	_check(is_equal_approx(g.component("chamine").wear_multiplier, 1.0), "exaustor compensa o ar parado")
	_reach(g, 8)
	g.buy_producer("foguista")
	g._apply_region()
	var base_prod := g.total_production() / g.region_production
	_check(g.current_region() == "cinzas" and is_equal_approx(g.region_production, 1.25), "mar de cinzas: produção +25%")
	_check(is_equal_approx(g.total_production(), base_prod * 1.25), "a regra entra na produção total")
	var saved := g.to_save(0.0)
	var g2 := GameState.new(B)
	g2.load_save(saved)
	_check(g2.current_region() == "cinzas" and is_equal_approx(g2.component("caldeira").wear_multiplier, 1.5), "regra da região volta ao carregar")


func _test_save_roundtrip_and_migration() -> void:
	print("Save v3 e migração")
	var s := _new_state()
	s.stock.add(1e6)
	s.buy_producer("foguista"); s.buy_producer("carvoaria"); s.buy_upgrade("click_1")
	s.train.distance_m = 4000.0
	s.route.update(4000.0)
	s.buy_producer("mina")
	var data := s.to_save(1000.0)
	var json: Dictionary = JSON.parse_string(JSON.stringify(data))  # passa pelo JSON como no disco
	var l := _new_state()
	l.load_save(json)
	_check(l.producer("mina").level == 1 and l.producer("carvoaria").level == 1, "níveis restaurados")
	_check(l.upgrades.is_purchased("click_1") and is_equal_approx(l.click_multiplier, 2.0), "melhorias restauradas e aplicadas")
	_check(l.route.reached_count == 1, "estação recalculada pela distância")
	_check(is_equal_approx(l.total_production(), s.total_production()), "mesma produção após carregar")
	var cs := _new_state()
	cs.stock.add(1e9)
	_reach(cs, 3)
	cs.component("rodas").integrity = 0.42
	cs.reinforce_component("caldeira")
	cs.buy_auto_maintenance("pistoes")
	cs.maintenance.stop_left = 7.0
	var cj: Dictionary = JSON.parse_string(JSON.stringify(cs.to_save(1.0)))
	var cl := _new_state()
	cl.load_save(cj)
	_check(is_equal_approx(cl.component("rodas").integrity, 0.42) and cl.component("caldeira").level == 1, "save v4: integridade e reforço")
	_check(cl.component("pistoes").has_auto() and is_equal_approx(cl.maintenance.stop_left, 7.0), "save v4: manutenção automática e parada em andamento")
	# v5 (trechos antigos) -> v6: mesma posição relativa no mesmo trecho
	var m5 := _new_state()
	m5.load_save({"save_version": 5, "saved_at": 1.0, "stock": 0.0, "distance_m": 3500.0 + 7000.0 * 0.5, "best_station_count": 1})
	_check(is_equal_approx(m5.train.distance_m, 3500.0 + 23800.0 * 0.5) and m5.route.reached_count == 1, "save v5: meio da Cidade Tomada continua no meio do trecho (%.0f m)" % m5.train.distance_m)
	var m5b := _new_state()
	m5b.load_save({"save_version": 5, "saved_at": 1.0, "stock": 0.0, "distance_m": 108500.0 + 10.0})
	_check(m5b.route.reached_count == 5 and is_equal_approx(m5b.train.distance_m, m5b.route.target_distance(4) + 10.0 / 1300000.0 * 1550000.0), "save v5: logo depois do Ermo Gelado continua lá (%d estações)" % m5b.route.reached_count)
	var m5c := _new_state()
	m5c.load_save({"save_version": 5, "saved_at": 1.0, "stock": 0.0, "distance_m": 10250.0})
	_check(m5c.route.reached_count == 1 and m5c.train.distance_m < m5c.route.target_distance(1), "save v5 esperando antes da estação nova: continua antes dela")
	var m6 := _new_state()
	m6.load_save(m5.to_save(1.0))
	_check(is_equal_approx(m6.train.distance_m, m5.train.distance_m), "save v6 não converte de novo")
	var v3 := _new_state()
	v3.load_save({"save_version": 3, "saved_at": 1.0, "stock": 10.0, "tank": 100.0, "producers": {"foguista": 2}, "upgrades_purchased": [], "distance_m": 5000.0})
	_check(is_equal_approx(v3.component("rodas").integrity, 1.0) and v3.component("rodas").level == 0, "save v3 abre com as peças a 100%")
	_check(is_equal_approx(v3.stock.amount, 110.0), "save antigo: carvão do reservatório volta para o estoque")
	var v2 := _new_state()
	v2.load_save({"save_version": 2, "stock": 77.0, "tank": 50.0, "producer_level": 4, "distance_m": 4600.0, "station_reached": true, "upgrades_purchased": ["station_production"]})
	_check(v2.producer("foguista").level == 4 and v2.stock.amount == 127.0, "save da Fase 0 (v2) migrado (estoque + reservatório)")
	_check(v2.upgrades.is_purchased("station_0") and is_equal_approx(v2.global_multiplier, 1.5), "Caldeira reforçada antiga continua comprada")
	var v1 := _new_state()
	v1.load_save({"coal": 33.0, "producer_level": 2, "distance_m": 100.0})
	_check(v1.producer("foguista").level == 2 and v1.stock.amount == 33.0, "save v1 migrado")


# ---------------------------------------------------------------------------
# Simulação de ritmo
# ---------------------------------------------------------------------------

## Jogador que sempre compra a opção de melhor retorno (custo / produção ganha).
## style "cuidadoso": antes, reforça peças quando o reforço custa até 10 s de
## produção, repara peças abaixo de 20% e compra o Kit de ferramentas.
## style "ignora": nunca repara nem reforça (deixa quebrar).
## `stations`: para depois de alcançar essa quantidade de estações (0 = todas).
## O passo é 0.1 s na primeira hora e 0.5 s depois (rota longa).
func _simulate(cps: float, style: String = "cuidadoso", max_time: float = 3600.0, stations: int = 0) -> Dictionary:
	var s := _new_state()
	var goal := s.route.station_count() if stations <= 0 else stations
	var dt := 0.1
	var t := 0.0
	var click_acc := 0.0
	var reached: Array[float] = []
	var upgrade_wait: Array[float] = []  # tempo entre chegar e comprar a melhoria da estação
	var buys: Array[float] = []
	var stops := 0
	var worst_ratio := 0.0
	var maintenance_time := 0.0
	var failures := 0
	var first_failure := -1.0
	while t < max_time and (reached.size() < goal or not s.upgrades.is_purchased("station_%d" % (goal - 1))):
		dt = 0.1 if t < 3600.0 else 0.5
		# Melhor compra
		var best_id := ""
		var best_cost := 0.0
		var best_ratio := INF
		var is_upgrade := false
		var prod := s.total_production()
		if style == "cuidadoso" and s.has_active_components():
			if s.is_upgrade_available("tools") and s.upgrades.cost("tools") <= 40.0 * prod and s.buy_upgrade("tools"):
				continue
			var acted := false
			for c in s.maintenance.active_components(s.route):
				if c.reinforce_cost() <= 10.0 * prod and s.reinforce_component(c.id):
					acted = true
					break
				if c.integrity < 0.2 and not s.maintenance.is_stopped() and s.repair_component(c.id):
					acted = true
					break
			# respostas às regras das regiões e materiais novos, quando baratos
			for id in s.available_upgrade_ids():
				var e := s.upgrades.get_entry(id)
				if e["effect"] in ["wear_mult", "material"] and e["cost"] <= 20.0 * prod and s.buy_upgrade(id):
					acted = true
					break
			if acted:
				continue
		for p in s.producers:
			if not s.is_producer_unlocked(p.id):
				continue
			var gain := s.production_after_level_up(p.id) - prod
			var c := p.next_level_cost()
			if c / gain < best_ratio:
				best_ratio = c / gain; best_id = p.id; best_cost = c; is_upgrade = false
		for id in s.available_upgrade_ids():
			var e := s.upgrades.get_entry(id)
			var gain := 0.0
			match e["effect"]:
				"global_mult": gain = prod * (e["value"] - 1.0)
				"producer_mult": gain = s.producer_production(e["target"]) * (e["value"] - 1.0)
				"click_mult": gain = cps * s.click_value() * (e["value"] - 1.0)
			if gain <= 0.0:
				continue
			if e["cost"] / gain < best_ratio:
				best_ratio = e["cost"] / gain; best_id = id; best_cost = e["cost"]; is_upgrade = true
		if best_id != "" and s.stock.can_afford(best_cost):
			if is_upgrade:
				s.buy_upgrade(best_id)
				if best_id.begins_with("station_"):
					var idx := int(best_id.substr(8))
					upgrade_wait.append(t - reached[idx])
			else:
				s.buy_producer(best_id)
			buys.append(t)
			continue
		if cps > 0.0:
			click_acc += dt
			while click_acc >= 1.0 / cps:
				click_acc -= 1.0 / cps
				s.click()
		if s.waiting_departure:
			s.depart()   # o jogador ativo manda partir assim que a parada acaba
		var r := s.tick(dt)
		if r["station_stop"]:
			stops += 1
		if s.train.state == TrainMovement.State.MAINTENANCE:
			maintenance_time += dt
		if not r["failed"].is_empty():
			failures += r["failed"].size()
			if first_failure < 0.0:
				first_failure = t
		for i in r["stations"]:
			reached.append(t)
			if OS.has_environment("SIM_TRACE"):
				print("    [trace] estação %d em %.1f min: produção %s/s, %.0f m/s, níveis %s" % [i, t / 60.0, String.num_scientific(s.total_production()), s.train.target_speed, s.producers.map(func(p): return p.level)])
		t += dt
	var per_min: Array[int] = []
	for m in 15:
		var n := 0
		for b in buys:
			if b >= m * 60.0 and b < (m + 1) * 60.0:
				n += 1
		per_min.append(n)
	var levels := []
	for p in s.producers:
		levels.append(p.level)
	return {"reached": reached, "upgrade_wait": upgrade_wait, "per_min": per_min, "stops": stops,
		"worst_ratio": worst_ratio, "levels": levels, "production": s.total_production(),
		"speed": s.train.target_speed, "time": t, "maintenance_time": maintenance_time,
		"failures": failures, "first_failure": first_failure}


func _fmt_minutes(times: Array[float]) -> String:
	var parts := []
	for x in times:
		parts.append("%.1f" % (x / 60.0))
	return ", ".join(parts)


func _test_number_format() -> void:
	print("Resumo dos números (como nos jogos clicker)")
	_check(NumFormat.amount(999999.0) == "999.999", "abaixo de 1 mi: separador de milhar (%s)" % NumFormat.amount(999999.0))
	_check(NumFormat.amount(15.52e6) == "15,52 mi", "mi (%s)" % NumFormat.amount(15.52e6))
	_check(NumFormat.amount(8.9e6) == "8,90 mi" and NumFormat.amount(9e6) == "9,00 mi" and NumFormat.amount(8.09e6) == "8,09 mi", "sempre duas casas: não pisca ao passar por zero (%s, %s, %s)" % [NumFormat.amount(8.9e6), NumFormat.amount(9e6), NumFormat.amount(8.09e6)])
	_check(NumFormat.amount(3.2e12) == "3,20 tri", "tri (%s)" % NumFormat.amount(3.2e12))
	_check(NumFormat.amount(1.5e15) == "1,50 qua" and NumFormat.amount(2e18) == "2,00 qui", "qua e qui (%s, %s)" % [NumFormat.amount(1.5e15), NumFormat.amount(2e18)])
	_check(NumFormat.amount(8.999e6) == "8,99 mi" and NumFormat.amount(999.999e6) == "999,99 mi" and NumFormat.amount(999999.7) == "999.999", "casas cortadas, não arredondadas: nunca mostra mais do que tem (%s, %s, %s)" % [NumFormat.amount(8.999e6), NumFormat.amount(999.999e6), NumFormat.amount(999999.7)])
	var widths := {}
	for x in [8.0e6, 8.09e6, 8.9e6, 9.0e6, 9.99e6]:
		widths[NumFormat.amount(x).length()] = true
	_check(widths.size() == 1, "de 8 mi a 9,99 mi o texto tem sempre o mesmo tamanho")
	_check(NumFormat.distance(123000.0) == "123,0 km" and NumFormat.distance(123456.0) == "123,4 km", "distância com uma casa fixa (%s)" % NumFormat.distance(123000.0))
	_check(NumFormat.amount(999.99e33) == "999,99 dc", "dc (%s)" % NumFormat.amount(999.99e33))
	_check(NumFormat.amount(1.234e40) == "1,23e40" and NumFormat.amount(1e40) == "1,00e40", "acima de dc: notação científica (%s)" % NumFormat.amount(1.234e40))
	var longest := 0
	for e in range(0, 40):
		longest = maxi(longest, NumFormat.amount(9.99999 * pow(10.0, e)).length())
	_check(longest <= 10, "nenhum número passa de 10 caracteres (máx %d)" % longest)


func _test_simulation() -> void:
	print("Simulação de ritmo (jogador que sempre faz a melhor compra e cuida do trem)")
	for cps in [0.0, 1.0, 3.0]:
		var r := _simulate(cps, "cuidadoso", 3.0 * 3600.0, 5)
		var reached: Array[float] = r["reached"]
		print("    %.0f clique/s -> estações (min): %s | espera p/ melhoria da estação (s): %s" % [cps, _fmt_minutes(reached), r["upgrade_wait"]])
		print("      compras/min: %s | níveis: %s | produção final %.0f/s, %.1f m/s" % [r["per_min"], r["levels"], r["production"], r["speed"]])
		_check(reached.size() == 5, "%.0f clique/s: alcança as 5 estações" % cps)
		if reached.size() == 5:
			_check(reached[4] >= 55.0 * 60.0 and reached[4] <= 90.0 * 60.0, "%.0f clique/s: Ermo Gelado entre 55 e 90 min (%.1f)" % [cps, reached[4] / 60.0])
			_check(reached[0] >= 240.0 and reached[0] <= 420.0, "%.0f clique/s: 1ª estação entre 4 e 7 min (%.1f)" % [cps, reached[0] / 60.0])
			_check(reached[3] <= 55.0 * 60.0, "%.0f clique/s: 4ª estação em até 55 min (%.1f)" % [cps, reached[3] / 60.0])
			var gaps_grow := (reached[3] - reached[2]) > (reached[2] - reached[1])
			_check(gaps_grow, "%.0f clique/s: trechos finais ficam mais longos" % cps)
		_check(r["stops"] == 5, "%.0f clique/s: parou na plataforma das 5 estações (%d)" % [cps, r["stops"]])
		var first10 := 0
		for i in 10:
			first10 += r["per_min"][i]
		_check(first10 >= 25, "%.0f clique/s: pelo menos 25 compras nos 10 primeiros minutos (%d)" % [cps, first10])
		var waits: Array = r["upgrade_wait"]
		var max_wait := 0.0
		for w in waits:
			max_wait = maxf(max_wait, w)
		_check(waits.size() == 5 and max_wait <= 120.0, "%.0f clique/s: cada melhoria de estação comprável em até 2 min após chegar (máx %.0f s)" % [cps, max_wait])

	print("Simulação 1B: cuidar do trem x ignorar a manutenção (1 clique/s)")
	var careful := _simulate(1.0, "cuidadoso", 3.0 * 3600.0, 5)
	var ignore := _simulate(1.0, "ignora", 3.0 * 3600.0, 5)
	for pair in [["cuidadoso", careful], ["ignora", ignore]]:
		var r: Dictionary = pair[1]
		var reached: Array[float] = r["reached"]
		var after_first: float = r["time"] - (reached[0] if reached.size() > 0 else 0.0)
		print("    %-9s estações (min): %s | parado em manutenção %.0f s (%.1f%% após a 1ª estação) | falhas %d" % [pair[0], _fmt_minutes(reached), r["maintenance_time"], 100.0 * r["maintenance_time"] / after_first, r["failures"]])
	var cr: Array[float] = careful["reached"]
	var ir: Array[float] = ignore["reached"]
	_check(cr.size() == 5 and ir.size() == 5, "os dois estilos completam as 5 primeiras estações")
	if cr.size() == 5 and ir.size() == 5:
		_check(cr[4] <= ir[4], "cuidar do trem chega antes de ignorar (%.1f x %.1f min)" % [cr[4] / 60.0, ir[4] / 60.0])
		var pct: float = ignore["maintenance_time"] / (ignore["time"] - ir[0])
		_check(pct <= 0.20, "ignorar a manutenção custa no máximo 20%% do tempo parado (%.1f%%)" % (pct * 100.0))
		_check(careful["failures"] <= 1, "quem cuida quase não quebra (%d falhas)" % careful["failures"])
		_check(ignore["first_failure"] < 0.0 or ignore["first_failure"] - ir[0] >= 180.0, "primeira falha pelo menos 3 min depois da Estação Inicial (%.1f min de jogo)" % (ignore["first_failure"] / 60.0))


## Rota inteira (regiões 6 a 10), jogando ativamente a 1 clique/s.
func _test_long_route() -> void:
	print("Simulação da rota longa (10 estações, 1 clique/s)")
	var r := _simulate(1.0, "cuidadoso", 40.0 * 3600.0)
	var reached: Array[float] = r["reached"]
	var gaps: Array[float] = []
	var prev := 0.0
	for x in reached:
		gaps.append(x - prev)
		prev = x
	print("    estações (h): %s" % ", ".join(reached.map(func(x): return "%.2f" % (x / 3600.0))))
	print("    trechos (min): %s" % _fmt_minutes(gaps))
	print("    produção final %s/s, %.0f m/s, falhas %d, espera p/ melhoria (s): %s" % [String.num_scientific(r["production"]), r["speed"], r["failures"], r["upgrade_wait"]])
	_check(reached.size() == 10, "alcança as 10 estações")
	_check(r["stops"] == 10, "parou na plataforma das 10 estações (%d)" % r["stops"])
	if reached.size() < 10:
		return
	# Curva: cada trecho cerca de 1,6x o anterior (1,4x a 1,8x).
	var curve := true
	for i in range(1, 10):
		var ratio := gaps[i] / gaps[i - 1]
		curve = curve and ratio >= 1.4 and ratio <= 1.8
	_check(curve, "cada trecho é cerca de 1,6x o anterior")
	_check(gaps[5] >= 40.0 * 60.0 and gaps[5] <= 60.0 * 60.0, "Galerias de Pedra entre 40 e 60 min (%.0f)" % (gaps[5] / 60.0))
	_check(gaps[9] >= 4.5 * 3600.0 and gaps[9] <= 6.5 * 3600.0, "Mar de Cinzas entre 4,5 e 6,5 h (%.1f)" % (gaps[9] / 3600.0))
	_check(reached[9] >= 12.0 * 3600.0 and reached[9] <= 17.0 * 3600.0, "rota inteira entre 12 e 17 h de jogo ativo (%.1f)" % (reached[9] / 3600.0))
	var max_wait := 0.0
	for w in r["upgrade_wait"]:
		max_wait = maxf(max_wait, w)
	_check(max_wait <= 180.0, "toda melhoria de estação comprável em até 3 min após chegar (máx %.0f s)" % max_wait)
	_check(r["failures"] <= 3, "quem cuida do trem quase não quebra na rota longa (%d falhas)" % r["failures"])
