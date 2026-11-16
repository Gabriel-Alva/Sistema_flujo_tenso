<?php

namespace App\Modules\Orders\Http\Controllers;

use App\Core\Traits\CallsStoredProcedures;
use App\Http\Controllers\Controller;
use App\Modules\Orders\Actions\CreateOrderWithRoundAction;
use App\Modules\Orders\Http\Requests\StoreOrderRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class OrderController extends Controller
{
    use CallsStoredProcedures;

    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'estado' => ['nullable', Rule::in(['ABIERTO', 'EN_PAGO', 'PAGADO', 'ANULADO'])],
            'tipo' => ['nullable', Rule::in(['SALON', 'LLEVAR', 'DELIVERY'])],
        ]);
        $user = $request->user();
        $meseroId = $user->rolActivo() === 'MESERO' ? (int) $user->id_usuario : null;

        return response()->json($this->callProcedureRows(
            'sp_listar_pedidos_operativos',
            [$meseroId, $filters['estado'] ?? null, $filters['tipo'] ?? null]
        ));
    }

    public function clientesDelivery(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['required', 'string', 'min:2', 'max:120'],
        ]);

        return response()->json($this->callProcedureRows(
            'sp_buscar_clientes_delivery',
            [trim($data['q'])]
        ));
    }

    public function show(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        $meseroId = $user->rolActivo() === 'MESERO' ? (int) $user->id_usuario : null;
        $rows = $this->callProcedureRows('sp_detalle_pedido_operativo', [$id, $meseroId]);
        abort_if($rows === [], 404);

        $first = (array) $rows[0];
        $pedido = array_intersect_key($first, array_flip([
            'id_pedido', 'fecha', 'tipo', 'id_mesa', 'id_usuario', 'num_comensales',
            'notas_generales', 'estado', 'version', 'id_cliente', 'id_direccion_entrega',
            'numero_mesa',
        ]));
        $cuenta = array_intersect_key($first, array_flip([
            'subtotal_items', 'subtotal_modificadores', 'base_imponible',
            'impuestos', 'total', 'total_pagado', 'saldo_pendiente',
        ]));
        $itemFields = [
            'id_comanda', 'numero_ronda', 'enviado_en', 'id_detalle', 'id_producto',
            'id_variante', 'nombre_snapshot', 'precio_unitario_venta', 'cantidad',
            'estado_item', 'prioridad', 'nota', 'iniciado_en', 'listo_en', 'entregado_en',
        ];
        $items = [];
        foreach ($rows as $row) {
            $item = array_intersect_key((array) $row, array_flip($itemFields));
            if ($item['id_detalle'] !== null) {
                $items[] = $item;
            }
        }
        $payments = $this->callProcedureRows(
            'sp_historial_pagos_pedido',
            [$id, $meseroId]
        );

        return response()->json([
            'pedido' => $pedido,
            'cuenta' => $cuenta,
            'items' => $items,
            'pagos' => $payments,
        ]);
    }

    public function store(StoreOrderRequest $request, CreateOrderWithRoundAction $action): JsonResponse
    {
        $data = $action->execute($request->validated(), (int) $request->user()->id_usuario);

        return response()->json($data, 201);
    }

    public function entregarItem(Request $request, int $id): JsonResponse
    {
        $result = $this->callProcedure(
            'sp_marcar_item_entregado',
            [$id, (int) $request->user()->id_usuario],
            ['@p_estado_item_out']
        );

        return response()->json([
            'id_detalle' => $id,
            'estado_item' => $result['p_estado_item_out'],
        ]);
    }

    public function cancelar(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'motivo' => ['required', 'string', 'min:3', 'max:250'],
        ]);
        $result = $this->callProcedure(
            'sp_cancelar_pedido_mesero',
            [$id, (int) $request->user()->id_usuario, trim($data['motivo'])],
            ['@p_estado_pedido_out']
        );

        return response()->json([
            'id_pedido' => $id,
            'estado' => $result['p_estado_pedido_out'],
        ]);
    }
}
