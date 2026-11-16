<?php

namespace App\Console\Commands;

use App\Core\Database\SchemaFileRunner;
use Illuminate\Console\Command;
use InvalidArgumentException;
use PDO;

class InstallSipanSchema extends Command
{
    protected $signature = 'sipan:install-schema {--seed : Ejecuta seeders de restaurante}';

    protected $description = 'Crea bd_chifa_sipan y aplica el esquema v3.1, las rutinas operativas y sus triggers';

    public function handle(SchemaFileRunner $runner): int
    {
        $database = config('database.connections.mysql.database', 'bd_chifa_sipan');
        if ($database !== 'bd_chifa_sipan') {
            throw new InvalidArgumentException('La instalación solo admite la base de datos bd_chifa_sipan.');
        }
        if (! preg_match('/^[A-Za-z0-9_]+$/', $database)) {
            throw new InvalidArgumentException('DB_DATABASE solo puede contener letras, números y guion bajo.');
        }
        config(['database.connections.mysql_admin.database' => $database]);
        $this->createDatabase($database);

        $schemaPath = database_path('schema');
        $files = [
            '000_baseline.sql',
            '010_remediation.sql',
            '020_views.sql',
            '021_kitchen_queue_view.sql',
            '030_procedures.sql',
            '031_kitchen_item_status.sql',
            '040_triggers.sql',
            '070_admin_operations.sql',
            '080_cashier_dashboard.sql',
        ];

        foreach ($files as $file) {
            $this->info("Aplicando {$file}...");
            $runner->runFile($schemaPath.DIRECTORY_SEPARATOR.$file);
        }

        $this->info('Aplicando 050_events.sql...');
        $runner->runFile($schemaPath.DIRECTORY_SEPARATOR.'050_events.sql');

        $this->call('migrate', ['--database' => 'mysql_admin', '--force' => true]);
        $runner->runFile($schemaPath.DIRECTORY_SEPARATOR.'060_privileges.sql');

        if ($this->option('seed')) {
            $this->call('db:seed', ['--database' => 'mysql_admin', '--force' => true]);
        }

        $this->info('Esquema Chifa Sipán listo.');

        return self::SUCCESS;
    }

    private function createDatabase(string $database): void
    {
        $config = config('database.connections.mysql_admin');
        if (! $config['username'] || (! $config['password'] && ! app()->environment('local'))) {
            throw new InvalidArgumentException('Configure DB_ADMIN_USERNAME y DB_ADMIN_PASSWORD para instalar el esquema. Solo en desarrollo local se permite una contraseña vacía.');
        }
        $dsn = sprintf('mysql:host=%s;port=%s;charset=utf8mb4', $config['host'], $config['port']);
        $pdo = new PDO($dsn, $config['username'], $config['password'] ?: null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        ]);
        $pdo->exec(
            'CREATE DATABASE IF NOT EXISTS `'.$database.'` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci'
        );
    }
}
