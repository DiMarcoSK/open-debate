# Backlog - Fixture

Capacidade: 2 x 8 x 5 x 0.7 = 56 dias uteis; backlog soma 29 dias; cabe.

## Fase 0 - Fundacao (semana 1)

- [ ] B01 [P] Provisionar staging com deploy. Aceite: deploy em 5 min (ADR-0001) {E01, est M, #docs}
- [ ] B02 Publicar segredo em cofre. Aceite: 0 segredo no repo (ADR-0002) {E01, est P, dep B01, #seguranca}
- [ ] B03 Restaurar backup de ponta a ponta. Aceite: restore em 1 h (ADR-0003) {E01, est M, dep B01, #dados}

## Fase 1 - Esqueleto andante (semana 2)

- [ ] B04 [P] Receber alerta ate a tela. Aceite: 1 alerta em 2 s (spec 01:T001) {E01, est G, dep B02 B03, #observabilidade}
- [ ] B05 Triar alerta da fila. Aceite: triagem em 30 s (spec 02:T001) {E01, est G, dep B04, #estados}
- [ ] B06 Emitir relatorio diario. Aceite: 1 PDF por dia (spec 03:T001) {E01, est M, dep B05, #analytics}

## Fase 2 - Lapidacao (semana 3)

- [ ] B07 Auditar design-system nas telas. Aceite: 0 achados em 3 telas (SDD-5) {E02, est P, dep B06, #design-system}
- [ ] B08 Auditar a11y nas telas. Aceite: 0 achados em 3 telas (SDD-5) {E02, est P, dep B06, #a11y}
- [ ] B09 Auditar responsivo nas telas. Aceite: 0 achados em 3 telas (SDD-5) {E02, est P, dep B06, #responsivo}
- [ ] B10 Auditar motion nas telas. Aceite: 0 achados em 3 telas (SDD-5) {E02, est P, dep B06, #motion}
- [ ] B11 Auditar copy nas telas. Aceite: 0 achados em 3 telas (SDD-5) {E02, est P, dep B06, #copy}
- [ ] B12 Auditar perf nas telas. Aceite: 0 achados em 3 telas (SDD-5) {E02, est P, dep B06, #perf}
- [ ] B13 Auditar onboarding nas telas. Aceite: 0 achados em 3 telas (SDD-5) {E02, est P, dep B06, #onboarding}
- [ ] B14 Auditar assinatura nas telas. Aceite: 0 achados em 3 telas (SDD-5) {E02, est P, dep B06, #assinatura}
- [ ] B15 Auditar qa-visual nas telas. Aceite: 0 achados em 3 telas (SDD-5) {E02, est P, dep B06, #qa-visual}

## Fase 3 - Lancamento (semana 4)

- [ ] B16 [P] Abrir beta com usuarios. Aceite: 5 usuarios ativos (SDD-1) {E03, est M, dep B15, #lancamento}

## Pós-lançamento

- [ ] B17 Exportar para BI. Aceite: 1 export por dia (SDD-6) {E03, est P, dep B16, #docs}

## Definition of Done

- aceite verificado
