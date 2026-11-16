<?php

namespace App\Modules\Billing\Http\Controllers;

use App\Core\Traits\CallsStoredProcedures;
use App\Http\Controllers\Controller;
use App\Modules\Billing\Actions\IssueReceiptAction;
use App\Modules\Billing\Http\Requests\IssueReceiptRequest;
use App\Modules\Billing\Http\Requests\StorePaymentRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class PaymentController extends Controller
{
    use CallsStoredProcedures;

    public function cuenta(int $idPedido): JsonResponse
    {
        $cuenta = DB::table('vw_resumen_cuenta_pedido')->where('id_pedido', $idPedido)->first();
        abort_unless($cuenta, 404);

        return response()->json($cuenta);
    }

    public function emitirComprobante(IssueReceiptRequest $request, IssueReceiptAction $action): JsonResponse
    {
        $receipt = $action->execute($request->validated(), (int) $request->user()->id_usuario);

        $status = $receipt['replayed'] ? 200 : 201;
        unset($receipt['replayed']);

        return response()->json($receipt, $status);
    }

    public function pagar(StorePaymentRequest $request): JsonResponse
    {
        $data = $request->validated();
        $out = $this->callProcedure(
            'sp_registrar_pago_y_cerrar_cuenta',
            [
                $data['payment_request_id'],
                $data['id_comprobante'],
                $data['id_caja_sesion'],
                $request->user()->id_usuario,
                $data['metodo'],
                $data['monto'],
                $data['monto_recibido'] ?? null,
            ],
            ['@p_vuelto', '@p_id_pago_out', '@p_pedido_estado', '@p_replayed']
        );

        return response()->json($out, (int) $out['p_replayed'] === 1 ? 200 : 201);
    }
}
