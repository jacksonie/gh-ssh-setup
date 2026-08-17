# gh-key-setup-assist

Assistente de terminal, 100% interativo, que leva você do zero até autenticar no GitHub por SSH no Ubuntu 22.04 → 25.x.
Ele detecta o que já existe, pergunta apenas o que falta, espera você fazer a sua parte no navegador e testa o resultado no final.

*An interactive terminal assistant that takes you from zero to authenticating with GitHub over SSH on Ubuntu 22.04 → 25.x. Scroll down for English.*

---

## Como usar

```bash
chmod +x setup-github-keys.sh
./setup-github-keys.sh
```

Não rode com `sudo`: a chave iria parar em `/root/.ssh` e não serviria para o seu usuário. O script pede `sudo` sozinho, e só se precisar instalar algum pacote.

### Opções

| Flag | O que faz |
|---|---|
| `--lang pt-br \| en` | Define o idioma e pula o passo 1 |
| `--no-color` | Desliga as cores da saída |
| `-h`, `--help` | Mostra a ajuda |
| `--version` | Mostra a versão |
| `--selftest-i18n` | Verifica se as duas tabelas de tradução estão completas (uso em desenvolvimento) |

## Os 8 passos

1. **Idioma** — português ou inglês, antes de qualquer outra coisa.
2. **Sistema e programas** — confere a distribuição e se `git` e `openssh-client` estão instalados. Se faltar algo, mostra o comando `apt` exato e **só instala com o seu sim explícito**; se você recusar, ele mostra o comando para você rodar por fora e espera você voltar.
3. **Identidade do Git** — pergunta `user.name` e `user.email` apenas se ainda não estiverem definidos.
4. **Chaves existentes** — lista o que já existe em `~/.ssh` com tipo e fingerprint, e oferece reaproveitar ou criar uma nova.
5. **Gerar a chave** — cria um par `ed25519`. A passphrase é pedida pelo próprio `ssh-keygen`, nunca passada por argumento.
6. **ssh-agent, `~/.ssh/config` e `known_hosts`** — carrega a chave no agente, grava um bloco delimitado no config (com backup antes) e confere a fingerprint do servidor do GitHub contra a oficial antes de registrá-la.
7. **Cadastrar no GitHub** — mostra a chave pública, copia para a área de transferência quando possível, dá o passo a passo na interface do site (com a URL direta e o caminho pelos menus) e **espera você terminar**.
8. **Teste final** — roda `ssh -T git@github.com`, mostra com qual usuário você autenticou, e fecha com um checklist do que ficou pronto e os próximos comandos prontos para copiar. Se falhar, mostra o diagnóstico e oferece voltar ao passo 7 sem reiniciar tudo.

## O que ele **não** faz

- Chaves GPG e assinatura de commits
- GitHub CLI (`gh`) e tokens HTTPS
- Repositórios de terceiros no `apt`

## Detalhes que importam

- **Roda duas vezes sem estragar nada**: o bloco no `~/.ssh/config` fica entre marcadores e é substituído, não duplicado; o `known_hosts` não ganha linhas repetidas; nenhum arquivo é sobrescrito sem confirmação e backup.
- **Se você já tem um `Host github.com` próprio** no config, o script não o apaga: mostra o que encontrou e pergunta o que fazer.
- **`ssh -T git@github.com` sai com código 1 mesmo quando dá certo** (o GitHub aceita a chave mas não abre um shell). O script trata isso corretamente — é a causa nº 1 de falso negativo em scripts parecidos.
- Todo input vem de `/dev/tty`, então o assistente continua interativo mesmo executado através de um pipe.

---

# English

## Usage

```bash
chmod +x setup-github-keys.sh
./setup-github-keys.sh
```

Do not run it with `sudo`: the key would land in `/root/.ssh` and be useless for your user. The script asks for `sudo` on its own, and only if it needs to install a package.

### Options

| Flag | What it does |
|---|---|
| `--lang pt-br \| en` | Set the language and skip step 1 |
| `--no-color` | Turn off output colors |
| `-h`, `--help` | Show help |
| `--version` | Show version |
| `--selftest-i18n` | Check that both translation tables are complete (development use) |

## The 8 steps

1. **Language** — Portuguese or English, before anything else.
2. **System and programs** — checks the distribution and whether `git` and `openssh-client` are installed. If something is missing, it shows the exact `apt` command and **only installs with your explicit yes**; if you decline, it prints the command for you to run elsewhere and waits for you.
3. **Git identity** — asks for `user.name` and `user.email` only if they are not set yet.
4. **Existing keys** — lists what is already in `~/.ssh` with type and fingerprint, and offers to reuse one or create a new key.
5. **Generate the key** — creates an `ed25519` pair. The passphrase is asked by `ssh-keygen` itself, never passed as an argument.
6. **ssh-agent, `~/.ssh/config` and `known_hosts`** — loads the key into the agent, writes a delimited block into the config (backing it up first), and checks the GitHub server fingerprint against the official one before recording it.
7. **Register it on GitHub** — shows the public key, copies it to the clipboard when possible, walks you through the website UI (direct URL plus the menu path), and **waits for you to finish**.
8. **Final test** — runs `ssh -T git@github.com`, shows which user you authenticated as, and closes with a checklist plus copy-paste-ready next commands. On failure it shows a diagnosis and offers to go back to step 7 without restarting.

## What it does **not** do

- GPG keys and commit signing
- GitHub CLI (`gh`) and HTTPS tokens
- Third-party `apt` repositories

## Details that matter

- **Safe to run twice**: the `~/.ssh/config` block sits between markers and gets replaced, not duplicated; `known_hosts` gets no repeated lines; no file is overwritten without confirmation and a backup.
- **If you already have your own `Host github.com`** in the config, the script does not delete it: it shows what it found and asks what to do.
- **`ssh -T git@github.com` exits with code 1 even on success** (GitHub accepts the key but does not open a shell). The script handles this correctly — it is the number one false negative in similar scripts.
- All input comes from `/dev/tty`, so the assistant stays interactive even when executed through a pipe.
