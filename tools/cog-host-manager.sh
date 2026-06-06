#!/bin/sh

# Cog Host Manager
# POSIX shell entrypoint for panel/daemon installation and egg importing.

set -u

APP_NAME="Cog Host Manager"
VERSION="0.1.0"
LANG_CHOICE="pt"
DRY_RUN=0
FORCE=0
COG_EOF=0
COG_LANG_PRESET="${COG_LANG_PRESET:-0}"
SCRIPT_URL="https://raw.githubusercontent.com/hiudyy/pteroeggs/main/tools/cog-host-manager.sh"
PHP_IMPORT_URL="https://raw.githubusercontent.com/hiudyy/pteroeggs/main/tools/import-linguagens.php"

PANEL_PRODUCT=""
PANEL_NAME=""
PANEL_DIR=""
PANEL_DOMAIN=""
PANEL_SSL="no"
PANEL_SSL_EMAIL=""
PANEL_URL=""
PANEL_DB_MODE="local"
PANEL_DB_HOST="127.0.0.1"
PANEL_DB_PORT="3306"
PANEL_DB_CONNECTION="mysql"
PANEL_DB_NAME="panel"
PANEL_DB_USER="panel"
PANEL_DB_PASS=""
PANEL_DB_ROOT_PASS=""
PANEL_ADMIN_EMAIL=""
PANEL_ADMIN_USER="admin"
PANEL_ADMIN_FIRST="Admin"
PANEL_ADMIN_LAST="User"
PANEL_ADMIN_PASS=""
PANEL_TIMEZONE="UTC"
PANEL_APP_LOCALE="en"
PANEL_LOG_CHANNEL="stack"
PANEL_LOG_LEVEL="info"
PANEL_TELEMETRY="false"
PANEL_MAIL_MODE="mail"
PANEL_SMTP_HOST=""
PANEL_SMTP_PORT="587"
PANEL_SMTP_USER=""
PANEL_SMTP_PASS=""
PANEL_SMTP_ENCRYPTION="tls"
PANEL_MAIL_FROM=""
PANEL_MAIL_FROM_NAME="Cog Host Manager"
PANEL_IMPORT_EGGS="no"
PANEL_PHP_VERSION="8.3"
PANEL_QUEUE_SERVICE=""
PANEL_RELEASE_REPO=""
PANEL_RELEASE_ASSET="panel.tar.gz"
PANEL_NEEDS_NODE="no"
PANEL_WARN=""
PANEL_SERVICE_AUTHOR=""
PANEL_TRUSTED_PROXIES=""
PANEL_REDIS_HOST="127.0.0.1"
PANEL_REDIS_PORT="6379"
PANEL_REDIS_PASS=""
PANEL_WEB_USER="www-data"
PANEL_WEB_GROUP="www-data"
PANEL_FOLLOWUP=""
PANEL_SETUP_MODE="auto"

DAEMON_PRODUCT=""
DAEMON_NAME=""
DAEMON_DOMAIN=""
DAEMON_SSL="no"
DAEMON_SSL_EMAIL=""
DAEMON_CONFIG_DIR=""
DAEMON_CONFIG_FILE=""
DAEMON_BINARY=""
DAEMON_SERVICE=""
DAEMON_RELEASE_REPO=""
DAEMON_ASSET_PREFIX=""
DAEMON_DATA_DIR="/var/lib/pterodactyl/volumes"
DAEMON_RUNTIME_DIR="/var/run/wings"
DAEMON_PID_FILE="/var/run/wings/daemon.pid"
DAEMON_INSTALL_DOCKER="yes"
DAEMON_CONFIG_MODE="paste"
DAEMON_AUTODEPLOY_CMD=""
DAEMON_START_NOW="yes"
DAEMON_WARN=""
DAEMON_INSTALL_RUSTIC="no"
DAEMON_CREATE_SYSTEM_USER="no"
DAEMON_SYSTEM_USER="root"
DAEMON_VALIDATE_HINT="yes"
DAEMON_REUSE_PANEL_CERT="no"

t() {
    key="$1"
    case "$LANG_CHOICE:$key" in
        pt:select_language) printf '%s\n' 'Selecione o idioma / Select language' ;;
        en:select_language) printf '%s\n' 'Select language / Selecione o idioma' ;;
        pt:invalid_option) printf '%s\n' 'Opcao invalida.' ;;
        en:invalid_option) printf '%s\n' 'Invalid option.' ;;
        pt:main_title) printf '%s\n' "$APP_NAME" ;;
        en:main_title) printf '%s\n' "$APP_NAME" ;;
        pt:menu_import) printf '%s\n' '1) Importar eggs' ;;
        en:menu_import) printf '%s\n' '1) Import eggs' ;;
        pt:menu_panel) printf '%s\n' '2) Instalar painel' ;;
        en:menu_panel) printf '%s\n' '2) Install panel' ;;
        pt:menu_daemon) printf '%s\n' '3) Instalar Wings/daemon' ;;
        en:menu_daemon) printf '%s\n' '3) Install Wings/daemon' ;;
        pt:menu_combined) printf '%s\n' '4) Instalar painel + Wings/daemon na mesma maquina' ;;
        en:menu_combined) printf '%s\n' '4) Install panel + Wings/daemon on same machine' ;;
        pt:menu_exit) printf '%s\n' '0) Sair' ;;
        en:menu_exit) printf '%s\n' '0) Exit' ;;
        pt:choose_option) printf '%s' 'Escolha uma opcao' ;;
        en:choose_option) printf '%s' 'Choose an option' ;;
        pt:bye) printf '%s\n' 'Saindo. Nenhuma acao sera executada.' ;;
        en:bye) printf '%s\n' 'Exiting. No action will be executed.' ;;
        pt:need_root) printf '%s\n' 'Esta acao precisa ser executada como root.' ;;
        en:need_root) printf '%s\n' 'This action must be run as root.' ;;
        pt:unsupported_os) printf '%s\n' 'Sistema nao suportado para instalacao automatica. Use Ubuntu/Debian com apt.' ;;
        en:unsupported_os) printf '%s\n' 'Unsupported system for automatic installation. Use Ubuntu/Debian with apt.' ;;
        pt:summary) printf '%s\n' 'Resumo' ;;
        en:summary) printf '%s\n' 'Summary' ;;
        pt:confirm_continue) printf '%s' 'Continuar?' ;;
        en:confirm_continue) printf '%s' 'Continue?' ;;
        pt:cancelled) printf '%s\n' 'Operacao cancelada.' ;;
        en:cancelled) printf '%s\n' 'Operation cancelled.' ;;
        pt:done) printf '%s\n' 'Concluido.' ;;
        en:done) printf '%s\n' 'Done.' ;;
        *) printf '%s\n' "$key" ;;
    esac
}

log() { printf '%s\n' "[+] $*"; }
warn() { printf '%s\n' "[!] $*" >&2; }
err() { printf '%s\n' "[-] $*" >&2; }
die() { err "$*"; exit 1; }

run() {
    log "$*"
    if [ "$DRY_RUN" = "1" ]; then
        return 0
    fi
    "$@"
}

prompt() {
    label="$1"
    default="$2"
    if [ -n "$default" ]; then
        printf '%s [%s]: ' "$label" "$default" >&2
    else
        printf '%s: ' "$label" >&2
    fi
    if ! IFS= read -r answer; then
        answer=""
        COG_EOF=1
        [ -n "$default" ] || return 1
    fi
    if [ -z "$answer" ]; then
        printf '%s' "$default"
    else
        printf '%s' "$answer"
    fi
}

prompt_required() {
    label="$1"
    default="$2"
    while :; do
        value=$(prompt "$label" "$default") || return 1
        if [ -n "$value" ]; then
            printf '%s' "$value"
            return 0
        fi
        warn "Required value."
    done
}

prompt_secret() {
    label="$1"
    default="$2"
    printf '%s' "$label" >&2
    if [ -n "$default" ]; then
        printf ' [generated/hidden]' >&2
    fi
    printf ': ' >&2
    if command -v stty >/dev/null 2>&1; then
        stty -echo 2>/dev/null || true
        if ! IFS= read -r answer; then
            answer=""
            COG_EOF=1
        fi
        stty echo 2>/dev/null || true
        printf '\n' >&2
    else
        if ! IFS= read -r answer; then
            answer=""
            COG_EOF=1
        fi
    fi
    if [ -z "$answer" ]; then
        printf '%s' "$default"
    else
        printf '%s' "$answer"
    fi
}

