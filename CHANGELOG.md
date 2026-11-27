# Histórico de versões — Idle Train

Formato: `MAIOR.MENOR.CORREÇÃO`
- **MAIOR** — mudança grande de fase/estrutura (ex.: 1.0.0 = primeira versão pública)
- **MENOR** — conteúdo ou mecânica nova (estação, produtor, sistema)
- **CORREÇÃO** — ajustes de balanceamento, correções de bugs, visual

Cada versão vira uma tag no git (`v0.1.0`) e aparece no canto inferior direito do jogo.

## [0.8.1] — 2026-11-26 · Atalho da caldeira

- Espaço atiça a caldeira (mesmo efeito do clique no botão, que continua
  valendo). Segurar a tecla não repete: cada aperto vale um clique
- A tecla pode ser trocada no menu de opções (ESC), em "Atalho: atiçar a
  caldeira"; Delete remove o atalho. A escolha fica salva
- A dica embaixo do botão mostra o atalho atual

## [0.8.0] — 2026-11-26 · Regiões 6 a 10

**Cinco regiões novas** (cenários originais, só inspirados nas referências)
- Galerias de Pedra: túnel de pedra em arcos, lampiões e pouca luz
- Vila Alagada: vila de beirais curvos semi-submersa; o trem corre na água
- Fossa de Latão: túneis metálicos submersos, escotilhas, algas e bolhas
- Céu de Latão: nuvens, grandes vãos e ilhas flutuantes; trilho em ponte
- Mar de Cinzas: cinzas, rachaduras de lava e um colosso ao fundo
- A região agora é a do trecho até a próxima estação: o cenário troca quando o
  trem sai da estação anterior
- HUD com cor e ornamentos de cada região nova; música ainda provisória

**Economia**
- Produtores novos: Veio Profundo, Barcaça Carvoeira, Draga do Fundo, Doca de
  Dirigíveis e Forja de Brasa, cada um com seu equipamento
- Melhoria de produção em cada estação nova e duas pás novas para o clique
- Cada região tem uma regra (ex.: nas Galerias a chaminé gasta o dobro; no Céu
  o trem anda 15% mais rápido, mas os engates gastam mais), avisada na partida
- Melhorias que compensam as regras (Exaustor, Defletor, Casco, Estabilizadores)
- Materiais novos (aço, bronze naval, aço naval): a peça dura o dobro, mas a
  manutenção automática precisa ser comprada de novo
- Peças novas: Vedação e Filtro
- Trechos muito mais longos: jogando ativo, a rota inteira leva cerca de 18 h
- A velocidade cresce mais devagar nas regiões finais; distâncias e
  velocidades grandes aparecem com separador de milhar

## [0.7.0] — 2026-11-26 · Offline mais controlado

**Progresso com o jogo fechado**
- O trem anda bem menos: só 10% do tempo fora (10 horas fora = 1 hora de
  viagem). As peças gastam na mesma proporção
- A produção offline vale 80% (antes 100%); o limite de 24 horas continua
- Estações novas não passam mais offline: o trem para 250 m antes da próxima
  estação que você ainda não conhece e espera. Ao abrir, ele segue e chega com
  você vendo (placa, região nova, recompensa)
- Estações já conhecidas poderão ser atravessadas offline (preparação para o
  futuro reset): o jogo agora salva a estação mais longe que você já alcançou
- Resumo "Enquanto você esteve fora" avisa quando o trem está esperando

## [0.6.0] — 2026-11-21 · Regiões pós-apocalípticas

**As estações do ano viraram regiões devastadas** (referências: The Last of
Us, Mad Max, NieR: Automata). Progressão, trechos e recompensas não mudaram.
- Estação Inicial: pátio industrial enferrujado, árvores secas, cinzas e brasas
- Cidade Tomada (antiga Primavera): ruínas cobertas de mato e trepadeiras,
  arranha-céus vazios, carros abandonados, esporos boiando no ar
