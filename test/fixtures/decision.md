# Decisao

## 1. Pesos
velocidade=40 custo=30 prazo=30

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