confirm() {
    label="$1"
    default="$2"
    if [ "$LANG_CHOICE" = "en" ]; then
        suffix="y/N"
        [ "$default" = "yes" ] && suffix="Y/n"
    else
        suffix="s/N"
        [ "$default" = "yes" ] && suffix="S/n"
    fi
    printf '%s [%s]: ' "$label" "$suffix" >&2
    if ! IFS= read -r answer; then
        answer=""
        COG_EOF=1
    fi
    if [ -z "$answer" ]; then
        answer="$default"
    fi
    case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
        y|yes|s|sim) return 0 ;;
        *) return 1 ;;
    esac
}

random_password() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 24 | tr -d '/+=' | cut -c1-24
        return
    fi
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24
}

mask() {
    value="$1"
    if [ -z "$value" ]; then
        printf '%s' '(empty)'
    else
        printf '%s' '********'
    fi
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --lang=*) LANG_CHOICE=$(printf '%s' "${1#--lang=}" | tr '[:upper:]' '[:lower:]'); COG_LANG_PRESET=1 ;;
            --dry-run) DRY_RUN=1 ;;
            --force) FORCE=1 ;;
            --help|-h) usage; exit 0 ;;
            *) warn "Unknown option: $1" ;;
        esac
        shift
    done
    case "$LANG_CHOICE" in
        pt|br|pt-br) LANG_CHOICE="pt" ;;
        en|eng|en-us) LANG_CHOICE="en" ;;
        *)
            if [ "$COG_LANG_PRESET" = "1" ]; then
                die "Invalid --lang value. Use pt or en."
            fi
            LANG_CHOICE="pt"
            ;;
    esac
}

usage() {
    cat <<'EOF'
Cog Host Manager

Usage:
  sh tools/cog-host-manager.sh [--lang=pt|en] [--dry-run]

Options:
  --lang=pt|en   Interface language.
  --dry-run      Print actions without executing installers.
  --force        Reserved for future non-interactive flows.
  --help         Show help.
EOF
}

choose_language() {
    if [ "$LANG_CHOICE" = "pt" ] || [ "$LANG_CHOICE" = "en" ]; then
        # If provided by --lang, do not ask. With default pt and interactive stdin,
        # ask anyway unless COG_LANG_PRESET is set by tests/users.
        if [ "$COG_LANG_PRESET" = "1" ]; then
            return
        fi
    fi
    printf '\n'
    t select_language
    printf '%s\n' '1) Portugues'
    printf '%s\n' '2) English'
    printf 'pt/en [pt]: '
    if ! IFS= read -r answer; then
        answer=""
        COG_EOF=1
    fi
    answer=$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')
    case "$answer" in
        2|en|eng|english|ingles) LANG_CHOICE="en" ;;
        *) LANG_CHOICE="pt" ;;
    esac
}

main_menu() {
    while :; do
        printf '\n'
        t main_title
        t menu_import
        t menu_panel
        t menu_daemon
        t menu_combined
        t menu_exit
        printf '\n'
        choice=$(prompt "$(t choose_option)" "") || { t bye; return 0; }
        case "$choice" in
            1) import_eggs_flow ;;
            2) install_panel_menu ;;
            3) install_daemon_menu ;;
            4) install_combined_menu ;;
            0) t bye; return 0 ;;
            *) t invalid_option ;;
        esac
    done
}

require_root() {
    [ "$DRY_RUN" = "1" ] && return 0
    [ "$(id -u)" = "0" ] || die "$(t need_root)"
}

detect_os() {
    OS_ID=""
    OS_VERSION=""
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-}"
        OS_VERSION="${VERSION_ID:-}"
    fi
    case "$OS_ID" in
        ubuntu|debian) return 0 ;;
        *)
            if [ "$DRY_RUN" = "1" ]; then
                OS_ID="ubuntu"
                OS_VERSION="dry-run"
                return 0
            fi
            return 1
            ;;
    esac
}

detect_arch() {
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) printf '%s' 'amd64' ;;
        aarch64|arm64) printf '%s' 'arm64' ;;
        *) [ "$DRY_RUN" = "1" ] && { printf '%s' 'amd64'; return 0; }; die "Unsupported architecture: $arch" ;;
    esac
}

backup_file() {
    file="$1"
    if [ -e "$file" ]; then
        ts=$(date +%Y%m%d%H%M%S)
        backup_dir="/var/backups/cog-host-manager/$ts"
        run mkdir -p "$backup_dir"
        run cp -a "$file" "$backup_dir/"
        log "Backup: $file -> $backup_dir"
    fi
}

write_file() {
    file="$1"
    backup_file "$file"
    if [ "$DRY_RUN" = "1" ]; then
        log "Would write $file"
        cat >/dev/null
        return 0
    fi
    tmp="$file.tmp.$$"
    cat >"$tmp"
    mv "$tmp" "$file"
}

set_env_value() {
    key="$1"
    value="$2"
    file="$3"
    formatted=$(format_env_value "$value")
    escaped=$(printf '%s' "$formatted" | sed 's/[\\&|]/\\&/g')
    if [ -f "$file" ] && grep -q "^$key=" "$file"; then
        if [ "$DRY_RUN" = "1" ]; then
            log "Would set $key in $file"
        else
            sed -i "s|^$key=.*|$key=$escaped|" "$file"
        fi
    else
        if [ "$DRY_RUN" = "1" ]; then
            log "Would append $key to $file"
        else
            printf '%s=%s\n' "$key" "$formatted" >>"$file"
        fi
    fi
}

format_env_value() {
    value="$1"
    case "$value" in
        true|false|null|TRUE|FALSE|NULL) printf '%s' "$value" ;;
        ''|*[!A-Za-z0-9_./:@%+-]*)
            escaped=$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g')
            printf '"%s"' "$escaped"
            ;;
        *) printf '%s' "$value" ;;
    esac
}

product_panel_specs() {
    PANEL_PRODUCT="$1"
    PANEL_DOMAIN=""
    PANEL_SSL="no"
    PANEL_SSL_EMAIL=""
    PANEL_URL=""
    PANEL_DB_MODE="local"
    PANEL_DB_CONNECTION="mysql"
    PANEL_DB_HOST="127.0.0.1"
    PANEL_DB_PORT="3306"
    PANEL_DB_PASS=""
    PANEL_DB_ROOT_PASS=""
    PANEL_ADMIN_EMAIL=""
    PANEL_ADMIN_USER="admin"
    PANEL_ADMIN_FIRST="Admin"
    PANEL_ADMIN_LAST="User"
    PANEL_ADMIN_PASS=""
    PANEL_TIMEZONE="UTC"
    PANEL_APP_LOCALE="en"
    PANEL_LOG_CHANNEL="stack"
    PANEL_LOG_LEVEL="info"
    PANEL_TELEMETRY="false"
    PANEL_MAIL_MODE="mail"
    PANEL_SMTP_HOST=""
    PANEL_SMTP_PORT="587"
    PANEL_SMTP_USER=""
    PANEL_SMTP_PASS=""
    PANEL_SMTP_ENCRYPTION="tls"
    PANEL_MAIL_FROM=""
    PANEL_MAIL_FROM_NAME="Cog Host Manager"
    PANEL_IMPORT_EGGS="no"
    PANEL_SERVICE_AUTHOR=""
    PANEL_TRUSTED_PROXIES=""
    PANEL_REDIS_HOST="127.0.0.1"
    PANEL_REDIS_PORT="6379"
    PANEL_REDIS_PASS=""
    PANEL_WEB_USER="www-data"
    PANEL_WEB_GROUP="www-data"
    PANEL_WARN=""
    PANEL_NEEDS_NODE="no"
    PANEL_FOLLOWUP=""
    PANEL_SETUP_MODE="auto"
    case "$PANEL_PRODUCT" in
        pterodactyl)
            PANEL_NAME="Pterodactyl"
            PANEL_DIR="/var/www/pterodactyl"
            PANEL_DB_NAME="panel"
            PANEL_DB_USER="pterodactyl"
            PANEL_PHP_VERSION="8.3"
            PANEL_QUEUE_SERVICE="pteroq"
            PANEL_RELEASE_REPO="pterodactyl/panel"
            PANEL_DB_CONNECTION="mysql"
            ;;
        pelican)
            PANEL_NAME="Pelican"
            PANEL_DIR="/var/www/pelican"
            PANEL_DB_NAME="pelican"
            PANEL_DB_USER="pelican"
            PANEL_PHP_VERSION="8.5"
            PANEL_QUEUE_SERVICE="pelican-queue"
            PANEL_RELEASE_REPO="pelican-dev/panel"
            PANEL_WARN="Pelican is beta software and can require product-specific setup through /installer after files are installed."
            PANEL_FOLLOWUP="Open /installer after install to finish Pelican setup, then import eggs from the main menu if the web installer was required."
            PANEL_SETUP_MODE="wizard"
            ;;
        reviactyl)
            PANEL_NAME="Reviactyl"
            PANEL_DIR="/var/www/reviactyl"
            PANEL_DB_NAME="reviactyl"
            PANEL_DB_USER="reviactyl"
            PANEL_PHP_VERSION="8.5"
            PANEL_QUEUE_SERVICE="reviq"
            PANEL_RELEASE_REPO="reviactyl/panel"
            PANEL_WARN="Reviactyl is in active development; this is an experimental generic Laravel-style install. Verify upstream docs before production use."
            PANEL_FOLLOWUP="Open the Reviactyl setup wizard or follow upstream post-install docs before importing eggs."
            PANEL_SETUP_MODE="wizard"
            ;;
        pyrodactyl)
            PANEL_NAME="Pyrodactyl"
            PANEL_DIR="/var/www/pyrodactyl"
            PANEL_DB_NAME="panel"
            PANEL_DB_USER="pyrodactyl"
            PANEL_PHP_VERSION="8.4"
            PANEL_QUEUE_SERVICE="pyroq"
            PANEL_RELEASE_REPO="pyrodactyl-oss/pyrodactyl"
            PANEL_NEEDS_NODE="yes"
            PANEL_WARN="Pyrodactyl is pre-release/development software; this install may need fork-specific post-install steps."
            PANEL_FOLLOWUP="Verify Pyrodactyl-specific post-install steps in upstream docs."
            ;;
        *) die "Unknown panel product: $PANEL_PRODUCT" ;;
    esac
}

