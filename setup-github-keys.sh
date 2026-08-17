#!/usr/bin/env bash
# =============================================================================
#  gh-key-setup-assist — Assistente interativo de configuração de chave SSH
#                        para o GitHub no Ubuntu 22.04 -> 25.x
#
#  Escopo: chave SSH ed25519 + git config user.name/user.email.
#  Não cobre: GPG/assinatura de commits, GitHub CLI (gh), tokens HTTPS.
#
#  Uso:   chmod +x setup-github-keys.sh && ./setup-github-keys.sh
#  Flags: --lang pt-br|en   --no-color   -h|--help   --version
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# 0. Constantes
# -----------------------------------------------------------------------------
readonly VERSION="1.0.0"
readonly PROG_NAME="gh-key-setup-assist"
readonly TOTAL_STEPS=8
readonly MARK_START="# >>> gh-key-setup-assist >>>"
readonly MARK_END="# <<< gh-key-setup-assist <<<"
readonly URL_NEW_KEY="https://github.com/settings/ssh/new"
readonly URL_KEYS="https://github.com/settings/keys"
readonly URL_EMAILS="https://github.com/settings/emails"
readonly URL_FINGERPRINTS="https://docs.github.com/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints"

# Fingerprints oficiais publicadas pelo GitHub (ver URL_FINGERPRINTS).
readonly FP_ED25519="SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU"
readonly FP_ECDSA="SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM"
readonly FP_RSA="SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s"

# -----------------------------------------------------------------------------
# 1. Estado global (alimenta o checklist final do passo 8)
# -----------------------------------------------------------------------------
LANG_SEL=""              # PTBR | EN
NO_COLOR_FLAG=0
CUR_STEP=0

ST_DEPS=0                # dependencias obrigatorias presentes
ST_GITNAME=0             # git config user.name definido
ST_GITMAIL=0             # git config user.email definido
ST_KEY=0                 # chave escolhida/gerada
ST_PERMS=0               # permissoes corretas em ~/.ssh
ST_AGENT=0               # chave carregada no ssh-agent
ST_CONFIG=0              # bloco no ~/.ssh/config
ST_KNOWN=0               # github.com no known_hosts
ST_AUTH=0                # ssh -T autenticou

KEY_PATH=""              # caminho da chave privada
KEY_PUB=""               # caminho da chave publica
KEY_IS_NEW=0
GIT_NAME=""
GIT_EMAIL=""
GH_USER=""
# Modo de verificacao de host key usado no teste final. Nunca usamos o padrao
# do ssh ("ask"): a saida do teste e capturada, entao um prompt interativo
# ficaria invisivel e o assistente travaria esperando uma resposta que o
# usuario nao tem como ver.
#   yes        -> host ja conhecido e conferido, ou fingerprint suspeita
#   accept-new -> host ainda desconhecido, sem motivo para desconfiar
KH_MODE="accept-new"
CLIP_CMD=""              # comando de clipboard detectado (pode ficar vazio)
MISSING_PKGS=()          # pacotes obrigatorios ausentes
LAST_SSH_OUT=""

SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
KNOWN_HOSTS="$SSH_DIR/known_hosts"

# Cores e símbolos: inicializados vazios para que qualquer mensagem de erro
# disparada antes de setup_colors() não esbarre no `set -u`.
C_RESET="" C_BOLD="" C_DIM="" C_OK="" C_WARN="" C_ERR="" C_INFO="" C_HL=""
SYM_OK="[ok]" SYM_ERR="[x]" SYM_WARN="[!]" SYM_INFO="[i]" SYM_TIP="->" SYM_DOT="-"

# -----------------------------------------------------------------------------
# 2. Tabelas de tradução
#    Regra: toda string visível ao usuário mora aqui. As duas tabelas precisam
#    ter exatamente as mesmas chaves (validado por --selftest-i18n).
#    Placeholders são sempre %s (as strings passam por printf).
# -----------------------------------------------------------------------------
declare -A T_PTBR
declare -A T_EN

# --- geral / UI --------------------------------------------------------------
T_PTBR[app_title]="Assistente de configuração de chave SSH do GitHub"
T_EN[app_title]="GitHub SSH key setup assistant"
T_PTBR[app_sub]="Ubuntu 22.04 a 25.x  ·  versão %s"
T_EN[app_sub]="Ubuntu 22.04 to 25.x  ·  version %s"
T_PTBR[step_word]="Passo"
T_EN[step_word]="Step"
T_PTBR[yn_yes_default]="[S/n]"
T_EN[yn_yes_default]="[Y/n]"
T_PTBR[yn_no_default]="[s/N]"
T_EN[yn_no_default]="[y/N]"
T_PTBR[invalid_yn]="Não entendi. Responda 's' para sim ou 'n' para não."
T_EN[invalid_yn]="I did not get that. Answer 'y' for yes or 'n' for no."
T_PTBR[invalid_choice]="Opção inválida. Digite um número entre 1 e %s."
T_EN[invalid_choice]="Invalid option. Type a number between 1 and %s."
T_PTBR[value_required]="Esse valor não pode ficar vazio."
T_EN[value_required]="This value cannot be empty."
T_PTBR[press_enter]="Pressione ENTER para continuar"
T_EN[press_enter]="Press ENTER to continue"
T_PTBR[press_enter_done]="Pressione ENTER quando tiver terminado essa parte no navegador"
T_EN[press_enter_done]="Press ENTER once you have finished that part in the browser"
T_PTBR[aborted_eof]="Entrada encerrada (EOF). Saindo sem alterar mais nada."
T_EN[aborted_eof]="Input closed (EOF). Exiting without further changes."
T_PTBR[aborted_user]="Interrompido pelo usuário no passo %s. Nada mais foi alterado."
T_EN[aborted_user]="Interrupted by the user at step %s. Nothing else was changed."
T_PTBR[error_at]="Erro inesperado no passo %s (linha %s). Saindo."
T_EN[error_at]="Unexpected error at step %s (line %s). Exiting."
T_PTBR[no_tty]="Este assistente é 100%% interativo e precisa de um terminal (/dev/tty)."
T_EN[no_tty]="This assistant is 100%% interactive and needs a terminal (/dev/tty)."
T_PTBR[no_tty_hint]="Baixe o arquivo e execute direto: ./setup-github-keys.sh"
T_EN[no_tty_hint]="Download the file and run it directly: ./setup-github-keys.sh"
T_PTBR[bash_old]="Este script precisa do bash 4.3 ou superior. Versão encontrada: %s"
T_EN[bash_old]="This script needs bash 4.3 or newer. Found version: %s"
T_PTBR[is_root]="Rodando como root: a chave será criada em /root/.ssh, não na pasta do seu usuário comum."
T_EN[is_root]="Running as root: the key will be created in /root/.ssh, not in your regular user's folder."
T_PTBR[is_root_why]="Se a intenção era configurar o SSH do seu usuário, saia e rode sem sudo. Seguindo em frente do mesmo jeito."
T_EN[is_root_why]="If you meant to set up SSH for your own user, quit and run it without sudo. Carrying on anyway."
T_PTBR[cancelled]="Tudo bem, cancelado. Nada foi alterado."
T_EN[cancelled]="No problem, cancelled. Nothing was changed."
T_PTBR[copied_clipboard]="Copiado para a área de transferência (%s)."
T_EN[copied_clipboard]="Copied to the clipboard (%s)."
T_PTBR[copy_manual]="Sem área de transferência nesta sessão: selecione o texto acima com o mouse para copiar."
T_EN[copy_manual]="No clipboard in this session: select the text above with the mouse to copy it."

# --- help --------------------------------------------------------------------
T_PTBR[help_usage]="Uso: ./setup-github-keys.sh [opções]"
T_EN[help_usage]="Usage: ./setup-github-keys.sh [options]"
T_PTBR[help_lang]="  --lang pt-br|en   Define o idioma e pula o passo 1"
T_EN[help_lang]="  --lang pt-br|en   Set the language and skip step 1"
T_PTBR[help_nocolor]="  --no-color        Desliga as cores da saída"
T_EN[help_nocolor]="  --no-color        Turn off output colors"
T_PTBR[help_help]="  -h, --help        Mostra esta ajuda"
T_EN[help_help]="  -h, --help        Show this help"
T_PTBR[help_version]="  --version         Mostra a versão"
T_EN[help_version]="  --version         Show the version"
T_PTBR[help_what]="O que ele faz: gera (ou reaproveita) uma chave SSH ed25519, configura o ssh-agent e o ~/.ssh/config, guia você a colar a chave no GitHub pelo navegador e testa a autenticação no final."
T_EN[help_what]="What it does: generates (or reuses) an ed25519 SSH key, sets up ssh-agent and ~/.ssh/config, walks you through pasting the key into GitHub in your browser, and tests authentication at the end."
T_PTBR[help_not]="O que ele NÃO faz: chaves GPG / assinatura de commits, GitHub CLI (gh) e tokens HTTPS."
T_EN[help_not]="What it does NOT do: GPG keys / commit signing, GitHub CLI (gh), and HTTPS tokens."
T_PTBR[bad_flag]="Opção desconhecida: %s"
T_EN[bad_flag]="Unknown option: %s"

