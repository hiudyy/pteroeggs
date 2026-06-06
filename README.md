# Cog Host Manager

Gerenciador interativo em `sh` para importar eggs e automatizar instalacoes de panels/daemons compativeis com Pterodactyl.

O menu inicial pergunta o idioma, `pt` ou `en`, e oferece:

- Importar eggs
- Instalar painel
- Instalar Wings/daemon
- Instalar painel + Wings/daemon na mesma maquina
- Sair

## Comando Unico

Rode no servidor usando `curl`. O script e baixado para um arquivo temporario para que os prompts interativos funcionem corretamente:

```sh
sh -c 'tmp="$(mktemp)" || exit 1; curl -fsSL https://raw.githubusercontent.com/hiudyy/pteroeggs/main/tools/cog-host-manager.sh -o "$tmp" && sh "$tmp"; status=$?; rm -f "$tmp"; exit "$status"'
```

Para iniciar diretamente em portugues ou ingles:

```sh
sh -c 'tmp="$(mktemp)" || exit 1; curl -fsSL https://raw.githubusercontent.com/hiudyy/pteroeggs/main/tools/cog-host-manager.sh -o "$tmp" && sh "$tmp" --lang=pt; status=$?; rm -f "$tmp"; exit "$status"'
```

```sh
sh -c 'tmp="$(mktemp)" || exit 1; curl -fsSL https://raw.githubusercontent.com/hiudyy/pteroeggs/main/tools/cog-host-manager.sh -o "$tmp" && sh "$tmp" --lang=en; status=$?; rm -f "$tmp"; exit "$status"'
```

## Uso Local

```sh
sh tools/cog-host-manager.sh
```

Opcoes disponiveis:

```sh
sh tools/cog-host-manager.sh --lang=pt
sh tools/cog-host-manager.sh --lang=en
sh tools/cog-host-manager.sh --dry-run
```

## Niveis De Suporte

O Cog Host Manager tenta automatizar o maximo possivel, mas forks diferentes possuem instaladores e passos proprios. Por isso o suporte e dividido por nivel:

- Pterodactyl: fluxo automatico principal.
- Pyrodactyl: fluxo automatico experimental, com build Node/pnpm e aviso antes de instalar.
- Pelican: modo assistido por wizard; o script prepara arquivos, dependencias, webserver e banco, mas pode exigir finalizar em `/installer`.
- Reviactyl: modo assistido por wizard/experimental; o script prepara a base e deixa o follow-up claro.

## Panels Suportados

- Pterodactyl
- Pelican beta, com aviso e possivel finalizacao pelo `/installer`
- Reviactyl experimental, com aviso antes de instalar
- Pyrodactyl experimental/pre-release, com aviso antes de instalar

O fluxo de instalacao do painel coleta dominio, SSL, versao do PHP, locale, telemetria, banco de dados, primeira conta admin nos fluxos automaticos, contato/admin nos fluxos com wizard, service author, Redis, trusted proxies, usuario/grupo do webserver, e-mail de envio, diretorio de instalacao e mostra um resumo antes de executar qualquer alteracao.

Durante instalacoes automaticas, o gerenciador tambem pergunta se deve importar os eggs do Cog Host Manager assim que o painel terminar de instalar. Em panels com wizard assistido, a importacao fica para o menu principal depois que o wizard terminar, porque antes disso o banco pode ainda nao estar migrado.

Pterodactyl e o alvo principal da automacao completa. Pelican, Reviactyl e Pyrodactyl podem exigir passos especificos da propria documentacao upstream, entao o script mostra aviso e follow-up quando houver risco de diferenca entre forks.

## Daemons Suportados

- Pterodactyl Wings
- Pelican Wings
- Reviactyl Agent experimental
- Pyrodactyl Elytra, com opcoes extras para runtime, usuario interno `pyrodactyl` e aviso sobre rustic

O fluxo do daemon coleta FQDN/IP do node, SSL, diretorios, runtime dir, usuario do servico, instalacao do Docker, metodo de configuracao e mostra um resumo antes de executar qualquer alteracao.