product_daemon_specs() {
    DAEMON_PRODUCT="$1"
    DAEMON_DOMAIN=""
    DAEMON_SSL="no"
    DAEMON_SSL_EMAIL=""
    DAEMON_DATA_DIR="/var/lib/pterodactyl/volumes"
    DAEMON_INSTALL_DOCKER="yes"
    DAEMON_CONFIG_MODE="paste"
    DAEMON_AUTODEPLOY_CMD=""
    DAEMON_START_NOW="yes"
    DAEMON_INSTALL_RUSTIC="no"
    DAEMON_CREATE_SYSTEM_USER="no"
    DAEMON_SYSTEM_USER="root"
    DAEMON_VALIDATE_HINT="yes"
    DAEMON_REUSE_PANEL_CERT="no"
    DAEMON_WARN=""
    case "$DAEMON_PRODUCT" in
        pterodactyl)
            DAEMON_NAME="Pterodactyl Wings"
            DAEMON_CONFIG_DIR="/etc/pterodactyl"
            DAEMON_CONFIG_FILE="/etc/pterodactyl/config.yml"
            DAEMON_BINARY="/usr/local/bin/wings"
            DAEMON_SERVICE="wings"
            DAEMON_RELEASE_REPO="pterodactyl/wings"
            DAEMON_ASSET_PREFIX="wings"
            DAEMON_RUNTIME_DIR="/var/run/wings"
            DAEMON_PID_FILE="/var/run/wings/daemon.pid"
            DAEMON_SYSTEM_USER="root"
            ;;
        pelican)
            DAEMON_NAME="Pelican Wings"
            DAEMON_CONFIG_DIR="/etc/pelican"
            DAEMON_CONFIG_FILE="/etc/pelican/config.yml"
            DAEMON_BINARY="/usr/local/bin/wings"
            DAEMON_SERVICE="wings"
            DAEMON_RELEASE_REPO="pelican-dev/wings"
            DAEMON_ASSET_PREFIX="wings"
            DAEMON_RUNTIME_DIR="/var/run/wings"
            DAEMON_PID_FILE="/var/run/wings/daemon.pid"
            DAEMON_SYSTEM_USER="root"
            ;;
        reviactyl)
            DAEMON_NAME="Reviactyl Agent"
            DAEMON_CONFIG_DIR="/etc/reviactyl"
            DAEMON_CONFIG_FILE="/etc/reviactyl/config.yml"
            DAEMON_BINARY="/usr/local/bin/agent"
            DAEMON_SERVICE="agent"
            DAEMON_RELEASE_REPO="reviactyl/agent"
            DAEMON_ASSET_PREFIX="agent"
            DAEMON_RUNTIME_DIR="/var/run/agent"
            DAEMON_PID_FILE="/var/run/agent/daemon.pid"
            DAEMON_SYSTEM_USER="root"
            DAEMON_WARN="Reviactyl Agent is in active development; verify upstream daemon docs before production use."
            ;;
        pyrodactyl)
            DAEMON_NAME="Pyrodactyl Elytra"
            DAEMON_CONFIG_DIR="/etc/elytra"
            DAEMON_CONFIG_FILE="/etc/elytra/config.yml"
            DAEMON_BINARY="/usr/local/bin/elytra"
            DAEMON_SERVICE="elytra"
            DAEMON_RELEASE_REPO="pyrohost/elytra"
            DAEMON_ASSET_PREFIX="elytra"
            DAEMON_RUNTIME_DIR="/var/run/elytra"
            DAEMON_PID_FILE="/var/run/elytra/daemon.pid"
            DAEMON_SYSTEM_USER="root"
            DAEMON_WARN="Elytra is a maintained Pyrodactyl daemon; verify panel compatibility. Optional rustic backup support and a pyrodactyl user can be configured."
            ;;
        *) die "Unknown daemon product: $DAEMON_PRODUCT" ;;
    esac
}

choose_panel_product() {
    printf '\n%s\n' "Install panel" >&2
    printf '%s\n' '1) Pterodactyl' >&2
    printf '%s\n' '2) Pelican' >&2
    printf '%s\n' '3) Reviactyl' >&2
    printf '%s\n' '4) Pyrodactyl' >&2
    printf '%s\n' '0) Back' >&2
    choice=$(prompt "$(t choose_option)" "") || { printf '%s' ''; return 0; }
    case "$choice" in
        1) printf '%s' 'pterodactyl' ;;
        2) printf '%s' 'pelican' ;;
        3) printf '%s' 'reviactyl' ;;
        4) printf '%s' 'pyrodactyl' ;;
        0) printf '%s' '' ;;
        *) t invalid_option >&2; printf '%s' '' ;;
    esac
}

choose_daemon_product() {
    printf '\n%s\n' "Install Wings/daemon" >&2
    printf '%s\n' '1) Pterodactyl Wings' >&2
    printf '%s\n' '2) Pelican Wings' >&2
    printf '%s\n' '3) Reviactyl Agent' >&2
    printf '%s\n' '4) Pyrodactyl Elytra' >&2
    printf '%s\n' '0) Back' >&2
    choice=$(prompt "$(t choose_option)" "") || { printf '%s' ''; return 0; }
    case "$choice" in
        1) printf '%s' 'pterodactyl' ;;
        2) printf '%s' 'pelican' ;;
        3) printf '%s' 'reviactyl' ;;
        4) printf '%s' 'pyrodactyl' ;;
        0) printf '%s' '' ;;
        *) t invalid_option >&2; printf '%s' '' ;;
    esac
}

recommended_daemon_for_panel() {
    case "$1" in
        pterodactyl) printf '%s' 'pterodactyl' ;;
        pelican) printf '%s' 'pelican' ;;
        reviactyl) printf '%s' 'reviactyl' ;;
        pyrodactyl) printf '%s' 'pyrodactyl' ;;
        *) printf '%s' '' ;;
    esac
}

choose_daemon_for_panel() {
    recommended="$1"
    product_daemon_specs "$recommended"
    recommended_name="$DAEMON_NAME"
    printf '\n%s\n' "Install daemon for $PANEL_NAME" >&2
    printf '1) Recommended: %s\n' "$recommended_name" >&2
    printf '%s\n' '2) Choose another daemon' >&2
    printf '%s\n' '0) Back' >&2
    choice=$(prompt "$(t choose_option)" "1") || { printf '%s' ''; return 0; }
    case "$choice" in
        1|'') printf '%s' "$recommended" ;;
        2) choose_daemon_product ;;
        0) printf '%s' '' ;;
        *) t invalid_option >&2; printf '%s' '' ;;
    esac
}

prepare_same_machine_daemon_defaults() {
    [ -n "$PANEL_DOMAIN" ] && DAEMON_DOMAIN="$PANEL_DOMAIN"
    DAEMON_SSL="$PANEL_SSL"
    DAEMON_SSL_EMAIL="$PANEL_SSL_EMAIL"
    DAEMON_INSTALL_DOCKER="yes"
    DAEMON_START_NOW="yes"
    if [ "$PANEL_SETUP_MODE" = "wizard" ]; then
        DAEMON_CONFIG_MODE="skip"
        DAEMON_START_NOW="no"
    else
        DAEMON_CONFIG_MODE="paste"
    fi
    update_daemon_cert_reuse
}

