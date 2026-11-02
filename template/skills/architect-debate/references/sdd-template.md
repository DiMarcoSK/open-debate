# SDD - <nome do produto>

## 0. Resumo

5 linhas para quem so le isto: problema, decisao principal, custo/mes, prazo, maior risco.

## 1. Contexto e objetivo

Objetivo em 1 frase, quem usa, problema que some, metrica de sucesso em 90 dias. Nao-objetivos em 1 linha cada.

## 2. Restricoes, premissas e drivers

Prazo, time, custo teto, carga, dados sensiveis. Premissa nao confirmada leva `[assumido, dono <nome>, <semana>]`.
Drivers de qualidade: 3 cenarios `estimulo -> resposta -> medida`. Evidencia: research.md (ids citados no texto).

## 3. Decisoes

| ADR | Decisao | Alternativa rejeitada | Driver |

1 linha por ADR de adr/, sem paragrafo.

## 4. Arquitetura

C4 contexto e container em bloco mermaid. Capacidade com a conta (rps medio, pico, dado/ano).
Modulos e contratos versionados. Dados: dono por entidade, consistencia, backup, RPO/RTO.
Falhas por path: timeout, retry com teto, DLQ, chave de idempotencia. Seguranca: STRIDE top 3.
Cada servico com req/dia e custo/mes.

## 5. Experiencia e direcao visual (gate em visual-contract.md)

JTBD e tarefa critica com meta de passos/segundos. Conceito: <metafora>, convencao mantida e quebrada.
Bloco TOKENS literal com razoes de contraste. Escala de tipo, espaco, raio, elevacao, movimento.
Telas-chave em wireframe ASCII. Estados escritos: Vazio, Loading, Erro, Sucesso, Parcial.
Momento assinatura com custo. Lista banida confirmada ausente ou override escrito por item.

## 6. Cortes e backlog

O que ficou fora do MVP e por que, 1 linha cada.

## 7. Testes de aceitacao, SLO e fitness functions

1 teste por item mantido, verbo + condicao + resultado. SLO do fluxo principal. Fitness functions no CI.

## 8. Riscos, dissenso e perguntas abertas

Registro de riscos: | Risco | Prob (B/M/A) | Impacto (B/M/A) | Mitigacao | Dono |, max 5. Dissenso registrado nos ADRs. Max 3 perguntas abertas.
