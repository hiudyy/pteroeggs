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

const DEFAULT_NEST = 'Linguagens';
const DEFAULT_AUTHOR = 'pteroconfig@example.com';
const NEST_DESCRIPTION = 'Eggs genericos para executar aplicacoes em varias linguagens de programacao.';

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
    $nestName = $options['nest'] ?: DEFAULT_NEST;
    $eggs = languageEggs($author);

    if ($options['dry-run']) {
        printDryRun($nestName, $author, $eggs);
        return;
    }

    $panelPath = assertPanelPath($options['panel']);
    $app = bootstrapPanel($panelPath);

    $nest = findOrCreateNest($app, $nestName, $author);
    [$created, $updated] = importEggs($app, $nest, $eggs);

    out('Nest: ' . $nest->name . ' (#' . $nest->id . ')');
    out('Eggs criados: ' . $created);
    out('Eggs atualizados: ' . $updated);
}

function parseOptions(array $argv): array
{
    $result = [
        'panel' => null,
        'nest' => null,
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

        foreach (['panel', 'nest', 'author'] as $key) {
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
        $options['nest'] = $options['nest'] ?: DEFAULT_NEST;
        $options['author'] = $options['author'] ?: DEFAULT_AUTHOR;

        return $options;
    }

    $shouldPrompt = $options['interactive'] || $options['panel'] === null;

    if (!$shouldPrompt) {
        $options['nest'] = $options['nest'] ?: DEFAULT_NEST;
        $options['author'] = $options['author'] ?: DEFAULT_AUTHOR;

        return $options;
    }

    if (!canPrompt()) {
        fail('Informe --panel=/caminho/do/panel ao executar sem terminal interativo.');
    }

    out('Importador de eggs de linguagens para Pterodactyl');
    out('As credenciais do banco serao lidas automaticamente do .env do Panel.');
    out('');

    $options['panel'] = prompt('Pasta do Pterodactyl Panel', $options['panel'] ?: '/var/www/pterodactyl');
    $options['nest'] = prompt('Nome do nest', $options['nest'] ?: DEFAULT_NEST);
    $options['author'] = prompt('Email/autor dos eggs', $options['author'] ?: DEFAULT_AUTHOR);

    out('');
    out('Resumo:');
    out('  Panel: ' . $options['panel']);
    out('  Nest: ' . $options['nest']);
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
    out('  --nest=Linguagens      Nome do nest que sera criado/reutilizado.');
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

function findOrCreateNest(mixed $app, string $nestName, string $author): Nest
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
        'description' => NEST_DESCRIPTION,
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

function printDryRun(string $nestName, string $author, array $eggs): void
{
    out('Nest: ' . $nestName);
    out('Autor: ' . $author);
    out('Eggs:');

    foreach ($eggs as $egg) {
        $images = implode(', ', array_keys($egg['docker_images']));
        out('  - ' . $egg['name'] . ' [' . $images . ']');
    }
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
            'if [ -f Gemfile ]; then bundle install; fi',
            'ruby app.rb',
            'ruby:3.4-slim'
        ),
    ];
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
        'variables' => commonVariables($defaultStartCommand, $defaultInstallCommand),
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
    apt install -y git curl jq file unzip tar ca-certificates
fi

mkdir -p /mnt/server
cd /mnt/server

if [[ "${USER_UPLOAD}" != "1" ]] && [[ -n "${GIT_ADDRESS}" ]]; then
    if [[ -d .git ]]; then
        echo "Existing git repository found, pulling latest changes"
        git pull --ff-only || true
    elif [[ -z "$(ls -A .)" ]]; then
        echo "Cloning ${GIT_ADDRESS}"
        git clone --depth 1 --single-branch --branch "${BRANCH:-main}" "${GIT_ADDRESS}" .
    else
        echo "Server directory is not empty, skipping git clone"
    fi
fi

DEFAULT_INSTALL_CMD='__DEFAULT_INSTALL_CMD__'

if [[ -n "${INSTALL_CMD}" ]]; then
    echo "Running custom install command"
    eval "${INSTALL_CMD}"
elif [[ -n "${DEFAULT_INSTALL_CMD}" ]]; then
    echo "Running default install command"
    eval "${DEFAULT_INSTALL_CMD}"
else
    echo "No install command configured"
fi

echo "Install complete"
SCRIPT;

    return str_replace('__DEFAULT_INSTALL_CMD__', $escapedDefault, $script);
}

function commonVariables(string $defaultStartCommand, string $defaultInstallCommand): array
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
        variable(
            'Comando de instalacao',
            "Comando executado durante a instalacao.\r\nDeixe em branco para usar o padrao: " . ($defaultInstallCommand ?: 'nenhum'),
            'INSTALL_CMD',
            '',
            'nullable|string|max:1024'
        ),
        variable(
            'Repositorio Git',
            "Repositorio Git publico para clonar na instalacao.\r\nDeixe em branco se for enviar os arquivos manualmente.",
            'GIT_ADDRESS',
            '',
            'nullable|string|max:256'
        ),
        variable(
            'Branch Git',
            'Branch usada ao clonar o repositorio Git.',
            'BRANCH',
            'main',
            'required|string|max:64'
        ),
        variable(
            'Upload manual',
            'Use 1 para ignorar clone Git e manter somente arquivos enviados pelo usuario. Use 0 para permitir clone Git.',
            'USER_UPLOAD',
            '0',
            'required|boolean'
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