update_daemon_cert_reuse() {
    DAEMON_REUSE_PANEL_CERT="no"
    if [ "$PANEL_SSL" = "yes" ] && [ "$DAEMON_SSL" = "yes" ] && [ "$DAEMON_DOMAIN" = "$PANEL_DOMAIN" ]; then
        DAEMON_REUSE_PANEL_CERT="yes"
    fi
}

install_panel_menu() {
    product=$(choose_panel_product)
    [ -n "$product" ] || return 0
    product_panel_specs "$product"
    if [ -n "$PANEL_WARN" ]; then
        warn "$PANEL_WARN"
        confirm "Acknowledge warning" "no" || { t cancelled; return 0; }
    fi
    collect_panel_inputs || { t cancelled; return 0; }
    show_panel_summary
    if confirm "$(t confirm_continue)" "no"; then
        install_panel
    else
        t cancelled
    fi
}

install_daemon_menu() {
    product=$(choose_daemon_product)
    [ -n "$product" ] || return 0
    product_daemon_specs "$product"
    if [ -n "$DAEMON_WARN" ]; then
        warn "$DAEMON_WARN"
        confirm "Acknowledge warning" "no" || { t cancelled; return 0; }
    fi
    collect_daemon_inputs || { t cancelled; return 0; }
    show_daemon_summary
    if confirm "$(t confirm_continue)" "no"; then
        install_daemon
    else
        t cancelled
    fi
}

install_combined_menu() {
    panel_product=$(choose_panel_product)
    [ -n "$panel_product" ] || return 0
    product_panel_specs "$panel_product"
    if [ -n "$PANEL_WARN" ]; then
        warn "$PANEL_WARN"
        confirm "Acknowledge warning" "no" || { t cancelled; return 0; }
    fi
    collect_panel_inputs || { t cancelled; return 0; }

    recommended_daemon=$(recommended_daemon_for_panel "$panel_product")
    daemon_product=$(choose_daemon_for_panel "$recommended_daemon")
    [ -n "$daemon_product" ] || { t cancelled; return 0; }
    product_daemon_specs "$daemon_product"
    if [ -n "$DAEMON_WARN" ]; then
        warn "$DAEMON_WARN"
        confirm "Acknowledge warning" "no" || { t cancelled; return 0; }
    fi
    prepare_same_machine_daemon_defaults
    collect_daemon_inputs || { t cancelled; return 0; }
    update_daemon_cert_reuse

    show_combined_summary
    if confirm "$(t confirm_continue)" "no"; then
        install_combined
    else
        t cancelled
    fi
}

collect_panel_inputs() {
    PANEL_DOMAIN=$(prompt_required "Domain/FQDN" "$PANEL_DOMAIN") || return 1
    PANEL_SSL=$(prompt "Use SSL? (yes/no)" "yes")
    case "$PANEL_SSL" in y|Y|yes|s|S|sim) PANEL_SSL="yes" ;; *) PANEL_SSL="no" ;; esac
    if [ "$PANEL_SSL" = "yes" ]; then
        PANEL_SSL_EMAIL=$(prompt_required "Email for Let's Encrypt" "$PANEL_SSL_EMAIL") || return 1
        PANEL_URL="https://$PANEL_DOMAIN"
    else
        PANEL_URL="http://$PANEL_DOMAIN"
    fi
    PANEL_DIR=$(prompt "Install directory" "$PANEL_DIR")
    PANEL_TIMEZONE=$(prompt "Timezone" "$PANEL_TIMEZONE")
    PANEL_APP_LOCALE=$(prompt "App locale" "$PANEL_APP_LOCALE")
    PANEL_PHP_VERSION=$(prompt "PHP version" "$PANEL_PHP_VERSION")
    PANEL_TELEMETRY=$(prompt "Enable telemetry? (true/false)" "$PANEL_TELEMETRY")
    case "$PANEL_TELEMETRY" in y|Y|yes|s|S|sim|true|1) PANEL_TELEMETRY="true" ;; *) PANEL_TELEMETRY="false" ;; esac
    PANEL_DB_MODE=$(prompt "Database mode (local/external)" "$PANEL_DB_MODE")
    case "$PANEL_DB_MODE" in external|remote) PANEL_DB_MODE="external" ;; *) PANEL_DB_MODE="local" ;; esac
    if [ "$PANEL_DB_MODE" = "local" ]; then
        PANEL_DB_CONNECTION="mysql"
        PANEL_DB_HOST="127.0.0.1"
        PANEL_DB_PORT="3306"
        PANEL_DB_ROOT_PASS=$(prompt_secret "Existing MariaDB root password (blank for socket auth)" "")
    else
        if [ "$PANEL_PRODUCT" = "pterodactyl" ]; then
            PANEL_DB_CONNECTION="mysql"
        else
            PANEL_DB_CONNECTION=$(prompt "Database engine (mysql/pgsql)" "$PANEL_DB_CONNECTION")
            case "$PANEL_DB_CONNECTION" in pgsql|postgres|postgresql) PANEL_DB_CONNECTION="pgsql" ;; *) PANEL_DB_CONNECTION="mysql" ;; esac
        fi
        PANEL_DB_HOST=$(prompt_required "Database host" "$PANEL_DB_HOST") || return 1
        if [ "$PANEL_DB_CONNECTION" = "pgsql" ] && [ "$PANEL_DB_PORT" = "3306" ]; then
            PANEL_DB_PORT="5432"
        fi
        PANEL_DB_PORT=$(prompt "Database port" "$PANEL_DB_PORT")
    fi
    PANEL_DB_NAME=$(prompt "Database name" "$PANEL_DB_NAME")
    PANEL_DB_USER=$(prompt "Database user" "$PANEL_DB_USER")
    PANEL_DB_PASS=$(prompt_secret "Database password (blank to generate)" "$(random_password)")
    if [ "$PANEL_SETUP_MODE" = "auto" ]; then
        PANEL_ADMIN_EMAIL=$(prompt_required "Admin email" "$PANEL_ADMIN_EMAIL") || return 1
        PANEL_ADMIN_USER=$(prompt "Admin username" "$PANEL_ADMIN_USER")
        PANEL_ADMIN_FIRST=$(prompt "Admin first name" "$PANEL_ADMIN_FIRST")
        PANEL_ADMIN_LAST=$(prompt "Admin last name" "$PANEL_ADMIN_LAST")
        PANEL_ADMIN_PASS=$(prompt_secret "Admin password (blank to generate)" "$(random_password)")
    else
        PANEL_ADMIN_EMAIL=$(prompt_required "Contact/admin email for setup wizard" "$PANEL_ADMIN_EMAIL") || return 1
        PANEL_ADMIN_USER="(wizard)"
        PANEL_ADMIN_FIRST=""
        PANEL_ADMIN_LAST=""
        PANEL_ADMIN_PASS=""
    fi
    PANEL_SERVICE_AUTHOR=$(prompt "Service author email" "${PANEL_SERVICE_AUTHOR:-$PANEL_ADMIN_EMAIL}")
    PANEL_TRUSTED_PROXIES=$(prompt "Trusted proxies (blank for none, '*' for all)" "$PANEL_TRUSTED_PROXIES")
    PANEL_REDIS_HOST=$(prompt "Redis host" "$PANEL_REDIS_HOST")
    PANEL_REDIS_PORT=$(prompt "Redis port" "$PANEL_REDIS_PORT")
    PANEL_REDIS_PASS=$(prompt_secret "Redis password (blank for none)" "$PANEL_REDIS_PASS")
    PANEL_WEB_USER=$(prompt "Webserver/system user" "$PANEL_WEB_USER")
    PANEL_WEB_GROUP=$(prompt "Webserver/system group" "$PANEL_WEB_GROUP")
    PANEL_MAIL_MODE=$(prompt "Mail mode (mail/smtp)" "$PANEL_MAIL_MODE")
    case "$PANEL_MAIL_MODE" in smtp|SMTP) PANEL_MAIL_MODE="smtp" ;; *) PANEL_MAIL_MODE="mail" ;; esac
    PANEL_MAIL_FROM=$(prompt "Mail from address" "${PANEL_MAIL_FROM:-$PANEL_ADMIN_EMAIL}")
    PANEL_MAIL_FROM_NAME=$(prompt "Mail from name" "$PANEL_MAIL_FROM_NAME")
    if [ "$PANEL_MAIL_MODE" = "smtp" ]; then
        PANEL_SMTP_HOST=$(prompt_required "SMTP host" "$PANEL_SMTP_HOST") || return 1
        PANEL_SMTP_PORT=$(prompt "SMTP port" "$PANEL_SMTP_PORT")
        PANEL_SMTP_USER=$(prompt "SMTP username" "$PANEL_SMTP_USER")
        PANEL_SMTP_PASS=$(prompt_secret "SMTP password" "$PANEL_SMTP_PASS")
        PANEL_SMTP_ENCRYPTION=$(prompt "SMTP encryption (tls/ssl/null)" "$PANEL_SMTP_ENCRYPTION")
    fi
    if [ "$PANEL_SETUP_MODE" = "wizard" ]; then
        warn "This panel uses a setup wizard. Egg import will be available from the main menu after the wizard finishes."
        PANEL_IMPORT_EGGS="no"
    else
        PANEL_IMPORT_EGGS=$(prompt "Import Cog Host eggs after install? (yes/no)" "yes")
        case "$PANEL_IMPORT_EGGS" in y|Y|yes|s|S|sim) PANEL_IMPORT_EGGS="yes" ;; *) PANEL_IMPORT_EGGS="no" ;; esac
    fi
}

