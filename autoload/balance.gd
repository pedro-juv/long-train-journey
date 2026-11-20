extends Node
## Balance — todos os números e conteúdos de balanceamento em um único lugar.
##
## Nenhum outro script deve conter valores de balanceamento "mágicos".
## Todos os valores são PROVISÓRIOS (Fase 1A) e foram aprovados para teste.
## Produtores, equipamentos, estações e melhorias são DADOS: adicionar um item
## novo aqui não exige código novo.

# ---------------------------------------------------------------------------
# Estoque e clique
# ---------------------------------------------------------------------------

## Carvão no ESTOQUE ao começar uma partida nova (dá para contratar o Foguista).
## O trem não gasta carvão (v0.2.0): o estoque serve só para compras.
var initial_stock: float = 20.0

## Carvão por clique = (coal_per_click + produção * click_production_fraction)
##                     * multiplicador das pás.
## A parte proporcional mantém o clique útil o jogo todo (estilo Clicker Heroes).
var coal_per_click: float = 1.0

## Fração da produção POR SEGUNDO que cada clique rende (0.02 = 2%).
## Com as 3 pás (x8): 16% da produção por clique.
var click_production_fraction: float = 0.02

## "Atiçar a caldeira": cada clique soma pressão; a pressão dá velocidade extra
## e escoa sozinha. Bônus = pressão (0 a 1) * stoke_max_speed_bonus.
var stoke_per_click: float = 0.05
## Bônus máximo de velocidade com a caldeira no máximo (0.3 = +30%).
var stoke_max_speed_bonus: float = 0.3
## Segundos para a pressão cair ~63% sem cliques (decaimento exponencial).
## Equilíbrio: pressão ≈ cliques/s * stoke_per_click * stoke_decay_seconds
## (3 cliques/s -> 0,6 -> +18% de velocidade).
var stoke_decay_seconds: float = 4.0

# ---------------------------------------------------------------------------
# Produtores — cada um é uma unidade única com níveis
# ---------------------------------------------------------------------------
## Campos:
##   id, name           identificador e nome (nomes provisórios)
##   output_per_level   carvão/s por nível, antes de multiplicadores
##   base_cost          custo do nível 0 -> 1
##   unlock_station     índice da estação que libera (-1 = desde o início)
var producers: Array[Dictionary] = [
	{"id": "foguista", "name": "Foguista", "output_per_level": 1.0, "base_cost": 15.0, "unlock_station": -1},
	{"id": "carvoaria", "name": "Carvoaria", "output_per_level": 6.0, "base_cost": 250.0, "unlock_station": -1},
	{"id": "mina", "name": "Mina", "output_per_level": 60.0, "base_cost": 4000.0, "unlock_station": 0},
]

## Custo do próximo nível = base_cost * producer_cost_growth ^ nível_atual.
var producer_cost_growth: float = 1.32

## Níveis em que a produção daquele produtor é multiplicada.
var milestone_levels: Array[int] = [10, 25, 50]

## Multiplicador aplicado em cada marco atingido.
var milestone_multiplier: float = 2.0

