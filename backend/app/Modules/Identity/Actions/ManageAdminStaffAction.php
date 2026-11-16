<?php

namespace App\Modules\Identity\Actions;

use App\Core\Database\AdminProcedureGateway;
use Illuminate\Support\Facades\Hash;

class ManageAdminStaffAction
{
    public function __construct(private readonly AdminProcedureGateway $procedures) {}

    /** @return array<string, array<int, object>> */
    public function index(string $search): array
    {
        return [
            'staff' => $this->procedures->rows('sp_admin_listar_personal', [$search]),
            'stations' => $this->procedures->rows('sp_admin_listar_estaciones'),
        ];
    }

    /** @param array<string, mixed> $data */
    public function create(array $data): void
    {
        $this->procedures->execute('sp_admin_crear_usuario', [
            (int) auth()->id(),
            $data['id_persona'],
            $data['nombres'],
            $data['primer_apellido'],
            ($data['segundo_apellido'] ?? '') ?: null,
            ($data['tipo_documento'] ?? '') ?: null,
            ($data['numero_documento'] ?? '') ?: null,
            ($data['telefono'] ?? '') ?: null,
            ($data['email'] ?? '') ?: null,
            $data['username'],
            Hash::make($data['password']),
            $data['rol'],
            ($data['id_estacion'] ?? '') ?: null,
        ]);
    }

    public function setActive(int $userId, bool $active): void
    {
        $this->procedures->execute('sp_admin_estado_usuario', [
            (int) auth()->id(),
            $userId,
            (int) $active,
        ]);
    }
}
