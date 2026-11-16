<?php

namespace App\Modules\Reporting\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Reporting\Actions\GetAdminAuditAction;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminAuditController extends Controller
{
    public function index(Request $request, GetAdminAuditAction $action): View
    {
        $filters = $request->validate([
            'q' => ['nullable', 'string', 'max:120'],
            'desde' => ['nullable', 'date_format:Y-m-d'],
            'hasta' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:desde'],
            'page' => ['nullable', 'integer', 'min:1', 'max:100000'],
        ]);
        $to = $filters['hasta'] ?? now()->toDateString();
        $from = $filters['desde'] ?? now()->subDays(30)->toDateString();
        abort_if($from > $to, 422, 'El rango de fechas no es válido.');

        return view('pages.audit.index', [
            ...$action->execute($filters['q'] ?? '', $from, $to, (int) ($filters['page'] ?? 1)),
            'filters' => [...$filters, 'desde' => $from, 'hasta' => $to],
        ]);
    }
}
