# GitHub SSH Setup Assistant

🔐 **Interactive SSH key setup automation for GitHub** — Bash script that handles GitHub SSH authentication in one command.

A complete, user-friendly Bash script to configure SSH authentication with GitHub on Ubuntu. Supports bilingual interface (English/Portuguese), built-in security validation, and automatic dependency installation.

**Available in:** English • [Português (Brasil)](#português--brasil)

---

## 📋 Features

✅ **Ed25519 SSH key generation** — modern and secure algorithm  
✅ **Automatic git config setup** — name and email  
✅ **ssh-agent management** — persistent session with `AddKeysToAgent`  
✅ **Fingerprint validation** — verifies legitimate GitHub identity  
✅ **Step-by-step guidance** — safely paste public key into GitHub  
✅ **Authentication testing** — validates SSH access at the end  
✅ **Bilingual interface** — English and Portuguese (Brazil)  
✅ **Zero extra dependencies** — just `bash`, `git`, and `openssh`  

---

## 🚀 Quick Start

### 1. Download and run

```bash
curl -sSL https://raw.githubusercontent.com/jacksonie/gh-ssh-setup/master/setup-github-keys.sh \
  -o setup-github-keys.sh && chmod +x setup-github-keys.sh && ./setup-github-keys.sh
```

Or clone the repository:

```bash
git clone https://github.com/jacksonie/gh-ssh-setup.git
cd gh-ssh-setup
chmod +x setup-github-keys.sh
./setup-github-keys.sh
```

### 2. Follow interactive prompts

The script walks you through 8 simple steps:

1. **Choose language** — English or Português
2. **Check dependencies** — auto-installs `git`, `openssh-client` if needed
3. **Configure Git identity** — your name and email
4. **Existing keys** — reuse old keys or create new
5. **Generate SSH key** — Ed25519 with custom comment
6. **Setup ssh-agent** — loads key in memory, adjusts `~/.ssh/config`
7. **Paste on GitHub** — copies key and guides you through the browser
8. **Final test** — validates SSH authentication success

---

## 📖 Command-Line Options

```bash
./setup-github-keys.sh [options]
```

| Option | Description |
|--------|-------------|
| `--lang pt-br` | Set language to Portuguese (Brazil) |
| `--lang en` | Set language to English |
| `--no-color` | Disable colored output |
| `-h, --help` | Show help message |
| `--version` | Show version |

### Examples

```bash
# Force English, skip language selection
./setup-github-keys.sh --lang en

# Run in Portuguese without colors
./setup-github-keys.sh --lang pt-br --no-color

# Show version
./setup-github-keys.sh --version
```

---

## ✅ What It Does

### Creates & Configures

- ✅ Generates an **Ed25519 SSH key pair** (modern, secure, smaller than RSA 4096)
- ✅ Configures `git config --global user.name` and `user.email`
- ✅ Adds a `Host github.com` block to `~/.ssh/config`
- ✅ Loads the key into **ssh-agent** with `AddKeysToAgent yes` (persistence)
- ✅ Registers GitHub in `~/.ssh/known_hosts` with fingerprint validation
- ✅ Tests SSH authentication with `ssh -T git@github.com`

### Protects

- 🔒 Correct permissions: `~/.ssh` at `700`, private keys at `600`
- 🔒 Never stores passwords/passphrases — all interactive
- 🔒 Validates official GitHub fingerprints against MITM attacks
- 🔒 Creates backups before overwriting existing files
- 🔒 Warns clearly if run as `root`

### Does NOT Handle

- ❌ **Not** GPG key management or commit signing
- ❌ **Not** GitHub CLI (`gh`) setup
- ❌ **Not** HTTPS tokens or password authentication

---

## 🛠️ Requirements

| Requirement | Minimum Version |
|-------------|------------------|
| **Bash** | 4.3+ |
| **Ubuntu** | 22.04 to 25.x (other Linux distros may work) |
| **Git** | Any recent version |
| **OpenSSH** | Standard Ubuntu client + server |

The script automatically checks and offers to install via `apt` if anything is missing.

---

## 📝 Detailed 8-Step Flow

### Step 1: Language Selection
Choose between English or Portuguese (Brazil). Can be skipped with `--lang`.

### Step 2: System Check
Verifies Ubuntu, Bash version, and presence of `git`, `ssh`, `ssh-keygen`, `ssh-agent`, `ssh-add`, `ssh-keyscan`. Offers automatic installation.

### Step 3: Git Identity
Configures global `user.name` and `user.email`. Suggests using `@users.noreply.github.com` address for privacy in public commits.

### Step 4: Existing Keys
Lists SSH keys already in `~/.ssh/`. You can:
- Create a new key (recommended)
- Reuse an existing key

### Step 5: Generate SSH Key
If creating new:
- Choose key file path (default: `~/.ssh/id_ed25519_github`)
- Replace existing file (creates backup first)
- Add custom comment for identification
- Choose whether to use a passphrase (recommended for security)
- ssh-keygen generates the key pair

### Step 6: Agent + Config Setup
- Start/reuse ssh-agent
- Load key into agent (prompts for passphrase if set)
- Create `Host github.com` block in `~/.ssh/config`
- Register github.com in `~/.ssh/known_hosts` with fingerprint validation

### Step 7: Paste Key on GitHub
- Displays public key (highlighted, with clipboard copy option)
- Auto-opens browser if GUI available
- Step-by-step guide to paste at https://github.com/settings/ssh/new
- Waits for your confirmation

### Step 8: Final Test
- Tests `ssh -T git@github.com`
- On success: shows username, full checklist summary
- On failure: offers retry, diagnostics, or config review

---

## 🔍 Security Validation

The script validates GitHub's identity by checking official fingerprints:

- **Ed25519:** `SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU`
- **ECDSA:** `SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM`
- **RSA:** `SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s`

If fingerprints don't match (corporate proxy, MITM), the script **doesn't add** to `known_hosts` and uses `StrictHostKeyChecking=yes` for testing.

Reference: https://docs.github.com/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints

---

## 🎯 Next Steps After Completion

Once the script finishes successfully:

### Clone a repository

```bash
git clone git@github.com:username/repository.git
```

### Switch existing HTTPS repository to SSH

```bash
cd your-repository
git remote set-url origin git@github.com:username/repository.git
```

### View your registered SSH keys

https://github.com/settings/keys (shows last-used date)

---

## 🐛 Troubleshooting

### "Permission denied (publickey)"
**Most common cause:** Key wasn't pasted into GitHub, or pasted incomplete.
- Go to https://github.com/settings/ssh/new
- Paste the **entire** key, starting with `ssh-ed25519`, on **one single line**
- The script offers a retry option in step 8

### "ssh-agent doesn't persist between sessions"
**This is normal!** The script creates a temporary agent for the current session only. Real persistence comes from `AddKeysToAgent yes` in `~/.ssh/config` — ssh will automatically load the key when needed.

### "Running as root"
**Warning!** If you use `sudo ./setup-github-keys.sh`, the key is created in `/root/.ssh`, not your regular user's `~/.ssh`.
- **Solution:** Run without `sudo`: `./setup-github-keys.sh`

### "Distro is not Ubuntu"
Ubuntu derivatives (Linux Mint, Pop!_OS, Zorin) usually work. Other distros may need manual package installation.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

You're free to use, modify, and distribute this script.

---

## 🤝 Contributing

Found a bug? Have an improvement idea?

1. Open an [Issue](https://github.com/jacksonie/gh-ssh-setup/issues)
2. Describe the problem or suggestion
3. Pull requests are welcome!

---

## 📞 Support

For general GitHub SSH questions:
- https://docs.github.com/authentication/connecting-to-github-with-ssh

For issues with this script:
- Open an issue on this repository

---

## 📊 Repository Structure

```
gh-ssh-setup/
├── setup-github-keys.sh     # Main script
├── README.md                # This file
└── LICENSE                  # MIT License
```

---

## Português — Brasil

### O que é?

Um script Bash interativo que configura autenticação SSH com o GitHub no Ubuntu em um único comando. Suporta português e inglês, validação de segurança integrada e instalação automática de dependências.

### Como usar?

```bash
# Executar com português (Brasil)
./setup-github-keys.sh --lang pt-br
```

O script o guiará por 8 passos simples para:
1. Gerar uma chave SSH Ed25519
2. Configurar identidade Git (nome e e-mail)
3. Configurar ssh-agent e `~/.ssh/config`
4. Validar a identidade do GitHub
5. Testar autenticação SSH

### Características

✅ Geração de chaves SSH Ed25519  
✅ Configuração automática de `git config`  
✅ Gerenciamento de ssh-agent com persistência  
✅ Validação de fingerprint do GitHub  
✅ Guia passo-a-passo interativo  
✅ Teste de autenticação final  
✅ Suporte bilíngue (português/inglês)  
✅ Sem dependências extras  

### Próximos passos

```bash
# Clonar um repositório por SSH
git clone git@github.com:usuario/repositorio.git

# Converter repositório de HTTPS para SSH
git remote set-url origin git@github.com:usuario/repositorio.git
```

Para mais detalhes em português, execute:
```bash
./setup-github-keys.sh --lang pt-br
```

---

**Version:** 1.0.0  
**Maintained by:** Jackson Souza  
**License:** MIT  
**Last updated:** 2024

Ready to go! 🚀