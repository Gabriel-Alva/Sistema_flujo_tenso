<?php

namespace App\Modules\Billing\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Billing\Actions\GetAdminFinanceAction;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminFinanceController extends Controller
{
    public function __invoke(Request $request, GetAdminFinanceAction $action): View
    {
        $filters = $request->validate([
            'desde' => ['nullable', 'date_format:Y-m-d'],
            'hasta' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:desde'],
        ]);
        $from = $filters['desde'] ?? now()->startOfMonth()->toDateString();
        $to = $filters['hasta'] ?? now()->toDateString();
        abort_if($from > $to, 422, 'El rango de fechas no es válido.');

        return view('pages.finance.index', [
            ...$action->execute($from, $to),
            'desde' => $from,
            'hasta' => $to,
        ]);
    }
}
