class_name TrainMovement
extends RefCounted
## TrainMovement — velocidade, consumo por distância e contagem de distância.
##
## Regras:
## - A velocidade alvo vem da PRODUÇÃO total de carvão:
##       velocidade = base + fator * produção ^ expoente
##   Toda melhoria de produção acelera o trem; gastar do estoque não o freia.
##   Com expoente < 1, a velocidade cresce mais devagar que a produção.
## - Consumo é por metro percorrido (coal_per_meter), tirado do reservatório.
## - Se o reservatório não tiver carvão para o trecho, o trem anda só o que o
##   carvão disponível permite (desacelera). Só para com o reservatório vazio.
## - Não conhece animação nenhuma: o visual apenas lê estado e velocidade.

enum State { STOPPED, SLOW, CRUISING, MAINTENANCE }

## Abaixo desta velocidade (m/s) o trem é considerado parado.
const STOP_EPSILON := 0.01

var distance_m: float = 0.0
var current_speed: float = 0.0
var target_speed: float = 0.0
var state: State = State.STOPPED

var base_speed: float
var speed_factor: float
var speed_exponent: float
var coal_per_meter: float
## Multiplicador de velocidade vindo dos reforços das peças (1.0 = sem bônus).
var speed_multiplier: float = 1.0


func _init(p_base_speed: float, p_speed_factor: float, p_speed_exponent: float, p_coal_per_meter: float) -> void:
	base_speed = p_base_speed
	speed_factor = p_speed_factor
	speed_exponent = p_speed_exponent
	coal_per_meter = p_coal_per_meter
	target_speed = base_speed


## Velocidade alvo (m/s) para uma produção de `production_per_second`.
func speed_for_production(production_per_second: float) -> float:
	return (base_speed + speed_factor * pow(maxf(production_per_second, 0.0), speed_exponent)) * speed_multiplier


## Consumo de carvão por segundo na velocidade atual (para exibição).
func consumption_per_second() -> float:
	return current_speed * coal_per_meter


func is_moving() -> bool:
	return state != State.STOPPED and state != State.MAINTENANCE


## Parado em manutenção: não anda nem gasta combustível. Retorna se o estado mudou.
func hold_for_maintenance(production_per_second: float) -> bool:
	var previous_state := state
	target_speed = speed_for_production(production_per_second)
	current_speed = 0.0
	state = State.MAINTENANCE
	return state != previous_state


## Avança `delta` segundos. `production_per_second` define a velocidade alvo;
## o carvão sai de `tank`. Retorna true se o estado mudou neste tick.
func tick(delta: float, tank: FuelTank, production_per_second: float) -> bool:
	var previous_state := state
	target_speed = speed_for_production(production_per_second)

	var meters := target_speed * delta
	var cost := meters * coal_per_meter
	if cost > tank.current:
		cost = tank.current
		meters = cost / coal_per_meter
	tank.try_consume(cost)
	distance_m += meters
	current_speed = meters / delta if delta > 0.0 else 0.0

	if current_speed < STOP_EPSILON:
		state = State.STOPPED
	elif current_speed < target_speed * 0.99:
		state = State.SLOW
	else:
		state = State.CRUISING
	return state != previous_state