# --- passo 1: idioma ---------------------------------------------------------
T_PTBR[s1_title]="Idioma / Language"
T_EN[s1_title]="Language / Idioma"

# --- passo 2: sistema e dependências ----------------------------------------
T_PTBR[s2_title]="Sistema e programas necessários"
T_EN[s2_title]="System and required programs"
T_PTBR[s2_checking]="Verificando o sistema e o que já está instalado..."
T_EN[s2_checking]="Checking the system and what is already installed..."
T_PTBR[s2_os_ok]="Sistema: %s %s"
T_EN[s2_os_ok]="System: %s %s"
T_PTBR[s2_os_unknown]="Não consegui identificar a distribuição (sem /etc/os-release)."
T_EN[s2_os_unknown]="Could not identify the distribution (no /etc/os-release)."
T_PTBR[s2_os_not_ubuntu]="Este assistente foi feito para Ubuntu 22.04 a 25.x. Detectei: %s"
T_EN[s2_os_not_ubuntu]="This assistant targets Ubuntu 22.04 to 25.x. Detected: %s"
T_PTBR[s2_os_derivative]="Derivados do Ubuntu (Mint, Pop!_OS, Zorin) costumam funcionar sem problema."
T_EN[s2_os_derivative]="Ubuntu derivatives (Mint, Pop!_OS, Zorin) usually work fine."
T_PTBR[s2_os_version_odd]="A versão %s está fora da faixa testada (22 a 25), mas provavelmente funciona."
T_EN[s2_os_version_odd]="Version %s is outside the tested range (22 to 25), but it will likely work."
T_PTBR[s2_continue_anyway]="Quer continuar mesmo assim?"
T_EN[s2_continue_anyway]="Do you want to continue anyway?"
T_PTBR[s2_found]="%s encontrado"
T_EN[s2_found]="%s found"
T_PTBR[s2_missing]="%s faltando (pacote: %s)"
T_EN[s2_missing]="%s missing (package: %s)"
T_PTBR[s2_all_ok]="Todos os programas obrigatórios já estão instalados."
T_EN[s2_all_ok]="All required programs are already installed."
T_PTBR[s2_need_install]="Faltam programas para seguir. Posso instalar por você usando o apt."
T_EN[s2_need_install]="Some programs are missing. I can install them for you using apt."
T_PTBR[s2_cmd_intro]="Comando exato que será executado (vai pedir a sua senha do sudo):"
T_EN[s2_cmd_intro]="Exact command that will be run (it will ask for your sudo password):"
T_PTBR[s2_ask_install]="Posso executar esse comando agora?"
T_EN[s2_ask_install]="May I run that command now?"
T_PTBR[s2_installing]="Instalando... isso pode levar alguns instantes."
T_EN[s2_installing]="Installing... this may take a moment."
T_PTBR[s2_install_ok]="Instalação concluída."
T_EN[s2_install_ok]="Installation finished."
T_PTBR[s2_install_fail]="A instalação falhou. Veja a mensagem acima."
T_EN[s2_install_fail]="The installation failed. See the message above."
T_PTBR[s2_manual_intro]="Sem problema. Abra OUTRO terminal, rode o comando abaixo e depois volte aqui:"
T_EN[s2_manual_intro]="No problem. Open ANOTHER terminal, run the command below, then come back here:"
T_PTBR[s2_recheck]="Verificando de novo..."
T_EN[s2_recheck]="Checking again..."
T_PTBR[s2_still_missing]="Ainda faltam: %s"
T_EN[s2_still_missing]="Still missing: %s"
T_PTBR[s2_retry]="Quer tentar de novo?"
T_EN[s2_retry]="Do you want to try again?"
T_PTBR[s2_cannot_continue]="Sem esses programas não dá para continuar. Instale-os e rode o assistente novamente."
T_EN[s2_cannot_continue]="Without those programs we cannot continue. Install them and run the assistant again."
T_PTBR[s2_no_sudo]="O comando 'sudo' não existe neste sistema, então não posso instalar nada."
T_EN[s2_no_sudo]="The 'sudo' command does not exist on this system, so I cannot install anything."
T_PTBR[s2_clip_ok]="Área de transferência: %s"
T_EN[s2_clip_ok]="Clipboard: %s"
T_PTBR[s2_clip_none]="Sem área de transferência (sessão sem interface gráfica). Isso não é um problema: no passo 7 a chave será exibida para você copiar com o mouse."
T_EN[s2_clip_none]="No clipboard (session without a graphical interface). Not a problem: in step 7 the key will be printed for you to copy with the mouse."

# --- passo 3: git config -----------------------------------------------------
T_PTBR[s3_title]="Identidade do Git (nome e e-mail)"
T_EN[s3_title]="Git identity (name and email)"
T_PTBR[s3_intro]="O Git carimba seu nome e e-mail em cada commit. Sem isso, o primeiro commit falha."
T_EN[s3_intro]="Git stamps your name and email on every commit. Without them, the first commit fails."
T_PTBR[s3_name_set]="user.name já definido: %s"
T_EN[s3_name_set]="user.name already set: %s"
T_PTBR[s3_mail_set]="user.email já definido: %s"
T_EN[s3_mail_set]="user.email already set: %s"
T_PTBR[s3_change_q]="Quer alterar esse valor?"
T_EN[s3_change_q]="Do you want to change that value?"
T_PTBR[s3_ask_name]="Seu nome (aparece na autoria dos commits)"
T_EN[s3_ask_name]="Your name (shown as the commit author)"
T_PTBR[s3_ask_mail]="Seu e-mail do GitHub"
T_EN[s3_ask_mail]="Your GitHub email"
T_PTBR[s3_mail_invalid]="Isso não parece um e-mail válido. Tente de novo."
T_EN[s3_mail_invalid]="That does not look like a valid email. Try again."
T_PTBR[s3_noreply_tip]="Para não expor seu e-mail nos commits públicos, use o endereço @users.noreply.github.com da sua conta."
T_EN[s3_noreply_tip]="To keep your email out of public commits, use your account's @users.noreply.github.com address."
T_PTBR[s3_noreply_where]="Onde achar: %s  ->  seção 'Keep my email addresses private'"
T_EN[s3_noreply_where]="Where to find it: %s  ->  'Keep my email addresses private' section"
T_PTBR[s3_saved]="Salvo com 'git config --global %s'."
T_EN[s3_saved]="Saved with 'git config --global %s'."

# --- passo 4: chaves existentes ---------------------------------------------
T_PTBR[s4_title]="Chaves SSH que já existem nesta máquina"
T_EN[s4_title]="SSH keys already on this machine"
T_PTBR[s4_dir_created]="Criei a pasta %s com permissão 700."
T_EN[s4_dir_created]="Created the folder %s with permission 700."
T_PTBR[s4_none]="Nenhuma chave SSH encontrada em %s. Vamos criar uma."
T_EN[s4_none]="No SSH key found in %s. Let's create one."
T_PTBR[s4_found_n]="Encontrei %s chave(s) existente(s):"
T_EN[s4_found_n]="Found %s existing key(s):"
T_PTBR[s4_entry]="  %s) %s"
T_EN[s4_entry]="  %s) %s"
T_PTBR[s4_entry_info]="       tipo: %s · fingerprint: %s"
T_EN[s4_entry_info]="       type: %s · fingerprint: %s"
T_PTBR[s4_choose]="O que você quer fazer?"
T_EN[s4_choose]="What do you want to do?"
T_PTBR[s4_opt_new]="Criar uma chave nova, dedicada ao GitHub (recomendado)"
T_EN[s4_opt_new]="Create a new key dedicated to GitHub (recommended)"
T_PTBR[s4_opt_reuse]="Reaproveitar uma das chaves acima"
T_EN[s4_opt_reuse]="Reuse one of the keys above"
T_PTBR[s4_pick_existing]="Qual chave você quer usar?"
T_EN[s4_pick_existing]="Which key do you want to use?"
T_PTBR[s4_reuse_ok]="Vamos usar: %s"
T_EN[s4_reuse_ok]="We will use: %s"
T_PTBR[s4_no_private]="A chave privada correspondente (%s) não existe. Escolha outra ou crie uma nova."
T_EN[s4_no_private]="The matching private key (%s) does not exist. Pick another one or create a new key."

