<?php

namespace App\Modules\Reporting\Actions;

use App\Core\Database\AdminProcedureGateway;

class GetAdminAuditAction
{
    public function __construct(private readonly AdminProcedureGateway $procedures) {}

    /**
     * @return array{entries: array<int, object>, page: int}
     */
    public function execute(string $search, string $from, string $to, int $page): array
    {
        $perPage = 50;

        return [
            'entries' => $this->procedures->rows(
                'sp_admin_listar_auditoria',
                [$search, $from, $to, $perPage, ($page - 1) * $perPage],
            ),
            'page' => $page,
        ];
    }
}
