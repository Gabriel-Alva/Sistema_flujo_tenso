<?php

namespace App\Modules\Orders\Actions;

use App\Core\Traits\CallsStoredProcedures;

class CreateOrderWithRoundAction
{
    use CallsStoredProcedures;

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    public function execute(array $payload, int $idUsuario): array
    {
        $requestHash = hash('sha256', json_encode(
            $this->canonicalize($payload),
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
        ));
        $out = $this->callProcedure(
            'sp_registrar_ronda_pedido',
            [
                $payload['client_request_id'],
                $requestHash,
                $idUsuario,
                $payload['id_pedido'] ?? null,
                $payload['tipo'],
                $payload['id_mesa'] ?? null,
                $payload['num_comensales'] ?? null,
                $payload['notas_generales'] ?? null,
                $payload['id_cliente'] ?? null,
                $payload['id_direccion_entrega'] ?? null,
                isset($payload['direccion_snapshot']) ? json_encode($payload['direccion_snapshot']) : null,
                json_encode($payload['items']),
            ],
            ['@p_id_pedido_out', '@p_id_comanda_out']
        );

        $idPedido = (int) $out['p_id_pedido_out'];
        $rows = $this->callProcedureRows(
            'sp_detalle_pedido_operativo',
            [$idPedido, $idUsuario]
        );
        $first = (array) $rows[0];
        $pedido = array_intersect_key($first, array_flip([
            'id_pedido', 'fecha', 'tipo', 'id_mesa', 'id_usuario', 'num_comensales',
            'notas_generales', 'estado', 'version', 'updated_at', 'id_cliente',
            'id_direccion_entrega', 'direccion_snapshot', 'client_request_id',
        ]));
        $roundFields = [
            'id_comanda', 'id_pedido', 'numero_ronda', 'enviado_en',
        ];
        $itemFields = [
            'id_detalle', 'id_comanda', 'id_producto', 'id_variante', 'nombre_snapshot',
            'precio_unitario_venta', 'id_estacion_cocina', 'cantidad', 'estado_item',
            'prioridad', 'nota', 'iniciado_en', 'listo_en', 'entregado_en',
            'motivo_cancelacion',
        ];
        $rondas = [];
        $items = [];
        foreach ($rows as $row) {
            $record = (array) $row;
            if ($record['id_comanda'] !== null) {
                $rondas[$record['id_comanda']] = [
                    ...array_intersect_key($record, array_flip($roundFields)),
                    'client_request_id' => $record['ronda_client_request_id'],
                    'request_hash' => $record['ronda_request_hash'],
                ];
            }
            if ($record['id_detalle'] !== null) {
                $items[] = array_intersect_key($record, array_flip($itemFields));
            }
        }

        return [
            'pedido' => $pedido,
            'id_comanda' => (int) $out['p_id_comanda_out'],
            'rondas' => array_values($rondas),
            'items' => $items,
        ];
    }

    private function canonicalize(array $value): array
    {
        foreach ($value as $key => $item) {
            if (is_array($item)) {
                $value[$key] = $this->canonicalize($item);
            }
        }

        if (! array_is_list($value)) {
            ksort($value);
        }

        return $value;
    }
}
