<?php

namespace App\Modules\Reporting\Actions;

use App\Core\Database\AdminProcedureGateway;

class GetAdminSalesReportAction
{
    public function __construct(private readonly AdminProcedureGateway $procedures) {}

    /** @return array<int, object> */
    public function execute(string $from, string $to): array
    {
        return $this->procedures->rows('sp_admin_reporte_ventas', [$from, $to]);
    }
}
