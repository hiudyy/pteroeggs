#!/usr/bin/env php
<?php

declare(strict_types=1);

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Http\UploadedFile;
use Pterodactyl\Models\Egg;
use Pterodactyl\Models\Nest;
use Pterodactyl\Services\Eggs\Sharing\EggImporterService;
use Pterodactyl\Services\Eggs\Sharing\EggUpdateImporterService;
use Pterodactyl\Services\Nests\NestCreationService;

const DEFAULT_AUTHOR = 'pteroconfig@example.com';

main($argv);

function main(array $argv): void
{
    $options = parseOptions($argv);

    if ($options['help']) {
        printUsage();
        return;
    }

    $options = completeOptions($options);

    $author = $options['author'] ?: DEFAULT_AUTHOR;
    $packs = eggPacks($author);

    if ($options['dry-run']) {
        printDryRun($author, $packs);
        return;
    }

    $panelPath = assertPanelPath($options['panel']);
    $app = bootstrapPanel($panelPath);

    $totalCreated = 0;
    $totalUpdated = 0;

    foreach ($packs as $pack) {
        $nest = findOrCreateNest($app, $pack['name'], $pack['description'], $author);
        [$created, $updated] = importEggs($app, $nest, $pack['eggs']);
        $totalCreated += $created;
        $totalUpdated += $updated;

        out('Nest: ' . $nest->name . ' (#' . $nest->id . ')');
        out('Eggs criados neste nest: ' . $created);
        out('Eggs atualizados neste nest: ' . $updated);
        out('');
    }

    out('Total de eggs criados: ' . $totalCreated);
    out('Total de eggs atualizados: ' . $totalUpdated);
}

function parseOptions(array $argv): array
{
    $result = [
        'panel' => null,
        'author' => null,
        'dry-run' => false,
        'interactive' => false,
        'help' => false,
    ];

    foreach (array_slice($argv, 1) as $arg) {
        if ($arg === '--help' || $arg === '-h') {
            $result['help'] = true;
            continue;
        }

        if ($arg === '--dry-run') {
            $result['dry-run'] = true;
            continue;
        }

        if ($arg === '--interactive') {
            $result['interactive'] = true;
            continue;
        }

        foreach (['panel', 'author'] as $key) {
            $prefix = '--' . $key . '=';
            if (str_starts_with($arg, $prefix)) {
                $result[$key] = substr($arg, strlen($prefix));
                continue 2;
            }
        }

        if (!str_starts_with($arg, '-')) {
            $result['panel'] = $arg;
            continue;
        }

        fail('Opcao desconhecida: ' . $arg);
    }

    return $result;
}

function completeOptions(array $options): array
{
    if ($options['dry-run']) {
        $options['author'] = $options['author'] ?: DEFAULT_AUTHOR;

        return $options;
    }

    $shouldPrompt = $options['interactive'] || $options['panel'] === null;

    if (!$shouldPrompt) {
        $options['author'] = $options['author'] ?: DEFAULT_AUTHOR;

        return $options;
    }

    if (!canPrompt()) {
        fail('Informe --panel=/caminho/do/panel ao executar sem terminal interativo.');
    }

    out('Importador de eggs para Pterodactyl');
    out('As credenciais do banco serao lidas automaticamente do .env do Panel.');
    out('Packs importados: Linguagens, Bancos de Dados, Web & Proxy.');
    out('');

    $options['panel'] = prompt('Pasta do Pterodactyl Panel', $options['panel'] ?: '/var/www/pterodactyl');
    $options['author'] = prompt('Email/autor dos eggs', $options['author'] ?: DEFAULT_AUTHOR);

    out('');
    out('Resumo:');
    out('  Panel: ' . $options['panel']);
    out('  Nests: Linguagens, Bancos de Dados, Web & Proxy');
    out('  Autor: ' . $options['author']);
    out('');

    if (!confirm('Continuar com a importacao?', true)) {
        fail('Importacao cancelada.');
    }

    return $options;
}

function printUsage(): void
{
    out('Uso: php tools/import-linguagens.php --panel=/var/www/pterodactyl [opcoes]');
    out('');
    out('Opcoes:');
    out('  --panel=/caminho       Raiz do Pterodactyl Panel. Se omitir, o script pergunta.');
    out('  --author=email         Autor usado nos eggs criados.');
    out('  --interactive          Pergunta pasta do Panel, nest e autor mesmo com flags.');
    out('  --dry-run              Lista os eggs sem conectar ao Panel.');
    out('  --help                 Mostra esta ajuda.');
}

