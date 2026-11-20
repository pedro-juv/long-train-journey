extends Node
## EventBus — sinais globais para desacoplar lógica, interface e visual.
##
## O GameController emite; HUD e TrainView escutam.
## Nenhum sistema do núcleo escuta a interface.

## Estoque de carvão (carteira do jogador) mudou.
signal stock_changed(amount: float)

## O jogador clicou para gerar carvão (evento; usado para som e efeitos).
signal coal_clicked()

## Um produtor subiu de nível (evento). milestone = atingiu um marco de produção.
signal producer_bought(producer_id: String, level: int, milestone: bool)

## Algo na loja mudou (compra, desbloqueio): a HUD reconstrói a lista.
signal shop_changed()

## Estado do trem mudou (TrainMovement.State: CRUISING, ACCELERATING, BRAKING,
## MAINTENANCE, APPROACHING, AT_STATION).
signal train_state_changed(state: int)

## Velocidade atual, velocidade de cruzeiro e pressão da caldeira (0 a 1).
signal speed_changed(speed_mps: float, target_speed_mps: float, stoke: float)

## Distância acumulada mudou.
signal distance_changed(distance_m: float)

## Estação alcançada (evento: dispara uma vez por estação).
signal station_reached(index: int, station_name: String)

## Melhoria comprada (evento).
signal upgrade_purchased(upgrade_id: String)

## Um componente quebrou: o trem para para manutenção (evento).
signal component_failed(component_id: String, component_name: String)

## Um componente foi consertado: automatic = pela manutenção automática (evento).
signal component_repaired(component_id: String, automatic: bool)

## Um componente recebeu um nível de reforço (evento).
signal component_reinforced(component_id: String, level: int)

## O trem parou na plataforma de uma estação (evento).
signal station_stopped(index: int, station_name: String)

## O trem partiu da plataforma (evento).
signal station_departed()

## O jogador ligou/desligou "Parar nas estações".
signal stop_at_stations_changed(enabled: bool)

## A parada para manutenção terminou e o trem voltou a andar (evento).
signal maintenance_finished()

## Resumo do progresso offline ao abrir o jogo.
## { "seconds", "elapsed_real", "stock_delta", "distance", "stations": [índices],
##   "failures", "downtime", "auto_repairs", "auto_cost", "waiting_at_station" }
signal offline_summary(summary: Dictionary)

## Jogo carregado ou reiniciado (HUD deve sincronizar tudo).
signal game_loaded()