# --- passo 5: gerar chave ----------------------------------------------------
T_PTBR[s5_title]="Gerar a chave SSH"
T_EN[s5_title]="Generate the SSH key"
T_PTBR[s5_skip]="Você escolheu reaproveitar uma chave existente, então não há nada a gerar."
T_EN[s5_skip]="You chose to reuse an existing key, so there is nothing to generate."
T_PTBR[s5_intro]="Vamos criar um par de chaves ed25519: uma privada (fica só aqui, nunca compartilhe) e uma pública (essa sim você cola no GitHub)."
T_EN[s5_intro]="We will create an ed25519 key pair: a private one (stays here, never share it) and a public one (that is the one you paste into GitHub)."
T_PTBR[s5_ask_path]="Caminho do arquivo da chave"
T_EN[s5_ask_path]="Key file path"
T_PTBR[s5_exists]="Já existe um arquivo em %s."
T_EN[s5_exists]="A file already exists at %s."
T_PTBR[s5_overwrite_q]="Quer substituir esse arquivo? (faço um backup antes)"
T_EN[s5_overwrite_q]="Do you want to replace that file? (I will back it up first)"
T_PTBR[s5_overwrite_confirm]="Confirmando: se alguma conta ou servidor usa essa chave, ela vai parar de funcionar. Substituir mesmo assim?"
T_EN[s5_overwrite_confirm]="Confirming: if any account or server uses that key, it will stop working. Replace anyway?"
T_PTBR[s5_backup_made]="Backup salvo em %s"
T_EN[s5_backup_made]="Backup saved to %s"
T_PTBR[s5_pick_other]="Ok, escolha outro caminho."
T_EN[s5_pick_other]="Ok, choose another path."
T_PTBR[s5_ask_comment]="Comentário da chave (serve só para você identificá-la)"
T_EN[s5_ask_comment]="Key comment (only to help you identify it)"
T_PTBR[s5_pass_intro]="Agora a senha (passphrase) da chave:"
T_EN[s5_pass_intro]="Now the key passphrase:"
T_PTBR[s5_pass_yes]="Com senha: se alguém copiar o arquivo da sua chave, ainda precisa da senha. Você a digita uma vez por sessão."
T_EN[s5_pass_yes]="With a passphrase: if someone copies your key file, they still need the passphrase. You type it once per session."
T_PTBR[s5_pass_no]="Sem senha: mais cômodo, mas quem tiver acesso ao arquivo entra na sua conta do GitHub."
T_EN[s5_pass_no]="Without a passphrase: more convenient, but anyone with the file gets into your GitHub account."
T_PTBR[s5_pass_prompt]="O próprio ssh-keygen vai pedir a senha a seguir. Para não usar senha, é só pressionar ENTER duas vezes."
T_EN[s5_pass_prompt]="ssh-keygen itself will ask for the passphrase next. For no passphrase, just press ENTER twice."
T_PTBR[s5_generating]="Gerando a chave..."
T_EN[s5_generating]="Generating the key..."
T_PTBR[s5_gen_fail]="Não consegui gerar a chave. Veja a mensagem acima."
T_EN[s5_gen_fail]="Could not generate the key. See the message above."
T_PTBR[s5_gen_ok]="Chave criada: %s"
T_EN[s5_gen_ok]="Key created: %s"
T_PTBR[s5_fingerprint]="Fingerprint: %s"
T_EN[s5_fingerprint]="Fingerprint: %s"
T_PTBR[s5_perms_ok]="Permissões ajustadas (pasta 700, privada 600, pública 644)."
T_EN[s5_perms_ok]="Permissions fixed (folder 700, private 600, public 644)."

# --- passo 6: agent + config -------------------------------------------------
T_PTBR[s6_title]="ssh-agent, ~/.ssh/config e known_hosts"
T_EN[s6_title]="ssh-agent, ~/.ssh/config and known_hosts"
T_PTBR[s6_agent_running]="O ssh-agent já está rodando nesta sessão."
T_EN[s6_agent_running]="ssh-agent is already running in this session."
T_PTBR[s6_agent_start]="Iniciando um ssh-agent temporário para este assistente..."
T_EN[s6_agent_start]="Starting a temporary ssh-agent for this assistant..."
T_PTBR[s6_agent_temp_warn]="Esse agente vive apenas enquanto o assistente roda. A persistência de verdade vem da linha 'AddKeysToAgent yes' que vou colocar no ~/.ssh/config."
T_EN[s6_agent_temp_warn]="That agent only lives while the assistant runs. Real persistence comes from the 'AddKeysToAgent yes' line I will add to ~/.ssh/config."
T_PTBR[s6_adding_key]="Adicionando a chave ao agente (se ela tiver senha, digite-a agora)..."
T_EN[s6_adding_key]="Adding the key to the agent (if it has a passphrase, type it now)..."
T_PTBR[s6_add_ok]="Chave carregada no ssh-agent."
T_EN[s6_add_ok]="Key loaded into ssh-agent."
T_PTBR[s6_add_fail]="Não consegui carregar a chave no agente. O teste final ainda pode funcionar, mas você vai digitar a senha mais vezes."
T_EN[s6_add_fail]="Could not load the key into the agent. The final test may still work, but you will type the passphrase more often."
T_PTBR[s6_cfg_intro]="Agora o ~/.ssh/config, que diz ao ssh qual chave usar para o github.com."
T_EN[s6_cfg_intro]="Now ~/.ssh/config, which tells ssh which key to use for github.com."
T_PTBR[s6_cfg_preview]="Bloco que será adicionado no início do arquivo:"
T_EN[s6_cfg_preview]="Block that will be added at the top of the file:"
T_PTBR[s6_cfg_replace]="Já existe um bloco deste assistente no arquivo; ele será substituído."
T_EN[s6_cfg_replace]="There is already a block from this assistant in the file; it will be replaced."
T_PTBR[s6_cfg_foreign]="Atenção: o arquivo já tem uma configuração própria para github.com, escrita por você ou por outro programa:"
T_EN[s6_cfg_foreign]="Heads up: the file already has its own github.com configuration, written by you or another program:"
T_PTBR[s6_cfg_foreign_q]="Como quer prosseguir?"
T_EN[s6_cfg_foreign_q]="How do you want to proceed?"
T_PTBR[s6_cfg_opt_keep]="Manter o que já está lá e não mexer no arquivo"
T_EN[s6_cfg_opt_keep]="Keep what is already there and leave the file alone"
T_PTBR[s6_cfg_opt_add]="Adicionar meu bloco no início (ele terá prioridade sobre o existente)"
T_EN[s6_cfg_opt_add]="Add my block at the top (it will take priority over the existing one)"
T_PTBR[s6_cfg_kept]="Ok, o ~/.ssh/config foi mantido como estava."
T_EN[s6_cfg_kept]="Ok, ~/.ssh/config was left untouched."
T_PTBR[s6_cfg_ask]="Posso gravar esse bloco no %s?"
T_EN[s6_cfg_ask]="May I write that block into %s?"
T_PTBR[s6_cfg_backup]="Backup do config salvo em %s"
T_EN[s6_cfg_backup]="Config backup saved to %s"
T_PTBR[s6_cfg_ok]="~/.ssh/config atualizado (permissão 600)."
T_EN[s6_cfg_ok]="~/.ssh/config updated (permission 600)."
T_PTBR[s6_kh_intro]="Falta registrar a identidade do servidor github.com, para o ssh saber que está falando com o GitHub de verdade."
T_EN[s6_kh_intro]="Now we register the github.com server identity, so ssh knows it is really talking to GitHub."
T_PTBR[s6_kh_already]="github.com já está no seu known_hosts."
T_EN[s6_kh_already]="github.com is already in your known_hosts."
T_PTBR[s6_kh_scanning]="Consultando a chave pública do servidor github.com..."
T_EN[s6_kh_scanning]="Fetching the github.com server public key..."
T_PTBR[s6_kh_fail]="Não consegui consultar o github.com. Verifique sua conexão com a internet."
T_EN[s6_kh_fail]="Could not reach github.com. Check your internet connection."
T_PTBR[s6_kh_got]="Fingerprint recebida: %s"
T_EN[s6_kh_got]="Received fingerprint: %s"
T_PTBR[s6_kh_expect]="Fingerprint oficial:   %s"
T_EN[s6_kh_expect]="Official fingerprint:  %s"
T_PTBR[s6_kh_match]="As duas conferem: é o servidor legítimo do GitHub."
T_EN[s6_kh_match]="They match: this is the legitimate GitHub server."
T_PTBR[s6_kh_mismatch]="As fingerprints NÃO conferem. Isso pode ser um proxy corporativo interceptando a conexão, ou algo pior. Não vou adicionar nada ao known_hosts."
T_EN[s6_kh_mismatch]="The fingerprints do NOT match. This may be a corporate proxy intercepting the connection, or something worse. I will not add anything to known_hosts."
T_PTBR[s6_kh_ref]="Lista oficial de fingerprints do GitHub: %s"
T_EN[s6_kh_ref]="GitHub's official fingerprint list: %s"
T_PTBR[s6_kh_ask]="Posso registrar o github.com no seu known_hosts?"
T_EN[s6_kh_ask]="May I record github.com in your known_hosts?"
T_PTBR[s6_kh_ok]="github.com registrado em %s"
T_EN[s6_kh_ok]="github.com recorded in %s"
T_PTBR[s6_kh_skip]="Ok, não mexi no known_hosts. O ssh pode perguntar sobre isso no teste final."
T_EN[s6_kh_skip]="Ok, known_hosts untouched. ssh may ask about it during the final test."