function assertPanelPath(string $path): string
{
    $realPath = realpath($path);

    if ($realPath === false) {
        fail('Caminho do Panel nao existe: ' . $path);
    }

    if (!is_file($realPath . '/artisan') || !is_file($realPath . '/bootstrap/app.php')) {
        fail('Caminho informado nao parece ser a raiz do Pterodactyl Panel: ' . $realPath);
    }

    return $realPath;
}

function bootstrapPanel(string $panelPath): mixed
{
    require_once $panelPath . '/vendor/autoload.php';

    $app = require $panelPath . '/bootstrap/app.php';
    $app->make(Kernel::class)->bootstrap();

    return $app;
}

function findOrCreateNest(mixed $app, string $nestName, string $description, string $author): Nest
{
    $nest = Nest::query()->where('name', $nestName)->first();

    if ($nest instanceof Nest) {
        out('Reutilizando nest existente: ' . $nest->name . ' (#' . $nest->id . ')');
        return $nest;
    }

    /** @var NestCreationService $creationService */
    $creationService = $app->make(NestCreationService::class);
    $nest = $creationService->handle([
        'name' => $nestName,
        'description' => $description,
    ], $author);

    out('Criado nest: ' . $nest->name . ' (#' . $nest->id . ')');

    return $nest;
}

function importEggs(mixed $app, Nest $nest, array $eggs): array
{
    /** @var EggImporterService $importer */
    $importer = $app->make(EggImporterService::class);
    /** @var EggUpdateImporterService $updater */
    $updater = $app->make(EggUpdateImporterService::class);

    $created = 0;
    $updated = 0;

    foreach ($eggs as $egg) {
        $file = uploadedJsonFile($egg);

        try {
            $existing = $nest->eggs()
                ->where('author', $egg['author'])
                ->where('name', $egg['name'])
                ->first();

            if ($existing instanceof Egg) {
                $updater->handle($existing, $file);
                $updated++;
                out('Atualizado egg: ' . $egg['name']);
            } else {
                $importer->handle($file, $nest->id);
                $created++;
                out('Criado egg: ' . $egg['name']);
            }
        } finally {
            @unlink($file->getPathname());
        }
    }

    return [$created, $updated];
}

function uploadedJsonFile(array $egg): UploadedFile
{
    $path = tempnam(sys_get_temp_dir(), 'ptero-egg-');

    if ($path === false) {
        fail('Nao foi possivel criar arquivo temporario para importacao.');
    }

    file_put_contents($path, json_encode($egg, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR));

    return new UploadedFile(
        $path,
        slug($egg['name']) . '.json',
        'application/json',
        UPLOAD_ERR_OK,
        true
    );
}

function printDryRun(string $author, array $packs): void
{
    out('Autor: ' . $author);

    foreach ($packs as $pack) {
        out('');
        out('Nest: ' . $pack['name']);
        out('Eggs:');

        foreach ($pack['eggs'] as $egg) {
            $images = implode(', ', array_keys($egg['docker_images']));
            out('  - ' . $egg['name'] . ' [' . $images . ']');
        }
    }
}

function eggPacks(string $author): array
{
    return [
        [
            'name' => 'Linguagens',
            'description' => 'Eggs genericos para executar aplicacoes em varias linguagens de programacao.',
            'eggs' => languageEggs($author),
        ],
        [
            'name' => 'Bancos de Dados',
            'description' => 'Eggs para bancos de dados e caches populares.',
            'eggs' => databaseEggs($author),
        ],
        [
            'name' => 'Web & Proxy',
            'description' => 'Eggs para servidores web, sites estaticos e proxies reversos.',
            'eggs' => webProxyEggs($author),
        ],
    ];
}

