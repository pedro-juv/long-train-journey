class_name NumFormat
extends RefCounted
## NumFormat — formatação de números para a interface, no padrão brasileiro.
## (vírgula decimal, ponto de milhar, "mil/mi/bi/tri" para valores grandes)
## Só apresentação: nenhuma regra de jogo usa isto.

## Resumo dos números grandes (como nos jogos clicker): mi, bi, tri, qua
## (quatrilhão), qui (quintilhão), sx, sp, oc, no, dc. Acima disso, "1,23e36".
const _SUFFIXES := [[1e33, "dc"], [1e30, "no"], [1e27, "oc"], [1e24, "sp"], [1e21, "sx"],
	[1e18, "qui"], [1e15, "qua"], [1e12, "tri"], [1e9, "bi"], [1e6, "mi"]]
const _SCIENTIFIC_FROM := 1e36


## Quantidade de carvão ou custo: "15", "1.234", "12,50 mi".
## Números resumidos têm sempre duas casas ("8,90 mi", não "8,9 mi"): o texto
## não muda de tamanho nem pisca quando a casa decimal passa por zero. As casas
## são truncadas (8,999 mi -> "8,99 mi"): nunca mostra mais do que existe.
static func amount(value: float) -> String:
	var v := absf(value)
	var prefix := "-" if value < 0.0 else ""
	if v >= _SCIENTIFIC_FROM:
		var e := int(floor(log(v) / log(10.0)))
		var m := v / pow(10.0, e)
		if m >= 10.0:   # imprecisão do log
			m /= 10.0
			e += 1
		return prefix + _fixed(_truncate(m, 2), 2) + "e" + str(e)
	for s in _SUFFIXES:
		if v >= s[0]:
			return prefix + _fixed(_truncate(v / s[0], 2), 2) + " " + s[1]
	return prefix + _thousands(int(floor(v)))


## Taxa (carvão/s): mostra uma casa decimal quando o valor é pequeno.
static func rate(value: float) -> String:
	if absf(value) < 100.0 and not is_equal_approx(value, roundf(value)):
		return _decimal(value, 1)
	return amount(roundf(value))


## Corta (sem arredondar) em `places` casas; a folga evita 8,09 virar 8,08.
static func _truncate(value: float, places: int) -> float:
	var f := pow(10.0, places)
	return floor(value * f + 1e-6) / f


## Número com exatamente `places` casas e vírgula decimal ("8,90").
static func _fixed(value: float, places: int) -> String:
	return ("%.*f" % [places, value]).replace(".", ",")


## Número com `places` casas e vírgula decimal (sem zeros sobrando).
static func _decimal(value: float, places: int) -> String:
	var text := String.num(value, places)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text.replace(".", ",")


static func _thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out


## Distância: "850 m", "12.345 m", "52,0 km", "350.000 km" (uma casa fixa
## entre 100 e 10.000 km, para não piscar quando a casa passa por zero).
static func distance(meters: float) -> String:
	if meters >= 10000000.0:
		return _thousands(int(floor(meters / 1000.0))) + " km"
	if meters >= 100000.0:
		return _fixed(floor(meters / 100.0) / 10.0, 1) + " km"
	return _thousands(int(floor(meters))) + " m"


## Velocidade: "6,0 m/s".
static func speed(mps: float) -> String:
	if mps >= 1000.0:
		return _thousands(int(floor(mps))) + " m/s"
	return String.num(mps, 1).replace(".", ",") + " m/s"


## Duração: "45 s", "12 min", "2 h 14 min", "3 dias".
static func duration(seconds: float) -> String:
	var s := int(seconds)
	if s < 60:
		return "%d s" % s
	var h := s / 3600
	var m := (s % 3600) / 60
	if h >= 48:
		return "%d dias" % (h / 24)
	if h == 0:
		return "%d min" % m
	return "%d h %d min" % [h, m] if m > 0 else "%d h" % h