# --- passo 7: colar no GitHub ------------------------------------------------
T_PTBR[s7_title]="Cadastrar a chave pública na sua conta do GitHub"
T_EN[s7_title]="Register the public key in your GitHub account"
T_PTBR[s7_intro]="Esta é a parte que só você pode fazer: o GitHub precisa receber a sua chave PÚBLICA. Vou te dar tudo pronto e esperar aqui."
T_EN[s7_intro]="This is the part only you can do: GitHub needs to receive your PUBLIC key. I will hand you everything and wait right here."
T_PTBR[s7_key_below]="Esta é a sua chave pública (pode ser copiada sem medo, ela não é secreta):"
T_EN[s7_key_below]="This is your public key (safe to copy, it is not a secret):"
T_PTBR[s7_open_browser_q]="Quer que eu abra a página do GitHub no seu navegador agora?"
T_EN[s7_open_browser_q]="Should I open the GitHub page in your browser now?"
T_PTBR[s7_opening]="Abrindo %s ..."
T_EN[s7_opening]="Opening %s ..."
T_PTBR[s7_open_fail]="Não consegui abrir o navegador. Abra o endereço manualmente."
T_EN[s7_open_fail]="Could not open the browser. Open the address manually."
T_PTBR[s7_steps_title]="Passo a passo no navegador:"
T_EN[s7_steps_title]="Step by step in the browser:"
T_PTBR[s7_step1]="1) Abra este endereço (já logado na sua conta): %s"
T_EN[s7_step1]="1) Open this address (already signed in to your account): %s"
T_PTBR[s7_step1b]="   Caminho pelos menus: foto do seu perfil (canto superior direito) -> Settings -> menu da esquerda 'SSH and GPG keys' -> botão verde 'New SSH key'."
T_EN[s7_step1b]="   Menu path: your profile picture (top right corner) -> Settings -> left menu 'SSH and GPG keys' -> green button 'New SSH key'."
T_PTBR[s7_step2]="2) Campo 'Title': um apelido para lembrar de qual máquina é esta chave. Sugestão: %s"
T_EN[s7_step2]="2) 'Title' field: a nickname so you remember which machine this key is from. Suggestion: %s"
T_PTBR[s7_step3]="3) Campo 'Key type': deixe em 'Authentication Key' (a opção 'Signing Key' é para assinar commits com a chave, que não é o nosso caso)."
T_EN[s7_step3]="3) 'Key type' field: leave it as 'Authentication Key' ('Signing Key' is for signing commits, which is not our case)."
T_PTBR[s7_step4]="4) Campo 'Key': cole a chave (Ctrl+V). Ela precisa entrar INTEIRA, começando em 'ssh-ed25519' e em uma única linha."
T_EN[s7_step4]="4) 'Key' field: paste the key (Ctrl+V). It must go in WHOLE, starting with 'ssh-ed25519' and on a single line."
T_PTBR[s7_step5]="5) Clique no botão verde 'Add SSH key'. O GitHub pode pedir sua senha ou o código de 2 fatores para confirmar."
T_EN[s7_step5]="5) Click the green 'Add SSH key' button. GitHub may ask for your password or 2FA code to confirm."
T_PTBR[s7_no_account]="Ainda não tem conta? Crie em https://github.com/signup e volte para cá."
T_EN[s7_no_account]="No account yet? Create one at https://github.com/signup and come back here."

# --- passo 8: verificação ----------------------------------------------------
T_PTBR[s8_title]="Teste final e resumo"
T_EN[s8_title]="Final test and summary"
T_PTBR[s8_testing]="Testando a autenticação com o GitHub..."
T_EN[s8_testing]="Testing authentication with GitHub..."
T_PTBR[s8_accept_new]="Como o github.com não está no seu known_hosts, o teste vai aceitar a identidade do servidor automaticamente nesta conexão."
T_EN[s8_accept_new]="Since github.com is not in your known_hosts, the test will accept the server identity automatically for this connection."
T_PTBR[s8_ok]="Autenticado com sucesso como: %s"
T_EN[s8_ok]="Successfully authenticated as: %s"
T_PTBR[s8_ok_generic]="Autenticação bem-sucedida."
T_EN[s8_ok_generic]="Authentication succeeded."
T_PTBR[s8_note_exit1]="(O ssh retorna código 1 nesse teste mesmo quando dá certo: o GitHub aceita a chave mas não abre um shell. O que vale é a mensagem acima.)"
T_EN[s8_note_exit1]="(ssh returns exit code 1 in this test even on success: GitHub accepts the key but does not open a shell. What matters is the message above.)"
T_PTBR[s8_fail]="A autenticação não funcionou. Resposta do servidor:"
T_EN[s8_fail]="Authentication did not work. Server response:"
T_PTBR[s8_diag]="Diagnóstico rápido:"
T_EN[s8_diag]="Quick diagnosis:"
T_PTBR[s8_diag_none]="Sem detalhes adicionais do ssh."
T_EN[s8_diag_none]="No extra details from ssh."
T_PTBR[s8_cause_hint]="Causa mais comum: a chave não foi colada no GitHub, ou foi colada pela metade / com quebra de linha no meio."
T_EN[s8_cause_hint]="Most common cause: the key was not pasted into GitHub, or it was pasted incomplete / with a line break in the middle."
T_PTBR[s8_what_now]="O que você quer fazer?"
T_EN[s8_what_now]="What do you want to do?"
T_PTBR[s8_opt_retry_paste]="Voltar e colar a chave no GitHub de novo, depois testar outra vez"
T_EN[s8_opt_retry_paste]="Go back and paste the key into GitHub again, then test once more"
T_PTBR[s8_opt_retry_test]="Só testar de novo (já arrumei do meu lado)"
T_EN[s8_opt_retry_test]="Just test again (I already fixed it on my side)"
T_PTBR[s8_opt_show_cfg]="Mostrar o meu ~/.ssh/config e a chave em uso"
T_EN[s8_opt_show_cfg]="Show my ~/.ssh/config and the key in use"
T_PTBR[s8_opt_quit]="Sair e resolver isso depois"
T_EN[s8_opt_quit]="Quit and sort this out later"
T_PTBR[s8_cfg_dump]="Conteúdo de %s:"
T_EN[s8_cfg_dump]="Contents of %s:"
T_PTBR[s8_cfg_absent]="O arquivo %s não existe."
T_EN[s8_cfg_absent]="The file %s does not exist."
T_PTBR[s8_key_in_use]="Chave configurada: %s"
T_EN[s8_key_in_use]="Configured key: %s"
T_PTBR[s8_checklist]="Resumo do que ficou pronto"
T_EN[s8_checklist]="Summary of what is in place"
T_PTBR[s8_ck_deps]="Programas necessários instalados"
T_EN[s8_ck_deps]="Required programs installed"
T_PTBR[s8_ck_name]="git config user.name"
T_EN[s8_ck_name]="git config user.name"
T_PTBR[s8_ck_mail]="git config user.email"
T_EN[s8_ck_mail]="git config user.email"
T_PTBR[s8_ck_key]="Chave SSH criada ou escolhida"
T_EN[s8_ck_key]="SSH key created or selected"
T_PTBR[s8_ck_perms]="Permissões corretas em ~/.ssh"
T_EN[s8_ck_perms]="Correct permissions on ~/.ssh"
T_PTBR[s8_ck_agent]="Chave carregada no ssh-agent"
T_EN[s8_ck_agent]="Key loaded into ssh-agent"
T_PTBR[s8_ck_config]="Bloco github.com no ~/.ssh/config"
T_EN[s8_ck_config]="github.com block in ~/.ssh/config"
T_PTBR[s8_ck_known]="github.com no known_hosts"
T_EN[s8_ck_known]="github.com in known_hosts"
T_PTBR[s8_ck_auth]="Autenticação SSH no GitHub"
T_EN[s8_ck_auth]="SSH authentication with GitHub"
T_PTBR[s8_next_title]="Próximos passos (pode copiar e colar)"
T_EN[s8_next_title]="Next steps (copy and paste ready)"
T_PTBR[s8_next_clone]="Clonar um repositório por SSH:"
T_EN[s8_next_clone]="Clone a repository over SSH:"
T_PTBR[s8_next_switch]="Trocar um repositório já clonado de HTTPS para SSH (rode dentro da pasta dele):"
T_EN[s8_next_switch]="Switch a repository already cloned over HTTPS to SSH (run inside its folder):"
T_PTBR[s8_next_where]="Ver suas chaves cadastradas (com a data do último uso): %s"
T_EN[s8_next_where]="See your registered keys (with the last-used date): %s"
T_PTBR[s8_done]="Tudo pronto. Bom trabalho!"
T_EN[s8_done]="All set. Have fun!"
T_PTBR[s8_partial]="O assistente terminou, mas alguns itens acima ficaram pendentes. Rode o assistente de novo quando quiser retomar: ele detecta o que já está feito."
T_EN[s8_partial]="The assistant is done, but some items above are still pending. Run it again whenever you want to resume: it detects what is already done."

# --- selftest ----------------------------------------------------------------
T_PTBR[st_ok]="i18n ok: %s chaves em ambas as tabelas."
T_EN[st_ok]="i18n ok: %s keys in both tables."
T_PTBR[st_missing_en]="Faltando em T_EN: %s"
T_EN[st_missing_en]="Missing in T_EN: %s"
T_PTBR[st_missing_pt]="Faltando em T_PTBR: %s"
T_EN[st_missing_pt]="Missing in T_PTBR: %s"
T_PTBR[st_undefined]="Usada no código mas não definida: %s"
T_EN[st_undefined]="Used in code but not defined: %s"
T_PTBR[st_badfmt]="Formato printf inválido nas chaves: %s"
T_EN[st_badfmt]="Invalid printf format in keys: %s"

# -----------------------------------------------------------------------------
# 3. Tradução e saída formatada
# -----------------------------------------------------------------------------

