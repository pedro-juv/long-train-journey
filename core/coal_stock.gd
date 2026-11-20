class_name CoalStock
extends RefCounted
## CoalStock — o estoque de carvão (a "carteira" do jogador).
##
## Recebe a produção e os cliques; paga as compras; abastece o reservatório.
## Sem limite na Fase 0 (limite de armazenamento é assunto do vagão Depósito).

var amount: float = 0.0


func _init(start_amount: float) -> void:
	amount = maxf(0.0, start_amount)


func add(value: float) -> void:
	if value > 0.0:
		amount += value


func can_afford(cost: float) -> bool:
	return amount >= cost


## Gasta se houver o suficiente; retorna se conseguiu.
func try_spend(cost: float) -> bool:
	if cost <= 0.0:
		return true
	if amount < cost:
		return false
	amount -= cost
	return true


## Transfere até `max_amount` para fora do estoque. Retorna quanto saiu.
func take_up_to(max_amount: float) -> float:
	var taken := clampf(max_amount, 0.0, amount)
	amount -= taken
	return taken
