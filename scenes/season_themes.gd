class_name SeasonThemes
extends RefCounted
## SeasonThemes — os temas visuais das regiões da rota (só apresentação).
##
## Cada estação do Balance aponta para um tema pelo campo "theme". O tema vale
## a partir da chegada na estação. Juntos, os temas do Mundo Terra percorrem
## um dia inteiro:
##
##   inicio     amanhecer, região industrial
##   primavera  manhã ensolarada, árvores em flor, pétalas no ar
##   verao      sol alto do meio-dia, campos dourados, calor
##   outono     fim de tarde, árvores alaranjadas, folhas caindo
##   inverno    noite, lua e estrelas, neve
##
## Valores "contínuos" (cores e números) são interpolados aos poucos na troca
## de tema; os "discretos" (formato das árvores, tipo de clima) fazem fusão.

const DEFAULT := "inicio"

## Chaves interpoladas continuamente (Color ou float).
const CONTINUOUS := ["sky_top", "sky_mid", "sky_horizon", "sun", "sun_x", "sun_y", "sun_r", "moon",
	"stars", "rays", "haze", "mountain", "caps", "city", "window", "ground_top", "ground_bottom",
	"ballast", "tuft", "cloud", "snow", "beam"]

const THEMES := {
	"inicio": {
		"label": "Amanhecer",
		"sky_top": Color(0.16, 0.20, 0.36), "sky_mid": Color(0.62, 0.45, 0.50), "sky_horizon": Color(0.98, 0.70, 0.45),
		"sun": Color(1.0, 0.86, 0.6), "sun_x": 0.66, "sun_y": 120.0, "sun_r": 44.0, "moon": 0.0, "stars": 0.15, "rays": 0.0, "haze": 0.0,
		"mountain": Color(0.38, 0.29, 0.35), "caps": 0.0,
		"city": Color(0.23, 0.18, 0.22), "window": 0.55,
		"ground_top": Color(0.36, 0.32, 0.20), "ground_bottom": Color(0.20, 0.16, 0.12), "ballast": Color(0.30, 0.27, 0.26),
		"tuft": Color(0.16, 0.20, 0.10), "cloud": Color(1.0, 0.80, 0.70, 0.30), "snow": 0.0, "beam": 0.16,
		"tree_shape": "round", "tree_colors": [Color(0.20, 0.26, 0.16), Color(0.17, 0.22, 0.15)], "tree_density": 0.4, "blossom": false,
		"weather": "none", "weather_colors": [], "dots": [],
	},
	"primavera": {
		"label": "Manhã de primavera",
		"sky_top": Color(0.36, 0.62, 0.90), "sky_mid": Color(0.62, 0.82, 0.95), "sky_horizon": Color(0.96, 0.93, 0.80),
		"sun": Color(1.0, 0.97, 0.78), "sun_x": 0.61, "sun_y": 235.0, "sun_r": 38.0, "moon": 0.0, "stars": 0.0, "rays": 0.35, "haze": 0.0,
		"mountain": Color(0.45, 0.62, 0.55), "caps": 0.0,
		"city": Color(0.50, 0.62, 0.66), "window": 0.10,
		"ground_top": Color(0.42, 0.66, 0.28), "ground_bottom": Color(0.20, 0.38, 0.17), "ballast": Color(0.38, 0.36, 0.33),
		"tuft": Color(0.18, 0.46, 0.14), "cloud": Color(1.0, 1.0, 1.0, 0.80), "snow": 0.0, "beam": 0.05,
		"tree_shape": "round", "tree_colors": [Color(0.98, 0.68, 0.80), Color(1.0, 0.86, 0.91), Color(0.60, 0.82, 0.42)], "tree_density": 1.0, "blossom": true,
		"weather": "petals", "weather_colors": [Color(1.0, 0.72, 0.84), Color(1.0, 0.90, 0.95)],
		"dots": [Color(1.0, 0.50, 0.70), Color(1.0, 1.0, 1.0), Color(1.0, 0.85, 0.30), Color(0.72, 0.55, 1.0)],
	},
	"verao": {
		"label": "Meio-dia de verão",
		"sky_top": Color(0.10, 0.42, 0.86), "sky_mid": Color(0.36, 0.68, 0.96), "sky_horizon": Color(0.86, 0.94, 0.98),
		"sun": Color(1.0, 1.0, 0.86), "sun_x": 0.50, "sun_y": 395.0, "sun_r": 40.0, "moon": 0.0, "stars": 0.0, "rays": 1.0, "haze": 1.0,
		"mountain": Color(0.42, 0.56, 0.70), "caps": 0.0,
		"city": Color(0.46, 0.56, 0.68), "window": 0.05,
		"ground_top": Color(0.84, 0.70, 0.30), "ground_bottom": Color(0.52, 0.40, 0.16), "ballast": Color(0.42, 0.39, 0.35),
		"tuft": Color(0.66, 0.56, 0.18), "cloud": Color(1.0, 1.0, 1.0, 0.92), "snow": 0.0, "beam": 0.03,
		"tree_shape": "round", "tree_colors": [Color(0.16, 0.50, 0.20), Color(0.22, 0.58, 0.22), Color(0.12, 0.42, 0.20)], "tree_density": 0.8, "blossom": false,
		"weather": "none", "weather_colors": [], "dots": [Color(1.0, 0.86, 0.20), Color(0.95, 0.75, 0.15)],
	},
	"outono": {
		"label": "Fim de tarde de outono",
		"sky_top": Color(0.30, 0.22, 0.42), "sky_mid": Color(0.86, 0.44, 0.30), "sky_horizon": Color(1.0, 0.70, 0.30),
		"sun": Color(1.0, 0.62, 0.28), "sun_x": 0.37, "sun_y": 190.0, "sun_r": 54.0, "moon": 0.0, "stars": 0.0, "rays": 0.25, "haze": 0.0,
		"mountain": Color(0.42, 0.24, 0.30), "caps": 0.0,
		"city": Color(0.26, 0.15, 0.18), "window": 0.65,
		"ground_top": Color(0.56, 0.36, 0.16), "ground_bottom": Color(0.28, 0.16, 0.09), "ballast": Color(0.33, 0.27, 0.24),
		"tuft": Color(0.48, 0.28, 0.10), "cloud": Color(1.0, 0.72, 0.52, 0.60), "snow": 0.0, "beam": 0.20,
		"tree_shape": "round", "tree_colors": [Color(0.92, 0.46, 0.10), Color(0.80, 0.24, 0.10), Color(0.96, 0.72, 0.18)], "tree_density": 1.0, "blossom": false,
		"weather": "leaves", "weather_colors": [Color(0.92, 0.46, 0.10), Color(0.80, 0.24, 0.10), Color(0.96, 0.72, 0.18)],
		"dots": [Color(0.92, 0.46, 0.10), Color(0.80, 0.24, 0.10), Color(0.96, 0.72, 0.18)],
	},
	"inverno": {
		"label": "Noite de inverno",
		"sky_top": Color(0.02, 0.03, 0.10), "sky_mid": Color(0.06, 0.10, 0.24), "sky_horizon": Color(0.20, 0.28, 0.46),
		"sun": Color(0.92, 0.95, 1.0), "sun_x": 0.60, "sun_y": 320.0, "sun_r": 34.0, "moon": 1.0, "stars": 1.0, "rays": 0.0, "haze": 0.0,
		"mountain": Color(0.16, 0.20, 0.34), "caps": 1.0,
		"city": Color(0.07, 0.09, 0.18), "window": 0.95,
		"ground_top": Color(0.80, 0.86, 0.95), "ground_bottom": Color(0.42, 0.50, 0.66), "ballast": Color(0.58, 0.63, 0.72),
		"tuft": Color(0.30, 0.34, 0.44), "cloud": Color(0.45, 0.52, 0.70, 0.25), "snow": 1.0, "beam": 0.40,
		"tree_shape": "pine", "tree_colors": [Color(0.08, 0.20, 0.20), Color(0.06, 0.16, 0.18)], "tree_density": 1.0, "blossom": false,
		"weather": "snow", "weather_colors": [Color(1.0, 1.0, 1.0), Color(0.88, 0.94, 1.0)], "dots": [],
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
