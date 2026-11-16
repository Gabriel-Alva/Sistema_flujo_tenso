<?php

namespace App\Modules\Settings\Actions;

use App\Core\Database\AdminProcedureGateway;

class UpdateAdminParameterAction
{
    public function __construct(private readonly AdminProcedureGateway $procedures) {}

    public function execute(string $key, string $value): void
    {
        $this->procedures->execute('sp_admin_actualizar_parametro', [
            (int) auth()->id(),
            $key,
            $value,
        ]);
    }
}
