class_name SeasonThemes
extends RefCounted
## SeasonThemes — os temas visuais das regiões da rota (só apresentação).
##
## Cada estação do Balance aponta para um tema pelo campo "theme". O tema vale
## a partir da chegada na estação. O mundo é pós-apocalíptico; cada região tem
## uma cara própria (referências: The Last of Us, Mad Max, NieR: Automata):
##
##   inicio   Estação Inicial      pátio industrial enferrujado ao amanhecer, cinzas
##   tomada   Cidade Tomada        cidade em ruínas coberta de mato, carros largados, esporos
##   deserto  Deserto de Ferrugem  dunas, céu laranja, sucata de veículos, poeira
##   ruinas   Ruínas Brancas       arranha-céus quebrados sob luz clara e lavada, partículas de luz
##   inverno  Ermo Gelado          noite azul-petróleo, neve
##   tunel    Galerias de Pedra    túnel de pedra de castelo, lampiões, pouca luz
##   alagada  Vila Alagada         vila de telhados curvos debaixo d'água, chuva
##   fossa    Fossa de Latão       cidade art déco no fundo do mar, tubo de vidro, bolhas
##   ceu      Céu de Latão         ilhas flutuantes, pontes sobre o vazio, nuvens
##   cinzas   Mar de Cinzas        planície de cinza, rachaduras de lava, brasas
##
## Valores "contínuos" (cores e números) são interpolados aos poucos na troca
## de tema; os "discretos" (formato das árvores, tipo de clima) fazem fusão.

const DEFAULT := "inicio"

## Chaves interpoladas continuamente (Color ou float).
##   fog           névoa entre os planos (cor + opacidade)
##   gloom         quanto a região é sombria: tamanho da escuridão na borda
##   lamp          lampiões dos postes acesos
##   ruin          fração dos prédios em ruínas (topo quebrado)
##   vines         mato e trepadeiras tomando prédios e postes
##   tall          arranha-céus (prédios bem mais altos, com andares vazios)
##   city_density  fração dos prédios que existem (deserto: quase nada)
##   wrecks        carros e veículos abandonados perto do trilho
##   dunes         colinas viram dunas de areia
##   tunnel        túnel de pedra cobrindo o céu, pilares com lampiões
##   water         água acima do trilho (vila alagada)
##   deep          fundo do mar: tubo de vidro, feixes de luz, criatura ao longe
##   void          sem chão: ponte de treliça sobre nuvens, ilhas flutuantes
##   lava          rachaduras de lava no chão, silhueta colossal na névoa
##   eaves         casas baixas de telhado curvo
##   deco          torres art déco (topo escalonado, janelas redondas)
const CONTINUOUS := ["sky_top", "sky_mid", "sky_horizon", "sun", "sun_x", "sun_y", "sun_r", "moon",
	"stars", "rays", "haze", "mountain", "caps", "city", "window", "ground_top", "ground_bottom",
	"ballast", "tuft", "cloud", "snow", "beam", "fog", "gloom", "lamp",
	"ruin", "vines", "tall", "city_density", "wrecks", "dunes",
	"tunnel", "water", "deep", "void", "lava", "eaves", "deco"]

