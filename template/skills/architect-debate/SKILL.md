---
name: architect-debate
description: Turn a raw product idea into a researched, debated design doc with ADRs (MADR 4.0), C4, design tokens (W3C DTCG), style tile, per-feature spec/plan/tasks (Spec Kit style) and an executable backlog to a polished, launched product (CSV/JSON/gh export). Triggers: quero construir, tenho ideia, SDD, design doc, RFC, ADR, debate de arquitetura, /debate. Runs intake, web research with scout subagents, an agenda of contested decisions, blind proposals in parallel from a panel picked for the idea (always architecture, UI/UX and product; plus software design, art direction and brandbook, security, AI, data, mobile, GCP, AWS or Kubernetes when the brief calls for them), attacks with verified citations, fact-check, rebuttal, weighted judge, independent audit, gates.
---

Padroes: design doc no formato arc42 enxuto, backlog com epicos, fatias verticais INVEST, esqueleto andante, DoR/DoD e caminho critico, C4 em mermaid, ISO/IEC 25010 + cenarios ATAM, ADR em MADR 4.0, requisitos EARS, specs no estilo GitHub Spec Kit, tokens W3C DTCG, contraste WCAG 2.2, heuristicas de Nielsen, STRIDE.
Estado do caso em `references/protocol.md`. Scripts em `{{SCRIPTS}}/` (abaixo, `$S`).

## Modo sessao (padrao: /debate; um especialista por subagent)

Antes do intake: se `open-debate` estiver no PATH, rode `open-debate upgrade --check` e, havendo versao nova, diga em 1 linha.

Fase 0, intake em modo grill: o produto final so e conciso se o brief for. Pergunte em rodadas, 1 tema por rodada,
ate 3 perguntas por rodada, cada uma com 2-4 opcoes e a sua recomendacao marcada como default. Temas, nesta ordem:
1. objetivo, quem usa, metrica de sucesso em 90 dias; 2. carga (usuarios, req/dia, pico); 3. prazo, time, custo teto/mes;
4. drivers de qualidade top 3; 5. dados sensiveis e regulacao; 6. plataforma, concorrentes e referencias visuais.
Grill, a cada resposta:
- Vaga ("todo mundo", "rapido", "barato", "escalavel") volta como pergunta com numero ou exemplo: "quantos?", "em quanto tempo?", "ate quanto/mes?".
- Contradicao entre respostas (prazo de 4 semanas com 9 features; custo zero com SLA 99,99) e apontada e o usuario escolhe o que cede.
- Corte de escopo: liste as features citadas e peca o MVP: o que entra no dia 1, o que vai para depois, o que sai. Pergunte "se so desse para lancar 1 fluxo, qual?".
- Pergunte o porque de cada requisito duro ate chegar na restricao real; requisito sem dono vira hipotese.
- Encerra o grill quando objetivo, metrica, usuario principal, MVP, prazo e teto de custo tem resposta concreta, ou quando o usuario pedir para seguir (teto 5 rodadas).
Antes de seguir, mostre o brief em 6 linhas (problema, usuario, metrica, MVP, fora do escopo, restricoes) e peca confirmacao.
Sem resposta: assume e marca `[assumido, dono <nome>, <semana>]`. Roda `$S/new-debate.sh "<ideia>" <dest>` (dest default `cases` na raiz do projeto), preenche `brief.md`, ajusta `constitution.md`, roda `$S/gate.sh <caso> brief` ate passar.
Painel: `debate-arch`, `debate-ux` e `debate-pm` sentam sempre. Os opcionais saem do brief: rode `$S/painel.sh <caso>`, que mostra o painel e a palavra do brief que acionou cada assento (catalogo em `references/painel.conf`):

| Assento | Entra quando o brief tem |
|---|---|
| debate-design | telas: web, app, dashboard, portal, backoffice |
| debate-brand | rosto publico: marca, B2C, consumidor, loja, lancamento, landing |
| debate-sec | dado pessoal, financeiro, de saude ou regulado (LGPD, PCI) |
| debate-ai | LLM, RAG, agente, ML, recomendacao |
| debate-data | analytics, BI, ETL, pipeline, relatorios, streaming |
| debate-mobile | iOS, Android, aplicativo, offline, push |
| debate-gcp, debate-aws, debate-k8s | a nuvem ou o cluster citados |

