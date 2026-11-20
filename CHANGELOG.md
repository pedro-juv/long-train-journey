# Histórico de versões — Idle Train

Formato: `MAIOR.MENOR.CORREÇÃO`
- **MAIOR** — mudança grande de fase/estrutura (ex.: 1.0.0 = primeira versão pública)
- **MENOR** — conteúdo ou mecânica nova (estação, produtor, sistema)
- **CORREÇÃO** — ajustes de balanceamento, correções de bugs, visual

Cada versão vira uma tag no git (`v0.1.0`) e aparece no canto inferior direito do jogo.

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