- Deserto de Ferrugem (antigo Verão): céu laranja, dunas, quase nenhum prédio
  de pé, sucata de carros, ônibus e caminhões, árvores mortas, poeira soprando
- Ruínas Brancas (antigo Outono): arranha-céus quebrados sob luz clara e
  lavada, mato no concreto, partículas de luz subindo
- Ermo Gelado (antigo Inverno): mesma noite de neve, agora com destroços
- Veículos abandonados perto do trilho (também no trem flutuante)
- Mato subindo pelos postes na Cidade Tomada e nas Ruínas Brancas
- HUD: cada região com sua cor e seus ornamentos (trepadeiras, sol do deserto,
  estilhaços de concreto); nomes longos quebram em duas linhas na placa da rota
- Música: provisoriamente, as mesmas variações da valsa das estações antigas

**Versão web no ar:** https://pedro-juv.github.io/long-train-journey/ (publicada
automaticamente a cada atualização da main; o progresso fica salvo no navegador)

## [0.5.0] — 2026-11-21 · Trem flutuante (desktop)

**Modo trem flutuante (só na versão desktop)**
- Botão "FLUTUAR" (embaixo da engrenagem) ou "Trem flutuante" no menu de
  opções: a janela do jogo vira uma janelinha (520 x 250) sem borda, sempre por
  cima das outras, no canto inferior direito da tela
- Fundo transparente de verdade (o Windows mostra o desktop por trás): ficam só
  o trem, o trilho com uma faixa de chão, árvores, postes com lampiões, clima,
  plataforma e placa das estações. Céu, montanhas, cidade e a escuridão somem
- Carvão pequeno no canto e botão "+": a janela cresce para cima e mostra a
  loja (a mesma loja da HUD, com as mesmas compras e as duas abas)
- Botões pequenos de música e efeitos sonoros (os mesmos do menu de opções)
- Alça no canto superior esquerdo para mudar o tamanho: o trem acompanha a
  altura. Tamanho e lugar ficam salvos para a próxima vez
- Arrastar em qualquer parte move a janela; fora do trem e da barra o clique
  atravessa para o que está atrás
- Voltar à janela normal: botão, ESC ou duplo clique no trem (mesmo tamanho e
  lugar de antes). Botão X fecha o jogo salvando
- Mesma partida em memória e mesmo save: nada recarrega ao alternar
- Corrigido: abrir o menu de opções e ir para o trem flutuante deixava a placa
  do menu torta e fora do lugar nas vezes seguintes
- Mais leve: limitado a 30 quadros por segundo e camadas escondidas não são
  redesenhadas

**Executável do Windows**
- `gerar-exe.ps1` gera `build\windows\IdleTrain.exe` (um arquivo só, com a
  versão e a branch no canto do jogo)

**Não incluído:** o save do desktop e o do navegador continuam separados
(cada um no seu armazenamento local; o projeto não tem conta nem nuvem)

## [0.4.0] — 2026-11-20 · Desenho sombrio e a escuridão

**Arte (desenho sombrio, provisório)**
- Novo estilo inspirado em cenários desenhados e atmosféricos: cores
  dessaturadas, névoa entre os planos, cordilheira distante, silhuetas com traço
  fino e primeiro plano escuro. A cor vem das luzes (brilho suave em lote)
- Cidade com torres, telhados pontudos e janelas em arco que brilham; nas
  regiões mais sombrias, parte dos prédios está em ruínas
- Postes com lampiões acesos, plataforma de pedra com lampiões, feixe do farol
  em degradê e luz da fornalha saindo da cabine
- Locomotiva e tender em ferro azulado com latão gasto
- Temas revistos: Amanhecer cinzento (cinzas e brasas no ar), Primavera e
  Verão mais vivos, Outono e Noite de inverno (azul-petróleo) mais sombrios
- Chegada na estação: luzinhas subindo no lugar do confete

**Removido**
- Maquinista da cabine (personagens existirão, mas não nesse formato)