show_panel_summary() {
    printf '\n==== %s ====\n' "$(t summary)"
    printf 'Product: %s\n' "$PANEL_NAME"
    printf 'Domain: %s\n' "$PANEL_DOMAIN"
    printf 'URL: %s\n' "$PANEL_URL"
    printf 'Directory: %s\n' "$PANEL_DIR"
    printf 'SSL: %s\n' "$PANEL_SSL"
    [ "$PANEL_SSL" = "yes" ] && printf 'SSL email: %s\n' "$PANEL_SSL_EMAIL"
    printf 'Setup mode: %s\n' "$PANEL_SETUP_MODE"
    printf 'PHP: %s\n' "$PANEL_PHP_VERSION"
    printf 'Locale: %s\n' "$PANEL_APP_LOCALE"
    printf 'Telemetry: %s\n' "$PANEL_TELEMETRY"
    printf 'Database mode: %s\n' "$PANEL_DB_MODE"
    printf 'Database engine: %s\n' "$PANEL_DB_CONNECTION"
    printf 'Database: %s@%s:%s/%s\n' "$PANEL_DB_USER" "$PANEL_DB_HOST" "$PANEL_DB_PORT" "$PANEL_DB_NAME"
    printf 'Database password: %s\n' "$(mask "$PANEL_DB_PASS")"
    if [ "$PANEL_SETUP_MODE" = "auto" ]; then
        printf 'Admin: %s (%s)\n' "$PANEL_ADMIN_EMAIL" "$PANEL_ADMIN_USER"
        printf 'Admin password: %s\n' "$(mask "$PANEL_ADMIN_PASS")"
    else
        printf 'Setup contact/admin email: %s\n' "$PANEL_ADMIN_EMAIL"
    fi
    printf 'Service author: %s\n' "$PANEL_SERVICE_AUTHOR"
    printf 'Trusted proxies: %s\n' "${PANEL_TRUSTED_PROXIES:-none}"
    printf 'Redis: %s:%s\n' "$PANEL_REDIS_HOST" "$PANEL_REDIS_PORT"
    printf 'Redis password: %s\n' "$(mask "$PANEL_REDIS_PASS")"
    printf 'Web user/group: %s:%s\n' "$PANEL_WEB_USER" "$PANEL_WEB_GROUP"
    printf 'Mail mode: %s\n' "$PANEL_MAIL_MODE"
    printf 'Mail from: %s (%s)\n' "$PANEL_MAIL_FROM" "$PANEL_MAIL_FROM_NAME"
    if [ "$PANEL_MAIL_MODE" = "smtp" ]; then
        printf 'SMTP: %s:%s user=%s encryption=%s\n' "$PANEL_SMTP_HOST" "$PANEL_SMTP_PORT" "${PANEL_SMTP_USER:-none}" "$PANEL_SMTP_ENCRYPTION"
        printf 'SMTP password: %s\n' "$(mask "$PANEL_SMTP_PASS")"
    fi
    printf 'Import eggs: %s\n' "$PANEL_IMPORT_EGGS"
    [ -n "$PANEL_FOLLOWUP" ] && printf 'Follow-up: %s\n' "$PANEL_FOLLOWUP"
    printf 'Will install/change: PHP %s, Composer, MariaDB/DB config, Redis, Nginx, Certbot, queue worker, cron.\n' "$PANEL_PHP_VERSION"
    printf '=================\n'
}

collect_daemon_inputs() {
    DAEMON_DOMAIN=$(prompt_required "Node FQDN/IP" "$DAEMON_DOMAIN") || return 1
    DAEMON_SSL=$(prompt "Use SSL? (yes/no)" "$DAEMON_SSL")
    case "$DAEMON_SSL" in y|Y|yes|s|S|sim) DAEMON_SSL="yes" ;; *) DAEMON_SSL="no" ;; esac
    if [ "$DAEMON_SSL" = "yes" ]; then
        DAEMON_SSL_EMAIL=$(prompt_required "Email for Let's Encrypt" "$DAEMON_SSL_EMAIL") || return 1
    fi
    DAEMON_CONFIG_DIR=$(prompt "Config directory" "$DAEMON_CONFIG_DIR")
    DAEMON_CONFIG_FILE="$DAEMON_CONFIG_DIR/config.yml"
    DAEMON_RUNTIME_DIR=$(prompt "Runtime directory" "$DAEMON_RUNTIME_DIR")
    DAEMON_PID_FILE="$DAEMON_RUNTIME_DIR/daemon.pid"
    DAEMON_DATA_DIR=$(prompt "Server data directory" "$DAEMON_DATA_DIR")
    DAEMON_INSTALL_DOCKER=$(prompt "Install Docker automatically? (yes/no)" "$DAEMON_INSTALL_DOCKER")
    case "$DAEMON_INSTALL_DOCKER" in y|Y|yes|s|S|sim) DAEMON_INSTALL_DOCKER="yes" ;; *) DAEMON_INSTALL_DOCKER="no" ;; esac
    if [ "$DAEMON_PRODUCT" = "pyrodactyl" ]; then
        DAEMON_INSTALL_RUSTIC=$(prompt "Attempt to install rustic backup tool? (yes/no)" "$DAEMON_INSTALL_RUSTIC")
        case "$DAEMON_INSTALL_RUSTIC" in y|Y|yes|s|S|sim) DAEMON_INSTALL_RUSTIC="yes" ;; *) DAEMON_INSTALL_RUSTIC="no" ;; esac
        DAEMON_CREATE_SYSTEM_USER=$(prompt "Create/use pyrodactyl system user? (yes/no)" "$DAEMON_CREATE_SYSTEM_USER")
        case "$DAEMON_CREATE_SYSTEM_USER" in y|Y|yes|s|S|sim) DAEMON_CREATE_SYSTEM_USER="yes" ;; *) DAEMON_CREATE_SYSTEM_USER="no" ;; esac
        DAEMON_SYSTEM_USER="root"
        warn "Elytra's systemd service is kept as root; the pyrodactyl user is only pre-created for Elytra internals if requested."
    else
        DAEMON_SYSTEM_USER=$(prompt "Service user" "$DAEMON_SYSTEM_USER")
    fi
    DAEMON_CONFIG_MODE=$(prompt "Config method (paste/auto/skip)" "$DAEMON_CONFIG_MODE")
    case "$DAEMON_CONFIG_MODE" in auto|paste|skip) : ;; *) DAEMON_CONFIG_MODE="paste" ;; esac
    if [ "$DAEMON_CONFIG_MODE" = "auto" ]; then
        DAEMON_AUTODEPLOY_CMD=$(prompt_required "Paste auto-deploy command" "") || return 1
    fi
    if [ "$DAEMON_CONFIG_MODE" = "skip" ] && [ "$DAEMON_START_NOW" = "yes" ]; then
        DAEMON_START_NOW="no"
    fi
    DAEMON_START_NOW=$(prompt "Start service now? (yes/no)" "$DAEMON_START_NOW")
    case "$DAEMON_START_NOW" in y|Y|yes|s|S|sim) DAEMON_START_NOW="yes" ;; *) DAEMON_START_NOW="no" ;; esac
    update_daemon_cert_reuse
}