# ---------------------------------------------------------------------------
# Melhorias de compra única
# ---------------------------------------------------------------------------
## Campos:
##   id, name, cost
##   effect     "producer_mult" | "global_mult" | "click_mult"
##   target     id do produtor (só para producer_mult)
##   value      multiplicador aplicado
##   requires   condição para aparecer na loja:
##                {"producer": id}    produtor com pelo menos 1 nível
##                {"upgrade": id}     outra melhoria já comprada
##                {"station": índice} estação alcançada
##                {}                  desde o início
var upgrades: Array[Dictionary] = [
	# Clique
	{"id": "click_1", "name": "Pá de mão", "cost": 50.0, "effect": "click_mult", "value": 2.0, "requires": {}},
	{"id": "click_2", "name": "Pá de aço", "cost": 500.0, "effect": "click_mult", "value": 2.0, "requires": {"upgrade": "click_1"}},
	{"id": "click_3", "name": "Pá dupla", "cost": 5000.0, "effect": "click_mult", "value": 2.0, "requires": {"upgrade": "click_2"}},
	# Equipamentos dos produtores (melhorias individuais)
	{"id": "eq_foguista", "name": "Pá reforçada", "cost": 150.0, "effect": "producer_mult", "target": "foguista", "value": 2.0, "requires": {"producer": "foguista"}},
	{"id": "eq_carvoaria", "name": "Forno selado", "cost": 2500.0, "effect": "producer_mult", "target": "carvoaria", "value": 2.0, "requires": {"producer": "carvoaria"}},
	{"id": "eq_mina", "name": "Trilhos de vagonete", "cost": 40000.0, "effect": "producer_mult", "target": "mina", "value": 2.0, "requires": {"producer": "mina"}},
	# Recompensas das estações
	{"id": "station_0", "name": "Caldeira reforçada", "cost": 1500.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 0}},
	{"id": "station_1", "name": "Caldeira de alta pressão", "cost": 60000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 1}},
	{"id": "station_2", "name": "Tiragem forçada", "cost": 600000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 2}},
	{"id": "station_3", "name": "Superaquecedor", "cost": 1400000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 3}},
	{"id": "station_4", "name": "Isolamento térmico", "cost": 3000000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 4}},
	# Manutenção (Fase 1B)
	{"id": "tools", "name": "Kit de ferramentas", "cost": 50000.0, "effect": "maintenance_time_mult", "value": 0.6, "requires": {"station": 1}},
]

# ---------------------------------------------------------------------------
# Trem — velocidade vem da produção
# ---------------------------------------------------------------------------
## velocidade = train_base_speed + train_speed_factor * produção ^ train_speed_exponent
## Exemplos: produção 0 -> 4 m/s | 1 -> 6 | 10 -> 8,5 | 100 -> 14 | 1.000 -> 26,4 | 10.000 -> 54,2

## Velocidade (m/s) sem produção automática.
var train_base_speed: float = 4.0

## Fator da produção na velocidade.
var train_speed_factor: float = 2.0

## Expoente da produção na velocidade (< 1: a velocidade cresce mais devagar
## que a produção). Principal ajuste de ritmo entre estações.
var train_speed_exponent: float = 0.35

## Inércia: segundos para ir de parado à velocidade de cruzeiro.
var train_accel_seconds: float = 6.0

## Segundos para frear do cruzeiro até parar quando uma peça quebra.
var train_brake_seconds: float = 3.0

## Segundos para frear do cruzeiro até parar na plataforma (mais suave).
var train_station_brake_seconds: float = 7.0

## Segundos parado na plataforma de cada estação (quando "Parar nas estações" está ligado).
var station_stop_seconds: float = 5.0

# ---------------------------------------------------------------------------
# Estações — rota contínua; cada trecho tem o dobro do anterior
# ---------------------------------------------------------------------------
## Campos: name, length (metros do trecho desde a estação anterior),
## theme (tema visual e musical da região, a partir da chegada na estação;
## os temas são definidos em scenes/train_view.gd e scenes/audio_director.gd).
## A recompensa de cada estação é a melhoria com requires {"station": índice};
## produtores com unlock_station também são liberados por ela.
var stations: Array[Dictionary] = [
	{"name": "Estação Inicial", "length": 3500.0, "theme": "inicio"},
	{"name": "Primavera", "length": 7000.0, "theme": "primavera"},
	{"name": "Verão", "length": 14000.0, "theme": "verao"},
	{"name": "Outono", "length": 28000.0, "theme": "outono"},
	{"name": "Inverno", "length": 56000.0, "theme": "inverno"},
]

