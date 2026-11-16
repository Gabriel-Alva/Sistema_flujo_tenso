<?php

namespace App\Core\Database;

use RuntimeException;
use Symfony\Component\Process\Process;

class SchemaFileRunner
{
    public function runFile(string $absolutePath): void
    {
        if (! is_file($absolutePath)) {
            throw new RuntimeException("No existe el archivo SQL: {$absolutePath}");
        }

        $this->runWithMysqlClient($absolutePath);
    }

    private function runWithMysqlClient(string $absolutePath): void
    {
        $config = config('database.connections.mysql_admin');
        if (! $config['username'] || (! $config['password'] && ! app()->environment('local'))) {
            throw new RuntimeException('Configure DB_ADMIN_USERNAME y DB_ADMIN_PASSWORD para instalar el esquema. Solo en desarrollo local se permite una contraseña vacía.');
        }
        $mysql = $this->mysqlBinary();
        $file = str_replace('\\', '/', $absolutePath);

        $args = [
            $mysql,
            '--host='.$config['host'],
            '--port='.(string) $config['port'],
            '--user='.$config['username'],
            '--database='.$config['database'],
            '--default-character-set=utf8mb4',
        ];

        $process = new Process($args);
        $process->setInput(file_get_contents($absolutePath));
        if (! empty($config['password'])) {
            $process->setEnv([...$_ENV, 'MYSQL_PWD' => $config['password']]);
        }
        $process->setTimeout(180);
        $process->run();

        if (! $process->isSuccessful()) {
            throw new RuntimeException(
                "MySQL rechazó {$file}: ".$process->getErrorOutput().$process->getOutput()
            );
        }
    }

    private function mysqlBinary(): string
    {
        $configured = env('MYSQL_CLIENT');
        $candidates = array_filter([
            $configured,
            'C:\\wamp64\\bin\\mysql\\mysql8.4.7\\bin\\mysql.exe',
            'mysql',
        ]);

        foreach ($candidates as $path) {
            if ($path === 'mysql' || is_file($path)) {
                return $path;
            }
        }

        throw new RuntimeException('No se encontró mysql.exe. Defina MYSQL_CLIENT en .env');
    }
}