show_daemon_summary() {
    printf '\n==== %s ====\n' "$(t summary)"
    printf 'Product: %s\n' "$DAEMON_NAME"
    printf 'Node FQDN/IP: %s\n' "$DAEMON_DOMAIN"
    printf 'SSL: %s\n' "$DAEMON_SSL"
    [ "$DAEMON_SSL" = "yes" ] && printf 'SSL email: %s\n' "$DAEMON_SSL_EMAIL"
    printf 'Binary: %s\n' "$DAEMON_BINARY"
    printf 'Config: %s\n' "$DAEMON_CONFIG_FILE"
    printf 'Runtime directory: %s\n' "$DAEMON_RUNTIME_DIR"
    printf 'PID file: %s\n' "$DAEMON_PID_FILE"
    printf 'Data directory: %s\n' "$DAEMON_DATA_DIR"
    printf 'Docker install: %s\n' "$DAEMON_INSTALL_DOCKER"
    printf 'Reuse panel SSL certificate: %s\n' "$DAEMON_REUSE_PANEL_CERT"
    printf 'Service user: %s\n' "$DAEMON_SYSTEM_USER"
    if [ "$DAEMON_PRODUCT" = "pyrodactyl" ]; then
        printf 'Install rustic: %s\n' "$DAEMON_INSTALL_RUSTIC"
        printf 'Create pyrodactyl user: %s\n' "$DAEMON_CREATE_SYSTEM_USER"
    fi
    printf 'Config mode: %s\n' "$DAEMON_CONFIG_MODE"
    printf 'Service: %s.service\n' "$DAEMON_SERVICE"
    printf 'Start now: %s\n' "$DAEMON_START_NOW"
    printf '=================\n'
}

show_combined_summary() {
    printf '\n==== %s ====%s\n' "$(t summary)" ' - Panel + Daemon'
    show_panel_summary
    show_daemon_summary
    printf 'Execution order: panel -> optional egg import -> daemon\n'
    if [ "$PANEL_SETUP_MODE" = "wizard" ]; then
        printf 'Wizard note: finish %s/installer before importing eggs or expecting generated node config.\n' "$PANEL_URL"
    fi
    if [ "$DAEMON_CONFIG_MODE" = "skip" ]; then
        printf 'Daemon config note: config creation is skipped; create node in panel and paste/autodeploy config later.\n'
    fi
    if [ "$DAEMON_REUSE_PANEL_CERT" = "yes" ]; then
        printf 'SSL note: daemon will reuse the panel certificate for %s.\n' "$PANEL_DOMAIN"
    fi
    printf '=================\n'
}

install_base_apt() {
    require_root
    detect_os || die "$(t unsupported_os)"
    if [ "$DRY_RUN" != "1" ]; then
        command -v systemctl >/dev/null 2>&1 || die "systemd is required."
    fi
    run apt-get update
    run apt-get install -y curl ca-certificates gnupg lsb-release software-properties-common apt-transport-https tar unzip git sed coreutils
}

install_php_repo() {
    php_version="$1"
    if command -v php >/dev/null 2>&1 && php -v 2>/dev/null | grep -q "PHP $php_version"; then
        return 0
    fi
    if [ "$OS_ID" = "ubuntu" ]; then
        run apt-get install -y software-properties-common
        run add-apt-repository -y ppa:ondrej/php
    elif [ "$OS_ID" = "debian" ]; then
        run mkdir -p /usr/share/keyrings
        if [ "$DRY_RUN" = "1" ]; then
            log "Would add Sury PHP repository"
        else
            curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
            printf 'deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ %s main\n' "$(lsb_release -sc)" >/etc/apt/sources.list.d/sury-php.list
        fi
    fi
    run apt-get update
}

install_panel_dependencies() {
    install_base_apt
    install_php_repo "$PANEL_PHP_VERSION"
    run apt-get install -y "php$PANEL_PHP_VERSION" "php$PANEL_PHP_VERSION-cli" "php$PANEL_PHP_VERSION-fpm" "php$PANEL_PHP_VERSION-common" "php$PANEL_PHP_VERSION-gd" "php$PANEL_PHP_VERSION-mysql" "php$PANEL_PHP_VERSION-pgsql" "php$PANEL_PHP_VERSION-mbstring" "php$PANEL_PHP_VERSION-bcmath" "php$PANEL_PHP_VERSION-xml" "php$PANEL_PHP_VERSION-curl" "php$PANEL_PHP_VERSION-zip" "php$PANEL_PHP_VERSION-intl" "php$PANEL_PHP_VERSION-sqlite3" "php$PANEL_PHP_VERSION-redis" nginx redis-server
    if [ "$PANEL_DB_MODE" = "local" ]; then
        run apt-get install -y mariadb-server
    fi
    if [ "$PANEL_SSL" = "yes" ]; then
        run apt-get install -y certbot python3-certbot-nginx
    fi
    if ! command -v composer >/dev/null 2>&1; then
        if [ "$DRY_RUN" = "1" ]; then
            log "Would install Composer"
        else
            curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        fi
    fi
    if [ "$PANEL_NEEDS_NODE" = "yes" ]; then
        install_node_pnpm
    fi
}

install_node_pnpm() {
    if ! command -v node >/dev/null 2>&1; then
        if [ "$DRY_RUN" = "1" ]; then
            log "Would install Node.js LTS"
        else
            curl -fsSL https://deb.nodesource.com/setup_22.x | sh -
            apt-get install -y nodejs
        fi
    elif [ "$DRY_RUN" != "1" ]; then
        node_major=$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)
        case "$node_major" in
            ''|*[!0-9]*) die "Could not detect Node.js version." ;;
            *) [ "$node_major" -ge 20 ] || die "Node.js 20+ is required for $PANEL_NAME. Current: $(node -v)" ;;
        esac
    fi
    if command -v corepack >/dev/null 2>&1; then
        run corepack enable
        if [ "$PANEL_PRODUCT" = "pyrodactyl" ]; then
            run corepack prepare pnpm@10.13.1 --activate
        fi
    elif command -v npm >/dev/null 2>&1; then
        if [ "$PANEL_PRODUCT" = "pyrodactyl" ]; then
            run npm install -g pnpm@10.13.1
        else
            run npm install -g pnpm
        fi
    fi
}

setup_database() {
    if [ "$PANEL_DB_MODE" != "local" ]; then
        return 0
    fi
    run systemctl enable --now mariadb
    sql="CREATE DATABASE IF NOT EXISTS \`$PANEL_DB_NAME\`; CREATE USER IF NOT EXISTS '$PANEL_DB_USER'@'127.0.0.1' IDENTIFIED BY '$PANEL_DB_PASS'; GRANT ALL PRIVILEGES ON \`$PANEL_DB_NAME\`.* TO '$PANEL_DB_USER'@'127.0.0.1' WITH GRANT OPTION; FLUSH PRIVILEGES;"
    if [ "$DRY_RUN" = "1" ]; then
        log "Would create database and user for $PANEL_DB_NAME"
    else
        if [ -n "$PANEL_DB_ROOT_PASS" ]; then
            mariadb -u root -p"$PANEL_DB_ROOT_PASS" -e "$sql" || mysql -u root -p"$PANEL_DB_ROOT_PASS" -e "$sql"
        else
            mariadb -u root -e "$sql" || mysql -u root -e "$sql"
        fi
    fi
}

download_panel() {
    if [ "$DRY_RUN" = "1" ]; then
        log "Would create/use $PANEL_DIR"
        log "Would download https://github.com/$PANEL_RELEASE_REPO/releases/latest/download/$PANEL_RELEASE_ASSET"
        return 0
    fi
    if [ -d "$PANEL_DIR" ] && [ "$(ls -A "$PANEL_DIR" 2>/dev/null | wc -l)" -gt 0 ]; then
        confirm "Directory $PANEL_DIR is not empty. Continue and merge files?" "no" || die "Cancelled."
    fi
    run mkdir -p "$PANEL_DIR"
    cd "$PANEL_DIR" || exit 1
    curl -fLo panel.tar.gz "https://github.com/$PANEL_RELEASE_REPO/releases/latest/download/$PANEL_RELEASE_ASSET"
    tar -tzf panel.tar.gz >/dev/null
    tar -xzf panel.tar.gz
    rm -f panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/ 2>/dev/null || true
}