function languageEggs(string $author): array
{
    return [
        languageEgg(
            $author,
            'NodeJS',
            'Egg generico para aplicacoes Node.js, bots, APIs e frameworks JavaScript/TypeScript.',
            [
                'Nodejs 25' => 'ghcr.io/ptero-eggs/yolks:nodejs_25',
                'Nodejs 24' => 'ghcr.io/ptero-eggs/yolks:nodejs_24',
                'Nodejs 23' => 'ghcr.io/ptero-eggs/yolks:nodejs_23',
                'Nodejs 22' => 'ghcr.io/ptero-eggs/yolks:nodejs_22',
                'Nodejs 21' => 'ghcr.io/ptero-eggs/yolks:nodejs_21',
                'Nodejs 20' => 'ghcr.io/ptero-eggs/yolks:nodejs_20',
                'Nodejs 18' => 'ghcr.io/ptero-eggs/yolks:nodejs_18',
                'Nodejs 16' => 'ghcr.io/ptero-eggs/yolks:nodejs_16',
            ],
            'if [ -f package.json ]; then npm install; fi',
            'node index.js',
            'node:24-bookworm-slim'
        ),
        languageEgg(
            $author,
            'Python',
            'Egg generico para scripts, bots, APIs e aplicacoes Python.',
            [
                'Python 3.14' => 'ghcr.io/ptero-eggs/yolks:python_3.14',
                'Python 3.13' => 'ghcr.io/ptero-eggs/yolks:python_3.13',
                'Python 3.12' => 'ghcr.io/ptero-eggs/yolks:python_3.12',
                'Python 3.11' => 'ghcr.io/ptero-eggs/yolks:python_3.11',
                'Python 3.10' => 'ghcr.io/ptero-eggs/yolks:python_3.10',
            ],
            'python -m pip install --upgrade pip && if [ -f requirements.txt ]; then pip install -r requirements.txt; fi',
            'python app.py',
            'python:3.13-slim'
        ),
        languageEgg(
            $author,
            'Java',
            'Egg generico para aplicacoes Java em JAR.',
            [
                'Java 25' => 'ghcr.io/ptero-eggs/yolks:java_25',
                'Java 24' => 'ghcr.io/ptero-eggs/yolks:java_24',
                'Java 23' => 'ghcr.io/ptero-eggs/yolks:java_23',
                'Java 22' => 'ghcr.io/ptero-eggs/yolks:java_22',
                'Java 21' => 'ghcr.io/ptero-eggs/yolks:java_21',
                'Java 17' => 'ghcr.io/ptero-eggs/yolks:java_17',
                'Java 11' => 'ghcr.io/ptero-eggs/yolks:java_11',
                'Java 8' => 'ghcr.io/ptero-eggs/yolks:java_8',
            ],
            '',
            'java -jar app.jar',
            'eclipse-temurin:25-jdk'
        ),
        languageEgg(
            $author,
            'Go',
            'Egg generico para aplicacoes Go/Golang com modules.',
            [
                'Go Latest' => 'ghcr.io/ptero-eggs/yolks:go_latest',
                'Go 1.25' => 'ghcr.io/ptero-eggs/yolks:go_1.25',
                'Go 1.24' => 'ghcr.io/ptero-eggs/yolks:go_1.24',
                'Go 1.23' => 'ghcr.io/ptero-eggs/yolks:go_1.23',
                'Go 1.22' => 'ghcr.io/ptero-eggs/yolks:go_1.22',
                'Go 1.21' => 'ghcr.io/ptero-eggs/yolks:go_1.21',
            ],
            'if [ -f go.mod ]; then go mod download; fi',
            'go run .',
            'golang:1.25-bookworm'
        ),
        languageEgg(
            $author,
            'Rust',
            'Egg generico para projetos Rust/Cargo.',
            [
                'Rust Latest' => 'ghcr.io/ptero-eggs/yolks:rust_latest',
                'Rust 1.60' => 'ghcr.io/ptero-eggs/yolks:rust_1.60',
                'Rust 1.56' => 'ghcr.io/ptero-eggs/yolks:rust_1.56',
            ],
            'if [ -f Cargo.toml ]; then cargo fetch; fi',
            'cargo run --release',
            'rust:1-bookworm'
        ),
        languageEgg(
            $author,
            'Bun',
            'Egg generico para aplicacoes Bun, JavaScript e TypeScript.',
            [
                'Bun Latest' => 'ghcr.io/ptero-eggs/yolks:bun_latest',
                'Bun Canary' => 'ghcr.io/ptero-eggs/yolks:bun_canary',
            ],
            'if [ -f package.json ]; then bun install; fi',
            'bun run index.ts',
            'oven/bun:1-debian'
        ),
        languageEgg(
            $author,
            '.NET',
            'Egg generico para aplicacoes .NET/C#.',
            [
                '.NET 10' => 'ghcr.io/ptero-eggs/yolks:dotnet_10',
                '.NET 9' => 'ghcr.io/ptero-eggs/yolks:dotnet_9',
                '.NET 8' => 'ghcr.io/ptero-eggs/yolks:dotnet_8',
                '.NET 6' => 'ghcr.io/ptero-eggs/yolks:dotnet_6',
            ],
            'if ls *.csproj >/dev/null 2>&1 || ls */*.csproj >/dev/null 2>&1; then dotnet restore; fi',
            'dotnet run',
            'mcr.microsoft.com/dotnet/sdk:10.0'
        ),
        languageEgg(
            $author,
            'Dart',
            'Egg generico para aplicacoes Dart.',
            [
                'Dart Stable' => 'ghcr.io/ptero-eggs/yolks:dart_stable',
                'Dart 3.3' => 'ghcr.io/ptero-eggs/yolks:dart_3.3',
            ],
            'if [ -f pubspec.yaml ]; then dart pub get; fi',
            'dart run',
            'dart:stable'
        ),
        languageEgg(
            $author,
            'PHP',
            'Egg generico para scripts, APIs e workers PHP.',
            [
                'PHP 8.4 CLI' => 'php:8.4-cli',
                'PHP 8.3 CLI' => 'php:8.3-cli',
                'PHP 8.2 CLI' => 'php:8.2-cli',
            ],
            'if [ -f composer.json ]; then install -d /tmp/composer && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && composer install --no-interaction --prefer-dist; fi',
            'php index.php',
            'php:8.4-cli'
        ),
        languageEgg(
            $author,
            'Ruby',
            'Egg generico para scripts, bots, APIs e workers Ruby.',
            [
                'Ruby 3.4' => 'ruby:3.4-slim',
                'Ruby 3.3' => 'ruby:3.3-slim',
                'Ruby 3.2' => 'ruby:3.2-slim',
            ],
            'gem install bundler --no-document && if [ -f Gemfile ]; then bundle install; fi',
            'ruby app.rb',
            'ruby:3.4-slim'
        ),
    ];
}

