# Lapidacao - o que separa "funciona" de "produto lapidado"

Cada tag vira ao menos 1 item no BACKLOG.md (`#tag` no bloco `{...}`); gate.sh reprova tag ausente.
Basico entra no DoD de todo item (estados, foco, copy real). A fase Lapidacao audita e refina o conjunto.

| Tag | Lapidado quando (criterio medivel) |
|---|---|
| design-system | tokens.css e a unica fonte de cor/tipo/espaco no codigo; componentes base (botao, input, select, tabela, badge, dialog, toast, skeleton) com hover, foco, desabilitado, erro; catalogo vivo (Storybook ou rota /ui) |
| estados | toda tela com Vazio, Loading (skeleton no formato do conteudo), Erro, Sucesso e Parcial, com a copy do SDD |
| a11y | WCAG 2.2 AA: axe sem violacao serious/critical, fluxo principal so por teclado, leitor de tela (VoiceOver e NVDA) no fluxo principal, foco visivel, alvo 24 px |
| responsivo | 360, 768, 1280 e 1920 px sem scroll horizontal; tabela densa vira lista em 360 |
| motion | transicao de estado 120-240 ms com o easing dos tokens; prefers-reduced-motion respeitado |
| copy | microcopy revisada por tela (verbo, numero, tom), erro diz o que fazer, glossario pt-BR sem jargao |
| perf | Core Web Vitals p75: LCP < 2.5 s, INP < 200 ms, CLS < 0.1; orcamento de JS por rota; p95 de API do SDD medido |
| onboarding | primeira execucao com dado de exemplo; tempo ate o primeiro valor medido e abaixo da meta do SDD |
| assinatura | momento assinatura do SDD implementado e revisado pelo design |
| qa-visual | regressao visual por screenshot (Playwright) nas telas-chave; design QA por tela contra style-tile.html |
| observabilidade | SLO do fluxo principal, metricas RED, log com trace id, alerta com dono |
| seguranca | mitigacoes STRIDE do SDD, authz testado por papel, segredos em cofre, CSP/HSTS, dependencias escaneadas no CI |
| dados | backup com restore testado, migracao com rollback testado, RPO/RTO verificados |
| analytics | eventos de produto medem a metrica de sucesso de 90 dias (funil do fluxo principal) |
| docs | README de setup em 1 comando, runbook por servico, ADRs atualizados, changelog |
| lancamento | beta com usuarios reais, canal de feedback, checklist de go-live, rollback ensaiado |