configure_panel_env() {
    env_file="$PANEL_DIR/.env"
    if [ "$DRY_RUN" = "1" ]; then
        log "Would configure $env_file"
        return 0
    fi
    cd "$PANEL_DIR" || exit 1
    [ -f .env ] || cp .env.example .env
    set_env_value APP_URL "$PANEL_URL" "$env_file"
    set_env_value APP_ENV production "$env_file"
    set_env_value APP_DEBUG false "$env_file"
    set_env_value APP_TIMEZONE "$PANEL_TIMEZONE" "$env_file"
    set_env_value APP_LOCALE "$PANEL_APP_LOCALE" "$env_file"
    set_env_value LOG_CHANNEL "$PANEL_LOG_CHANNEL" "$env_file"
    set_env_value LOG_LEVEL "$PANEL_LOG_LEVEL" "$env_file"
    set_env_value PTERODACTYL_TELEMETRY_ENABLED "$PANEL_TELEMETRY" "$env_file"
    set_env_value APP_SERVICE_AUTHOR "$PANEL_SERVICE_AUTHOR" "$env_file"
    if [ -n "$PANEL_TRUSTED_PROXIES" ]; then
        set_env_value TRUSTED_PROXIES "$PANEL_TRUSTED_PROXIES" "$env_file"
    fi
    set_env_value DB_CONNECTION "$PANEL_DB_CONNECTION" "$env_file"
    set_env_value DB_HOST "$PANEL_DB_HOST" "$env_file"
    set_env_value DB_PORT "$PANEL_DB_PORT" "$env_file"
    set_env_value DB_DATABASE "$PANEL_DB_NAME" "$env_file"
    set_env_value DB_USERNAME "$PANEL_DB_USER" "$env_file"
    set_env_value DB_PASSWORD "$PANEL_DB_PASS" "$env_file"
    set_env_value CACHE_DRIVER redis "$env_file"
    set_env_value SESSION_DRIVER redis "$env_file"
    set_env_value QUEUE_CONNECTION redis "$env_file"
    set_env_value REDIS_HOST "$PANEL_REDIS_HOST" "$env_file"
    set_env_value REDIS_PORT "$PANEL_REDIS_PORT" "$env_file"
    if [ -n "$PANEL_REDIS_PASS" ]; then
        set_env_value REDIS_PASSWORD "$PANEL_REDIS_PASS" "$env_file"
    else
        set_env_value REDIS_PASSWORD null "$env_file"
    fi
    set_env_value MAIL_MAILER "$PANEL_MAIL_MODE" "$env_file"
    set_env_value MAIL_FROM_ADDRESS "$PANEL_MAIL_FROM" "$env_file"
    set_env_value MAIL_FROM_NAME "$PANEL_MAIL_FROM_NAME" "$env_file"
    if [ "$PANEL_MAIL_MODE" = "smtp" ]; then
        set_env_value MAIL_HOST "$PANEL_SMTP_HOST" "$env_file"
        set_env_value MAIL_PORT "$PANEL_SMTP_PORT" "$env_file"
        set_env_value MAIL_USERNAME "$PANEL_SMTP_USER" "$env_file"
        set_env_value MAIL_PASSWORD "$PANEL_SMTP_PASS" "$env_file"
        set_env_value MAIL_ENCRYPTION "$PANEL_SMTP_ENCRYPTION" "$env_file"
    fi
}

install_panel_code() {
    if [ "$DRY_RUN" = "1" ]; then
        log "Would run composer/artisan setup in $PANEL_DIR"
        return 0
    fi
    cd "$PANEL_DIR" || exit 1
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    if [ "$PANEL_NEEDS_NODE" = "yes" ] && [ -f package.json ]; then
        if command -v pnpm >/dev/null 2>&1; then
            pnpm install --frozen-lockfile || pnpm install
            pnpm build
        else
            die "pnpm is required to build $PANEL_NAME assets."
        fi
    fi
    if ! grep -q '^APP_KEY=base64:.' .env 2>/dev/null; then
        php artisan key:generate --force
    else
        warn "Existing APP_KEY detected; not regenerating it."
    fi
    if [ "$PANEL_SETUP_MODE" = "auto" ]; then
        php artisan migrate --seed --force
    else
        warn "$PANEL_NAME uses wizard-assisted setup. Finish setup at $PANEL_URL/installer before starting queue/importing eggs."
    fi
}

create_panel_admin() {
    if [ "$PANEL_SETUP_MODE" != "auto" ]; then
        warn "Skipping automatic admin creation for $PANEL_NAME; complete it in the setup wizard."
        return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
        log "Would create admin user $PANEL_ADMIN_EMAIL"
        return 0
    fi
    cd "$PANEL_DIR" || exit 1
    php artisan p:user:make --email="$PANEL_ADMIN_EMAIL" --username="$PANEL_ADMIN_USER" --name-first="$PANEL_ADMIN_FIRST" --name-last="$PANEL_ADMIN_LAST" --password="$PANEL_ADMIN_PASS" --admin=1 || {
        warn "Could not create admin non-interactively. Run: cd $PANEL_DIR && php artisan p:user:make"
    }
}

write_nginx_config() {
    site_name=$(printf '%s' "$PANEL_NAME" | tr '[:upper:]' '[:lower:]')
    conf="/etc/nginx/sites-available/$site_name.conf"
    if [ "$PANEL_SSL" = "yes" ]; then
        if [ "$DRY_RUN" = "1" ]; then
            log "Would obtain Let's Encrypt cert for $PANEL_DOMAIN"
        else
            systemctl stop nginx 2>/dev/null || true
            certbot certonly --standalone --non-interactive --agree-tos -m "$PANEL_SSL_EMAIL" -d "$PANEL_DOMAIN"
        fi
        write_file "$conf" <<EOF
server {
    listen 80;
    server_name $PANEL_DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $PANEL_DOMAIN;
    root $PANEL_DIR/public;
    index index.php;

    access_log /var/log/nginx/$site_name.app-access.log;
    error_log  /var/log/nginx/$site_name.app-error.log error;

    server_tokens off;
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    ssl_certificate /etc/letsencrypt/live/$PANEL_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$PANEL_DOMAIN/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305";
    ssl_prefer_server_ciphers on;

    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php$PANEL_PHP_VERSION-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    location ~ /\.ht { deny all; }
}
EOF
    else
        write_file "$conf" <<EOF
server {
    listen 80;
    server_name $PANEL_DOMAIN;
    root $PANEL_DIR/public;
    index index.php;

    access_log /var/log/nginx/$site_name.app-access.log;
    error_log  /var/log/nginx/$site_name.app-error.log error;

    server_tokens off;
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php$PANEL_PHP_VERSION-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    location ~ /\.ht { deny all; }
}
EOF
    fi
    run rm -f /etc/nginx/sites-enabled/default
    run ln -sf "$conf" "/etc/nginx/sites-enabled/$site_name.conf"
    run nginx -t
    run systemctl enable --now "php$PANEL_PHP_VERSION-fpm"
    run systemctl enable --now nginx
    run systemctl reload nginx
}

write_queue_and_cron() {
    cron_file="/etc/cron.d/cog-host-manager-$PANEL_QUEUE_SERVICE"
    write_file "$cron_file" <<EOF
* * * * * root php $PANEL_DIR/artisan schedule:run >> /dev/null 2>&1
EOF
    service_file="/etc/systemd/system/$PANEL_QUEUE_SERVICE.service"
    write_file "$service_file" <<EOF
[Unit]
Description=$PANEL_NAME Queue Worker
After=redis-server.service redis.service

[Service]
User=$PANEL_WEB_USER
Group=$PANEL_WEB_GROUP
Restart=always
ExecStart=/usr/bin/php $PANEL_DIR/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    run systemctl daemon-reload
    run systemctl enable --now "$PANEL_QUEUE_SERVICE.service"
}

install_panel() {
    require_root
    install_panel_dependencies
    setup_database
    download_panel
    configure_panel_env
    install_panel_code
    create_panel_admin
    run chown -R "$PANEL_WEB_USER:$PANEL_WEB_GROUP" "$PANEL_DIR"
    write_nginx_config
    run systemctl enable --now redis-server || run systemctl enable --now redis
    if [ "$PANEL_SETUP_MODE" = "auto" ]; then
        write_queue_and_cron
    else
        warn "Skipping queue service until $PANEL_NAME setup wizard is completed."
    fi
    if [ "$PANEL_SETUP_MODE" = "auto" ] && [ "$PANEL_IMPORT_EGGS" = "yes" ]; then
        PANEL_PATH_FOR_IMPORT="$PANEL_DIR"
        AUTHOR_FOR_IMPORT="$PANEL_ADMIN_EMAIL"
        import_eggs_run "$PANEL_PATH_FOR_IMPORT" "$AUTHOR_FOR_IMPORT"
    elif [ "$PANEL_IMPORT_EGGS" = "yes" ]; then
        warn "Skipping egg import until $PANEL_NAME setup wizard is completed. Use the import menu after finishing setup."
    fi
    printf '\n'
    t done
    printf 'URL: %s\n' "$PANEL_URL"
    printf 'Admin: %s\n' "$PANEL_ADMIN_EMAIL"
    if [ "$PANEL_SETUP_MODE" = "auto" ]; then
        printf 'Admin password: %s\n' "$PANEL_ADMIN_PASS"
    else
        printf 'Setup URL: %s/installer\n' "$PANEL_URL"
    fi
    if [ -f "$PANEL_DIR/.env" ]; then
        grep '^APP_KEY=' "$PANEL_DIR/.env" || true
        warn "Save APP_KEY and generated passwords now."
    fi
}