function databaseEggs(string $author): array
{
    $databaseNameRules = 'required|string|regex:/^[A-Za-z0-9_]{1,64}$/';
    $passwordRules = 'required|string|regex:/^[A-Za-z0-9_.!@#%+=-]{8,128}$/';

    return [
        serviceEgg(
            $author,
            'MariaDB',
            'Servidor MariaDB com inicializacao automatica de database, usuario e senha.',
            [
                'MariaDB 12.0' => 'ghcr.io/ptero-eggs/yolks:mariadb_12.0',
                'MariaDB 11.8' => 'ghcr.io/ptero-eggs/yolks:mariadb_11.8',
                'MariaDB 11.4 LTS' => 'ghcr.io/ptero-eggs/yolks:mariadb_11.4',
                'MariaDB 10.11 LTS' => 'ghcr.io/ptero-eggs/yolks:mariadb_10.11',
            ],
            "mkdir -p /home/container/mysql /home/container/run/mysqld; if [ ! -d /home/container/mysql/mysql ]; then mariadb-install-db --datadir=/home/container/mysql --auth-root-authentication-method=normal; mariadbd --datadir=/home/container/mysql --socket=/home/container/run/mysqld/mysqld.sock --skip-networking & pid=\$!; until mariadb-admin --socket=/home/container/run/mysqld/mysqld.sock ping --silent; do sleep 1; done; mariadb --socket=/home/container/run/mysqld/mysqld.sock -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '{{DB_ROOT_PASSWORD}}'; CREATE DATABASE IF NOT EXISTS {{DB_NAME}}; CREATE USER IF NOT EXISTS '{{DB_USER}}'@'%' IDENTIFIED BY '{{DB_PASSWORD}}'; GRANT ALL PRIVILEGES ON {{DB_NAME}}.* TO '{{DB_USER}}'@'%'; FLUSH PRIVILEGES;\"; mariadb-admin --socket=/home/container/run/mysqld/mysqld.sock -uroot -p'{{DB_ROOT_PASSWORD}}' shutdown; wait \$pid || true; fi; exec mariadbd --datadir=/home/container/mysql --bind-address=0.0.0.0 --port={{server.build.default.port}} --socket=/home/container/run/mysqld/mysqld.sock",
            simpleInstallScript('mkdir -p /mnt/server/mysql /mnt/server/run/mysqld'),
            [
                variable('Database', 'Nome da database criada no primeiro start.', 'DB_NAME', 'pterodb', $databaseNameRules),
                variable('Usuario', 'Usuario criado no primeiro start.', 'DB_USER', 'pterouser', $databaseNameRules),
                variable('Senha do Usuario', 'Senha do usuario criado no primeiro start. Use apenas letras, numeros e ._!@#%+=-', 'DB_PASSWORD', 'ChangeMe123!', $passwordRules),
                variable('Senha Root', 'Senha do usuario root criada no primeiro start. Use apenas letras, numeros e ._!@#%+=-', 'DB_ROOT_PASSWORD', 'RootChangeMe123!', $passwordRules),
            ]
        ),
        serviceEgg(
            $author,
            'PostgreSQL',
            'Servidor PostgreSQL com initdb automatico e database inicial.',
            [
                'PostgreSQL 17' => 'ghcr.io/ptero-eggs/yolks:postgres_17',
                'PostgreSQL 16' => 'ghcr.io/ptero-eggs/yolks:postgres_16',
                'PostgreSQL 15' => 'ghcr.io/ptero-eggs/yolks:postgres_15',
                'PostgreSQL 14' => 'ghcr.io/ptero-eggs/yolks:postgres_14',
            ],
            "mkdir -p /home/container/postgres; if [ ! -s /home/container/postgres/PG_VERSION ]; then printf \"%s\" \"{{PG_ADMIN_PASSWORD}}\" > /tmp/pgpassfile; initdb -D /home/container/postgres --username=\"{{PG_ADMIN_USER}}\" --pwfile=/tmp/pgpassfile --auth-host=scram-sha-256; rm -f /tmp/pgpassfile; echo \"listen_addresses='*'\" >> /home/container/postgres/postgresql.conf; pg_ctl -D /home/container/postgres -o \"-p {{server.build.default.port}}\" -w start; createdb -p {{server.build.default.port}} -U \"{{PG_ADMIN_USER}}\" \"{{PG_DATABASE}}\" || true; pg_ctl -D /home/container/postgres -m fast -w stop; fi; exec postgres -D /home/container/postgres -p {{server.build.default.port}}",
            simpleInstallScript('mkdir -p /mnt/server/postgres'),
            [
                variable('Usuario Admin', 'Usuario administrador criado no initdb.', 'PG_ADMIN_USER', 'postgres', $databaseNameRules),
                variable('Senha Admin', 'Senha do usuario administrador. Use apenas letras, numeros e ._!@#%+=-', 'PG_ADMIN_PASSWORD', 'ChangeMe123!', $passwordRules),
                variable('Database', 'Database criada no primeiro start.', 'PG_DATABASE', 'pterodb', $databaseNameRules),
            ]
        ),
        serviceEgg(
            $author,
            'MongoDB',
            'Servidor MongoDB com usuario root inicial e autenticacao habilitada.',
            [
                'MongoDB 8' => 'ghcr.io/ptero-eggs/yolks:mongodb_8',
                'MongoDB 7' => 'ghcr.io/ptero-eggs/yolks:mongodb_7',
                'MongoDB 6' => 'ghcr.io/ptero-eggs/yolks:mongodb_6',
            ],
            "mkdir -p /home/container/data/db /home/container/data/configdb; if [ ! -f /home/container/data/db/.auth_created ]; then mongod --dbpath /home/container/data/db --bind_ip 127.0.0.1 --port 27017 --fork --logpath /home/container/mongod-init.log; until mongosh --eval \"db.adminCommand('ping')\" >/dev/null 2>&1; do sleep 1; done; mongosh admin --eval \"db.createUser({user:'{{MONGO_ROOT_USER}}',pwd:'{{MONGO_ROOT_PASSWORD}}',roles:[{role:'root',db:'admin'}]})\"; mongod --dbpath /home/container/data/db --shutdown || true; touch /home/container/data/db/.auth_created; fi; exec mongod --dbpath /home/container/data/db --bind_ip 0.0.0.0 --port {{server.build.default.port}} --auth",
            simpleInstallScript('mkdir -p /mnt/server/data/db /mnt/server/data/configdb'),
            [
                variable('Usuario Root', 'Usuario root criado no primeiro start.', 'MONGO_ROOT_USER', 'admin', $databaseNameRules),
                variable('Senha Root', 'Senha root do MongoDB. Use apenas letras, numeros e ._!@#%+=-', 'MONGO_ROOT_PASSWORD', 'ChangeMe123!', $passwordRules),
            ]
        ),
        serviceEgg(
            $author,
            'Redis',
            'Servidor Redis com appendonly e senha obrigatoria.',
            [
                'Redis 8' => 'ghcr.io/ptero-eggs/yolks:redis_8',
                'Redis 7' => 'ghcr.io/ptero-eggs/yolks:redis_7',
                'Redis 6' => 'ghcr.io/ptero-eggs/yolks:redis_6',
            ],
            'mkdir -p /home/container/data; exec redis-server --bind 0.0.0.0 --port {{server.build.default.port}} --dir /home/container/data --appendonly yes --requirepass "{{REDIS_PASSWORD}}"',
            simpleInstallScript('mkdir -p /mnt/server/data'),
            [
                variable('Senha Redis', 'Senha exigida para conexao ao Redis. Use apenas letras, numeros e ._!@#%+=-', 'REDIS_PASSWORD', 'ChangeMe123!', $passwordRules),
            ]
        ),
        serviceEgg(
            $author,
            'Valkey',
            'Servidor Valkey, fork comunitario do Redis, com appendonly e senha obrigatoria.',
            [
                'Valkey 8 Alpine' => 'valkey/valkey:8-alpine',
                'Valkey 7 Alpine' => 'valkey/valkey:7-alpine',
            ],
            'mkdir -p /home/container/data; exec valkey-server --bind 0.0.0.0 --port {{server.build.default.port}} --dir /home/container/data --appendonly yes --requirepass "{{VALKEY_PASSWORD}}"',
            simpleInstallScript('mkdir -p /mnt/server/data'),
            [
                variable('Senha Valkey', 'Senha exigida para conexao ao Valkey. Use apenas letras, numeros e ._!@#%+=-', 'VALKEY_PASSWORD', 'ChangeMe123!', $passwordRules),
            ]
        ),
    ];
}