**A escuridão**
- Algo consome tudo atrás do trem: massa escura que respira na borda esquerda,
  com tentáculos e pedaços do mundo sendo puxados para dentro
- Avança ao acaso de vez em quando, chega mais perto com o trem parado e, ao
  sair de uma estação, escurece a tela por alguns segundos. Nunca cobre o trem
  e não muda a jogabilidade

**HUD**
- Mesmo layout, agora em ferro escuro, papel envelhecido e latão gasto; cada
  estação do ano mantém sua cor de destaque

**Desempenho**
- Mesmo desempenho da 0.3.0 na mesma máquina (347 vs 352 FPS, dentro da
  variação; 127 chamadas de desenho por quadro)

## [0.3.0] — 2026-11-20 · Arte cartoon, HUD ferroviária, câmera e menu de opções

**Arte (cartoon 2D desenhado à mão)**
- Contornos fortes de tinta, silhuetas simples, sombras chapadas e brilhos em
  todo o cenário: nuvens fofas, montanhas, colinas novas (profundidade), cidade,
  árvores, campo, dormentes de madeira, trilho, postes, mato e clima
- Paleta ferroviária antiga: vinho, madeira, carvão, metal, bronze, cobre,
  ouro envelhecido e creme; temas do amanhecer e da noite de inverno mais claros
- Locomotiva redesenhada (vinho com cintas de ouro, chaminé de funil, domos de
  latão, rodas vermelhas com contrapeso, placa "1857") e tender de madeira com
  brasão. Continuam sendo só a locomotiva e o tender
- Maquinista original na janela da cabine, com expressões: normal (pisca),
  feliz com a caldeira atiçada/estação, aflito (suor) em falhas; acena na estação
- Plataforma da estação maior (cobre o trem inteiro), placa pendurada legível,
  tranco de câmera nas falhas

**Câmera**
- Câmera bem mais afastada (zoom 0,58 do mundo): aparece muito mais trilho,
  céu e campo; o trem fica à direita, com trilho livre atrás para vagões futuros

**HUD**
- Nova interface ferroviária: bilhete do estoque, placa da rota com as estações
  e o trenzinho, placa de estado, painel com velocímetro e manômetro analógicos
  (ponteiros com mola) e o botão grande "Atiçar a caldeira", armazém de madeira
- Pele por estação do ano (uma só HUD): acento de cor, decoração dos painéis
  (engrenagens, flores, sol, folhas, neve e pingentes de gelo) e carimbo do bilhete
- Música, efeitos e "Parar nas estações" saíram da HUD

**Menu de opções (ESC ou botão de engrenagem)**
- Placa vinho pendurada por correntes, com chaves de alavanca animadas:
  Música, Efeitos sonoros, Parada automática, Reiniciar partida (com
  confirmação) e Voltar ao jogo
- Pausa o jogo de verdade (a partida congela; a música continua) e salva ao abrir
- Preferências persistem: áudio em `user://settings.cfg`; parada automática no
  save, mantida ao reiniciar a partida

**Desempenho**
- Desenho em quads com uma textura compartilhada (círculo suavizado): mesmo com
  a arte nova, 126 chamadas de desenho por quadro (antes 444) e ~2,3 ms por
  quadro no desktop (antes ~2,5 ms)

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

**Desempenho**
- Cenário em camadas: céu, montanhas, cidade, árvores, campo, trilho, postes,
  mato e carroceria do trem são desenhados uma vez e só deslizam/balançam;
  só rodas, bielas, fumaça, faíscas, clima e brilhos redesenham a cada quadro.
  Desenho por quadro: 3,4 ms → 0,5 ms; quadro total 6,4 ms → 2,1 ms (desktop)
- Contador de FPS no canto e `jogar-web.ps1 -Release` para testar sem depuração
- Ferramentas: `tests/benchmark.tscn` (tempo por camada) e `tests/capture.tscn`
  (capturas de tela por tema)

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
