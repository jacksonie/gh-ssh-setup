# gh-ssh-setup

A single Bash script that sets up SSH authentication with GitHub on Ubuntu, end to end: generates an Ed25519 key, configures `git`, wires up `ssh-agent` and `~/.ssh/config`, verifies GitHub's host fingerprint, walks you through adding the key on GitHub, and confirms the connection works — all through one interactive, bilingual (English/Portuguese) prompt flow.

No dependencies beyond `bash`, `git`, and OpenSSH, which the script will offer to install via `apt` if missing.

**Read this in:** English • [Português (Brasil)](#português-brasil)

---

## Quick start

```bash
curl -sSL https://raw.githubusercontent.com/jacksonie/gh-ssh-setup/master/setup-github-keys.sh \
  -o setup-github-keys.sh && chmod +x setup-github-keys.sh && ./setup-github-keys.sh
```

Or clone and run locally:

```bash
git clone https://github.com/jacksonie/gh-ssh-setup.git
cd gh-ssh-setup
chmod +x setup-github-keys.sh
./setup-github-keys.sh
```

## Usage

```bash
./setup-github-keys.sh [options]
```

| Option | Description |
|---|---|
| `--lang pt-br \| en` | Set the language and skip the language prompt |
| `--no-color` | Disable colored output |
| `--selftest-i18n` | Verify both translation tables have identical keys, then exit |
| `-h`, `--help` | Show help |
| `--version` | Show the script version |

## What the script does

The script walks through 8 steps, tracking your choices along the way for a final summary:

1. **Language** — choose English or Português, or skip via `--lang`.
2. **Dependency check** — confirms Ubuntu, Bash ≥ 4.3, and the presence of `git`, `ssh`, `ssh-keygen`, `ssh-agent`, `ssh-add`, `ssh-keyscan`; offers to install anything missing via `apt`.
3. **Git identity** — sets `git config --global user.name` and `user.email`. Suggests a `@users.noreply.github.com` address for commits you'd rather not attach a personal email to.
4. **Existing keys** — lists keys already in `~/.ssh/` so you can reuse one instead of generating a new one.
5. **Key generation** — creates an Ed25519 key pair at a path you choose (default `~/.ssh/id_ed25519_github`), with a custom comment and an optional passphrase. Existing files are backed up before being overwritten.
6. **Agent and config** — starts or reuses `ssh-agent`, loads the key, adds a `Host github.com` block to `~/.ssh/config` with `AddKeysToAgent yes`, and registers `github.com` in `~/.ssh/known_hosts` after checking its fingerprint.
7. **Add the key to GitHub** — prints the public key, copies it to the clipboard if available, opens `https://github.com/settings/ssh/new` in a browser when possible, and waits for confirmation.
8. **Verification** — runs `ssh -T git@github.com` and reports success with a full checklist, or offers retry and diagnostics on failure.

### Explicitly out of scope

- GPG keys or commit signing
- GitHub CLI (`gh`) setup
- HTTPS tokens or password-based authentication

## Security

Before trusting `github.com` as a known SSH host, the script checks the fingerprint it receives against GitHub's officially published values:

| Key type | Fingerprint |
|---|---|
| Ed25519 | `SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU` |
| ECDSA | `SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM` |
| RSA | `SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s` |

If the fingerprint doesn't match — which can happen behind a corporate proxy or during a MITM attack — the script refuses to add the host to `known_hosts` and falls back to `StrictHostKeyChecking=yes` for the final test.

Reference: [GitHub's SSH key fingerprints](https://docs.github.com/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)

Other safeguards:

- Sets correct permissions (`~/.ssh` at `700`, private keys at `600`)
- Never stores or transmits passwords or passphrases — all input stays interactive
- Backs up any file it's about to overwrite
- Warns if run as `root` (the key would land in `/root/.ssh`, not your user's)

## Requirements

| Requirement | Notes |
|---|---|
| Bash | 4.3+ |
| OS | Ubuntu 22.04–25.x (other Debian-based distros likely work) |
| Git | Any recent version |
| OpenSSH client | `ssh`, `ssh-keygen`, `ssh-agent`, `ssh-add`, `ssh-keyscan` |

Missing packages are detected automatically and can be installed via `apt` from within the script.

## After setup

Clone a repository over SSH:

```bash
git clone git@github.com:username/repository.git
```

Switch an existing HTTPS remote to SSH:

```bash
cd your-repository
git remote set-url origin git@github.com:username/repository.git
```

Review your registered keys (and last-used dates) at [github.com/settings/keys](https://github.com/settings/keys).

## Troubleshooting

**`Permission denied (publickey)`**
The public key wasn't pasted into GitHub, or was pasted incomplete. Go to [github.com/settings/ssh/new](https://github.com/settings/ssh/new) and paste the entire key — starting with `ssh-ed25519` — on a single line. Step 8 offers a retry.

**ssh-agent doesn't persist between terminal sessions**
Expected: the script starts an agent for the current session only. Persistence comes from `AddKeysToAgent yes` in `~/.ssh/config`, which makes `ssh` load the key on demand regardless of agent state.

**Ran with `sudo`**
The key was generated under `/root/.ssh`, not your regular user's home. Re-run without `sudo`.

**Distro isn't Ubuntu**
Ubuntu derivatives (Linux Mint, Pop!_OS, Zorin) generally work; other distros may need dependencies installed manually first.

## Contributing

Issues and pull requests are welcome — open one at [github.com/jacksonie/gh-ssh-setup/issues](https://github.com/jacksonie/gh-ssh-setup/issues).

## License

[MIT](LICENSE)

---

## Português (Brasil)

Script Bash interativo que configura autenticação SSH com o GitHub no Ubuntu em um único comando: gera uma chave Ed25519, configura o `git`, ajusta `ssh-agent` e `~/.ssh/config`, valida o fingerprint do GitHub, guia a colagem da chave no navegador e testa a conexão — tudo em português ou inglês, sem dependências além de `bash`, `git` e OpenSSH.

### Uso

```bash
./setup-github-keys.sh --lang pt-br
```

O script guia você por 8 passos: seleção de idioma, checagem de dependências, configuração da identidade Git, reaproveitamento ou geração de chave, configuração de `ssh-agent`/`known_hosts`, colagem da chave no GitHub e teste final de autenticação. Veja a seção em inglês acima para o detalhamento completo de cada passo, as opções de linha de comando (`--lang`, `--no-color`, `--selftest-i18n`, `--version`) e a tabela de fingerprints oficiais usada na validação de segurança.

### Depois de configurar

```bash
# Clonar um repositório por SSH
git clone git@github.com:usuario/repositorio.git

# Converter um repositório existente de HTTPS para SSH
git remote set-url origin git@github.com:usuario/repositorio.git
```

### Licença

[MIT](LICENSE)
