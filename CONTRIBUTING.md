# Contribuindo

## Estrutura

```text
bin/open-debate   CLI: despacha comandos
lib/install.sh    init, update, uninstall, doctor, models
template/         o que `init` copia para o opencode
  agents/         orquestrador, especialistas, juiz, pesquisa e PM
  commands/       comando /debate
  skills/architect-debate/
    SKILL.md      protocolo do modo sessao
    references/   templates e regras copiados para cada caso
    scripts/      gates e modo CLI
test/             suite, fixtures e opencode falso
```

`{{SCRIPTS}}` e `{{SCRIPTS_ABS}}` nos templates são resolvidos na instalação.

## Regras

- Shell POSIX, sem dependências além de `jq`, `awk` e `perl`. O `sh` do Linux é dash e o awk pode ser mawk: nada de bashismo nem gawkismo.
- Gate é determinístico. Se uma regra importa, ela vira checagem em `gates.sh`, não só instrução de prompt.
- Bug em gate ganha fixture e teste em `test/run.sh`.
- Em `test/run.sh`, use `nao` em vez de `! cmd` e 1 comando por linha: `set -e` ignora os outros formatos.
- Nunca inclua caminho local, provider privado ou chave em `template/`. A suíte reprova.

## Mudanças de formato

Agents e `gates.sh` são um contrato: os gates leem palavras dos templates (`Concessao`, `Veto`, `Lacunas`). Ao mudar um template, ajuste o gate, a fixture e o agent juntos.

## Testes

```sh
npm test
open-debate doctor    # confere os modelos contra o catalogo real
```

A CI roda em Ubuntu e macOS. Mudança em prompt só se valida com um debate real: registre no PR o modelo usado e o resultado.
