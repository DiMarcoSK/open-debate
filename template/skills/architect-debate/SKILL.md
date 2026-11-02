---
name: architect-debate
description: Turn a raw product idea into a researched, debated design doc with ADRs (MADR 4.0), C4, design tokens (W3C DTCG), style tile, per-feature spec/plan/tasks (Spec Kit style) and an executable backlog to a polished, launched product (CSV/JSON/gh export). Triggers: quero construir, tenho ideia, SDD, design doc, RFC, ADR, debate de arquitetura, /debate. Runs intake, web research with scout subagents, blind proposals from architecture, product design, GCP and Kubernetes specialists in parallel, attacks with citations, fact-check, rebuttal, weighted judge, gates.
---

Padroes: design doc no formato arc42 enxuto, backlog com epicos, fatias verticais INVEST, esqueleto andante, DoR/DoD e caminho critico, C4 em mermaid, ISO/IEC 25010 + cenarios ATAM, ADR em MADR 4.0, requisitos EARS, specs no estilo GitHub Spec Kit, tokens W3C DTCG, contraste WCAG 2.2, heuristicas de Nielsen, STRIDE.
Estado do caso em `references/protocol.md`. Scripts em `{{SCRIPTS}}/` (abaixo, `$S`).

## Modo sessao (padrao: /debate; um especialista por subagent)

Fase 0, intake, 1 rodada com ate 6 perguntas, cada uma com 2-4 opcoes e default:
1. objetivo, quem usa, metrica de sucesso em 90 dias; 2. carga (usuarios, req/dia, pico); 3. prazo, time, custo teto/mes;
4. drivers de qualidade top 3; 5. dados sensiveis e regulacao; 6. plataforma, concorrentes e referencias visuais.
Sem resposta: assume e marca `[assumido, dono <nome>, <semana>]`. Roda `$S/new-debate.sh "<ideia>" <dest>` (dest default `cases` na raiz do projeto), preenche `brief.md`, ajusta `constitution.md`, roda `$S/gate.sh <caso> brief` ate passar.
Opcoes: `--painel arch,design` vira `painel: debate-arch debate-design` em meta.txt; `--rounds N` corta fases (1 = so proposta, 2 = +ataque e fact-check, 3 = +replica); `--sem-pesquisa` grava `research.md` com `pulado: ...`; `--sem-factcheck` pula a fase 4.

Fases 1-6, cada linha e 1 leva de Task. `le` e `escreve` vao no prompt do Task, com caminho absoluto do caso:

| Fase | Subagent(s), em paralelo | Le | Escreve | Gate |
|---|---|---|---|---|
| 1 pesquisa | debate-research (abre debate-scout por pergunta) | brief.md, research-template.md | research.md | `gate.sh <caso> pesquisa` |
| 2 proposta | painel inteiro | brief.md, constitution.md, research.md, regras-debate.md, visual-contract.md (design) | proposals/<agent>.md | `gate.sh <caso> proposta` |
| 3 ataque | painel inteiro | brief.md, research.md, regras-debate.md, propostas rivais | critiques/<agent>.md | `gate.sh <caso> ataque` |
| 4 fact-check | debate-research, `modo fact-check` | proposals/, critiques/, research-template.md | research-check.md | nao bloqueia |
| 5 replica | painel inteiro | brief.md, research.md, research-check.md, propria proposta, vetos contra si, rivais | proposals/<agent>-r2.md | nao bloqueia |
| 6a decisao | debate-judge, `fase decisao` | tudo acima, adr-template.md | decision.md | `gate.sh <caso> decisao` (separa adr/) |
| 6b SDD | debate-judge, `fase sdd` e depois `fase revisao` | decision.md, adr/, sdd-template.md, visual-contract.md | SDD.md | `gate.sh <caso> sdd` (gera style-tile.html, tokens.json, tokens.css) |