# t <chave> [args...] -> imprime a string traduzida, sem quebra de linha.
t() {
    local key="$1"; shift
    local ref="T_${LANG_SEL:-PTBR}[$key]"
    local fmt=""
    # Checa a existencia antes de desreferenciar: sem isso, uma chave ausente
    # (ou LANG_SEL ainda vazio) derrubaria o script pelo `set -u`.
    if [[ -v "$ref" ]]; then fmt="${!ref}"; fi
    if [[ -z "$fmt" ]]; then
        printf '!!%s!!' "$key"
        return 0
    fi
    # shellcheck disable=SC2059  # o formato vem da tabela de tradução, por design
    printf "$fmt" "$@"
}

# p <chave> [args...] -> linha traduzida com quebra de linha.
p() { t "$@"; printf '\n'; }

setup_colors() {
    if [[ $NO_COLOR_FLAG -eq 1 ]] || [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
        C_RESET="" C_BOLD="" C_DIM="" C_OK="" C_WARN="" C_ERR="" C_INFO="" C_HL=""
    else
        C_RESET=$'\033[0m'  C_BOLD=$'\033[1m'   C_DIM=$'\033[2m'
        C_OK=$'\033[32m'    C_WARN=$'\033[33m'  C_ERR=$'\033[31m'
        C_INFO=$'\033[36m'  C_HL=$'\033[1;36m'
    fi
    # Símbolos: usa UTF-8 quando o terminal suporta, ASCII caso contrário.
    if [[ "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" == *[Uu][Tt][Ff]* ]]; then
        SYM_OK="✔" SYM_ERR="✖" SYM_WARN="⚠" SYM_INFO="ℹ" SYM_TIP="→" SYM_DOT="·"
    else
        SYM_OK="[ok]" SYM_ERR="[x]" SYM_WARN="[!]" SYM_INFO="[i]" SYM_TIP="->" SYM_DOT="-"
    fi
}

ok()   { printf '%s%s%s ' "$C_OK"   "$SYM_OK"   "$C_RESET"; p "$@"; }
err()  { printf '%s%s%s ' "$C_ERR"  "$SYM_ERR"  "$C_RESET"; p "$@"; }
warn() { printf '%s%s%s ' "$C_WARN" "$SYM_WARN" "$C_RESET"; p "$@"; }
info() { printf '%s%s%s ' "$C_INFO" "$SYM_INFO" "$C_RESET"; p "$@"; }
tip()  { printf '%s%s%s ' "$C_DIM"  "$SYM_TIP"  "$C_RESET"; printf '%s' "$C_DIM"; t "$@"; printf '%s\n' "$C_RESET"; }
bullet() { printf '   %s ' "$SYM_DOT"; p "$@"; }

hr() { printf '%s%s%s\n' "$C_DIM" "------------------------------------------------------------------------" "$C_RESET"; }

# Bloco de texto literal destacado (comandos, chaves, trechos de config).
literal() { printf '%s%s%s\n' "$C_HL" "$1" "$C_RESET"; }

banner() {
    printf '\n%s' "$C_BOLD"
    printf '=========================================================================\n'
    printf '  '; t app_title; printf '\n'
    printf '%s' "$C_RESET$C_DIM"
    printf '  '; t app_sub "$VERSION"; printf '\n'
    printf '=========================================================================%s\n\n' "$C_RESET"
}

step_header() {
    local n="$1" key="$2"
    CUR_STEP="$n"
    printf '\n%s' "$C_BOLD"
    printf '%s %s/%s %s ' "$(t step_word)" "$n" "$TOTAL_STEPS" "$SYM_DOT"
    t "$key"
    printf '%s\n' "$C_RESET"
    hr
}

# -----------------------------------------------------------------------------
# 4. Entrada do usuário (sempre pelo fd 3, ligado a /dev/tty)
# -----------------------------------------------------------------------------

die_eof() { printf '\n'; err aborted_eof; exit 130; }

# ask_yes_no <chave> <default:y|n> [args...] -> 0 = sim, 1 = não
ask_yes_no() {
    local key="$1" def="$2"; shift 2
    local suffix ans
    if [[ "$def" == "y" ]]; then suffix="$(t yn_yes_default)"; else suffix="$(t yn_no_default)"; fi
    while true; do
        printf '%s' "$C_BOLD"; t "$key" "$@"; printf '%s %s ' "$C_RESET" "$suffix"
        IFS= read -r ans <&3 || die_eof
        ans="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
        [[ -z "$ans" ]] && ans="$def"
        case "$ans" in
            s|si|sim|y|ye|yes) return 0 ;;
            n|no|nao|não|nop)  return 1 ;;
            *) warn invalid_yn ;;
        esac
    done
}

# ask_input <chave> <default> <nome_da_variável> [required]
ask_input() {
    local key="$1" def="$2" varname="$3" required="${4:-1}"
    local ans
    while true; do
        printf '%s' "$C_BOLD"; t "$key"; printf '%s' "$C_RESET"
        if [[ -n "$def" ]]; then printf '%s [%s]%s' "$C_DIM" "$def" "$C_RESET"; fi
        printf ': '
        IFS= read -r ans <&3 || die_eof
        [[ -z "$ans" ]] && ans="$def"
        if [[ -z "$ans" && "$required" == "1" ]]; then
            warn value_required
            continue
        fi
        printf -v "$varname" '%s' "$ans"
        return 0
    done
}

# ask_choice <chave_pergunta> <nome_da_variável> <chave_opcao1> [chave_opcao2...]
# Grava em <nome_da_variável> o índice escolhido (1..N).
ask_choice() {
    local key="$1" varname="$2"; shift 2
    local opts=("$@") n="$#" i ans
    printf '%s' "$C_BOLD"; t "$key"; printf '%s\n' "$C_RESET"
    for i in "${!opts[@]}"; do
        printf '  %s%s)%s ' "$C_HL" "$((i + 1))" "$C_RESET"; p "${opts[$i]}"
    done
    while true; do
        printf '  > '
        IFS= read -r ans <&3 || die_eof
        ans="$(printf '%s' "$ans" | tr -d '[:space:]')"
        if [[ "$ans" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= n )); then
            printf -v "$varname" '%s' "$ans"
            return 0
        fi
        warn invalid_choice "$n"
    done
}

# ask_choice_raw <chave_pergunta> <nome_da_variável> <texto1> [texto2...]
# Igual ao ask_choice, mas as opções são textos literais (nomes de arquivo etc).
ask_choice_raw() {
    local key="$1" varname="$2"; shift 2
    local opts=("$@") n="$#" i ans
    printf '%s' "$C_BOLD"; t "$key"; printf '%s\n' "$C_RESET"
    for i in "${!opts[@]}"; do
        printf '  %s%s)%s %s\n' "$C_HL" "$((i + 1))" "$C_RESET" "${opts[$i]}"
    done
    while true; do
        printf '  > '
        IFS= read -r ans <&3 || die_eof
        ans="$(printf '%s' "$ans" | tr -d '[:space:]')"
        if [[ "$ans" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= n )); then
            printf -v "$varname" '%s' "$ans"
            return 0
        fi
        warn invalid_choice "$n"
    done
}

pause_enter() {
    local key="${1:-press_enter}"
    local _discard
    printf '\n%s' "$C_DIM"; t "$key"; printf '...%s ' "$C_RESET"
    IFS= read -r _discard <&3 || die_eof
    printf '\n'
}

# -----------------------------------------------------------------------------
# 5. Utilitários
# -----------------------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

# Junta os argumentos com espaço. Necessário porque o IFS deste script não
# contém espaço, então "${array[*]}" sozinho colaria os itens com quebra de linha.
join_sp() { local out="" item; for item in "$@"; do out="${out:+$out }$item"; done; printf '%s' "$out"; }

copy_to_clipboard() {
    [[ -z "$CLIP_CMD" ]] && return 1
    case "$CLIP_CMD" in
        wl-copy) printf '%s' "$1" | wl-copy 2>/dev/null || return 1 ;;
        xclip)   printf '%s' "$1" | xclip -selection clipboard 2>/dev/null || return 1 ;;
        xsel)    printf '%s' "$1" | xsel --clipboard --input 2>/dev/null || return 1 ;;
        *) return 1 ;;
    esac
    return 0
}

fingerprint_of() {
    ssh-keygen -lf "$1" 2>/dev/null | awk '{print $2}'
}

keytype_of() {
    ssh-keygen -lf "$1" 2>/dev/null | awk '{print $NF}' | tr -d '()'
}

