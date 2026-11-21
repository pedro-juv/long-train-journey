class_name SeasonThemes
extends RefCounted
## SeasonThemes — os temas visuais das regiões da rota (só apresentação).
##
## Cada estação do Balance aponta para um tema pelo campo "theme". O tema vale
## a partir da chegada na estação. Juntos, os temas do Mundo Terra percorrem
## um dia inteiro:
##
##   inicio     amanhecer cinzento, cidade industrial meio em ruínas, cinzas
##   primavera  manhã ensolarada, árvores em flor, pétalas no ar
##   verao      sol alto do meio-dia, campos dourados, calor
##   outono     fim de tarde, árvores alaranjadas, folhas caindo
##   inverno    noite, lua e estrelas, neve
##
## Valores "contínuos" (cores e números) são interpolados aos poucos na troca
## de tema; os "discretos" (formato das árvores, tipo de clima) fazem fusão.

const DEFAULT := "inicio"

## Chaves interpoladas continuamente (Color ou float).
##   fog    névoa entre os planos (cor + opacidade)
##   gloom  quanto a região é sombria: tamanho da escuridão na borda, prédios
##          em ruínas e árvores apagadas (0 = viva, 1 = bem sombria)
##   lamp   lampiões dos postes acesos
const CONTINUOUS := ["sky_top", "sky_mid", "sky_horizon", "sun", "sun_x", "sun_y", "sun_r", "moon",
	"stars", "rays", "haze", "mountain", "caps", "city", "window", "ground_top", "ground_bottom",
	"ballast", "tuft", "cloud", "snow", "beam", "fog", "gloom", "lamp"]