install_combined() {
    install_panel
    printf '\n'
    log "Starting same-machine daemon install after panel setup"
    install_daemon
    printf '\n'
    t done
    printf 'Panel URL: %s\n' "$PANEL_URL"
    printf 'Daemon service: %s.service\n' "$DAEMON_SERVICE"
    if [ "$PANEL_SETUP_MODE" = "wizard" ]; then
        warn "Finish $PANEL_URL/installer, then create the node and configure $DAEMON_NAME from the panel."
    elif [ "$DAEMON_CONFIG_MODE" = "skip" ]; then
        warn "Create the node in the panel and configure $DAEMON_NAME before expecting it to start correctly."
    fi
}

install_docker() {
    if command -v docker >/dev/null 2>&1; then
        run systemctl enable --now docker
        return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
        log "Would install Docker via get.docker.com"
    else
        curl -sSL https://get.docker.com/ | CHANNEL=stable sh
    fi
    run systemctl enable --now docker
}

daemon_preflight_warnings() {
    virt=""
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt=$(systemd-detect-virt 2>/dev/null || true)
    fi
    case "$virt" in
        openvz|lxc|lxc-libvirt|systemd-nspawn|vz)
            warn "Detected virtualization '$virt'. Docker-based daemons often fail on OpenVZ/LXC/Virtuozzo-style hosts. KVM is recommended."
            ;;
    esac
    kernel=$(uname -r 2>/dev/null || true)
    case "$kernel" in
        *-grs-ipv6-64|*-mod-std-ipv6-64)
            warn "Detected kernel '$kernel', which may lack Docker features required by Wings/Agent/Elytra."
            ;;
    esac
}

install_daemon() {
    require_root
    detect_os || die "$(t unsupported_os)"
    install_base_apt
    daemon_preflight_warnings
    if [ "$DAEMON_INSTALL_DOCKER" = "yes" ]; then
        install_docker
    fi
    if [ "$DAEMON_SSL" = "yes" ]; then
        if [ "$DAEMON_REUSE_PANEL_CERT" = "yes" ]; then
            log "Reusing panel certificate for $DAEMON_DOMAIN"
        else
            run apt-get install -y certbot
            if [ "$DRY_RUN" = "1" ]; then
                log "Would obtain Let's Encrypt cert for $DAEMON_DOMAIN"
            else
                warn "Standalone certbot needs port 80 free for $DAEMON_DOMAIN. Temporarily stopping nginx if it is running."
                systemctl stop nginx 2>/dev/null || true
                certbot certonly --standalone --non-interactive --agree-tos -m "$DAEMON_SSL_EMAIL" -d "$DAEMON_DOMAIN"
                systemctl start nginx 2>/dev/null || true
            fi
        fi
    fi
    if [ "$DAEMON_PRODUCT" = "pyrodactyl" ] && [ "$DAEMON_INSTALL_RUSTIC" = "yes" ]; then
        warn "rustic is recommended by Elytra for deduplicated/encrypted backups, but it is not installed from apt here. Install it from the upstream rustic release before enabling those backups."
    fi
    if [ "$DAEMON_CREATE_SYSTEM_USER" = "yes" ]; then
        internal_user="pyrodactyl"
        if ! id "$internal_user" >/dev/null 2>&1; then
            run useradd --system --create-home --shell /usr/sbin/nologin "$internal_user"
        fi
        if command -v usermod >/dev/null 2>&1; then
            run usermod -aG docker "$internal_user" || true
        fi
    fi
    arch=$(detect_arch)
    asset="${DAEMON_ASSET_PREFIX}_linux_${arch}"
    url="https://github.com/$DAEMON_RELEASE_REPO/releases/latest/download/$asset"
    run mkdir -p "$DAEMON_CONFIG_DIR" "$DAEMON_RUNTIME_DIR" "$DAEMON_DATA_DIR"
    if [ "$DRY_RUN" = "1" ]; then
        log "Would download $url to $DAEMON_BINARY"
    else
        curl -fL -o "$DAEMON_BINARY" "$url"
        [ -s "$DAEMON_BINARY" ] || die "Downloaded daemon binary is empty: $DAEMON_BINARY"
        chmod u+x "$DAEMON_BINARY"
    fi
    if [ "$DAEMON_CONFIG_MODE" = "paste" ]; then
        paste_daemon_config
    elif [ "$DAEMON_CONFIG_MODE" = "auto" ]; then
        show_and_run_autodeploy
    else
        warn "Skipping config.yml creation. Service may not start until configured."
    fi
    write_daemon_service
    run systemctl daemon-reload
    if [ "$DAEMON_START_NOW" = "yes" ]; then
        run systemctl enable --now "$DAEMON_SERVICE.service"
    else
        run systemctl enable "$DAEMON_SERVICE.service"
    fi
    t done
}

paste_daemon_config() {
    printf '%s\n' "Paste config.yml content. Finish with a single line containing EOF."
    if [ "$DRY_RUN" = "1" ]; then
        log "Would read and write $DAEMON_CONFIG_FILE"
        return 0
    fi
    backup_file "$DAEMON_CONFIG_FILE"
    : >"$DAEMON_CONFIG_FILE"
    while IFS= read -r line; do
        [ "$line" = "EOF" ] && break
        printf '%s\n' "$line" >>"$DAEMON_CONFIG_FILE"
    done
}

show_and_run_autodeploy() {
    warn "Auto-deploy command will be shown before execution. Verify it came from your panel."
    printf '%s\n' "$DAEMON_AUTODEPLOY_CMD"
    confirm "Execute this command?" "no" || return 0
    if [ "$DRY_RUN" = "1" ]; then
        log "Would execute auto-deploy command"
    else
        sh -c "$DAEMON_AUTODEPLOY_CMD"
    fi
}

write_daemon_service() {
    service_file="/etc/systemd/system/$DAEMON_SERVICE.service"
    write_file "$service_file" <<EOF
[Unit]
Description=$DAEMON_NAME Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=$DAEMON_SYSTEM_USER
WorkingDirectory=$DAEMON_CONFIG_DIR
PIDFile=$DAEMON_PID_FILE
LimitNOFILE=4096
ExecStart=$DAEMON_BINARY
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
}

import_eggs_flow() {
    panel_path=$(prompt "Panel path" "/var/www/pterodactyl")
    author=$(prompt "Egg author/email" "cog-host-manager@example.com")
    printf '\n==== %s ====\n' "$(t summary)"
    printf 'Panel path: %s\n' "$panel_path"
    printf 'Author: %s\n' "$author"
    printf '=================\n'
    if confirm "$(t confirm_continue)" "no"; then
        import_eggs_run "$panel_path" "$author"
    else
        t cancelled
    fi
}

import_eggs_run() {
    panel_path="$1"
    author="$2"
    if [ "$DRY_RUN" = "1" ]; then
        log "Would import Cog Host eggs into $panel_path with author $author"
        return 0
    fi
    if [ ! -f "$panel_path/artisan" ] || [ ! -f "$panel_path/bootstrap/app.php" ]; then
        die "Panel path does not look valid: $panel_path"
    fi
    if [ ! -f "$panel_path/vendor/autoload.php" ]; then
        die "Panel dependencies are missing: $panel_path/vendor/autoload.php"
    fi
    if ! command -v php >/dev/null 2>&1; then
        die "PHP is required to import eggs because the panel itself is a PHP/Laravel app."
    fi
    helper=""
    script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || pwd)
    if [ -f "$script_dir/import-linguagens.php" ]; then
        helper="$script_dir/import-linguagens.php"
    else
        tmp="/tmp/cog-host-import-$$.php"
        curl -fsSL "$PHP_IMPORT_URL" -o "$tmp"
        helper="$tmp"
    fi
    php "$helper" --panel="$panel_path" --author="$author" --lang="$LANG_CHOICE"
    [ -n "${tmp:-}" ] && rm -f "$tmp"
}

main() {
    parse_args "$@"
    choose_language
    main_menu
}

main "$@"
