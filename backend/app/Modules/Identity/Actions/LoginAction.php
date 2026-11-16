<?php

namespace App\Modules\Identity\Actions;

use App\Core\Exceptions\DomainException;
use App\Modules\Identity\Models\Usuario;
use Illuminate\Support\Facades\Hash;

class LoginAction
{
    /**
     * @return array{user: Usuario, role: string, station_id: int|null}
     */
    public function execute(string $username, string $password, string $context): array
    {
        $context = strtoupper($context);
        /** @var Usuario|null $user */
        $user = Usuario::query()->where('username', $username)->first();

        if (! $user) {
            throw new DomainException('AUTH_INVALID', 'Credenciales incorrectas.', 401);
        }

        if ($user->bloqueado_hasta && $user->bloqueado_hasta->isFuture()) {
            throw new DomainException('AUTH_LOCKED', 'Usuario bloqueado temporalmente.', 403);
        }

        if (! $user->activo || ! Hash::check($password, $user->password_hash)) {
            $user->increment('intentos_fallidos');
            if ($user->intentos_fallidos >= 5) {
                $user->bloqueado_hasta = now()->addMinutes(15);
                $user->save();
            }
            throw new DomainException('AUTH_INVALID', 'Credenciales incorrectas.', 401);
        }

        $role = $user->rolActivo();
        if ($role !== $context) {
            throw new DomainException('FORBIDDEN_ROLE', 'El usuario no tiene el perfil '.$context.'.', 403);
        }

        $user->intentos_fallidos = 0;
        $user->bloqueado_hasta = null;
        $user->ultimo_login = now();
        $user->save();

        return [
            'user' => $user->load('persona'),
            'role' => $role,
            'station_id' => $user->idEstacion(),
        ];
    }
}
