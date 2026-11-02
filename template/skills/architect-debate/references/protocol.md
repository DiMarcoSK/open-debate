# Protocolo do debate - estado e gates

## Estado

```text
cases/<slug>/
  idea.md  meta.txt  brief.md  constitution.md
  regras-debate.md  visual-contract.md  *-template.md
  research.md                  fase 1, debate-research
  agenda.md                    fase 1b, debate-judge: decisoes em disputa
  proposals/<agent>.md         fase 2
  critiques/<agent>.md         fase 3
  research-check.md            fase 4, fact-check
  proposals/<agent>-r2.md      fase 5
  decision.md  adr/NNNN-*.md   fase 6
  SDD.md  auditoria.md         fase 6, debate-judge e debate-auditor
  style-tile.html tokens.json tokens.css   gerados do TOKENS do SDD (DTCG)
  specs/<nn>-<slug>/{spec,plan,tasks}.md  checklists/requirements-<nn>-<slug>.md   fase 7
  backlog/design.md  backlog/eng.md   fase 8, rascunhos por trilha
  BACKLOG.md  backlog.csv  backlog.json  backlog-gh.sh   fase 8, debate-pm + export
  raw/   json bruto, stderr, summary.log, metricas.tsv, arquivo/ (saidas trocadas por --from)
```

## Gates (gate.sh no modo sessao, debate.sh no CLI; reprovou = 1 reparo com o motivo, reprovou de novo = para)

| Fase | Gate |
|---|---|
| 0 intake | validate.sh: brief sem campo vazio |
| 1 pesquisa | >= 5 URLs distintas, >= 5 achados Rn com URL ou `nao verificado`, secao Lacunas |
| 1b agenda | 3-8 decisoes Dn, 2+ opcoes, dono no painel, driver |
| 2 proposta | concessao, posicao em cada Dn, id Rn existente, teto de linhas; arch: mermaid, ADR, capacidade; design: contraste, estados, lista banida; gcp: custo, IAM, budget; k8s: custo, rollback; sec: STRIDE, autorizacao, auditoria |
| 3 ataque | 1-3 vetos, nenhum contra si, citacao achada literalmente no arquivo citado, id Rn existente, concessao |
| 4 fact-check | nao bloqueia; falha vira aviso em research-check.md |
| 5 replica | so quem levou veto; nao bloqueia; falha cai para a proposta r1 |
| 6 decisao | pesos somam 100, conta de cada placar confere, todo Dn decidido, todo veto julgado, todo claim errado zerado, >= 3 ADRs MADR com Resultado, Opcoes e Confirmacao, indice de 3-6 specs, Dissenso |
| 6 SDD | secoes 0-8, mermaid, TOKENS com contraste e identico a decision.md, todo ADR citado, Vazio/Loading/Erro, lista banida, sem placeholder |
| 6 auditoria | Veredito; CORRIGIR traz linhas An e o juiz corrige so o que elas apontam; falha do provider nao bloqueia |
| 7 specs | EARS, ADR citado existe, toda US com task, sem placeholder, checklist |
| 8 trilhas | rascunho com 8+ itens e Aceite |
| 8 backlog | 15+ itens, 4+ fases, cada item com Aceite, origem, est P/M/G; deps existem e sem ciclo; toda tag de lapidacao.md, spec, task e ADR coberta; conta de capacidade confere e o plano cabe; DoD |

## Limites

- rounds 1-3 (1 = so proposta, 2 = +ataque e fact-check, 3 = +replica)
- painel 2-5 agents; juiz, pesquisador e auditor fora do painel
- resume por padrao: saida existente e reaproveitada; `FRESH=1` refaz tudo; `--from <fase>` arquiva a fase e as seguintes em raw/arquivo e refaz; `status` mostra a proxima fase e avisa quando uma saida e mais velha que a entrada
- proposta e ataque rodam em sala: diretorio so com o que o agent pode ler, sem saida de rival
- provider falhou: modo sessao repete o Task 1x e segue com painel >= 2; CLI espera com backoff em limite, usa `MODEL_FALLBACK` 1x em auth ou cota
- `PARALELO` limita chamadas simultaneas, `MAX_CHAMADAS` limita o run, 1 run por caso (raw/.lock)
- fase 7 no CLI: 1 chamada por item do indice de decision.md; `SPECS=0` deixa as specs para preenchimento manual
