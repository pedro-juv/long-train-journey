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
	# Regiões 6 a 10: cada estação libera o produtor da região seguinte
	{"id": "veio", "name": "Veio Profundo", "output_per_level": 600.0, "base_cost": 60000.0, "unlock_station": 4},
	{"id": "barcaca", "name": "Barcaça Carvoeira", "output_per_level": 6000.0, "base_cost": 900000.0, "unlock_station": 5},
	{"id": "draga", "name": "Draga do Fundo", "output_per_level": 60000.0, "base_cost": 13200000.0, "unlock_station": 6},
	{"id": "doca", "name": "Doca de Dirigíveis", "output_per_level": 600000.0, "base_cost": 198000000.0, "unlock_station": 7},
	{"id": "forja", "name": "Forja de Brasa", "output_per_level": 6000000.0, "base_cost": 3000000000.0, "unlock_station": 8},
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
##   effect     "producer_mult" | "global_mult" | "click_mult" | "maintenance_time_mult"
##              | "wear_mult" (peças em target gastam value x) | "material" (troca o
##              material da peça target para o material de id value)
##   target     id do produtor ou da peça (lista de peças no wear_mult)
##   value      multiplicador aplicado (ou id do material)
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
	{"id": "eq_veio", "name": "Martelete a vapor", "cost": 600000.0, "effect": "producer_mult", "target": "veio", "value": 2.0, "requires": {"producer": "veio"}},
	{"id": "eq_barcaca", "name": "Casco de ferro", "cost": 9000000.0, "effect": "producer_mult", "target": "barcaca", "value": 2.0, "requires": {"producer": "barcaca"}},
	{"id": "eq_draga", "name": "Caçamba dentada", "cost": 132000000.0, "effect": "producer_mult", "target": "draga", "value": 2.0, "requires": {"producer": "draga"}},
	{"id": "eq_doca", "name": "Dirigível cargueiro", "cost": 2000000000.0, "effect": "producer_mult", "target": "doca", "value": 2.0, "requires": {"producer": "doca"}},
	{"id": "eq_forja", "name": "Cadinho de basalto", "cost": 30000000000.0, "effect": "producer_mult", "target": "forja", "value": 2.0, "requires": {"producer": "forja"}},
	{"id": "click_4", "name": "Pá pneumática", "cost": 2000000.0, "effect": "click_mult", "value": 2.0, "requires": {"upgrade": "click_3", "station": 5}},
	{"id": "click_5", "name": "Pá a vapor", "cost": 500000000.0, "effect": "click_mult", "value": 2.0, "requires": {"upgrade": "click_4", "station": 7}},
	# Recompensas das estações
	{"id": "station_0", "name": "Caldeira reforçada", "cost": 1500.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 0}},
	{"id": "station_1", "name": "Caldeira de alta pressão", "cost": 60000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 1}},
	{"id": "station_2", "name": "Tiragem forçada", "cost": 600000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 2}},
	{"id": "station_3", "name": "Superaquecedor", "cost": 1400000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 3}},
	{"id": "station_4", "name": "Isolamento térmico", "cost": 3000000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 4}},
	{"id": "station_5", "name": "Grelha basculante", "cost": 20000000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 5}},
	{"id": "station_6", "name": "Injetor de água quente", "cost": 300000000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 6}},
	{"id": "station_7", "name": "Caldeira pressurizada", "cost": 5000000000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 7}},
	{"id": "station_8", "name": "Condensador de altitude", "cost": 80000000000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 8}},
	{"id": "station_9", "name": "Fornalha vulcânica", "cost": 1500000000000.0, "effect": "global_mult", "value": 1.5, "requires": {"station": 9}},
	# Respostas às regras das regiões (liberadas na entrada de cada uma)
	{"id": "exaustor", "name": "Exaustor de túnel", "cost": 5000000.0, "effect": "wear_mult", "target": ["chamine"], "value": 0.5, "requires": {"station": 4}},
	{"id": "defletor", "name": "Defletor de água", "cost": 60000000.0, "effect": "wear_mult", "target": ["rodas", "freios"], "value": 0.67, "requires": {"station": 5}},
	{"id": "casco", "name": "Casco pressurizado", "cost": 1000000000.0, "effect": "wear_mult", "target": ["caldeira"], "value": 0.67, "requires": {"station": 6}},
	{"id": "estabilizadores", "name": "Estabilizadores", "cost": 15000000000.0, "effect": "wear_mult", "target": ["engates"], "value": 0.67, "requires": {"station": 7}},
	# Materiais novos das peças (a manutenção automática precisa ser comprada de novo)
	{"id": "mat_rodas", "name": "Rodas de aço", "cost": 8000000.0, "effect": "material", "target": "rodas", "value": "aco", "requires": {"station": 4}},
	{"id": "mat_pistoes", "name": "Pistões de aço", "cost": 10000000.0, "effect": "material", "target": "pistoes", "value": "aco", "requires": {"station": 4}},
	{"id": "mat_freios", "name": "Freios de bronze naval", "cost": 80000000.0, "effect": "material", "target": "freios", "value": "bronze_naval", "requires": {"station": 5}},
	{"id": "mat_caldeira", "name": "Caldeira de aço naval", "cost": 1200000000.0, "effect": "material", "target": "caldeira", "value": "aco_naval", "requires": {"station": 6}},
	{"id": "mat_engates", "name": "Engates de aço naval", "cost": 1500000000.0, "effect": "material", "target": "engates", "value": "aco_naval", "requires": {"station": 6}},
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