function webProxyEggs(string $author): array
{
    return [
        serviceEgg(
            $author,
            'Nginx Static Site',
            'Servidor Nginx para site estatico em /home/container/html.',
            [
                'Nginx Stable Alpine' => 'nginx:stable-alpine',
                'Nginx Mainline Alpine' => 'nginx:mainline-alpine',
            ],
            'mkdir -p /home/container/html /home/container/nginx/logs /home/container/nginx/client_body_temp /home/container/nginx/proxy_temp /home/container/nginx/fastcgi_temp /home/container/nginx/uwsgi_temp /home/container/nginx/scgi_temp; if [ ! -f /home/container/html/index.html ]; then printf "<h1>Pterodactyl Nginx</h1>\n" > /home/container/html/index.html; fi; printf "pid /home/container/nginx/nginx.pid;\nevents {}\nhttp { include /etc/nginx/mime.types; access_log /home/container/nginx/logs/access.log; error_log /home/container/nginx/logs/error.log; server { listen {{server.build.default.port}}; server_name _; root /home/container/html; index index.html index.htm; location / { try_files \\$uri \\$uri/ =404; } } }\n" > /home/container/nginx/nginx.conf; exec nginx -p /home/container/nginx -c /home/container/nginx/nginx.conf -g "daemon off;"',
            simpleInstallScript('mkdir -p /mnt/server/html /mnt/server/nginx/logs'),
            []
        ),
        serviceEgg(
            $author,
            'Nginx Reverse Proxy',
            'Proxy reverso Nginx para encaminhar trafego HTTP para outro destino.',
            [
                'Nginx Stable Alpine' => 'nginx:stable-alpine',
                'Nginx Mainline Alpine' => 'nginx:mainline-alpine',
            ],
            'mkdir -p /home/container/nginx/logs /home/container/nginx/client_body_temp /home/container/nginx/proxy_temp /home/container/nginx/fastcgi_temp /home/container/nginx/uwsgi_temp /home/container/nginx/scgi_temp; printf "pid /home/container/nginx/nginx.pid;\nevents {}\nhttp { access_log /home/container/nginx/logs/access.log; error_log /home/container/nginx/logs/error.log; server { listen {{server.build.default.port}}; server_name _; location / { proxy_pass {{PROXY_TARGET}}; proxy_http_version 1.1; proxy_set_header Host \\$host; proxy_set_header X-Real-IP \\$remote_addr; proxy_set_header X-Forwarded-For \\$proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto \\$scheme; } } }\n" > /home/container/nginx/nginx.conf; exec nginx -p /home/container/nginx -c /home/container/nginx/nginx.conf -g "daemon off;"',
            simpleInstallScript('mkdir -p /mnt/server/nginx/logs'),
            [
                variable('Destino do Proxy', 'URL de destino do proxy. Ex: http://127.0.0.1:3000', 'PROXY_TARGET', 'http://127.0.0.1:3000', 'required|string|max:256'),
            ]
        ),
        serviceEgg(
            $author,
            'Caddy Static Site',
            'Servidor Caddy para site estatico em /home/container/site.',
            [
                'Caddy 2 Alpine' => 'caddy:2-alpine',
                'Caddy 2.11 Alpine' => 'caddy:2.11-alpine',
            ],
            'mkdir -p /home/container/site /home/container/data /home/container/config; if [ ! -f /home/container/site/index.html ]; then printf "<h1>Pterodactyl Caddy</h1>\n" > /home/container/site/index.html; fi; export XDG_DATA_HOME=/home/container/data; export XDG_CONFIG_HOME=/home/container/config; exec caddy file-server --listen :{{server.build.default.port}} --root /home/container/site',
            simpleInstallScript('mkdir -p /mnt/server/site /mnt/server/data /mnt/server/config'),
            []
        ),
        serviceEgg(
            $author,
            'Caddy Reverse Proxy',
            'Proxy reverso Caddy simples para encaminhar trafego HTTP para outro destino.',
            [
                'Caddy 2 Alpine' => 'caddy:2-alpine',
                'Caddy 2.11 Alpine' => 'caddy:2.11-alpine',
            ],
            'mkdir -p /home/container/data /home/container/config; export XDG_DATA_HOME=/home/container/data; export XDG_CONFIG_HOME=/home/container/config; exec caddy reverse-proxy --from :{{server.build.default.port}} --to "{{PROXY_TARGET}}"',
            simpleInstallScript('mkdir -p /mnt/server/data /mnt/server/config'),
            [
                variable('Destino do Proxy', 'URL de destino do proxy. Ex: http://127.0.0.1:3000', 'PROXY_TARGET', 'http://127.0.0.1:3000', 'required|string|max:256'),
            ]
        ),
        serviceEgg(
            $author,
            'Apache Static Site',
            'Servidor Apache httpd para site estatico em /home/container/htdocs.',
            [
                'Apache httpd 2.4 Alpine' => 'httpd:2.4-alpine',
                'Apache httpd 2.4' => 'httpd:2.4',
            ],
            'mkdir -p /home/container/htdocs /home/container/apache/logs; if [ ! -f /home/container/htdocs/index.html ]; then printf "<h1>Pterodactyl Apache</h1>\n" > /home/container/htdocs/index.html; fi; printf "ServerName localhost\nListen {{server.build.default.port}}\nPidFile /home/container/apache/httpd.pid\nErrorLog /home/container/apache/logs/error.log\nCustomLog /home/container/apache/logs/access.log combined\nLoadModule mpm_event_module modules/mod_mpm_event.so\nLoadModule authz_core_module modules/mod_authz_core.so\nLoadModule dir_module modules/mod_dir.so\nLoadModule mime_module modules/mod_mime.so\nLoadModule log_config_module modules/mod_log_config.so\nTypesConfig /usr/local/apache2/conf/mime.types\nDocumentRoot \"/home/container/htdocs\"\n<Directory \"/home/container/htdocs\">\nRequire all granted\nOptions Indexes FollowSymLinks\nAllowOverride All\n</Directory>\nDirectoryIndex index.html\n" > /home/container/apache/httpd.conf; exec httpd -f /home/container/apache/httpd.conf -DFOREGROUND',
            simpleInstallScript('mkdir -p /mnt/server/htdocs /mnt/server/apache/logs'),
            []
        ),
        serviceEgg(
            $author,
            'PHP Web Server',
            'Servidor PHP embutido para aplicacoes simples em /home/container/public.',
            [
                'PHP 8.4 CLI' => 'php:8.4-cli',
                'PHP 8.3 CLI' => 'php:8.3-cli',
                'PHP 8.2 CLI' => 'php:8.2-cli',
            ],
            "mkdir -p /home/container/public; if [ ! -f /home/container/public/index.php ]; then printf \"<?php echo 'Pterodactyl PHP Web Server';\\n\" > /home/container/public/index.php; fi; exec php -S 0.0.0.0:{{server.build.default.port}} -t /home/container/public",
            installScript('if [ -f composer.json ]; then install -d /tmp/composer && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && composer install --no-interaction --prefer-dist; fi'),
            [],
            'php:8.4-cli'
        ),
    ];
}

