# Backlog - <produto>

Fonte: SDD.md, decision.md, adr/, specs/, lapidacao.md. `[P]` bloqueia a fase seguinte. Estimativa P (ate 1 dia), M (2-3 dias), G (4-5 dias); maior que G quebra em 2.
Capacidade: <devs> x <semanas> x 5 x 0.7 = <N> dias uteis; backlog soma <M> dias; <cabe | corta para Pos-lancamento: B..>.
A linha acima e conferida pelo gate: M e a soma dos itens antes de Pos-lancamento (P=1, M=2.5, G=4.5) e precisa caber em N.

## Formato do item (gate.sh le)

`- [ ] Bnn [P] <acao com verbo, fatia vertical>. Aceite: <criterio testavel com numero> (spec NN:Txxx,Tyyy | spec NN:Txxx-Tyyy | ADR-NNNN | SDD-n) {Enn, est P|M|G, dep Bxx Byy, #tag #tag}`

Status de execucao vai depois, entre colchetes: `[x]` + `[verificado AAAA-MM-DD: como]`.

## Epicos

| Epico | Nome | Specs | Valor para o usuario |
|---|---|---|---|

## Fase 0 - Fundacao (semana n)

Meta: <1 linha>. Demo: <o que se mostra no fim da fase>.

## Fase 1 - Esqueleto andante (semanas n-m)

Fluxo principal ponta a ponta, real e em ambiente de staging, sem polimento.

## Fase 2..N - <spec> (semanas n-m, spec NN)

## Fase N+1 - Lapidacao (semanas n-m)

Auditoria e refino das tags de lapidacao.md em todas as telas.

## Fase N+2 - Lancamento (semanas n-m)

## Pos-lancamento

Cortes do SDD secao 6 e P2/P3 das specs, sem `[P]`.

## Caminho critico

<Bxx -> Byy -> ...> (gerado por backlog-export.sh)

## Definition of Ready

- criterio de aceite com numero, origem citada, dependencias resolvidas ou listadas, estimativa ate G, design da tela pronto quando ha UI

## Definition of Done

- aceite verificado e anotado, teste automatizado no CI, estados Vazio/Loading/Erro e foco por teclado na tela tocada, copy final, sem erro novo no log, docs/ADR atualizados
