<?php

namespace App\Core\Traits;

use App\Core\Exceptions\DomainException;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

trait CallsStoredProcedures
{
    /**
     * @param  array<int, mixed>  $bindings
     * @return array<string, mixed>
     */
    protected function callProcedure(string $name, array $bindings, array $outParams): array
    {
        if (! in_array($name, [
            'sp_registrar_ronda_pedido',
            'sp_marcar_item_entregado',
            'sp_cancelar_pedido_mesero',
            'sp_registrar_pago_y_cerrar_cuenta',
            'sp_cerrar_sesion_caja',
        ], true)) {
            throw new InvalidArgumentException('Procedimiento almacenado no permitido.');
        }
        foreach ($outParams as $parameter) {
            if (! preg_match('/^@[A-Za-z0-9_]+$/', $parameter)) {
                throw new InvalidArgumentException('Parámetro de salida inválido.');
            }
        }

        $placeholders = implode(', ', array_fill(0, count($bindings), '?'));
        $outs = implode(', ', $outParams);
        $sql = count($bindings) > 0
            ? "CALL {$name}({$placeholders}, {$outs})"
            : "CALL {$name}({$outs})";

        try {
            DB::statement($sql, $bindings);
        } catch (QueryException $exception) {
            $message = (string) ($exception->errorInfo[2] ?? $exception->getMessage());
            $errors = [
                'ORDER_TABLE_OCCUPIED' => ['ORDER_TABLE_OCCUPIED', 'La mesa ya tiene un pedido activo.', 409],
                'ORDER_TABLE_UNAVAILABLE' => ['ORDER_TABLE_UNAVAILABLE', 'La mesa no está disponible para un pedido.', 409],
                'ORDER_NOT_FOUND' => ['ORDER_NOT_FOUND', 'Pedido no encontrado.', 404],
                'ORDER_NOT_OPEN' => ['ORDER_NOT_OPEN', 'El pedido ya no admite nuevas rondas.', 409],
                'ORDER_NOT_CANCELLABLE' => ['ORDER_NOT_CANCELLABLE', 'El pedido ya no puede cancelarse en su estado actual.', 409],
                'ORDER_HAS_PREPARATION' => ['ORDER_HAS_PREPARATION', 'No se puede cancelar: la cocina ya inició uno o más productos.', 409],
                'ORDER_HAS_PAYMENT' => ['ORDER_HAS_PAYMENT', 'No se puede cancelar un pedido con comprobante o pago registrado.', 409],
                'ORDER_CANCELLATION_REASON_REQUIRED' => ['ORDER_CANCELLATION_REASON_REQUIRED', 'El motivo de cancelación es obligatorio.', 422],
                'ORDER_FORBIDDEN' => ['ORDER_FORBIDDEN', 'No puede modificar un pedido asignado a otro mesero.', 403],
                'IDEMPOTENCY_CONFLICT' => ['IDEMPOTENCY_CONFLICT', 'El identificador de solicitud ya fue usado con datos distintos.', 409],
                'ORDER_IDEMPOTENCY_BUSY' => ['ORDER_IDEMPOTENCY_BUSY', 'El pedido está procesando una solicitud idéntica. Reintente con el mismo identificador.', 503],
                'PRODUCT_NOT_FOUND' => ['PRODUCT_NOT_FOUND', 'Producto no encontrado o inactivo.', 422],
                'VARIANT_INVALID' => ['VARIANT_INVALID', 'La variante no pertenece al producto o está inactiva.', 422],
                'MODIFIER_NOT_FOUND' => ['MODIFIER_NOT_FOUND', 'Modificador no encontrado o inactivo.', 422],
                'PRODUCT_STATION_UNCONFIGURED' => ['PRODUCT_STATION_UNCONFIGURED', 'El producto no tiene estación de cocina configurada.', 422],
                'PRIORITY_INVALID' => ['PRIORITY_INVALID', 'La prioridad ya no está disponible.', 422],
                'CASH_SESSION_INVALID' => ['CASH_SESSION_INVALID', 'La sesión de caja no está abierta o no pertenece al usuario.', 409],
                'RECEIPT_NOT_FOUND' => ['RECEIPT_NOT_FOUND', 'Comprobante no encontrado.', 404],
                'RECEIPT_NOT_PAYABLE' => ['RECEIPT_NOT_PAYABLE', 'El comprobante no admite pagos.', 409],
                'CASH_RECEIVED_INVALID' => ['CASH_RECEIVED_INVALID', 'El monto recibido no cubre el pago.', 422],
                'PAYMENT_EXCEEDS_BALANCE' => ['PAYMENT_EXCEEDS_BALANCE', 'El pago supera el saldo pendiente.', 409],
                'PAYMENT_AMOUNT_INVALID' => ['PAYMENT_AMOUNT_INVALID', 'El monto de pago debe ser positivo.', 422],
                'PAYMENT_REQUEST_REUSED' => ['PAYMENT_REQUEST_REUSED', 'El identificador de pago ya fue usado con otros datos.', 409],
                'PAYMENT_IDEMPOTENCY_BUSY' => ['PAYMENT_IDEMPOTENCY_BUSY', 'El pago está procesando una solicitud idéntica. Reintente con el mismo identificador.', 503],
                'ITEM_NOT_FOUND' => ['ITEM_NOT_FOUND', 'Ítem no encontrado.', 404],
                'ITEM_DELETE_FORBIDDEN' => ['ITEM_DELETE_FORBIDDEN', 'Los ítems enviados no pueden eliminarse.', 409],
                'INVALID_ITEM_TRANSITION' => ['INVALID_ITEM_TRANSITION', 'Solo se pueden entregar ítems listos.', 409],
            ];

            foreach ($errors as $signal => [$code, $description, $status]) {
                if (str_contains($message, $signal)) {
                    throw new DomainException($code, $description, $status);
                }
            }

            throw $exception;
        }

        $select = implode(', ', array_map(
            fn (string $p) => "{$p} AS ".ltrim($p, '@'),
            $outParams
        ));

        return (array) DB::selectOne("SELECT {$select}");
    }

    /**
     * @param  array<int, mixed>  $bindings
     * @return array<int, object>
     */
    protected function callProcedureRows(string $name, array $bindings): array
    {
        if (! in_array($name, [
            'sp_listar_pedidos_operativos',
            'sp_detalle_pedido_operativo',
            'sp_buscar_clientes_delivery',
            'sp_historial_pagos_pedido',
        ], true)) {
            throw new InvalidArgumentException('Procedimiento almacenado no permitido.');
        }

        $placeholders = implode(', ', array_fill(0, count($bindings), '?'));

        try {
            return DB::select("CALL {$name}({$placeholders})", $bindings);
        } catch (QueryException $exception) {
            $message = (string) ($exception->errorInfo[2] ?? $exception->getMessage());
            if (str_contains($message, 'ORDER_NOT_FOUND')) {
                throw new DomainException('ORDER_NOT_FOUND', 'Pedido no encontrado.', 404);
            }

            throw $exception;
        }
    }
}
