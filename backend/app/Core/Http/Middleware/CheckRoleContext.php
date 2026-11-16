<?php

namespace App\Core\Http\Middleware;

use App\Core\Exceptions\DomainException;
use App\Modules\Identity\Models\Usuario;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckRoleContext
{
    public function handle(Request $request, Closure $next, string $role, string ...$otherRoles): Response
    {
        $user = $request->user();
        $allowedRoles = array_map('strtoupper', [$role, ...$otherRoles]);
        if (! $user instanceof Usuario || ! $user->activo || ! in_array($user->rolActivo(), $allowedRoles, true)) {
            throw new DomainException(
                'FORBIDDEN_ROLE',
                'Este perfil no puede usar este módulo.',
                403
            );
        }

        return $next($request);
    }
}