function serviceEgg(
    string $author,
    string $name,
    string $description,
    array $dockerImages,
    string $startup,
    string $installScript,
    array $variables,
    string $installContainer = 'ghcr.io/ptero-eggs/installers:debian'
): array {
    return [
        '_comment' => 'DO NOT EDIT: FILE GENERATED AUTOMATICALLY BY PTERODACTYL PANEL - PTERODACTYL.IO',
        'meta' => [
            'version' => 'PTDL_v2',
            'update_url' => null,
        ],
        'exported_at' => date(DATE_ATOM),
        'name' => $name,
        'author' => $author,
        'description' => $description,
        'features' => [],
        'docker_images' => $dockerImages,
        'file_denylist' => [],
        'startup' => $startup,
        'config' => [
            'files' => '{}',
            'startup' => "{\r\n    \"done\": [\r\n        \"ready\",\r\n        \"Ready\",\r\n        \"started\",\r\n        \"Started\",\r\n        \"listening\",\r\n        \"Listening\",\r\n        \"server started\",\r\n        \"database system is ready\",\r\n        \"Ready to accept connections\"\r\n    ]\r\n}",
            'logs' => '{}',
            'stop' => '^C',
        ],
        'scripts' => [
            'installation' => [
                'script' => $installScript,
                'container' => $installContainer,
                'entrypoint' => 'bash',
            ],
        ],
        'variables' => $variables,
    ];
}