Daemons dependem de Docker. OpenVZ, LXC, Virtuozzo e kernels modificados podem falhar mesmo com o script correto; o gerenciador mostra avisos quando detecta ambientes arriscados.

## Painel + Daemon Na Mesma Maquina

O menu tambem possui a opcao `Instalar painel + Wings/daemon na mesma maquina`. Esse fluxo segue a logica dos instaladores automaticos conhecidos: primeiro instala/prepara o painel, depois instala/prepara o daemon correspondente.

O daemon recomendado e pre-selecionado por painel, mas o usuario pode confirmar ou trocar antes de continuar:

- Pterodactyl -> Pterodactyl Wings
- Pelican -> Pelican Wings
- Reviactyl -> Reviactyl Agent
- Pyrodactyl -> Pyrodactyl Elytra

O fluxo combinado usa defaults inteligentes para mesma maquina:

- dominio do daemon comeca igual ao dominio do painel, mas pode ser alterado
- SSL e email do daemon herdam os valores do painel
- Docker fica ativado por padrao
- em panels com wizard, a config do daemon fica `skip` por padrao, porque o node/config normalmente so existe depois do wizard
- se painel e daemon usam o mesmo dominio com SSL, o daemon reutiliza o certificado do painel e nao tenta emitir outro certificado standalone
- se o daemon usar SSL em outro dominio, o gerenciador emite um certificado standalone e pode parar/reiniciar o Nginx temporariamente para liberar a porta 80

Mesmo no fluxo combinado, a criacao final do node/config do daemon ainda depende do painel. Quando o script nao receber `config.yml` ou comando auto-deploy, ele deixa o daemon instalado e mostra o follow-up para configurar depois pelo painel.

## Eggs Importados

O importador cria ou reutiliza estes nests:

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

## Requisitos

- Ubuntu ou Debian com `apt` para instalacoes automaticas de panel/daemon.
- Acesso `root` para instalar panel/daemon, configurar systemd, Nginx, Docker, PHP, MariaDB e Certbot.
- `curl` instalado para o comando unico.
- GitHub acessivel para baixar releases oficiais dos panels/daemons.
- Para importar eggs em um panel existente, o caminho do panel precisa ter `artisan`, `bootstrap/app.php`, `.env` e `vendor/autoload.php` funcionando.
- Para importar eggs, o comando `php` precisa ser o PHP usado pelo panel.

## Importador PHP

O arquivo `tools/import-linguagens.php` continua sendo usado pelo Cog Host Manager para importar eggs com seguranca atraves do Laravel do panel.

Tambem e possivel chamar somente o importador, sem abrir o gerenciador completo:

```sh
sh -c 'tmp="$(mktemp)" || exit 1; curl -fsSL https://raw.githubusercontent.com/hiudyy/pteroeggs/main/tools/import-linguagens.php -o "$tmp" && php "$tmp" --panel=/var/www/pterodactyl --author=admin@seudominio.com --lang=pt; status=$?; rm -f "$tmp"; exit "$status"'
```

Para listar os eggs sem conectar no panel e sem alterar o banco:

```sh
sh -c 'tmp="$(mktemp)" || exit 1; curl -fsSL https://raw.githubusercontent.com/hiudyy/pteroeggs/main/tools/import-linguagens.php -o "$tmp" && php "$tmp" --dry-run --lang=pt; status=$?; rm -f "$tmp"; exit "$status"'
```

## Observacoes

- Se um egg com o mesmo `author` e `name` ja existir no nest, ele sera atualizado.
- Se nao existir, ele sera criado.
- O script nao remove servidores, nests antigos ou eggs com outro autor.
- As imagens principais usam `ghcr.io/ptero-eggs/yolks` quando disponiveis.
- Reviactyl e Pyrodactyl podem estar em desenvolvimento ou pre-release; o gerenciador mostra aviso antes dessas instalacoes.
