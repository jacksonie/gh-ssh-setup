# gh-key-setup-assist

🔐 **Assistente interativo de configuração de chaves SSH para o GitHub** | **Interactive GitHub SSH key setup assistant**

Um script Bash completo e amigável para configurar autenticação SSH com o GitHub no Ubuntu, com suporte bilíngue (português/inglês) e validação de segurança integrada.

---

## 📋 Características

✅ **Geração de chaves SSH Ed25519** — algoritmo moderno e seguro  
✅ **Configuração automática de `git config`** — nome e e-mail  
✅ **Gerenciamento de ssh-agent** — sessão persistente com `AddKeysToAgent`  
✅ **Validação de fingerprint** — verifica a identidade legítima do GitHub  
✅ **Guia passo-a-passo** — cola a chave pública no GitHub de forma segura  
✅ **Teste de autenticação** — valida acesso SSH no final  
✅ **Suporte bilíngue** — português (Brasil) e inglês  
✅ **Sem dependências extras** — apenas `bash`, `git` e `openssh`  

---

## 🚀 Início Rápido

### 1. Baixe e execute

```bash
curl -sSL https://raw.githubusercontent.com/jacksonie/gh-key-setup-assist/master/setup-github-keys.sh \
  -o setup-github-keys.sh && chmod +x setup-github-keys.sh && ./setup-github-keys.sh
```

Ou clone o repositório:

```bash
git clone https://github.com/jacksonie/gh-key-setup-assist.git
cd gh-key-setup-assist
chmod +x setup-github-keys.sh
./setup-github-keys.sh
```

### 2. Siga as instruções interativas

O script guiará você por 8 passos simples:

1. **Escolher idioma** — Português ou English
2. **Verificar dependências** — instala `git`, `openssh-client` se necessário
3. **Configurar identidade Git** — seu nome e e-mail
4. **Chaves existentes** — reusar chaves antigas ou criar nova
5. **Gerar chave SSH** — Ed25519 com comentário personalizado
6. **Configurar ssh-agent** — carrega a chave na memória, ajusta `~/.ssh/config`
7. **Colar no GitHub** — copia a chave pública e guia pelo navegador
8. **Teste final** — valida autenticação SSH com sucesso

---

## 📖 Opções de Linha de Comando

```bash
./setup-github-keys.sh [opções]
```

| Opção | Descrição |
|-------|----------|
| `--lang pt-br` | Define idioma para português (Brasil) |
| `--lang en` | Define idioma para inglês |
| `--no-color` | Desativa cores da saída |
| `-h, --help` | Mostra ajuda |
| `--version` | Mostra versão |

### Exemplos

```bash
# Pula a tela de idioma direto para português
./setup-github-keys.sh --lang pt-br

# Executa em inglês sem cores
./setup-github-keys.sh --lang en --no-color

# Mostra versão do script
./setup-github-keys.sh --version
```

---

## ✅ O que o Script Faz

### Cria/Configura

- ✅ Gera uma chave SSH **Ed25519** (moderna, segura, menor que RSA 4096)
- ✅ Configura `git config --global user.name` e `user.email`
- ✅ Adiciona um bloco `Host github.com` em `~/.ssh/config`
- ✅ Carrega a chave no **ssh-agent** com `AddKeysToAgent yes` (persistência)
- ✅ Registra o GitHub em `~/.ssh/known_hosts` com validação de fingerprint
- ✅ Testa autenticação SSH final com `ssh -T git@github.com`

### Protege

- 🔒 Permissões corretas: `~/.ssh` com `700`, chaves privadas com `600`
- 🔒 Nunca armazena senhas/passphrases — tudo interativo
- 🔒 Valida fingerprints oficiais do GitHub contra MITM
- 🔒 Cria backup antes de sobrescrever arquivos existentes
- 🔒 Aviso claro se rodado como `root`

### Não Faz

- ❌ **Não** gerencia chaves GPG ou assinatura de commits
- ❌ **Não** instala/configura GitHub CLI (`gh`)
- ❌ **Não** gerencia tokens HTTPS ou autenticação por senha

---

## 🛠️ Requisitos

| Requisito | Versão Mínima |
|-----------|---------------|
| **Bash** | 4.3+ |
| **Ubuntu** | 22.04 a 25.x (outros distros Linux podem funcionar) |
| **Git** | Qualquer versão recente |
| **OpenSSH** | Cliente + server padrão do Ubuntu |

O script verifica automaticamente e oferece instalar via `apt` se faltar algo.

---

## 📝 Fluxo Detalhado dos 8 Passos

### Passo 1: Idioma
Escolha entre português (Brasil) ou inglês. Pode ser pulado com `--lang`.

