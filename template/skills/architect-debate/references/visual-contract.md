# Contrato visual - verificado por validate.sh e renderizado por style-tile.sh

## 1. Bloco TOKENS (formato exato, 1 chave por linha, comentario so depois de //; exportado como W3C DTCG em tokens.json)

```
TOKENS
papel #F2EFE8        // fundo de toda tela
superficie #FFFFFF   // cartao, tabela, input
tinta #16181D        // texto principal
tinta-2 #4A4F5A      // texto secundario
linha #D9D4C7        // bordas e divisores
acento #0B5FFF       // so acao primaria e foco
acento-tinta #FFFFFF // texto sobre acento
ok #1F6B3A
warn #9A5B00
crit #A3231B
display Instrument Serif
body Inter
mono JetBrains Mono
escala 1.25 base 16
espaco 4
raio 6
movimento 180ms cubic-bezier(.2,.8,.2,1)
FIM
```

Os valores acima mostram o formato, nao sao paleta padrao: cada projeto deriva a sua do conceito.
Hex com 6 digitos. Fontes do Google Fonts. Modo escuro opcional: `papel-escuro`, `tinta-escuro`, `acento-escuro`.

## 2. Gates de contraste (WCAG 2.2, validate.sh calcula)

| Par | Minimo |
|---|---|
| tinta / papel | 7.0 |
| tinta / superficie | 7.0 |
| tinta-2 / papel | 4.5 |
| acento-tinta / acento | 4.5 |
| acento / papel | 3.0 |
| ok, warn, crit / papel | 4.5 |
| tinta-escuro / papel-escuro | 7.0 (se existir) |

## 3. Sistema

Escala de tipo modular (ratio declarado), numerais tabulares em dados, 1 estrategia de elevacao,
movimento 120-240 ms so para mudanca de estado, com fallback em prefers-reduced-motion.
Foco visivel 2 px, alvo 24 px (44 px toque), cor nunca e o unico sinal.

## 4. Copy e estados (texto real com numero)

- Vazio: o que ha (zero), filtros ativos, proximo passo.
- Loading: skeleton com N linhas no formato do conteudo, sem spinner solto.
- Erro: o que houve, por que, o que fazer, entrada do usuario preservada.
- Sucesso: o que mudou e onde ver.
- Parcial: quanto chegou (N de M) e o que falta.

SDD sem as palavras Vazio, Loading e Erro reprova no gate.

## 5. Lista banida (veto vinculante, override so com ganho do usuario escrito)

gradiente roxo-azul, glass cards sobre gradiente, 3 colunas genericas com icones de linha,
lorem ipsum, sorrisos stock, ilustracao corporate memphis, emoji como icone de interface,
parede de texto centralizada, carousel de onboarding, dashboard de KPIs sem acao,
modal para tudo, toast como unico aviso de erro, neon em fundo escuro sem motivo,
paleta warm paper + terracota reaproveitada sem derivar do conceito.

## 6. Por spec

Toda spec com UI declara na secao 6: telas, tokens e componentes usados, estados escritos e criterio de acessibilidade.
Spec sem UI declara `sem UI` com motivo em 1 linha.