has_gui() { [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; }

check_perms() {
    # Retorna 0 se pasta/chaves estiverem com as permissões esperadas.
    [[ -d "$SSH_DIR" ]] || return 1
    [[ "$(stat -c '%a' "$SSH_DIR" 2>/dev/null)" == "700" ]] || return 1
    if [[ -n "$KEY_PATH" && -f "$KEY_PATH" ]]; then
        [[ "$(stat -c '%a' "$KEY_PATH" 2>/dev/null)" == "600" ]] || return 1
    fi
    return 0
}

fix_perms() {
    chmod 700 "$SSH_DIR" 2>/dev/null || true
    [[ -f "$KEY_PATH" ]] && chmod 600 "$KEY_PATH" 2>/dev/null || true
    [[ -f "$KEY_PUB"  ]] && chmod 644 "$KEY_PUB"  2>/dev/null || true
    [[ -f "$SSH_CONFIG" ]] && chmod 600 "$SSH_CONFIG" 2>/dev/null || true
    return 0
}

on_error() {
    local line="$1"
    printf '\n'
    err error_at "$CUR_STEP" "$line"
    exit 1
}

on_int() {
    printf '\n'
    warn aborted_user "$CUR_STEP"
    exit 130
}

# -----------------------------------------------------------------------------
# 6. Passos
# -----------------------------------------------------------------------------

step_1_language() {
    if [[ -n "$LANG_SEL" ]]; then return 0; fi
    CUR_STEP=1
    local sys="${LC_ALL:-${LANG:-}}" choice
    printf '\n%sStep / Passo 1/%s %s Language / Idioma%s\n' "$C_BOLD" "$TOTAL_STEPS" "$SYM_DOT" "$C_RESET"
    hr
    printf '  %s1)%s Portugues (Brasil)\n' "$C_HL" "$C_RESET"
    printf '  %s2)%s English\n' "$C_HL" "$C_RESET"
    local def=2
    [[ "$sys" == pt_BR* || "$sys" == pt* ]] && def=1
    while true; do
        printf '  > [%s] ' "$def"
        IFS= read -r choice <&3 || die_eof
        choice="$(printf '%s' "$choice" | tr -d '[:space:]')"
        [[ -z "$choice" ]] && choice="$def"
        case "$choice" in
            1) LANG_SEL="PTBR"; return 0 ;;
            2) LANG_SEL="EN";   return 0 ;;
            *) printf '  %s%s%s\n' "$C_WARN" "Invalid option / Opcao invalida" "$C_RESET" ;;
        esac
    done
}

detect_missing() {
    # Preenche MISSING_PKGS com os pacotes obrigatórios ausentes (sem repetir).
    MISSING_PKGS=()
    local -A need=( [git]=git [ssh]=openssh-client [ssh-keygen]=openssh-client \
                    [ssh-agent]=openssh-client [ssh-add]=openssh-client [ssh-keyscan]=openssh-client )
    local bin pkg seen=""
    for bin in git ssh ssh-keygen ssh-agent ssh-add ssh-keyscan; do
        pkg="${need[$bin]}"
        if have "$bin"; then
            ok s2_found "$bin"
        else
            err s2_missing "$bin" "$pkg"
            if [[ "$seen" != *"|$pkg|"* ]]; then
                MISSING_PKGS+=("$pkg")
                seen="$seen|$pkg|"
            fi
        fi
    done
    return 0
}

detect_clipboard() {
    CLIP_CMD=""
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && have wl-copy; then
        CLIP_CMD="wl-copy"
    elif [[ -n "${DISPLAY:-}" ]] && have xclip; then
        CLIP_CMD="xclip"
    elif [[ -n "${DISPLAY:-}" ]] && have xsel; then
        CLIP_CMD="xsel"
    elif have wl-copy && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        CLIP_CMD="wl-copy"
    fi
    if [[ -n "$CLIP_CMD" ]]; then
        ok s2_clip_ok "$CLIP_CMD"
    else
        info s2_clip_none
    fi
}

