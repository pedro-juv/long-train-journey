# Histórico de versões — Idle Train

Formato: `MAIOR.MENOR.CORREÇÃO`
- **MAIOR** — mudança grande de fase/estrutura (ex.: 1.0.0 = primeira versão pública)
- **MENOR** — conteúdo ou mecânica nova (estação, produtor, sistema)
- **CORREÇÃO** — ajustes de balanceamento, correções de bugs, visual

Cada versão vira uma tag no git (`v0.1.0`) e aparece no canto inferior direito do jogo.

## [0.2.0] — 2026-11-20 · Movimento com inércia, caldeira e estações

**Removido**
- Reservatório do trem e consumo de carvão por metro: o carvão agora serve só
  para compras (saves antigos devolvem o carvão do reservatório ao estoque)
- Linha "Trem: EM MOVIMENTO": o estado só aparece em falha, manutenção e estação

**Movimento**
- Inércia: o trem acelera (~6 s) e freia aos poucos, sem saltos de velocidade
- Falha de peça: freia em ~3 s com faíscas nas rodas, vapor/fumaça saindo da
  peça e alerta piscando; o conserto começa depois de parar; volta acelerando
- Estações: freia suave (~7 s), para na plataforma com a placa ao lado do trem,
  apita, espera 5 s e parte. Botão "Parar nas estações: sim/não" (a 1ª estação
  sempre para). Ao voltar do offline, o trem está parado na plataforma

**Clique**
- Botão vira "Atiçar a caldeira": rende 1 + 2% da produção por segundo,
  multiplicado pelas pás — continua útil o jogo todo
- Cada clique soma pressão à caldeira (barra laranja): até +30% de velocidade,
  escoando sozinha em poucos segundos. Fornalha brilha e solta brasas

**Balanceamento**
- Superaquecedor 2 mi → 1,4 mi; Isolamento térmico 6 mi → 3 mi
- Corrigidas as 2 falhas pendentes: toda melhoria de estação fica comprável em
  até 2 min após chegar (0, 1 e 3 cliques/s)

## [0.1.0] — 2026-11-20 · Versão inicial

Primeira versão no GitHub: protótipo com Fase 0, Fase 1A e Fase 1B.

- Loop principal: gerar carvão, produtores, melhorias e reservatório do trem
- Rota de estações até o Inverno, com temas visuais por estação
- Peças do trem com desgaste, falhas, reparo, reforço e conserto automático
- Progresso offline e save em `user://save.json`
- Visual steampunk desenhado por código e trilha sonora provisória
- Exportação Web local (`jogar-web.ps1`) com versão e branch no canto da tela
- Correção: polígono da neve nas montanhas não gera mais erros de triangulação

**Pendente:** 2 falhas de balanceamento no `tests/test_core.gd` (tempo para comprar
melhorias de estação com 0 e 3 cliques/s).
