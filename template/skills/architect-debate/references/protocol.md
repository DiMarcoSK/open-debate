# Protocolo do debate - estado e gates

## Estado

```text
cases/<slug>/
  idea.md  meta.txt  brief.md  constitution.md
  regras-debate.md  visual-contract.md  research-template.md  adr-template.md  sdd-template.md
  research.md                  fase 1, debate-research
  proposals/<agent>.md         fase 2
  critiques/<agent>.md         fase 3
  research-check.md            fase 4, fact-check
  proposals/<agent>-r2.md      fase 5
  decision.md  adr/NNNN-*.md   fase 6
  SDD.md                       fase 6
  style-tile.html tokens.json tokens.css   gerados do TOKENS do SDD (DTCG)
  specs/<nn>-<slug>/{spec,plan,tasks}.md  checklists/requirements-<nn>-<slug>.md   fase 7
  backlog/design.md  backlog/eng.md   fase 8, rascunhos por trilha
  BACKLOG.md  backlog.csv  backlog.json  backlog-gh.sh   fase 8, debate-pm + export
  raw/   json bruto, stderr, summary.log
```

## Gates (gate.sh no modo sessao, debate.sh no CLI; reprovou = 1 reparo com o motivo, reprovou de novo = para)

| Fase | Gate |
|---|---|
| 0 intake | validate.sh: brief sem campo vazio |
| 1 pesquisa | >= 5 URLs distintas, secao Lacunas |
| 2 proposta | nao vazia, concessao; arch com mermaid e ADR; design com TOKENS que passa contraste |
| 3 ataque | veto, citacao entre aspas, concessao |
| 4 fact-check | nao bloqueia; falha vira aviso em research-check.md |
| 5 replica | nao bloqueia; falha cai para a proposta r1 |
| 6 decisao | >= 3 ADRs MADR com Resultado, Opcoes e Confirmacao, indice de 3-6 specs, Dissenso |
| 6 SDD | secoes 0-8, mermaid, TOKENS com contraste, Vazio/Loading/Erro, sem placeholder |
| 7 specs | validate.sh zera |
| 8 trilhas | rascunho com 8+ itens e Aceite |
| 8 backlog | 15+ itens, 4+ fases, cada item com Aceite, origem, est P/M/G; deps existem e sem ciclo; toda tag de lapidacao.md, spec e ADR coberta; DoD e capacidade |

## Limites

- rounds 1-3 (1 = so proposta, 2 = +ataque e fact-check, 3 = +replica)
- painel 2-5 agents; juiz e pesquisador fora do painel
- resume por padrao: saida existente e reaproveitada; `FRESH=1` refaz
- provider falhou: modo sessao repete o Task 1x e segue com painel >= 2; CLI usa `MODEL_FALLBACK` 1x
- fase 7 no CLI: 1 chamada por item do indice de decision.md; `SPECS=0` deixa as specs para preenchimento manual