### Passo 2: Sistema
Verifica Ubuntu, versão do Bash, e se `git`, `ssh`, `ssh-keygen`, `ssh-agent`, `ssh-add`, `ssh-keyscan` estão instalados. Oferece instalar automaticamente.

### Passo 3: Identidade Git
Configura `user.name` e `user.email` globais. Sugere usar endereço `@users.noreply.github.com` para privacidade em commits públicos.

### Passo 4: Chaves Existentes
Lista chaves SSH já presentes em `~/.ssh/`. Você pode:
- Criar uma nova (recomendado)
- Reusar uma existente

### Passo 5: Gerar Chave
Se criando nova:
- Define caminho da chave (padrão: `~/.ssh/id_ed25519_github`)
- Pergunta se quer substituir arquivo existente (faz backup)
- Adiciona comentário para identificar depois
- Pergunta se usar senha na chave (recomendado para segurança)
- ssh-keygen gera o par

### Passo 6: Agent + Config
- Inicia/reutiliza ssh-agent
- Carrega a chave no agente (pede senha se houver)
- Cria bloco `Host github.com` em `~/.ssh/config`
- Registra github.com em `~/.ssh/known_hosts` com validação de fingerprint

### Passo 7: Colar no GitHub
- Exibe a chave pública (em destaque, com opção de copiar)
- Abre navegador automaticamente se GUI disponível
- Guia passo-a-passo para colar em https://github.com/settings/ssh/new
- Aguarda sua confirmação quando terminar

### Passo 8: Teste Final
- Testa `ssh -T git@github.com`
- Se sucesso: mostra username, resumo de todos os passos
- Se falha: oferece retry, diagnóstico ou mostrar config

---

## 🔍 Validação de Segurança

O script valida a identidade do GitHub consultando a fingerprint oficial:

- **Ed25519:** `SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU`
- **ECDSA:** `SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM`
- **RSA:** `SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s`

Se houver discrepância (proxy corporativo, MITM), o script **não adiciona** ao `known_hosts` e usa `StrictHostKeyChecking=yes` no teste.

Referência: https://docs.github.com/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints

---

## 🎯 Próximos Passos Após Completar

Depois que o script termina com sucesso:

### Clonar um repositório

```bash
git clone git@github.com:usuario/repositorio.git
```

### Converter repositório existente de HTTPS para SSH

```bash
cd seu-repositorio
git remote set-url origin git@github.com:usuario/repositorio.git
```

### Ver suas chaves cadastradas no GitHub

https://github.com/settings/keys (mostra data do último uso)

---

## 🐛 Troubleshooting

### "Permission denied (publickey)"
**Causa mais comum:** Chave não foi colada no GitHub, ou foi colada incompleta.
- Vá para https://github.com/settings/ssh/new
- Cole a chave **inteira**, começando em `ssh-ed25519`, em **uma única linha**
- Se faltando, o script oferece opção de retry no passo 8

### "ssh-agent não persiste entre sessões"
**Normal!** O script cria um agente temporário apenas para a sessão atual. A persistência real vem da linha `AddKeysToAgent yes` no `~/.ssh/config` — o ssh automaticamente carrega a chave quando precisar.

### "Rodando como root"
**Aviso!** Se usar `sudo ./setup-github-keys.sh`, a chave será criada em `/root/.ssh`, não em `~/.ssh` do seu usuário comum.
- **Solução:** Rode sem `sudo`: `./setup-github-keys.sh`

### "Distribuição não é Ubuntu"
Derivadas do Ubuntu (Linux Mint, Pop!_OS, Zorin) geralmente funcionam. Outros distros podem precisar instalar manualmente.

---

## 📄 Licença

Licença MIT — veja [LICENSE](LICENSE) para detalhes.

Você é livre para usar, modificar e distribuir este script.

---

## 🤝 Contribuições

Encontrou um bug? Ideias para melhorias?

1. Abra uma [Issue](https://github.com/jacksonie/gh-key-setup-assist/issues)
2. Descreva o problema ou sugestão
3. Pull requests são bem-vindos!

---

## 📞 Suporte

Para dúvidas sobre GitHub SSH em geral:
- https://docs.github.com/authentication/connecting-to-github-with-ssh

Para dúvidas específicas deste script:
- Abra uma Issue neste repositório

---

## 📊 Estrutura do Repositório

```
gh-key-setup-assist/
├── setup-github-keys.sh     # Script principal
├── README.md                # Este arquivo
└── LICENSE                  # Licença MIT
```

---

**Versão:** 1.0.0  
**Mantido por:** Jackson Souza  
**Última atualização:** 2024

Bom trabalho! 🚀