function simpleInstallScript(string $command): string
{
    $script = <<<'SCRIPT'
#!/bin/bash
set -e

mkdir -p /mnt/server
cd /mnt/server

__COMMAND__

echo "Install complete"
SCRIPT;

    return str_replace('__COMMAND__', $command, $script);
}

function languageEgg(
    string $author,
    string $name,
    string $description,
    array $dockerImages,
    string $defaultInstallCommand,
    string $defaultStartCommand,
    string $installContainer
): array {
    return [
        '_comment' => 'DO NOT EDIT: FILE GENERATED AUTOMATICALLY BY PTERODACTYL PANEL - PTERODACTYL.IO',
        'meta' => [
            'version' => 'PTDL_v2',
            'update_url' => null,
        ],
        'exported_at' => date(DATE_ATOM),
        'name' => $name,
        'author' => $author,
        'description' => $description,
        'features' => [],
        'docker_images' => $dockerImages,
        'file_denylist' => [],
        'startup' => 'if [[ ! -z "${CMD2}" ]]; then eval "${CMD2}"; fi; eval "${CMD1}"',
        'config' => [
            'files' => '{}',
            'startup' => "{\r\n    \"done\": [\r\n        \"listening\",\r\n        \"Listening\",\r\n        \"ready\",\r\n        \"Ready\",\r\n        \"started\",\r\n        \"Started\"\r\n    ]\r\n}",
            'logs' => '{}',
            'stop' => '^C',
        ],
        'scripts' => [
            'installation' => [
                'script' => installScript($defaultInstallCommand),
                'container' => $installContainer,
                'entrypoint' => 'bash',
            ],
        ],
        'variables' => commonVariables($defaultStartCommand),
    ];
}

