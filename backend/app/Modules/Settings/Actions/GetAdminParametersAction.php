<?php

namespace App\Modules\Settings\Actions;

use App\Core\Database\AdminProcedureGateway;

class GetAdminParametersAction
{
    public function __construct(private readonly AdminProcedureGateway $procedures) {}

    /** @return array<int, object> */
    public function execute(): array
    {
        return $this->procedures->rows('sp_admin_listar_parametros');
    }
}
