class_name PatchNotesData
extends RefCounted
## Notas da versão para o jogador (mais curtas e sem detalhes técnicos que o
## CHANGELOG.md). A primeira entrada é a versão atual. Ao lançar uma versão
## nova, acrescente uma entrada no topo.

const NOTES := [
	{"version": "0.9.1", "date": "27/11/2026", "title": "Correções", "items": [
		"O trenzinho do indicador da rota agora anda de acordo com a distância percorrida (antes só pulava ao chegar nas estações).",
		"O estoque de carvão virou a porta de uma caldeira de ferro, de tamanho fixo: o número não fica mais tremendo nem esticando a placa.",
		"Números grandes continuam resumidos como nos jogos de clique: mi, bi, tri, qua, qui, sx, sp, oc, no e dc.",
		"A produção mostrada soma o carvão dos cliques (e do Espaço); uma linha embaixo mostra só a parte dos cliques.",
	]},
	{"version": "0.9.0", "date": "27/11/2026", "title": "Ritmo proporcional e botão Partir", "items": [
		"Ao chegar numa estação, o trem espera você clicar em PARTIR.",
		"Nova opção \"Partir sozinho\" no menu (ESC), desligada por padrão: ligada, o trem parte sozinho depois de 5 s, como antes.",
		"No trem flutuante, o botão Partir aparece na barrinha.",
		"Cada trecho agora é cerca de 1,6x mais longo que o anterior, sem saltos. A 1ª estação continua em uns 5 minutos; a rota inteira leva cerca de 14 horas de jogo.",
		"Quem já jogava continua no mesmo ponto do trecho em que estava.",
		"Se o jogo fechar com o trem esperando na estação, ele continua lá (a produção continua) e o resumo avisa.",
		"Notas da versão: aparecem ao abrir uma versão nova e ficam no menu (ESC).",
	]},
	{"version": "0.8.1", "date": "26/11/2026", "title": "Atalho da caldeira", "items": [
		"Espaço atiça a caldeira (o clique no botão continua valendo). Cada aperto vale um clique.",
		"A tecla pode ser trocada no menu (ESC); Delete remove o atalho.",
	]},
	{"version": "0.8.0", "date": "26/11/2026", "title": "Regiões 6 a 10", "items": [
		"Cinco regiões novas: Galerias de Pedra, Vila Alagada, Fossa de Latão, Céu de Latão e Mar de Cinzas.",
		"O cenário da região troca quando o trem sai da estação anterior.",
		"Cada região tem uma regra (ex.: nas Galerias a chaminé gasta o dobro), avisada na partida, e melhorias para compensar.",
		"Produtores novos: Veio Profundo, Barcaça Carvoeira, Draga do Fundo, Doca de Dirigíveis e Forja de Brasa.",
		"Materiais novos (a peça dura o dobro) e peças novas: Vedação e Filtro.",
		"Distâncias e velocidades grandes aparecem com separador de milhar.",
	]},
	{"version": "0.7.0", "date": "26/11/2026", "title": "Offline mais controlado", "items": [
		"Com o jogo fechado, o trem anda só 10% do tempo e a produção vale 80%.",
		"O trem nunca chega sozinho numa estação nova: para um pouco antes e espera você voltar.",
		"O resumo \"Enquanto você esteve fora\" avisa quando o trem está esperando.",
	]},
	{"version": "0.6.0", "date": "21/11/2026", "title": "Regiões pós-apocalípticas", "items": [
		"As estações do ano viraram regiões devastadas: Cidade Tomada, Deserto de Ferrugem, Ruínas Brancas e Ermo Gelado.",
		"Veículos abandonados perto do trilho e HUD com a cor de cada região.",
		"Versão para jogar no navegador (o progresso fica salvo no navegador).",
	]},
	{"version": "0.5.0", "date": "21/11/2026", "title": "Trem flutuante", "items": [
		"Botão FLUTUAR: o trem vira uma janelinha transparente sobre o desktop (só no Windows).",
		"O botão \"+\" abre a loja; arraste para mover e use a alça do canto para mudar o tamanho.",
		"ESC ou duplo clique no trem volta à janela normal.",
	]},
	{"version": "0.4.0", "date": "20/11/2026", "title": "Desenho sombrio e a escuridão", "items": [
		"Visual novo, mais sombrio, com névoa, lampiões e luzes.",
		"Algo escuro persegue o trem pela esquerda (não muda a jogabilidade).",
	]},
	{"version": "0.3.0", "date": "20/11/2026", "title": "Arte nova, HUD e menu de opções", "items": [
		"Cenário e locomotiva redesenhados; câmera mais afastada.",
		"HUD ferroviária com velocímetro e manômetro.",
		"Menu de opções (ESC ou engrenagem): música, efeitos, parada automática e reiniciar partida.",
	]},
	{"version": "0.2.0", "date": "20/11/2026", "title": "Inércia, caldeira e estações", "items": [
		"O trem acelera e freia aos poucos.",
		"Atiçar a caldeira dá carvão e pressão: até +30% de velocidade.",
		"O trem para nas estações; uma peça quebrada faz o trem frear e parar para o conserto.",
	]},
	{"version": "0.1.0", "date": "20/11/2026", "title": "Versão inicial", "items": [
		"Gerar carvão, contratar produtores e comprar melhorias.",
		"Rota de estações, peças com desgaste e manutenção, progresso offline.",
	]},
]


## Texto com BBCode para um RichTextLabel (versão atual em destaque).
static func to_bbcode(current_version: String) -> String:
	var parts: Array[String] = []
	for n in NOTES:
		var head := "Versão %s — %s" % [n["version"], n["title"]]
		if n["version"] == current_version:
			head += "  (atual)"
		var lines: Array[String] = ["[font_size=21][b]%s[/b][/font_size]" % _escape(head),
			"[font_size=13][i]%s[/i][/font_size]" % n["date"]]
		for item in n["items"]:
			lines.append("•  " + _escape(str(item)))
		parts.append("\n".join(lines))
	return "\n\n".join(parts)


static func has_version(version: String) -> bool:
	for n in NOTES:
		if n["version"] == version:
			return true
	return false


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
