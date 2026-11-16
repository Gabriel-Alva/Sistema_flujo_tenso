<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;

class CreateSipanUser extends Command
{
    protected $signature = 'sipan:user-create {username} {role : ADMINISTRADOR, CAJERO, MESERO o COCINERO}';

    protected $description = 'Crea un usuario operativo con contraseña solicitada de forma segura';

    public function handle(): int
    {
        $username = trim((string) $this->argument('username'));
        $role = strtoupper((string) $this->argument('role'));
        $roleTables = [
            'ADMINISTRADOR' => 'ADMINISTRADOR',
            'CAJERO' => 'CAJERO',
            'MESERO' => 'MESERO',
            'COCINERO' => 'COCINERO',
        ];
        if ($username === '' || strlen($username) > 80 || ! isset($roleTables[$role])) {
            throw new InvalidArgumentException('Usuario o perfil inválido.');
        }

        $idPersona = trim((string) $this->ask('ID de persona'));
        $nombres = trim((string) $this->ask('Nombres'));
        $primerApellido = trim((string) $this->ask('Primer apellido'));
        $segundoApellido = trim((string) $this->ask('Segundo apellido (opcional)'));
        $tipoDocumento = strtoupper(trim((string) $this->choice('Tipo de documento', ['DNI', 'CE', 'PASAPORTE'])));
        $numeroDocumento = trim((string) $this->ask('Número de documento'));
        $telefono = trim((string) $this->ask('Teléfono (opcional)'));
        $email = trim((string) $this->ask('Email (opcional)'));
        $stationId = $role === 'COCINERO'
            ? (int) $this->ask('ID de estación de cocina activa')
            : null;
        $password = $this->secret('Contraseña (mínimo 16 caracteres)');
        $confirmation = $this->secret('Confirma la contraseña');

        if ($idPersona === '' || strlen($idPersona) > 20 || $nombres === '' || strlen($nombres) > 80
            || $primerApellido === '' || strlen($primerApellido) > 80 || $numeroDocumento === ''
            || strlen($numeroDocumento) > 20 || ! is_string($password) || strlen($password) < 16
            || ! hash_equals($password, (string) $confirmation)) {
            throw ValidationException::withMessages([
                'user' => 'Los datos son inválidos o la contraseña no cumple los requisitos.',
            ]);
        }

        DB::transaction(function () use (
            $username,
            $role,
            $roleTables,
            $idPersona,
            $nombres,
            $primerApellido,
            $segundoApellido,
            $tipoDocumento,
            $numeroDocumento,
            $telefono,
            $email,
            $stationId,
            $password
        ): void {
            if (DB::table('USUARIO')->where('username', $username)->exists()
                || DB::table('PERSONA')->where('id_persona', $idPersona)->exists()) {
                throw new InvalidArgumentException('El usuario o la persona ya existen.');
            }
            if ($role === 'COCINERO' && ! DB::table('ESTACION_COCINA')
                ->where('id_estacion', $stationId)
                ->where('activa', 1)
                ->exists()) {
                throw new InvalidArgumentException('La estación de cocina no existe o está inactiva.');
            }

            DB::table('PERSONA')->insert([
                'id_persona' => $idPersona,
                'nombres' => $nombres,
                'primer_apellido' => $primerApellido,
                'segundo_apellido' => $segundoApellido !== '' ? $segundoApellido : null,
                'tipo_documento' => $tipoDocumento,
                'numero_documento' => $numeroDocumento,
                'telefono' => $telefono !== '' ? $telefono : null,
                'email' => $email !== '' ? $email : null,
            ]);
            $userId = DB::table('USUARIO')->insertGetId([
                'id_persona' => $idPersona,
                'username' => $username,
                'password_hash' => Hash::make($password),
                'activo' => 1,
                'intentos_fallidos' => 0,
            ]);

            if ($role === 'COCINERO') {
                DB::table($roleTables[$role])->insert([
                    'id_persona' => $idPersona,
                    'id_estacion' => $stationId,
                ]);
            } else {
                DB::table($roleTables[$role])->insert(['id_persona' => $idPersona]);
            }

            DB::table('AUDITORIA')->insert([
                'tabla' => 'USUARIO',
                'id_registro' => (string) $userId,
                'accion' => 'I',
                'datos_despues' => json_encode(['username' => $username, 'role' => $role]),
                'id_usuario' => null,
                'fecha' => now(),
            ]);
        });

        $this->info('Usuario creado correctamente.');

        return self::SUCCESS;
    }
}
