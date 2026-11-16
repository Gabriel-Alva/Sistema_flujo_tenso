<?php

namespace App\Modules\Billing\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Billing\Actions\GetCashierDashboardAction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CashierDashboardController extends Controller
{
    public function __invoke(Request $request, GetCashierDashboardAction $action): JsonResponse
    {
        return response()->json($action->execute((int) $request->user()->id_usuario));
    }
}