## Estilo "desenho sombrio": cores dessaturadas, névoa e luzes quentes. As
## primeiras regiões (primavera e verão) são as mais vivas; o amanhecer
## cinzento da partida, o outono e a noite de inverno são as mais sombrias.
const THEMES := {
	"inicio": {
		"label": "Amanhecer cinzento",
		"sky_top": Color(0.10, 0.13, 0.20), "sky_mid": Color(0.30, 0.31, 0.38), "sky_horizon": Color(0.66, 0.54, 0.46),
		"sun": Color(0.98, 0.84, 0.64), "sun_x": 0.66, "sun_y": 120.0, "sun_r": 44.0, "moon": 0.0, "stars": 0.12, "rays": 0.0, "haze": 0.0,
		"mountain": Color(0.27, 0.30, 0.36), "caps": 0.0,
		"city": Color(0.15, 0.17, 0.22), "window": 0.80,
		"ground_top": Color(0.25, 0.25, 0.23), "ground_bottom": Color(0.10, 0.11, 0.12), "ballast": Color(0.20, 0.20, 0.22),
		"tuft": Color(0.20, 0.25, 0.22), "cloud": Color(0.62, 0.56, 0.58, 0.55), "snow": 0.0, "beam": 0.24,
		"fog": Color(0.58, 0.52, 0.52, 0.38), "gloom": 0.6, "lamp": 0.85,
		"tree_shape": "round", "tree_colors": [Color(0.20, 0.25, 0.24), Color(0.17, 0.21, 0.21)], "tree_density": 0.4, "blossom": false,
		"weather": "ash", "weather_colors": [Color(1.0, 0.6, 0.3), Color(0.35, 0.36, 0.40), Color(0.45, 0.45, 0.48)], "dots": [],
	},
	"primavera": {
		"label": "Manhã de primavera",
		"sky_top": Color(0.28, 0.45, 0.60), "sky_mid": Color(0.54, 0.68, 0.74), "sky_horizon": Color(0.86, 0.86, 0.76),
		"sun": Color(1.0, 0.96, 0.82), "sun_x": 0.61, "sun_y": 235.0, "sun_r": 38.0, "moon": 0.0, "stars": 0.0, "rays": 0.3, "haze": 0.0,
		"mountain": Color(0.40, 0.52, 0.55), "caps": 0.0,
		"city": Color(0.32, 0.40, 0.45), "window": 0.12,
		"ground_top": Color(0.34, 0.48, 0.30), "ground_bottom": Color(0.14, 0.24, 0.17), "ballast": Color(0.30, 0.31, 0.31),
		"tuft": Color(0.22, 0.38, 0.22), "cloud": Color(0.96, 0.96, 0.92, 0.72), "snow": 0.0, "beam": 0.06,
		"fog": Color(0.80, 0.86, 0.84, 0.28), "gloom": 0.15, "lamp": 0.1,
		"tree_shape": "round", "tree_colors": [Color(0.86, 0.62, 0.70), Color(0.92, 0.80, 0.84), Color(0.46, 0.62, 0.42)], "tree_density": 1.0, "blossom": true,
		"weather": "petals", "weather_colors": [Color(0.96, 0.72, 0.80), Color(0.98, 0.90, 0.92)],
		"dots": [Color(0.92, 0.52, 0.66), Color(0.94, 0.94, 0.90), Color(0.94, 0.82, 0.40), Color(0.66, 0.56, 0.90)],
	},
	"verao": {
		"label": "Meio-dia de verão",
		"sky_top": Color(0.18, 0.40, 0.62), "sky_mid": Color(0.44, 0.62, 0.78), "sky_horizon": Color(0.86, 0.88, 0.84),
		"sun": Color(1.0, 0.98, 0.86), "sun_x": 0.50, "sun_y": 395.0, "sun_r": 40.0, "moon": 0.0, "stars": 0.0, "rays": 0.8, "haze": 1.0,
		"mountain": Color(0.42, 0.52, 0.62), "caps": 0.0,
		"city": Color(0.38, 0.44, 0.52), "window": 0.05,
		"ground_top": Color(0.68, 0.58, 0.34), "ground_bottom": Color(0.36, 0.28, 0.16), "ballast": Color(0.36, 0.34, 0.32),
		"tuft": Color(0.50, 0.44, 0.22), "cloud": Color(1.0, 1.0, 0.98, 0.85), "snow": 0.0, "beam": 0.03,
		"fog": Color(0.92, 0.90, 0.82, 0.22), "gloom": 0.1, "lamp": 0.0,
		"tree_shape": "round", "tree_colors": [Color(0.20, 0.40, 0.24), Color(0.26, 0.46, 0.26), Color(0.16, 0.34, 0.22)], "tree_density": 0.8, "blossom": false,
		"weather": "none", "weather_colors": [], "dots": [Color(0.92, 0.80, 0.30), Color(0.86, 0.70, 0.24)],
	},
	"outono": {
		"label": "Fim de tarde de outono",
		"sky_top": Color(0.12, 0.11, 0.20), "sky_mid": Color(0.48, 0.28, 0.28), "sky_horizon": Color(0.90, 0.56, 0.32),
		"sun": Color(1.0, 0.62, 0.32), "sun_x": 0.37, "sun_y": 190.0, "sun_r": 54.0, "moon": 0.0, "stars": 0.0, "rays": 0.15, "haze": 0.0,
		"mountain": Color(0.28, 0.19, 0.25), "caps": 0.0,
		"city": Color(0.16, 0.12, 0.16), "window": 0.85,
		"ground_top": Color(0.36, 0.25, 0.16), "ground_bottom": Color(0.13, 0.09, 0.08), "ballast": Color(0.23, 0.20, 0.20),
		"tuft": Color(0.36, 0.24, 0.12), "cloud": Color(0.86, 0.56, 0.46, 0.5), "snow": 0.0, "beam": 0.28,
		"fog": Color(0.70, 0.44, 0.38, 0.32), "gloom": 0.5, "lamp": 0.75,
		"tree_shape": "round", "tree_colors": [Color(0.76, 0.40, 0.16), Color(0.62, 0.24, 0.14), Color(0.82, 0.60, 0.24)], "tree_density": 1.0, "blossom": false,
		"weather": "leaves", "weather_colors": [Color(0.80, 0.44, 0.16), Color(0.66, 0.26, 0.14), Color(0.86, 0.64, 0.26)],
		"dots": [Color(0.80, 0.44, 0.16), Color(0.66, 0.26, 0.14), Color(0.86, 0.64, 0.26)],
	},
	"inverno": {
		"label": "Noite de inverno",
		"sky_top": Color(0.02, 0.05, 0.08), "sky_mid": Color(0.06, 0.14, 0.18), "sky_horizon": Color(0.16, 0.30, 0.34),
		"sun": Color(0.86, 0.95, 0.96), "sun_x": 0.60, "sun_y": 320.0, "sun_r": 34.0, "moon": 1.0, "stars": 0.8, "rays": 0.0, "haze": 0.0,
		"mountain": Color(0.09, 0.19, 0.23), "caps": 0.7,
		"city": Color(0.04, 0.10, 0.13), "window": 1.0,
		"ground_top": Color(0.48, 0.60, 0.64), "ground_bottom": Color(0.14, 0.22, 0.26), "ballast": Color(0.26, 0.33, 0.37),
		"tuft": Color(0.24, 0.36, 0.40), "cloud": Color(0.20, 0.32, 0.36, 0.3), "snow": 1.0, "beam": 0.5,
		"fog": Color(0.30, 0.52, 0.56, 0.36), "gloom": 0.85, "lamp": 1.0,
		"tree_shape": "pine", "tree_colors": [Color(0.07, 0.16, 0.18), Color(0.06, 0.13, 0.15)], "tree_density": 1.0, "blossom": false,
		"weather": "snow", "weather_colors": [Color(0.86, 0.94, 0.96), Color(0.72, 0.86, 0.90)], "dots": [],
	},
}


static func has(id: String) -> bool:
	return THEMES.has(id)


static func get_theme(id: String) -> Dictionary:
	return THEMES.get(id, THEMES[DEFAULT])


## Tema da região atual: o da última estação alcançada (ou o inicial).
static func id_for_route(route: StationTracker) -> String:
	if route.reached_count <= 0:
		return DEFAULT
	var id := str(route.stations[route.reached_count - 1].get("theme", DEFAULT))
	return id if THEMES.has(id) else DEFAULT


## Copia os valores contínuos de um tema (para começar a interpolação).
static func continuous_of(id: String) -> Dictionary:
	var theme := get_theme(id)
	var out := {}
	for key in CONTINUOUS:
		out[key] = theme[key]
	return out