const THEMES := {
	"inicio": {
		"label": "Pátio enferrujado ao amanhecer",
		"sky_top": Color(0.10, 0.13, 0.20), "sky_mid": Color(0.30, 0.31, 0.38), "sky_horizon": Color(0.66, 0.54, 0.46),
		"sun": Color(0.98, 0.84, 0.64), "sun_x": 0.66, "sun_y": 120.0, "sun_r": 44.0, "moon": 0.0, "stars": 0.12, "rays": 0.0, "haze": 0.0,
		"mountain": Color(0.27, 0.30, 0.36), "caps": 0.0,
		"city": Color(0.17, 0.17, 0.20), "window": 0.80,
		"ground_top": Color(0.27, 0.25, 0.22), "ground_bottom": Color(0.10, 0.11, 0.12), "ballast": Color(0.22, 0.20, 0.20),
		"tuft": Color(0.22, 0.25, 0.20), "cloud": Color(0.62, 0.56, 0.58, 0.55), "snow": 0.0, "beam": 0.24,
		"fog": Color(0.58, 0.52, 0.52, 0.38), "gloom": 0.6, "lamp": 0.85,
		"ruin": 0.35, "vines": 0.1, "tall": 0.0, "city_density": 1.0, "wrecks": 0.35, "dunes": 0.0, "tunnel": 0.0, "water": 0.0, "deep": 0.0, "void": 0.0, "lava": 0.0, "eaves": 0.0, "deco": 0.0,
		"tree_shape": "dead", "tree_colors": [Color(0.17, 0.16, 0.16), Color(0.20, 0.18, 0.17)], "tree_density": 0.5, "blossom": false,
		"weather": "ash", "weather_colors": [Color(1.0, 0.6, 0.3), Color(0.35, 0.36, 0.40), Color(0.45, 0.45, 0.48)], "dots": [],
	},
	"tomada": {
		"label": "Cidade tomada pelo mato",
		"sky_top": Color(0.40, 0.48, 0.49), "sky_mid": Color(0.60, 0.66, 0.63), "sky_horizon": Color(0.80, 0.82, 0.74),
		"sun": Color(0.98, 0.96, 0.86), "sun_x": 0.62, "sun_y": 260.0, "sun_r": 36.0, "moon": 0.0, "stars": 0.0, "rays": 0.18, "haze": 0.0,
		"mountain": Color(0.42, 0.50, 0.48), "caps": 0.0,
		"city": Color(0.30, 0.34, 0.32), "window": 0.0,
		"ground_top": Color(0.30, 0.40, 0.24), "ground_bottom": Color(0.13, 0.19, 0.12), "ballast": Color(0.30, 0.30, 0.28),
		"tuft": Color(0.26, 0.40, 0.20), "cloud": Color(0.86, 0.88, 0.84, 0.7), "snow": 0.0, "beam": 0.04,
		"fog": Color(0.70, 0.76, 0.70, 0.34), "gloom": 0.4, "lamp": 0.0,
		"ruin": 0.6, "vines": 1.0, "tall": 0.5, "city_density": 1.0, "wrecks": 0.85, "dunes": 0.0, "tunnel": 0.0, "water": 0.0, "deep": 0.0, "void": 0.0, "lava": 0.0, "eaves": 0.0, "deco": 0.0,
		"tree_shape": "round", "tree_colors": [Color(0.26, 0.40, 0.22), Color(0.32, 0.46, 0.24), Color(0.20, 0.32, 0.20)], "tree_density": 1.0, "blossom": false,
		"weather": "spores", "weather_colors": [Color(0.94, 0.97, 0.82), Color(0.82, 0.92, 0.70)],
		"dots": [Color(0.56, 0.66, 0.34), Color(0.84, 0.82, 0.60), Color(0.44, 0.56, 0.28)],
	},
	"deserto": {
		"label": "Deserto de ferrugem",
		"sky_top": Color(0.60, 0.38, 0.24), "sky_mid": Color(0.88, 0.58, 0.34), "sky_horizon": Color(0.98, 0.82, 0.56),
		"sun": Color(1.0, 0.94, 0.78), "sun_x": 0.50, "sun_y": 360.0, "sun_r": 46.0, "moon": 0.0, "stars": 0.0, "rays": 0.4, "haze": 1.0,
		"mountain": Color(0.64, 0.40, 0.27), "caps": 0.0,
		"city": Color(0.44, 0.29, 0.21), "window": 0.0,
		"ground_top": Color(0.82, 0.62, 0.38), "ground_bottom": Color(0.54, 0.35, 0.20), "ballast": Color(0.48, 0.38, 0.30),
		"tuft": Color(0.52, 0.40, 0.22), "cloud": Color(0.98, 0.80, 0.60, 0.35), "snow": 0.0, "beam": 0.03,
		"fog": Color(0.95, 0.74, 0.48, 0.36), "gloom": 0.3, "lamp": 0.0,
		"ruin": 0.85, "vines": 0.0, "tall": 0.0, "city_density": 0.3, "wrecks": 1.0, "dunes": 1.0, "tunnel": 0.0, "water": 0.0, "deep": 0.0, "void": 0.0, "lava": 0.0, "eaves": 0.0, "deco": 0.0,
		"tree_shape": "dead", "tree_colors": [Color(0.30, 0.22, 0.16), Color(0.36, 0.26, 0.18)], "tree_density": 0.35, "blossom": false,
		"weather": "dust", "weather_colors": [Color(0.95, 0.80, 0.58), Color(0.85, 0.66, 0.44)], "dots": [],
	},
	"ruinas": {
		"label": "Ruínas brancas",
		"sky_top": Color(0.72, 0.73, 0.70), "sky_mid": Color(0.86, 0.85, 0.79), "sky_horizon": Color(0.97, 0.95, 0.89),
		"sun": Color(1.0, 1.0, 0.96), "sun_x": 0.70, "sun_y": 300.0, "sun_r": 40.0, "moon": 0.0, "stars": 0.0, "rays": 0.5, "haze": 0.3,
		"mountain": Color(0.70, 0.70, 0.66), "caps": 0.0,
		"city": Color(0.55, 0.54, 0.51), "window": 0.0,
		"ground_top": Color(0.58, 0.60, 0.46), "ground_bottom": Color(0.34, 0.36, 0.29), "ballast": Color(0.52, 0.50, 0.46),
		"tuft": Color(0.42, 0.50, 0.30), "cloud": Color(1.0, 1.0, 0.98, 0.6), "snow": 0.0, "beam": 0.02,
		"fog": Color(0.96, 0.95, 0.89, 0.46), "gloom": 0.35, "lamp": 0.0,
		"ruin": 0.75, "vines": 0.6, "tall": 1.0, "city_density": 1.0, "wrecks": 0.3, "dunes": 0.0, "tunnel": 0.0, "water": 0.0, "deep": 0.0, "void": 0.0, "lava": 0.0, "eaves": 0.0, "deco": 0.0,
		"tree_shape": "round", "tree_colors": [Color(0.46, 0.54, 0.34), Color(0.54, 0.60, 0.38)], "tree_density": 0.5, "blossom": false,
		"weather": "motes", "weather_colors": [Color(1.0, 1.0, 0.96), Color(0.96, 0.94, 0.84)], "dots": [Color(0.90, 0.90, 0.84)],
	},
	"inverno": {
		"label": "Ermo gelado",
		"sky_top": Color(0.02, 0.05, 0.08), "sky_mid": Color(0.06, 0.14, 0.18), "sky_horizon": Color(0.16, 0.30, 0.34),
		"sun": Color(0.86, 0.95, 0.96), "sun_x": 0.60, "sun_y": 320.0, "sun_r": 34.0, "moon": 1.0, "stars": 0.8, "rays": 0.0, "haze": 0.0,
		"mountain": Color(0.09, 0.19, 0.23), "caps": 0.7,
		"city": Color(0.04, 0.10, 0.13), "window": 1.0,
		"ground_top": Color(0.48, 0.60, 0.64), "ground_bottom": Color(0.14, 0.22, 0.26), "ballast": Color(0.26, 0.33, 0.37),
		"tuft": Color(0.24, 0.36, 0.40), "cloud": Color(0.20, 0.32, 0.36, 0.3), "snow": 1.0, "beam": 0.5,
		"fog": Color(0.30, 0.52, 0.56, 0.36), "gloom": 0.85, "lamp": 1.0,
		"ruin": 0.45, "vines": 0.0, "tall": 0.3, "city_density": 1.0, "wrecks": 0.4, "dunes": 0.0, "tunnel": 0.0, "water": 0.0, "deep": 0.0, "void": 0.0, "lava": 0.0, "eaves": 0.0, "deco": 0.0,
		"tree_shape": "pine", "tree_colors": [Color(0.07, 0.16, 0.18), Color(0.06, 0.13, 0.15)], "tree_density": 1.0, "blossom": false,
		"weather": "snow", "weather_colors": [Color(0.86, 0.94, 0.96), Color(0.72, 0.86, 0.90)], "dots": [],
	},
	"tunel": {
		"label": "Galerias de pedra",
		"sky_top": Color(0.03, 0.03, 0.04), "sky_mid": Color(0.06, 0.05, 0.05), "sky_horizon": Color(0.10, 0.08, 0.07),
		"sun": Color(0.10, 0.08, 0.07), "sun_x": 0.5, "sun_y": 300.0, "sun_r": 10.0, "moon": 0.0, "stars": 0.0, "rays": 0.0, "haze": 0.0,
		"mountain": Color(0.08, 0.07, 0.07), "caps": 0.0,
		"city": Color(0.24, 0.21, 0.19), "window": 0.0,
		"ground_top": Color(0.20, 0.18, 0.16), "ground_bottom": Color(0.06, 0.05, 0.05), "ballast": Color(0.22, 0.20, 0.18),
		"tuft": Color(0.14, 0.13, 0.12), "cloud": Color(0.1, 0.1, 0.1, 0.0), "snow": 0.0, "beam": 0.85,
		"fog": Color(0.30, 0.22, 0.14, 0.22), "gloom": 0.95, "lamp": 1.0,
		"ruin": 0.0, "vines": 0.0, "tall": 0.0, "city_density": 0.0, "wrecks": 0.0, "dunes": 0.0,
		"tunnel": 1.0, "water": 0.0, "deep": 0.0, "void": 0.0, "lava": 0.0, "eaves": 0.0, "deco": 0.0,
		"tree_shape": "dead", "tree_colors": [Color(0.1, 0.1, 0.1)], "tree_density": 0.0, "blossom": false,
		"weather": "drips", "weather_colors": [Color(0.70, 0.66, 0.58), Color(1.0, 0.80, 0.50)], "dots": [],
	},
	"alagada": {
		"label": "Vila alagada",
		"sky_top": Color(0.46, 0.52, 0.55), "sky_mid": Color(0.70, 0.72, 0.70), "sky_horizon": Color(0.88, 0.85, 0.78),
		"sun": Color(0.98, 0.94, 0.86), "sun_x": 0.30, "sun_y": 250.0, "sun_r": 30.0, "moon": 0.0, "stars": 0.0, "rays": 0.0, "haze": 0.0,
		"mountain": Color(0.50, 0.56, 0.58), "caps": 0.0,
		"city": Color(0.27, 0.27, 0.27), "window": 0.35,
		"ground_top": Color(0.36, 0.50, 0.52), "ground_bottom": Color(0.12, 0.22, 0.26), "ballast": Color(0.25, 0.32, 0.34),
		"tuft": Color(0.20, 0.30, 0.28), "cloud": Color(0.90, 0.90, 0.88, 0.75), "snow": 0.0, "beam": 0.10,
		"fog": Color(0.82, 0.84, 0.80, 0.45), "gloom": 0.45, "lamp": 0.6,
		"ruin": 0.2, "vines": 0.2, "tall": 0.0, "city_density": 0.85, "wrecks": 0.0, "dunes": 0.0,
		"tunnel": 0.0, "water": 1.0, "deep": 0.0, "void": 0.0, "lava": 0.0, "eaves": 1.0, "deco": 0.0,
		"tree_shape": "round", "tree_colors": [Color(0.22, 0.34, 0.26), Color(0.30, 0.40, 0.30)], "tree_density": 0.12, "blossom": false,
		"weather": "rain", "weather_colors": [Color(0.86, 0.90, 0.92), Color(0.74, 0.80, 0.84)], "dots": [],
	},
	"fossa": {
		"label": "Fossa de latão",
		"sky_top": Color(0.01, 0.04, 0.07), "sky_mid": Color(0.02, 0.12, 0.17), "sky_horizon": Color(0.05, 0.24, 0.28),
		"sun": Color(0.05, 0.24, 0.28), "sun_x": 0.5, "sun_y": 400.0, "sun_r": 8.0, "moon": 0.0, "stars": 0.0, "rays": 0.0, "haze": 0.0,
		"mountain": Color(0.03, 0.12, 0.15), "caps": 0.0,
		"city": Color(0.08, 0.17, 0.20), "window": 1.0,
		"ground_top": Color(0.22, 0.24, 0.24), "ground_bottom": Color(0.07, 0.09, 0.10), "ballast": Color(0.28, 0.26, 0.22),
		"tuft": Color(0.10, 0.20, 0.20), "cloud": Color(0.1, 0.2, 0.2, 0.0), "snow": 0.0, "beam": 0.70,
		"fog": Color(0.06, 0.30, 0.34, 0.40), "gloom": 0.8, "lamp": 0.0,
		"ruin": 0.15, "vines": 0.0, "tall": 0.9, "city_density": 0.9, "wrecks": 0.0, "dunes": 0.0,
		"tunnel": 0.0, "water": 0.0, "deep": 1.0, "void": 0.0, "lava": 0.0, "eaves": 0.0, "deco": 1.0,
		"tree_shape": "kelp", "tree_colors": [Color(0.10, 0.30, 0.22), Color(0.14, 0.36, 0.26)], "tree_density": 0.7, "blossom": false,
		"weather": "bubbles", "weather_colors": [Color(0.70, 0.92, 0.94), Color(0.50, 0.80, 0.84)], "dots": [],
	},
	"ceu": {
		"label": "Céu de latão",
		"sky_top": Color(0.30, 0.52, 0.76), "sky_mid": Color(0.62, 0.76, 0.88), "sky_horizon": Color(0.98, 0.90, 0.72),
		"sun": Color(1.0, 0.96, 0.82), "sun_x": 0.72, "sun_y": 330.0, "sun_r": 42.0, "moon": 0.0, "stars": 0.0, "rays": 0.35, "haze": 0.0,
		"mountain": Color(0.92, 0.90, 0.88), "caps": 0.0,
		"city": Color(0.40, 0.36, 0.34), "window": 0.2,
		"ground_top": Color(0.96, 0.94, 0.90), "ground_bottom": Color(0.80, 0.84, 0.90), "ballast": Color(0.30, 0.28, 0.27),
		"tuft": Color(0.9, 0.9, 0.9), "cloud": Color(1.0, 1.0, 1.0, 0.9), "snow": 0.0, "beam": 0.02,
		"fog": Color(1.0, 0.97, 0.92, 0.42), "gloom": 0.2, "lamp": 0.0,
		"ruin": 0.0, "vines": 0.0, "tall": 0.0, "city_density": 0.0, "wrecks": 0.0, "dunes": 0.0,
		"tunnel": 0.0, "water": 0.0, "deep": 0.0, "void": 1.0, "lava": 0.0, "eaves": 0.0, "deco": 0.0,
		"tree_shape": "round", "tree_colors": [Color(0.4, 0.5, 0.3)], "tree_density": 0.0, "blossom": false,
		"weather": "wisps", "weather_colors": [Color(1.0, 1.0, 1.0), Color(0.96, 0.96, 0.98)], "dots": [],
	},
	"cinzas": {
		"label": "Mar de cinzas",
		"sky_top": Color(0.10, 0.04, 0.04), "sky_mid": Color(0.30, 0.12, 0.08), "sky_horizon": Color(0.52, 0.24, 0.14),
		"sun": Color(0.80, 0.26, 0.14), "sun_x": 0.62, "sun_y": 280.0, "sun_r": 46.0, "moon": 0.0, "stars": 0.0, "rays": 0.0, "haze": 0.8,
		"mountain": Color(0.10, 0.08, 0.08), "caps": 0.0,
		"city": Color(0.09, 0.07, 0.07), "window": 0.0,
		"ground_top": Color(0.42, 0.38, 0.36), "ground_bottom": Color(0.16, 0.13, 0.12), "ballast": Color(0.20, 0.17, 0.16),
		"tuft": Color(0.20, 0.17, 0.16), "cloud": Color(0.36, 0.22, 0.18, 0.5), "snow": 0.0, "beam": 0.35,
		"fog": Color(0.46, 0.30, 0.24, 0.42), "gloom": 1.0, "lamp": 0.0,
		"ruin": 1.0, "vines": 0.0, "tall": 0.3, "city_density": 0.35, "wrecks": 0.0, "dunes": 1.0,
		"tunnel": 0.0, "water": 0.0, "deep": 0.0, "void": 0.0, "lava": 1.0, "eaves": 0.0, "deco": 0.0,
		"tree_shape": "dead", "tree_colors": [Color(0.08, 0.06, 0.06), Color(0.12, 0.09, 0.08)], "tree_density": 0.4, "blossom": false,
		"weather": "ash", "weather_colors": [Color(1.0, 0.5, 0.2), Color(0.50, 0.48, 0.48), Color(0.62, 0.60, 0.60)], "dots": [],
	},
}


static func has(id: String) -> bool:
	return THEMES.has(id)


static func get_theme(id: String) -> Dictionary:
	return THEMES.get(id, THEMES[DEFAULT])


## Tema da região atual. Cada estação fica no FIM da sua região: o trecho até
## a estação N é a região N. A troca acontece ao SAIR da estação anterior
## (parado na plataforma, o trem ainda está na região de onde chegou).
static func id_for_route(route: StationTracker, at_station: bool = false) -> String:
	var count := route.station_count()
	if count == 0:
		return DEFAULT
	var index := route.reached_count - 1 if at_station else route.reached_count
	index = clampi(index, 0, count - 1)
	var id := str(route.stations[index].get("theme", DEFAULT))
	return id if THEMES.has(id) else DEFAULT


## Copia os valores contínuos de um tema (para começar a interpolação).
static func continuous_of(id: String) -> Dictionary:
	var theme := get_theme(id)
	var out := {}
	for key in CONTINUOUS:
		out[key] = theme[key]
	return out