function installScript(string $defaultInstallCommand): string
{
    $escapedDefault = str_replace("'", "'\\''", $defaultInstallCommand);

    $script = <<<'SCRIPT'
#!/bin/bash
set -e

echo "Starting generic language app installation"

if command -v apt >/dev/null 2>&1; then
    apt update
    apt install -y curl jq file unzip tar ca-certificates build-essential
fi

mkdir -p /mnt/server
cd /mnt/server

BUILTIN_INSTALL_CMD='__BUILTIN_INSTALL_CMD__'

if [[ -n "${BUILTIN_INSTALL_CMD}" ]]; then
    echo "Running built-in install command"
    eval "${BUILTIN_INSTALL_CMD}"
else
    echo "No built-in install step needed"
fi

echo "Install complete"
SCRIPT;

    return str_replace('__BUILTIN_INSTALL_CMD__', $escapedDefault, $script);
}

function commonVariables(string $defaultStartCommand): array
{
    return [
        variable(
            'Comando 1',
            "Comando principal para iniciar a aplicacao.\r\nEx: " . $defaultStartCommand,
            'CMD1',
            $defaultStartCommand,
            'required|string|max:512'
        ),
        variable(
            'Comando 2 (opcional)',
            "Comando secundario executado antes do Comando 1.\r\nDeixe em branco para ignorar.",
            'CMD2',
            '',
            'nullable|string|max:512'
        ),
    ];
}

function variable(string $name, string $description, string $env, string $default, string $rules): array
{
    return [
        'name' => $name,
        'description' => $description,
        'env_variable' => $env,
        'default_value' => $default,
        'user_viewable' => true,
        'user_editable' => true,
        'rules' => $rules,
        'field_type' => 'text',
    ];
}

function slug(string $value): string
{
    $value = strtolower($value);
    $value = preg_replace('/[^a-z0-9]+/', '-', $value) ?: 'egg';

    return 'egg-' . trim($value, '-');
}

function canPrompt(): bool
{
    return !function_exists('posix_isatty') || posix_isatty(STDIN);
}

function prompt(string $label, string $default): string
{
    fwrite(STDOUT, $label . ' [' . $default . ']: ');

    $input = trim((string) fgets(STDIN));

    return $input === '' ? $default : $input;
}

function confirm(string $label, bool $default): bool
{
    $suffix = $default ? 'S/n' : 's/N';
    fwrite(STDOUT, $label . ' [' . $suffix . ']: ');

    $input = strtolower(trim((string) fgets(STDIN)));

    if ($input === '') {
        return $default;
    }

    return in_array($input, ['s', 'sim', 'y', 'yes'], true);
}

function out(string $message): void
{
    fwrite(STDOUT, $message . PHP_EOL);
}

function fail(string $message): never
{
    fwrite(STDERR, $message . PHP_EOL);
    exit(1);
}