Ajuste pelo que o brief quer dizer e nao so pela palavra (ex: produto sem tela tira `design`; ideia que vai ao publico soma `brand`), grave com `$S/painel.sh <caso> --grava <agents>` e diga o painel em 1 linha. Teto 8 assentos.
Papeis de design: debate-design decide o que cada tela tem (fluxos, inventario, wireframes, estados); debate-ux revisa essas telas no ataque (`## Revisao debate-design`) e fecha usabilidade, acessibilidade e sistema de UI; debate-brand cria a marca e o TOKENS e, depois do SDD, escreve o BRANDBOOK.md adaptando as telas a marca. Sem debate-brand, o TOKENS e de debate-ux.
Opcoes: `--painel design,brand` vira `$S/painel.sh <caso> --grava design brand` (a base entra sozinha); `--rounds N` corta fases (1 = so proposta, 2 = +ataque e fact-check, 3 = +replica); `--sem-pesquisa` grava `research.md` com `pulado: ...`; `--sem-factcheck` pula a fase 4.

Fases 1-6, cada linha e 1 leva de Task. `le` e `escreve` vao no prompt do Task, com caminho absoluto do caso:

| Fase | Subagent(s), em paralelo | Le | Escreve | Gate |
|---|---|---|---|---|
| 1 pesquisa | debate-research (abre debate-scout por pergunta) | brief.md, research-template.md | research.md | `gate.sh <caso> pesquisa` |
| 1b agenda | debate-judge, `fase agenda`, com o painel no prompt | brief.md, constitution.md, research.md, agenda-template.md | agenda.md | `gate.sh <caso> agenda`; depois, grill 2: as decisoes da agenda que dependem de preferencia do usuario (e nao de evidencia) viram ate 3 perguntas com default; a resposta entra em brief.md antes da proposta |
| 2 proposta | painel inteiro | brief.md, constitution.md, research.md, agenda.md, regras-debate.md, visual-contract.md (design, ux, brand) | proposals/<agent>.md | `gate.sh <caso> proposta` |
| 3 ataque | painel inteiro | brief.md, research.md, agenda.md, regras-debate.md, propostas rivais | critiques/<agent>.md | `gate.sh <caso> ataque` |
| 4 fact-check | debate-research, `modo fact-check` | proposals/, critiques/, research-template.md | research-check.md | nao bloqueia |
| 5 replica | so quem sai de `gate.sh <caso> vetados` | brief.md, research.md, research-check.md, propria proposta, vetos contra si, rivais | proposals/<agent>-r2.md | nao bloqueia |
| 6a decisao | debate-judge, `fase decisao` | tudo acima, adr-template.md | decision.md | `gate.sh <caso> decisao` (separa adr/) |
| 6b SDD | debate-judge, `fase sdd` | decision.md, adr/, sdd-template.md, visual-contract.md | SDD.md | `gate.sh <caso> sdd` (gera style-tile.html, tokens.json, tokens.css) |
| 6c auditoria | debate-auditor, `fase auditoria` | SDD.md, brief.md, constitution.md, decision.md, adr/, research-check.md, auditoria-template.md | auditoria.md | `gate.sh <caso> auditoria`; `Veredito: CORRIGIR`: debate-judge `fase correcao` reemite o SDD e o gate sdd roda de novo |
| 6d marca (so com debate-brand) | debate-brand, `fase marca` | brief.md, SDD.md, decision.md, proposals/debate-brand(-r2).md, proposals/debate-design.md, critiques/debate-ux.md, brandbook-template.md, visual-contract.md | BRANDBOOK.md | `gate.sh <caso> marca` |

Gate reprovado: 1 Task de reparo para o mesmo agent com `CORRECAO: <motivo do gate>`; reprovou de novo, para e reporta. Caso existente retoma: `$S/gate.sh <caso> status` mostra cada fase, a proxima e saidas defasadas.
Nas fases 2 e 3, o prompt do Task nomeia so os arquivos da coluna Le: quem nao recebe o caminho do rival segue cego.

Fase 7, specs: `$S/make-specs.sh <caso> <slugs do indice de decision.md>`; 1 Task por spec em paralelo (debate-arch, `fase spec`, para spec/plan/tasks; debate-design, ou debate-ux sem design no painel, preenche spec secao 6 quando ha UI), depois `$S/gate.sh <caso> specs`, reparo na origem ate zerar.

