class_name TrainMovement
extends RefCounted
## TrainMovement — velocidade com inércia, frenagem e contagem de distância.
##
## Regras (v0.2.0):
## - A velocidade de cruzeiro vem da PRODUÇÃO total de carvão:
##       cruzeiro = (base + fator * produção ^ expoente) * multiplicador * impulso
##   (multiplicador = reforços das peças; impulso = caldeira atiçada pelo clique).
## - O trem não gasta carvão: o carvão serve só para comprar.
## - A velocidade atual NUNCA salta: acelera e freia aos poucos (inércia).
##   * Falha de peça: freia em ~brake_seconds até parar; o conserto só começa parado.
##   * Chegada em estação (se for parar): freia suave até parar na plataforma,
##     espera e parte acelerando.
##   * Depois de qualquer parada: acelera em ~accel_seconds até o cruzeiro.
## - Não conhece animação nenhuma: o visual apenas lê estado e velocidade.

enum State { CRUISING, ACCELERATING, BRAKING, MAINTENANCE, APPROACHING, AT_STATION }

## Abaixo desta velocidade (m/s) o trem é considerado parado.
const STOP_EPSILON := 0.05
## Velocidade mínima de "chegada" ao encostar na plataforma (m/s).
const CRAWL_SPEED := 0.6

var distance_m: float = 0.0
var current_speed: float = 0.0
## Velocidade de cruzeiro atual (produção + reforços + impulso).
var target_speed: float = 0.0
var state: State = State.ACCELERATING

var base_speed: float
var speed_factor: float
var speed_exponent: float
## Acima de `soft_knee` de produção, a velocidade cresce com o expoente
## `soft_exponent` (menor): as regiões finais não viram um borrão.
var soft_knee: float = INF
var soft_exponent: float = 0.2
## Multiplicador de velocidade vindo dos reforços das peças (1.0 = sem bônus).
var speed_multiplier: float = 1.0
## Segundos para ir de parado ao cruzeiro.
var accel_seconds: float = 6.0
## Segundos para frear do cruzeiro até parar numa falha.
var brake_seconds: float = 3.0
## Segundos para frear do cruzeiro até parar na estação (mais suave).
var station_brake_seconds: float = 7.0


func _init(p_base_speed: float, p_speed_factor: float, p_speed_exponent: float) -> void:
	base_speed = p_base_speed
	speed_factor = p_speed_factor
	speed_exponent = p_speed_exponent
	target_speed = base_speed


## Velocidade de cruzeiro (m/s) para uma produção, sem o impulso da caldeira.
func speed_for_production(production_per_second: float) -> float:
	var p := maxf(production_per_second, 0.0)
	var term: float
	if p <= soft_knee:
		term = pow(p, speed_exponent)
	else:
		term = pow(soft_knee, speed_exponent) * pow(p / soft_knee, soft_exponent)
	return (base_speed + speed_factor * term) * speed_multiplier


func is_stopped() -> bool:
	return current_speed < STOP_EPSILON


func is_moving() -> bool:
	return not is_stopped()


## Distância (m) que o trem precisa para parar vindo da velocidade atual,
## com a frenagem suave da estação.
func station_braking_distance(cruise: float) -> float:
	var decel := maxf(cruise, 1.0) / station_brake_seconds
	return current_speed * current_speed / (2.0 * decel)


## Avança `delta` segundos.
##   cruise        velocidade de cruzeiro desejada (já com o impulso)
##   must_stop     true = uma peça quebrou: frear até parar
##   stop_at       distância (m) onde precisa parar (estação) ou INF
## Retorna os metros andados.
func tick(delta: float, cruise: float, must_stop: bool, stop_at: float = INF) -> float:
	target_speed = cruise
	var desired := cruise
	# Sem falha nem estação: perde velocidade tão suave quanto ganha (ex.: impulso acabando).
	var decel := maxf(cruise, 1.0) / accel_seconds
	var approaching := false

	if must_stop:
		desired = 0.0
		decel = maxf(maxf(cruise, current_speed), 1.0) / brake_seconds
	elif is_finite(stop_at):
		var remaining := stop_at - distance_m
		var s_decel := maxf(cruise, 1.0) / station_brake_seconds
		# Velocidade que ainda permite parar exatamente na estação.
		var v_stop := sqrt(maxf(0.0, 2.0 * s_decel * remaining))
		if v_stop < cruise:
			approaching = true
			desired = maxf(v_stop, CRAWL_SPEED)
			decel = s_decel * 1.5  # folga para acompanhar a curva

	var accel := maxf(cruise, 1.0) / accel_seconds
	if current_speed < desired:
		current_speed = minf(desired, current_speed + accel * delta)
	else:
		current_speed = maxf(desired, current_speed - decel * delta)

	var meters := current_speed * delta
	if is_finite(stop_at) and distance_m + meters >= stop_at:
		meters = maxf(0.0, stop_at - distance_m)
		distance_m = stop_at
		current_speed = 0.0
	else:
		distance_m += meters

	if must_stop:
		state = State.MAINTENANCE if is_stopped() else State.BRAKING
	elif approaching:
		state = State.APPROACHING
	elif current_speed < cruise * 0.98:
		state = State.ACCELERATING
	else:
		state = State.CRUISING
	return meters


## Parado (manutenção ou estação): não anda.
func hold(new_state: State, cruise: float) -> void:
	target_speed = cruise
	current_speed = 0.0
	state = new_state
