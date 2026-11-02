# Regras do debate - vale para todo agent

Escrita: 1 ideia por linha, numero antes de adjetivo, tabela antes de paragrafo, sem enchimento, sem travessao longo.
Evidencia: numero cita `research.md Rn`, `research-check.md` ou mostra a conta. Sem isso, e opiniao e o juiz zera.

## Proposta
Formato do teu papel, no limite de linhas do teu papel.

## Ataque (max 25 linhas)
1 a 3 vetos, no maximo 1 por rival, os de maior impacto. Por veto:

```
### Veto contra <agent>
- Citacao: "<trecho literal>" (proposals/<agent>.md:<linha>)
- Problema: <o que quebra, com numero>
- Evidencia: <research.md Rn | conta | heuristica>
- Troca: <proposta concreta>
```

Fecha com `## Concessao` (1 linha: agent e onde ele tem razao). Sem concessao, o juiz descarta a critica.

## Replica (max 35 linhas)
- `## Aceito`: cortes que voce aceita, 1 linha cada
- `## Refuto`: max 1 veto, com numero e evidencia nova (repetir defesa e descartado)
- `## Concessao`: mantida da fase anterior
- `## Proposta revisada`: so o delta, nas secoes do teu formato

## Execucao
- Task com `escreve: <arquivo>`: grava o texto completo nesse arquivo (e so nele) e responde so `OK <arquivo> <n linhas>`, ou `FALHA <motivo>`. Sem `escreve:`: responde com o texto completo.
- Caminhos relativos sao relativos a `caso:`.
- Fato que research.md nao cobre: ate 2 Tasks para `debate-scout` no mesmo turno, 1 pergunta cada, e cita a URL que ele devolver. Nao delega opiniao.