Fase 8, backlog ate o produto lapidado:
1. Leva em paralelo: debate-ux `fase backlog-design` escreve `backlog/design.md`; debate-arch `fase backlog-eng` escreve `backlog/eng.md`. Ambos leem SDD.md, adr/, specs/, lapidacao.md, backlog-template.md e, se existir, BRANDBOOK.md. Gate: `$S/gate.sh <caso> trilhas`.
2. debate-pm `fase backlog` escreve `BACKLOG.md` (le os 2 rascunhos, SDD, ADRs, specs/*/tasks.md, BRANDBOOK.md se existir, lapidacao.md, backlog-template.md). Gate: `$S/gate.sh <caso> backlog` (cobertura de toda tag de lapidacao.md, toda spec e todo ADR, dependencias sem ciclo, estimativa P/M/G, DoD, capacidade); aprovado exporta `backlog.csv` (Jira/Linear/GitHub Projects), `backlog.json` e `backlog-gh.sh` (revisar antes de rodar) e imprime dias por fase e caminho critico.

Fase 9, entrega no chat (max 16 linhas):

```
Caso: <caminho>
Resumo: <secao 0 do SDD em 2 linhas>
Decisoes: <ADR-NNNN titulo, max 6>
Arquitetura: <forma + nuvem + custo/mes>
Painel: <agents>
Direcao visual: <conceito> - <display>/<body>, acento <hex>; abrir style-tile.html (e BRANDBOOK.md com debate-brand)
Specs: <NN slug, ...>
Backlog: <N itens, D dias, cabe|corta em <prazo>>; caminho critico <Bxx -> ...>; BACKLOG.md e backlog.csv
Dissenso que pode reabrir: <1 linha>
Perguntas abertas: <max 3, com default>
```

## Modo CLI (`debate.sh`, qualquer harness com modo headless)

Cada especialista roda como processo isolado, com a persona no prompt; nada precisa estar instalado no harness. Nas fases 2 e 3 o processo roda numa sala: um diretorio so com o que ele pode ler. Mesmo protocolo, mesmos gates, ate o backlog. E o caminho para harness sem subagents (agy, pi, dsh, cline), CI, reexecucao em lote e mesa com harnesses diferentes. Modelos gratuitos do opencode recusam chamada headless (`Free usage limit reached`): neles use o modo sessao.

```sh
$S/new-debate.sh "<ideia>" [dest-cases]
HARNESS=<id> $S/debate.sh <caso> [rounds]
MESA="claude codex gemini" HARNESS=claude $S/debate.sh <caso>   # painel distribuido
$S/validate.sh <caso> [--brief]
$S/gate.sh <caso> status          # onde parou, proxima fase, defasagens, custo
FROM=ataque HARNESS=<id> $S/debate.sh <caso>   # arquiva ataque em diante e refaz
```

Env: `HARNESS`, `MODEL` (vazio = padrao do harness), `MODEL_FALLBACK`, `MESA`, `ROTAS` (`debate-arch=claude debate-ux=codex:<modelo>`), `HARNESS_CMD` (com `HARNESS=custom`), `RETRIES=2`, `TIMEOUT=600` s por chamada, `BACKOFF=20` s, `PARALELO=6`, `MAX_CHAMADAS=0` (sem teto), `MIN_LINES=5`, `PAINEL` (vazio = meta.txt ou o brief; a base entra sempre), `FROM`, `RESEARCH=1`, `AGENDA=1`, `FACTCHECK=1`, `SPECS=1`, `REVIEW=1` (auditoria), `REPAIR=1`, `FRESH=0`, `OVERWRITE=0`.

## Modelos

No opencode, `modelos.conf` define 1 modelo gratuito por agent, de familias diferentes (paralelo sem disputar o mesmo limite, opinioes menos parecidas). Nos demais harnesses os agents herdam o modelo da sessao; edite a linha `model` do agent ou use `MESA` para diversificar. `$S/modelos.sh check` confere contra `opencode models`; `$S/modelos.sh aplicar` grava nos agents e troca modelo que saiu do catalogo pela reserva. Rodar `check` antes de um debate longo.
