# PteroConfig

Utilitario para criar nests no Pterodactyl Panel e importar eggs genericos para linguagens, bancos de dados, web e proxy.

## O Que Ele Importa

O script cria ou reutiliza estes nests:

- `Linguagens`
- `Bancos de Dados`
- `Web & Proxy`

Eggs de `Linguagens`:

- NodeJS
- Python
- Java
- Go
- Rust
- Bun
- .NET
- Dart
- PHP
- Ruby

Eggs de `Bancos de Dados`:

- MariaDB
- PostgreSQL
- MongoDB
- Redis
- Valkey

Eggs de `Web & Proxy`:

- Nginx Static Site
- Nginx Reverse Proxy
- Caddy Static Site
- Caddy Reverse Proxy
- Apache Static Site
- PHP Web Server

Os eggs usam formato `PTDL_v2`, com instalacao padrao embutida para cada tipo de servico. Nos eggs de linguagens, o usuario configura apenas os comandos de inicializacao pelo painel:

- `CMD1`: comando principal para iniciar a aplicacao.
- `CMD2`: comando opcional executado antes do comando principal.

Nos eggs de banco e web/proxy, o script tambem cria variaveis especificas quando necessario, por exemplo senha do banco ou destino do proxy.

## Comando Unico

Rode este comando no servidor onde o Pterodactyl Panel esta instalado:

```bash
bash -c 'set -e; tmp="$(mktemp -d)"; curl -fsSL https://raw.githubusercontent.com/hiudyy/pteroeggs/main/tools/import-linguagens.php -o "$tmp/import-linguagens.php"; php "$tmp/import-linguagens.php"'
```

O script vai perguntar:

- pasta do Pterodactyl Panel, por exemplo `/var/www/pterodactyl`
- email/autor dos eggs
- confirmacao antes de importar

As credenciais do banco nao precisam ser digitadas. O script carrega o proprio Pterodactyl Panel e usa as credenciais ja configuradas no arquivo `.env` do Panel.

## Exemplo De Execucao

```txt
Importador de eggs para Pterodactyl
As credenciais do banco serao lidas automaticamente do .env do Panel.
Packs importados: Linguagens, Bancos de Dados, Web & Proxy.

Pasta do Pterodactyl Panel [/var/www/pterodactyl]: /var/www/pterodactyl
Email/autor dos eggs [pteroconfig@example.com]: admin@seudominio.com

Resumo:
  Panel: /var/www/pterodactyl
  Nests: Linguagens, Bancos de Dados, Web & Proxy
  Autor: admin@seudominio.com

Continuar com a importacao? [S/n]: s
```

## Modo Automatico

Tambem da para passar tudo por parametro, sem perguntas, ainda puxando direto do repo:

```bash
bash -c 'set -e; tmp="$(mktemp -d)"; curl -fsSL https://raw.githubusercontent.com/hiudyy/pteroeggs/main/tools/import-linguagens.php -o "$tmp/import-linguagens.php"; php "$tmp/import-linguagens.php" --panel=/var/www/pterodactyl --author=admin@seudominio.com'
```

## Testar Sem Importar

Para listar os eggs sem conectar no Panel e sem alterar o banco:

```bash
bash -c 'set -e; tmp="$(mktemp -d)"; curl -fsSL https://raw.githubusercontent.com/hiudyy/pteroeggs/main/tools/import-linguagens.php -o "$tmp/import-linguagens.php"; php "$tmp/import-linguagens.php" --dry-run'
```

## Requisitos

- Rodar no servidor que tem acesso aos arquivos do Pterodactyl Panel.
- Ter `curl` instalado para baixar o script pelo comando unico.
- O Panel precisa estar instalado e com `vendor/autoload.php`, `artisan` e `.env` funcionando.
- O comando `php` precisa ser o PHP usado pelo Panel.
- O usuario que roda o comando precisa conseguir ler a pasta do Panel e acessar o banco usando as configuracoes do `.env`.

## Observacoes

- Se um egg com o mesmo `author` e `name` ja existir no nest, ele sera atualizado.
- Se nao existir, ele sera criado.
- O script nao remove servidores, nests antigos ou eggs com outro autor.
- As imagens principais usam `ghcr.io/ptero-eggs/yolks` quando disponiveis.