# ---------------------------------------------------------------------------
# Componentes e manutenção (Fase 1B)
# ---------------------------------------------------------------------------
## Campos:
##   id, name           identificador e nome
##   wear               "distance" (desgasta por metro) ou "time" (por segundo em movimento)
##   life               vida sem reforço: metros (distance) ou segundos (time)
##   unlock_station     índice da estação que libera o componente
##   reinforce_cost     custo do 1º nível de reforço
##   materials          lista de materiais; na 1B só existe o primeiro.
##                      Cada um: id, name (como aparece: "Rodas de <name>"),
##                      auto_cost (preço da manutenção automática para ESTE material)
var components: Array[Dictionary] = [
	{"id": "rodas", "name": "Rodas", "wear": "distance", "life": 15000.0, "unlock_station": 0, "reinforce_cost": 2000.0,
		"materials": [{"id": "ferro_fundido", "name": "ferro fundido", "auto_cost": 5000000.0}]},
	{"id": "caldeira", "name": "Caldeira", "wear": "time", "life": 750.0, "unlock_station": 0, "reinforce_cost": 2000.0,
		"materials": [{"id": "cobre_rebitado", "name": "cobre rebitado", "auto_cost": 5000000.0}]},
	{"id": "pistoes", "name": "Pistões", "wear": "distance", "life": 22500.0, "unlock_station": 0, "reinforce_cost": 3000.0,
		"materials": [{"id": "ferro_fundido", "name": "ferro fundido", "auto_cost": 5000000.0}]},
	{"id": "freios", "name": "Freios", "wear": "distance", "life": 37500.0, "unlock_station": 1, "reinforce_cost": 40000.0,
		"materials": [{"id": "madeira", "name": "sapatas de madeira", "auto_cost": 8000000.0}]},
	{"id": "engates", "name": "Engates", "wear": "time", "life": 1200.0, "unlock_station": 2, "reinforce_cost": 400000.0,
		"materials": [{"id": "ferro_forjado", "name": "ferro forjado", "auto_cost": 12000000.0}]},
	{"id": "chamine", "name": "Chaminé", "wear": "time", "life": 1050.0, "unlock_station": 3, "reinforce_cost": 2500000.0,
		"materials": [{"id": "chapa_ferro", "name": "chapa de ferro", "auto_cost": 20000000.0}]},
]

## Cada nível de reforço de qualquer peça soma este bônus à velocidade do trem
## (0.04 = +4% por nível). Reforçar é durabilidade E recompensa.
var reinforce_speed_bonus: float = 0.04

## Cada nível de reforço multiplica a vida do componente por isto.
var reinforce_life_multiplier: float = 1.4

## Custo do próximo reforço = reinforce_cost * reinforce_cost_growth ^ nível.
var reinforce_cost_growth: float = 2.5

## Duração (segundos) da parada quando um componente quebra.
var maintenance_seconds: float = 15.0

## Custo do reparo = segundos de produção atual * parte que falta para 100%.
var repair_seconds_of_production: float = 20.0

## A manutenção automática conserta a peça quando ela chega a esta integridade.
var auto_repair_threshold: float = 0.10

## Índice da estação que libera a compra da manutenção automática (Outono).
var auto_maintenance_unlock_station: int = 3

## Abaixo desta integridade a interface avisa o jogador.
var component_warning_threshold: float = 0.25

# ---------------------------------------------------------------------------
# Progresso offline
# ---------------------------------------------------------------------------

## Caminho B (decisão 20): offline o trem anda no máximo até a próxima estação
## e espera o jogador lá. A produção continua valendo pelo tempo todo.
var offline_stop_at_next_station: bool = true

## Tempo máximo (segundos) contado enquanto o jogo está fechado: 24 horas.
var offline_max_seconds: float = 86400.0

## Fração da produção e do movimento aplicada offline (1.0 = 100%).
var offline_efficiency: float = 1.0

## Ausências menores que isso (segundos) não mostram resumo.
var offline_min_seconds_for_summary: float = 60.0

# ---------------------------------------------------------------------------
# Salvamento
# ---------------------------------------------------------------------------

## Intervalo do autosave em segundos.
var autosave_interval: float = 10.0
