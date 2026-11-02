# Decisao

## 1. Pesos
velocidade=40 custo=30 prazo=30

## 2. Placar

### D1 Monolito ou servicos

| Opcao | velocidade | custo | prazo | Total |
|---|---|---|---|---|
| Monolito | 4 | 4 | 5 | 430 |
| Servicos | 3 | 2 | 4 | 300 |

### D2 Direcao visual

| Opcao | velocidade | custo | prazo | Total |
|---|---|---|---|---|
| Densa | 5 | 3 | 3 | 380 |
| Leve | 3 | 3 | 3 | 300 |

### D3 Banco

| Opcao | velocidade | custo | prazo | Total |
|---|---|---|---|---|
| Cloud SQL | 4 | 4 | 4 | 400 |
| Firestore | 4 | 3 | 3 | 340 |

## 3. ADRs

## ADR-0001 Usar monolito modular

- Status: aceito

### Contexto e problema

Driver e numero.

### Opcoes consideradas

- A
- B

### Resultado da decisao

Escolhida: "A", porque 80 x 60.

### Consequencias

- Bom: simples

### Confirmacao

Teste no CI.

### Dissenso

nenhum

## ADR-0002 Usar Cloud Run

- Status: aceito

### Contexto e problema

Driver e numero.

### Opcoes consideradas

- A
- B

### Resultado da decisao

Escolhida: "A", porque 80 x 60.

### Consequencias

- Bom: simples

### Confirmacao

Teste no CI.

### Dissenso

nenhum

## ADR-0003 Usar Cloud SQL

- Status: aceito

### Contexto e problema

Driver e numero.

### Opcoes consideradas

- A
- B

### Resultado da decisao

Escolhida: "A", porque 80 x 60.

### Consequencias

- Bom: simples

### Confirmacao

Teste no CI.

### Dissenso

nenhum

## 7. Specs

`01 ingestao` - recebe alertas
`02 triagem` - fila de triagem
`03 relatorio` - relatorio diario

## 8. Dissenso

debate-k8s: portabilidade; reabre se > 10 servicos

## 9. Vetos

| Alvo | Veto | Resultado | Motivo |
|---|---|---|---|
| debate-gcp | budget | mantido | custo |
| debate-gcp | budget | mantido | custo |
| debate-design | budget | rejeitado | fora do papel |
| debate-arch | budget | rejeitado | fora do papel |
