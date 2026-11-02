# Changelog

## 0.1.0

Primeira versão como produto, extraída da skill `architect-debate` do opencode.

### Adicionado

- CLI `open-debate`: `init`, `update`, `uninstall`, `doctor`, `models`, `new`, `run`, `specs`, `gate`, `validate`, `backlog`, `tile`.
- Instalação global ou por projeto, com manifesto: não sobrescreve edições e faz backup com `--force`.
- Suíte sem rede nem LLM, com `opencode` falso percorrendo o protocolo inteiro.

### Alterado

- Caminhos dos scripts resolvidos na instalação. `modelos.sh` acha os agents a partir da própria skill.
- `debate.sh` exige `perl` explicitamente.

### Corrigido

- Permissão de bash do orquestrador: o padrão `*architect-debate/scripts/*` casava com qualquer comando contendo esse trecho. Agora só libera o caminho exato dos scripts.
- Gates de ADR reprovavam `Opções`, `Decisão` e `Confirmação` com acento.
- `## Pós-lançamento` com acento não era reconhecido no backlog: os itens caíam na fase anterior.