Gate reprovado: 1 Task de reparo para o mesmo agent com `CORRECAO: <motivo do gate>`; reprovou de novo, para e reporta. Caso existente retoma: pula fase cujo arquivo ja passa no gate.

Fase 7, specs: `$S/make-specs.sh <caso> <slugs do indice de decision.md>`; 1 Task por spec em paralelo (debate-arch, `fase spec`, para spec/plan/tasks, debate-design preenche spec secao 6 quando ha UI), depois `$S/gate.sh <caso> specs`, reparo na origem ate zerar.

Fase 8, backlog ate o produto lapidado:
1. Leva em paralelo: debate-design `fase backlog-design` escreve `backlog/design.md`; debate-arch `fase backlog-eng` escreve `backlog/eng.md`. Ambos leem SDD.md, adr/, specs/, lapidacao.md, backlog-template.md. Gate: `$S/gate.sh <caso> trilhas`.
2. debate-pm `fase backlog` escreve `BACKLOG.md` (le os 2 rascunhos, SDD, ADRs, specs/*/tasks.md, lapidacao.md, backlog-template.md). Gate: `$S/gate.sh <caso> backlog` (cobertura de toda tag de lapidacao.md, toda spec e todo ADR, dependencias sem ciclo, estimativa P/M/G, DoD, capacidade); aprovado exporta `backlog.csv` (Jira/Linear/GitHub Projects), `backlog.json` e `backlog-gh.sh` (revisar antes de rodar) e imprime dias por fase e caminho critico.

Fase 9, entrega no chat (max 16 linhas):

```
Caso: <caminho>
Resumo: <secao 0 do SDD em 2 linhas>
Decisoes: <ADR-NNNN titulo, max 6>
Arquitetura: <forma + nuvem + custo/mes>
Direcao visual: <conceito> - <display>/<body>, acento <hex>; abrir style-tile.html
Specs: <NN slug, ...>
Backlog: <N itens, D dias, cabe|corta em <prazo>>; caminho critico <Bxx -> ...>; BACKLOG.md e backlog.csv
Dissenso que pode reabrir: <1 linha>
Perguntas abertas: <max 3, com default>
```

## Modo CLI (`debate.sh`, qualquer harness com modo headless)

Cada especialista roda como processo isolado, com a persona no prompt; nada precisa estar instalado no harness. Mesmo protocolo, mesmos gates, ate o backlog. E o caminho para harness sem subagents (agy, pi, dsh, cline), CI, reexecucao em lote e mesa com harnesses diferentes. Modelos gratuitos do opencode recusam chamada headless (`Free usage limit reached`): neles use o modo sessao.

```sh
$S/new-debate.sh "<ideia>" [dest-cases]
HARNESS=<id> $S/debate.sh <caso> [rounds]
MESA="claude codex gemini" HARNESS=claude $S/debate.sh <caso>   # painel distribuido
$S/validate.sh <caso> [--brief]
```

Env: `HARNESS`, `MODEL` (vazio = padrao do harness), `MODEL_FALLBACK`, `MESA`, `ROTAS` (`debate-arch=claude debate-design=codex:<modelo>`), `HARNESS_CMD` (com `HARNESS=custom`), `RETRIES=2`, `TIMEOUT=600` s por chamada, `MIN_LINES=5`, `PAINEL`, `RESEARCH=1`, `FACTCHECK=1`, `SPECS=1`, `REVIEW=1`, `REPAIR=1`, `FRESH=0`, `OVERWRITE=0`.

## Modelos

No opencode, `modelos.conf` define 1 modelo gratuito por agent, de familias diferentes (paralelo sem disputar o mesmo limite, opinioes menos parecidas). Nos demais harnesses os agents herdam o modelo da sessao; edite a linha `model` do agent ou use `MESA` para diversificar. `$S/modelos.sh check` confere contra `opencode models`; `$S/modelos.sh aplicar` grava nos agents e troca modelo que saiu do catalogo pela reserva. Rodar `check` antes de um debate longo.
