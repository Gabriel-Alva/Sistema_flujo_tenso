<?php

namespace App\Modules\Billing\Actions;

use App\Core\Database\AdminProcedureGateway;

class GetAdminFinanceAction
{
    public function __construct(private readonly AdminProcedureGateway $procedures) {}

    /** @return array<string, mixed> */
    public function execute(string $from, string $to): array
    {
        $receipts = $this->procedures->rows('sp_admin_listar_comprobantes', [20]);
        foreach ($receipts as $receipt) {
            $receipt->items = json_decode((string) $receipt->items, true, 512, JSON_THROW_ON_ERROR);
        }

        return [
            'summary' => (array) ($this->procedures->rows('sp_admin_resumen_financiero', [$from, $to])[0] ?? []),
            'sessions' => $this->procedures->rows('sp_admin_sesiones_caja', [$from, $to]),
            'balances' => $this->procedures->rows('sp_admin_saldos_pendientes'),
            'receipts' => $receipts,
        ];
    }
}
