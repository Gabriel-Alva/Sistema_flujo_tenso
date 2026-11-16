<?php

namespace App\Modules\Salon\Actions;

use App\Core\Database\AdminProcedureGateway;

class ManageAdminSalonAction
{
    public function __construct(private readonly AdminProcedureGateway $procedures) {}

    /** @return array<string, array<int, object>> */
    public function index(): array
    {
        return [
            'zones' => $this->procedures->rows('sp_admin_listar_zonas'),
            'tables' => $this->procedures->rows('sp_admin_listar_mesas'),
        ];
    }

    /** @param array<string, mixed> $data */
    public function saveZone(array $data): void
    {
        $this->procedures->execute('sp_admin_guardar_zona', [
            (int) auth()->id(),
            $data['id_zona'] ?? null,
            $data['nombre'],
            (int) $data['activa'],
        ]);
    }

    /** @param array<string, mixed> $data */
    public function saveTable(array $data): void
    {
        $this->procedures->execute('sp_admin_guardar_mesa', [
            (int) auth()->id(),
            $data['id_mesa'] ?? null,
            $data['id_zona'],
            $data['numero'],
            $data['capacidad'],
            (int) $data['activa'],
        ]);
    }
}