## Acima desta produção (o fim da região 5) a velocidade cresce mais devagar,
## com train_speed_soft_exponent no lugar do expoente normal.
var train_speed_soft_knee: float = 100000.0
var train_speed_soft_exponent: float = 0.2

## Inércia: segundos para ir de parado à velocidade de cruzeiro.
var train_accel_seconds: float = 6.0

## Segundos para frear do cruzeiro até parar quando uma peça quebra.
var train_brake_seconds: float = 3.0

## Segundos para frear do cruzeiro até parar na plataforma (mais suave).
var train_station_brake_seconds: float = 7.0

## Segundos parado na plataforma de cada estação (quando "Parar nas estações" está ligado).
var station_stop_seconds: float = 5.0

# ---------------------------------------------------------------------------
# Estações — rota contínua; cada trecho leva ~1,6x o tempo do anterior
# (comprimentos calibrados pela simulação da rota longa em tests/test_core.gd)
# ---------------------------------------------------------------------------
## Campos: name, length (metros do trecho desde a estação anterior),
## theme (tema visual e musical da região, a partir da chegada na estação;
## os temas são definidos em scenes/season_themes.gd e scenes/audio_director.gd).
## A recompensa de cada estação é a melhoria com requires {"station": índice};
## produtores com unlock_station também são liberados por ela.
var stations: Array[Dictionary] = [
	{"name": "Estação Inicial", "length": 3500.0, "theme": "inicio"},
	{"name": "Cidade Tomada", "length": 23800.0, "theme": "tomada"},
	{"name": "Deserto de Ferrugem", "length": 75000.0, "theme": "deserto"},
	{"name": "Ruínas Brancas", "length": 211000.0, "theme": "ruinas"},
	{"name": "Ermo Gelado", "length": 446000.0, "theme": "inverno"},
	{"name": "Galerias de Pedra", "length": 1550000.0, "theme": "tunel"},
	{"name": "Vila Alagada", "length": 5720000.0, "theme": "alagada"},
	{"name": "Fossa de Latão", "length": 19700000.0, "theme": "fossa"},
	{"name": "Céu de Latão", "length": 75900000.0, "theme": "ceu"},
	{"name": "Mar de Cinzas", "length": 233000000.0, "theme": "cinzas"},
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
##   (cada material pode ter "life_mult": vida multiplicada; padrão 1)
var components: Array[Dictionary] = [
	{"id": "rodas", "name": "Rodas", "wear": "distance", "life": 15000.0, "unlock_station": 0, "reinforce_cost": 2000.0,
		"materials": [{"id": "ferro_fundido", "name": "ferro fundido", "auto_cost": 5000000.0},
			{"id": "aco", "name": "aço", "auto_cost": 80000000.0, "life_mult": 2.0}]},
	{"id": "caldeira", "name": "Caldeira", "wear": "time", "life": 750.0, "unlock_station": 0, "reinforce_cost": 2000.0,
		"materials": [{"id": "cobre_rebitado", "name": "cobre rebitado", "auto_cost": 5000000.0},
			{"id": "aco_naval", "name": "aço naval", "auto_cost": 10000000000.0, "life_mult": 2.0}]},
	{"id": "pistoes", "name": "Pistões", "wear": "distance", "life": 22500.0, "unlock_station": 0, "reinforce_cost": 3000.0,
		"materials": [{"id": "ferro_fundido", "name": "ferro fundido", "auto_cost": 5000000.0},
			{"id": "aco", "name": "aço", "auto_cost": 100000000.0, "life_mult": 2.0}]},
	{"id": "freios", "name": "Freios", "wear": "distance", "life": 37500.0, "unlock_station": 1, "reinforce_cost": 40000.0,
		"materials": [{"id": "madeira", "name": "sapatas de madeira", "auto_cost": 8000000.0},
			{"id": "bronze_naval", "name": "bronze naval", "auto_cost": 800000000.0, "life_mult": 2.0}]},
	{"id": "engates", "name": "Engates", "wear": "time", "life": 1200.0, "unlock_station": 2, "reinforce_cost": 400000.0,
		"materials": [{"id": "ferro_forjado", "name": "ferro forjado", "auto_cost": 12000000.0},
			{"id": "aco_naval", "name": "aço naval", "auto_cost": 12000000000.0, "life_mult": 2.0}]},
	{"id": "chamine", "name": "Chaminé", "wear": "time", "life": 1050.0, "unlock_station": 3, "reinforce_cost": 2500000.0,
		"materials": [{"id": "chapa_ferro", "name": "chapa de ferro", "auto_cost": 20000000.0}]},
	# Regiões novas: peças que só passam a existir a partir delas
	{"id": "vedacao", "name": "Vedação", "wear": "distance", "life": 400000.0, "unlock_station": 5, "reinforce_cost": 50000000.0,
		"materials": [{"id": "couro", "name": "couro engraxado", "auto_cost": 2000000000.0}]},
	{"id": "filtro", "name": "Filtro", "wear": "time", "life": 900.0, "unlock_station": 8, "reinforce_cost": 50000000000.0,
		"materials": [{"id": "malha_aco", "name": "malha de aço", "auto_cost": 5000000000000.0}]},
]

## Regra de cada região (pela chave "theme" da estação): vale no trecho até
## ela. production/speed multiplicam; wear multiplica o desgaste por peça.
var region_effects: Dictionary = {
	"tunel": {"text": "Galerias de Pedra — ar parado: a chaminé gasta o dobro.", "wear": {"chamine": 2.0}},
	"alagada": {"text": "Vila Alagada — trilho alagado: rodas e freios gastam 50% a mais.", "wear": {"rodas": 1.5, "freios": 1.5}},
	"fossa": {"text": "Fossa de Latão — pressão do fundo: a caldeira gasta 50% a mais.", "wear": {"caldeira": 1.5}},
	"ceu": {"text": "Céu de Latão — vento de cauda: trem 15% mais rápido, mas os engates gastam 50% a mais.", "speed": 1.15, "wear": {"engates": 1.5}},
	"cinzas": {"text": "Mar de Cinzas — calor: produção +25%, mas caldeira e chaminé gastam 50% a mais.", "production": 1.25, "wear": {"caldeira": 1.5, "chamine": 1.5}},
}

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

## Índice da estação que libera a compra da manutenção automática (Ruínas Brancas).
var auto_maintenance_unlock_station: int = 3

## Abaixo desta integridade a interface avisa o jogador.
var component_warning_threshold: float = 0.25

# ---------------------------------------------------------------------------
# Progresso offline
# ---------------------------------------------------------------------------

## Estações novas não passam offline: o trem para um pouco antes da primeira
## estação que o jogador ainda não alcançou e espera ele voltar para chegar
## junto (placa, recompensa, região nova). Estações já conhecidas (depois de um
## futuro reset) podem ser atravessadas offline.
var offline_stop_before_new_station: bool = true

## Onde o trem espera: esta distância (m) antes da estação nova.
var offline_wait_distance_m: float = 250.0

## Tempo máximo (segundos) contado enquanto o jogo está fechado: 24 horas.
var offline_max_seconds: float = 86400.0

## Produção offline: fração da produção normal (0.8 = 80%).
var offline_production_efficiency: float = 0.8

## Movimento offline: fração do tempo fora em que o trem anda (0.1 = 10%).
## 10 horas fora andam o mesmo que 1 hora jogando; as peças gastam na mesma
## proporção.
var offline_movement_efficiency: float = 0.1

## Ausências menores que isso (segundos) não mostram resumo.
var offline_min_seconds_for_summary: float = 60.0

# ---------------------------------------------------------------------------
# Salvamento
# ---------------------------------------------------------------------------

## Intervalo do autosave em segundos.
var autosave_interval: float = 10.0