step_2_system() {
    step_header 2 s2_title
    info s2_checking
    printf '\n'

    # --- distribuição ---
    if [[ -r /etc/os-release ]]; then
        local os_id os_name os_ver os_major
        os_id="$(awk -F= '$1=="ID"{gsub(/"/,"",$2); print $2}' /etc/os-release)"
        os_name="$(awk -F= '$1=="NAME"{gsub(/"/,"",$2); print $2}' /etc/os-release)"
        os_ver="$(awk -F= '$1=="VERSION_ID"{gsub(/"/,"",$2); print $2}' /etc/os-release)"
        if [[ "$os_id" == "ubuntu" ]]; then
            ok s2_os_ok "$os_name" "$os_ver"
            os_major="${os_ver%%.*}"
            if [[ "$os_major" =~ ^[0-9]+$ ]] && { (( os_major < 22 )) || (( os_major > 25 )); }; then
                warn s2_os_version_odd "$os_ver"
            fi
        else
            warn s2_os_not_ubuntu "${os_name:-$os_id} ${os_ver:-}"
            tip s2_os_derivative
        fi
    else
        warn s2_os_unknown
    fi
    printf '\n'

    # --- binários obrigatórios ---
    detect_missing
    printf '\n'

    local cmd
    while [[ ${#MISSING_PKGS[@]} -gt 0 ]]; do
        warn s2_need_install
        cmd="sudo apt-get update && sudo apt-get install -y $(join_sp "${MISSING_PKGS[@]}")"
        printf '\n'; p s2_cmd_intro
        literal "  $cmd"
        printf '\n'

        if ! have sudo; then
            warn s2_no_sudo
            p s2_manual_intro
            literal "  $cmd"
            pause_enter press_enter
        elif ask_yes_no s2_ask_install n; then
            info s2_installing
            if sudo apt-get update && sudo apt-get install -y "${MISSING_PKGS[@]}"; then
                ok s2_install_ok
            else
                err s2_install_fail
            fi
        else
            printf '\n'; p s2_manual_intro
            literal "  $cmd"
            pause_enter press_enter
        fi

        printf '\n'; info s2_recheck
        detect_missing
        if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
            printf '\n'; err s2_still_missing "$(join_sp "${MISSING_PKGS[@]}")"
            if ! ask_yes_no s2_retry y; then
                err s2_cannot_continue
                exit 1
            fi
        fi
    done

    ok s2_all_ok
    ST_DEPS=1
    printf '\n'
    detect_clipboard
}

step_3_gitconfig() {
    step_header 3 s3_title
    p s3_intro
    printf '\n'

    local current
    current="$(git config --global --get user.name 2>/dev/null || true)"
    if [[ -n "$current" ]]; then
        ok s3_name_set "$current"
        GIT_NAME="$current"
        if ask_yes_no s3_change_q n; then
            ask_input s3_ask_name "$current" GIT_NAME
            git config --global user.name "$GIT_NAME"
            ok s3_saved "user.name"
        fi
    else
        ask_input s3_ask_name "" GIT_NAME
        git config --global user.name "$GIT_NAME"
        ok s3_saved "user.name"
    fi
    ST_GITNAME=1
    printf '\n'

    current="$(git config --global --get user.email 2>/dev/null || true)"
    local need_email=0
    if [[ -n "$current" ]]; then
        ok s3_mail_set "$current"
        GIT_EMAIL="$current"
        ask_yes_no s3_change_q n && need_email=1
    else
        need_email=1
        tip s3_noreply_tip
        tip s3_noreply_where "$URL_EMAILS"
    fi

    if [[ $need_email -eq 1 ]]; then
        while true; do
            ask_input s3_ask_mail "$current" GIT_EMAIL
            if [[ "$GIT_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
                break
            fi
            warn s3_mail_invalid
        done
        git config --global user.email "$GIT_EMAIL"
        ok s3_saved "user.email"
    fi
    ST_GITMAIL=1
}

step_4_existing_keys() {
    step_header 4 s4_title

    if [[ ! -d "$SSH_DIR" ]]; then
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        ok s4_dir_created "$SSH_DIR"
    else
        chmod 700 "$SSH_DIR" 2>/dev/null || true
    fi

    local pubs=() f
    while IFS= read -r f; do
        [[ -n "$f" ]] && pubs+=("$f")
    done < <(find "$SSH_DIR" -maxdepth 1 -type f -name '*.pub' 2>/dev/null | sort)

    if [[ ${#pubs[@]} -eq 0 ]]; then
        info s4_none "$SSH_DIR"
        KEY_IS_NEW=1
        return 0
    fi

    p s4_found_n "${#pubs[@]}"
    printf '\n'
    local i
    for i in "${!pubs[@]}"; do
        p s4_entry "$((i + 1))" "${pubs[$i]}"
        p s4_entry_info "$(keytype_of "${pubs[$i]}")" "$(fingerprint_of "${pubs[$i]}")"
    done
    printf '\n'

    local choice
    ask_choice s4_choose choice s4_opt_new s4_opt_reuse
    if [[ "$choice" == "1" ]]; then
        KEY_IS_NEW=1
        return 0
    fi

    while true; do
        local pick
        ask_choice_raw s4_pick_existing pick "${pubs[@]}"
        local pub="${pubs[$((pick - 1))]}"
        local priv="${pub%.pub}"
        if [[ ! -f "$priv" ]]; then
            err s4_no_private "$priv"
            continue
        fi
        KEY_PUB="$pub"
        KEY_PATH="$priv"
        KEY_IS_NEW=0
        ok s4_reuse_ok "$KEY_PATH"
        ST_KEY=1
        return 0
    done
}

step_5_generate() {
    step_header 5 s5_title

    if [[ $KEY_IS_NEW -eq 0 ]]; then
        info s5_skip
        fix_perms
        if check_perms; then ST_PERMS=1; fi
        return 0
    fi

    p s5_intro
    printf '\n'

    local default_path="$SSH_DIR/id_ed25519_github"
    while true; do
        ask_input s5_ask_path "$default_path" KEY_PATH
        # Expande ~ manualmente, caso o usuário digite o caminho com til.
        KEY_PATH="${KEY_PATH/#\~/$HOME}"
        if [[ ! -e "$KEY_PATH" && ! -e "$KEY_PATH.pub" ]]; then
            break
        fi
        warn s5_exists "$KEY_PATH"
        if ask_yes_no s5_overwrite_q n; then
            local stamp="bak-$$"
            [[ -e "$KEY_PATH" ]] && { mv "$KEY_PATH" "$KEY_PATH.$stamp"; ok s5_backup_made "$KEY_PATH.$stamp"; }
            [[ -e "$KEY_PATH.pub" ]] && { mv "$KEY_PATH.pub" "$KEY_PATH.pub.$stamp"; ok s5_backup_made "$KEY_PATH.pub.$stamp"; }
            break
        fi
        info s5_pick_other
    done
    KEY_PUB="$KEY_PATH.pub"

    local default_comment="${GIT_EMAIL:-$USER@$(hostname)}"
    local comment
    ask_input s5_ask_comment "$default_comment" comment
    printf '\n'

    p s5_pass_intro
    bullet s5_pass_yes
    bullet s5_pass_no
    printf '\n'
    tip s5_pass_prompt
    printf '\n'
    info s5_generating

    # A senha não é passada por argumento (-N) de propósito: assim ela nunca
    # aparece em `ps` nem no histórico. Quem pergunta é o próprio ssh-keygen.
    if ! ssh-keygen -t ed25519 -C "$comment" -f "$KEY_PATH" <&3; then
        err s5_gen_fail
        exit 1
    fi

    printf '\n'
    ok s5_gen_ok "$KEY_PATH"
    p s5_fingerprint "$(fingerprint_of "$KEY_PUB")"
    fix_perms
    ok s5_perms_ok
    if check_perms; then ST_PERMS=1; fi
    ST_KEY=1
}

build_config_block() {
    printf '%s\n' "$MARK_START"
    printf 'Host github.com\n'
    printf '    HostName github.com\n'
    printf '    User git\n'
    printf '    IdentityFile %s\n' "$KEY_PATH"
    printf '    IdentitiesOnly yes\n'
    printf '    AddKeysToAgent yes\n'
    printf '%s\n' "$MARK_END"
}

setup_ssh_config() {
    printf '\n'
    p s6_cfg_intro
    printf '\n'

    local block
    block="$(build_config_block)"
    p s6_cfg_preview
    printf '\n'
    literal "$block"
    printf '\n'

    local had_block=0 stripped=""
    if [[ -f "$SSH_CONFIG" ]]; then
        if grep -Fq "$MARK_START" "$SSH_CONFIG"; then
            had_block=1
            info s6_cfg_replace
        fi
        # Conteúdo do config sem o nosso bloco antigo.
        stripped="$(awk -v s="$MARK_START" -v e="$MARK_END" '
            $0 == s { skip = 1; next }
            $0 == e { skip = 0; next }
            !skip   { print }
        ' "$SSH_CONFIG")"

        # Alguma configuração própria para github.com fora do nosso bloco?
        if printf '%s\n' "$stripped" | grep -Eiq '^[[:space:]]*Host([[:space:]]|=).*github\.com'; then
            warn s6_cfg_foreign
            printf '\n'
            printf '%s\n' "$stripped" | grep -Ei -A 6 '^[[:space:]]*Host([[:space:]]|=).*github\.com' \
                | sed "s/^/    /" || true
            printf '\n'
            local choice
            ask_choice s6_cfg_foreign_q choice s6_cfg_opt_keep s6_cfg_opt_add
            if [[ "$choice" == "1" ]]; then
                info s6_cfg_kept
                # Se o nosso bloco já estava lá, ele continua valendo.
                [[ $had_block -eq 1 ]] && ST_CONFIG=1
                return 0
            fi
        fi
    fi

    if ! ask_yes_no s6_cfg_ask y "$SSH_CONFIG"; then
        info s6_cfg_kept
        return 0
    fi

    if [[ -f "$SSH_CONFIG" ]]; then
        local backup="$SSH_CONFIG.bak-$$"
        cp -p "$SSH_CONFIG" "$backup"
        ok s6_cfg_backup "$backup"
    fi

    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/ghkeys.XXXXXX")"
    {
        printf '%s\n\n' "$block"
        [[ -n "$stripped" ]] && printf '%s\n' "$stripped"
    } > "$tmp"
    mv "$tmp" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    ok s6_cfg_ok
    ST_CONFIG=1
}

setup_known_hosts() {
    printf '\n'
    p s6_kh_intro
    printf '\n'

    if ssh-keygen -F github.com >/dev/null 2>&1; then
        ok s6_kh_already
        ST_KNOWN=1
        KH_MODE="yes"
        return 0
    fi

    info s6_kh_scanning
    local scanned fp
    scanned="$(ssh-keyscan -t ed25519 github.com 2>/dev/null || true)"
    if [[ -z "$scanned" ]]; then
        err s6_kh_fail
        return 0
    fi
    fp="$(printf '%s\n' "$scanned" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}' | head -n1)"

    printf '\n'
    p s6_kh_got "$fp"
    p s6_kh_expect "$FP_ED25519"
    printf '\n'

    if [[ "$fp" != "$FP_ED25519" ]]; then
        err s6_kh_mismatch
        tip s6_kh_ref "$URL_FINGERPRINTS"
        # Fingerprint suspeita: o teste final nao pode aceitar a chave em
        # silencio. Com "yes" o ssh recusa a conexao em vez de gravar nada.
        KH_MODE="yes"
        return 0
    fi

    ok s6_kh_match
    tip s6_kh_ref "$URL_FINGERPRINTS"
    printf '\n'
    if ask_yes_no s6_kh_ask y; then
        # Só anexa o que ainda não estiver lá: rodar o assistente duas vezes
        # não pode encher o known_hosts de linhas repetidas.
        local line
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if [[ ! -f "$KNOWN_HOSTS" ]] || ! grep -Fqx "$line" "$KNOWN_HOSTS"; then
                printf '%s\n' "$line" >> "$KNOWN_HOSTS"
            fi
        done <<< "$scanned"
        chmod 600 "$KNOWN_HOSTS" 2>/dev/null || true
        ok s6_kh_ok "$KNOWN_HOSTS"
        ST_KNOWN=1
        KH_MODE="yes"
    else
        info s6_kh_skip
    fi
}

step_6_agent_config() {
    step_header 6 s6_title

    # --- ssh-agent ---
    if [[ -n "${SSH_AUTH_SOCK:-}" ]] && ssh-add -l >/dev/null 2>&1; then
        ok s6_agent_running
    elif [[ -n "${SSH_AUTH_SOCK:-}" ]] && [[ -S "${SSH_AUTH_SOCK}" ]]; then
        # Socket existe, agente vazio (ssh-add -l retorna 1 quando não há chaves).
        ok s6_agent_running
    else
        info s6_agent_start
        eval "$(ssh-agent -s)" >/dev/null
        warn s6_agent_temp_warn
    fi

    printf '\n'
    info s6_adding_key
    if ssh-add "$KEY_PATH" <&3; then
        ok s6_add_ok
        ST_AGENT=1
    else
        warn s6_add_fail
    fi

    setup_ssh_config
    setup_known_hosts

    fix_perms
    if check_perms; then ST_PERMS=1; fi
    return 0
}

show_public_key() {
    printf '\n'
    p s7_key_below
    printf '\n'
    hr
    printf '%s' "$C_HL"
    cat "$KEY_PUB"
    printf '%s' "$C_RESET"
    hr
    printf '\n'

    if copy_to_clipboard "$(cat "$KEY_PUB")"; then
        ok copied_clipboard "$CLIP_CMD"
    else
        info copy_manual
    fi
}

step_7_paste_github() {
    step_header 7 s7_title
    p s7_intro
    show_public_key

    printf '\n'
    if has_gui && have xdg-open; then
        if ask_yes_no s7_open_browser_q y; then
            info s7_opening "$URL_NEW_KEY"
            xdg-open "$URL_NEW_KEY" >/dev/null 2>&1 || warn s7_open_fail
        fi
    fi

    printf '\n%s' "$C_BOLD"; t s7_steps_title; printf '%s\n\n' "$C_RESET"
    p s7_step1 "$URL_NEW_KEY"
    p s7_step1b
    printf '\n'
    p s7_step2 "$(printf 'ubuntu-%s-%s' "$(hostname -s 2>/dev/null || printf 'pc')" "$(date +%Y-%m-%d)")"
    printf '\n'
    p s7_step3
    printf '\n'
    p s7_step4
    printf '\n'
    p s7_step5
    printf '\n'
    tip s7_no_account

    pause_enter press_enter_done
}

run_ssh_test() {
    # Guarda a saída do teste em LAST_SSH_OUT; retorna 0 se autenticou.
    local out rc=0
    out="$(ssh -o "StrictHostKeyChecking=$KH_MODE" -o ConnectTimeout=15 \
              -T git@github.com 2>&1 <&3)" || rc=$?
    LAST_SSH_OUT="$out"
    # Importante: neste teste o ssh sai com código 1 mesmo quando dá certo,
    # porque o GitHub aceita a chave e recusa abrir um shell. O que vale é a
    # mensagem "successfully authenticated".
    if printf '%s' "$out" | grep -q "successfully authenticated"; then
        GH_USER="$(printf '%s' "$out" | sed -n 's/^Hi \([^!]*\)!.*/\1/p' | head -n1)"
        return 0
    fi
    return 1
}

show_diagnosis() {
    printf '\n'
    p s8_fail
    printf '\n'
    printf '%s%s%s\n' "$C_DIM" "$LAST_SSH_OUT" "$C_RESET"
    printf '\n'
    p s8_diag
    local diag
    diag="$(ssh -vT -o "StrictHostKeyChecking=$KH_MODE" -o ConnectTimeout=15 git@github.com 2>&1 <&3 \
        | grep -E 'Offering public key|Authentications that can continue|Permission denied|no such identity|Server accepts key' \
        || true)"
    if [[ -n "$diag" ]]; then
        printf '%s%s%s\n' "$C_DIM" "$diag" "$C_RESET"
    else
        printf '%s' "$C_DIM"; p s8_diag_none; printf '%s' "$C_RESET"
    fi
    printf '\n'
    tip s8_cause_hint
}

show_config_dump() {
    printf '\n'
    if [[ -f "$SSH_CONFIG" ]]; then
        p s8_cfg_dump "$SSH_CONFIG"
        hr
        printf '%s' "$C_DIM"; cat "$SSH_CONFIG"; printf '%s' "$C_RESET"
        hr
    else
        warn s8_cfg_absent "$SSH_CONFIG"
    fi
    p s8_key_in_use "$KEY_PATH"
}

ck() {
    # ck <flag> <chave_do_texto>
    if [[ "$1" -eq 1 ]]; then
        printf '  %s%s%s ' "$C_OK" "$SYM_OK" "$C_RESET"
    else
        printf '  %s%s%s ' "$C_ERR" "$SYM_ERR" "$C_RESET"
    fi
    p "$2"
}

step_8_verify() {
    step_header 8 s8_title

    while true; do
        info s8_testing
        [[ "$KH_MODE" == "accept-new" ]] && tip s8_accept_new
        printf '\n'

        if run_ssh_test; then
            ST_AUTH=1
            if [[ -n "$GH_USER" ]]; then
                ok s8_ok "$GH_USER"
            else
                ok s8_ok_generic
            fi
            tip s8_note_exit1
            break
        fi

        show_diagnosis
        printf '\n'
        local choice
        ask_choice s8_what_now choice s8_opt_retry_paste s8_opt_retry_test s8_opt_show_cfg s8_opt_quit
        case "$choice" in
            1) show_public_key; printf '\n'; p s7_step1 "$URL_NEW_KEY"; p s7_step4; pause_enter press_enter_done ;;
            2) printf '\n' ;;
            3) show_config_dump; pause_enter press_enter ;;
            4) break ;;
        esac
    done

    # --- checklist ---
    printf '\n%s' "$C_BOLD"; t s8_checklist; printf '%s\n' "$C_RESET"
    hr
    ck "$ST_DEPS"    s8_ck_deps
    ck "$ST_GITNAME" s8_ck_name
    ck "$ST_GITMAIL" s8_ck_mail
    ck "$ST_KEY"     s8_ck_key
    ck "$ST_PERMS"   s8_ck_perms
    ck "$ST_AGENT"   s8_ck_agent
    ck "$ST_CONFIG"  s8_ck_config
    ck "$ST_KNOWN"   s8_ck_known
    ck "$ST_AUTH"    s8_ck_auth
    hr

    # --- próximos passos ---
    printf '\n%s' "$C_BOLD"; t s8_next_title; printf '%s\n\n' "$C_RESET"
    p s8_next_clone
    literal "  git clone git@github.com:${GH_USER:-usuario}/repositorio.git"
    printf '\n'
    p s8_next_switch
    literal "  git remote set-url origin git@github.com:${GH_USER:-usuario}/repositorio.git"
    printf '\n'
    tip s8_next_where "$URL_KEYS"
    printf '\n'

    if [[ $ST_AUTH -eq 1 ]]; then
        ok s8_done
    else
        warn s8_partial
    fi
}

# -----------------------------------------------------------------------------
# 7. Selftest de i18n (--selftest-i18n)
# -----------------------------------------------------------------------------
selftest_i18n() {
    LANG_SEL="PTBR"
    local k missing_en=() missing_pt=() undefined=() badfmt=() rc=0

    for k in "${!T_PTBR[@]}"; do
        [[ -v "T_EN[$k]" ]] || missing_en+=("$k")
    done
    for k in "${!T_EN[@]}"; do
        [[ -v "T_PTBR[$k]" ]] || missing_pt+=("$k")
    done

    # Toda string passa por printf: um '%' solto ou um especificador inválido
    # só apareceria em tempo de execução, no meio do fluxo. Detecta aqui.
    local fmt
    for k in "${!T_PTBR[@]}"; do
        for fmt in "${T_PTBR[$k]}" "${T_EN[$k]-}"; do
            [[ -z "$fmt" ]] && continue
            # shellcheck disable=SC2059  # o formato é justamente o que está sob teste
            printf "$fmt" "" "" "" >/dev/null 2>&1 || badfmt+=("$k")
        done
    done

    # Chaves referenciadas no código (primeiro argumento das funções de saída).
    local used
    used="$(grep -oE '(^|[[:space:]])(t|p|ok|err|warn|info|tip|bullet|ck|step_header|pause_enter|ask_yes_no|ask_input|ask_choice)[[:space:]]+"?[a-z][a-z0-9_]*' "$0" \
        | awk '{print $NF}' | tr -d '"' | sort -u)"
    local candidate
    while IFS= read -r candidate; do
        [[ -z "$candidate" ]] && continue
        # Ignora nomes que são claramente de função/variável, não chaves.
        [[ -v "T_PTBR[$candidate]" ]] && continue
        case "$candidate" in
            s[0-9]_*|st_*|help_*|yn_*|app_*|invalid_*|value_*|press_*|aborted_*|error_*|no_*|bash_*|is_*|cancelled|copied_*|copy_*|step_word|bad_flag)
                undefined+=("$candidate") ;;
        esac
    done <<< "$used"

    if [[ ${#missing_en[@]} -gt 0 ]]; then p st_missing_en "$(join_sp "${missing_en[@]}")"; rc=1; fi
    if [[ ${#missing_pt[@]} -gt 0 ]]; then p st_missing_pt "$(join_sp "${missing_pt[@]}")"; rc=1; fi
    if [[ ${#undefined[@]}  -gt 0 ]]; then p st_undefined  "$(join_sp "${undefined[@]}")";  rc=1; fi
    if [[ ${#badfmt[@]}     -gt 0 ]]; then p st_badfmt     "$(join_sp "${badfmt[@]}")";     rc=1; fi
    [[ $rc -eq 0 ]] && p st_ok "${#T_PTBR[@]}"
    return $rc
}

# -----------------------------------------------------------------------------
# 8. Argumentos e main
# -----------------------------------------------------------------------------
show_help() {
    [[ -z "$LANG_SEL" ]] && LANG_SEL="PTBR"
    printf '%s %s\n\n' "$PROG_NAME" "$VERSION"
    p help_usage
    printf '\n'
    p help_lang
    p help_nocolor
    p help_help
    p help_version
    printf '\n'
    p help_what
    printf '\n'
    p help_not
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lang)
                shift
                case "${1:-}" in
                    pt-br|pt_BR|pt|ptbr) LANG_SEL="PTBR" ;;
                    en|en-us|en_US)      LANG_SEL="EN" ;;
                    *) LANG_SEL="PTBR"; printf 'Invalid --lang value, using pt-br\n' ;;
                esac
                ;;
            --no-color) NO_COLOR_FLAG=1 ;;
            -h|--help)  setup_colors; show_help; exit 0 ;;
            --version)  printf '%s %s\n' "$PROG_NAME" "$VERSION"; exit 0 ;;
            --selftest-i18n) setup_colors; selftest_i18n; exit $? ;;
            *) setup_colors; LANG_SEL="${LANG_SEL:-PTBR}"; err bad_flag "$1"; show_help; exit 2 ;;
        esac
        shift
    done
}

main() {
    trap 'on_error $LINENO' ERR
    trap 'on_int' INT TERM

    parse_args "$@"
    setup_colors

    # bash 4.3+ (arrays associativos + [[ -v arr[k] ]])
    if (( BASH_VERSINFO[0] < 4 )) || { (( BASH_VERSINFO[0] == 4 )) && (( BASH_VERSINFO[1] < 3 )); }; then
        LANG_SEL="${LANG_SEL:-PTBR}"
        err bash_old "${BASH_VERSION}"
        exit 1
    fi

    # Todo input do usuário vem do terminal, nunca do stdin: assim o assistente
    # continua interativo mesmo se for executado via pipe.
    if [[ ! -r /dev/tty ]]; then
        LANG_SEL="${LANG_SEL:-PTBR}"
        err no_tty
        tip no_tty_hint
        exit 1
    fi
    exec 3</dev/tty

    # A escolha do idioma vem antes do banner: só depois dela há um idioma
    # para apresentar o assistente.
    step_1_language
    banner

    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        warn is_root
        tip is_root_why
    fi

    step_2_system
    step_3_gitconfig
    step_4_existing_keys
    step_5_generate
    step_6_agent_config
    step_7_paste_github
    step_8_verify

    printf '\n'
    exec 3<&-
}

main "$@"
