<?php

namespace App\Modules\Billing\Actions;

use App\Core\Exceptions\DomainException;
use Illuminate\Support\Facades\DB;

class IssueReceiptAction
{
    /**
     * @param  array{id_pedido: int, receipt_request_id: string, id_cliente?: int|null, tipo: string}  $data
     * @return array{id_comprobante: int, serie: string, correlativo: int, replayed: bool}
     */
    public function execute(array $data, int $idUsuario): array
    {
        if ($data['tipo'] === 'NOTA_CREDITO') {
            throw new DomainException(
                'CREDIT_NOTE_REQUIRES_REFERENCE',
                'La nota de crédito requiere un flujo de referencia y devolución.',
                422
            );
        }

        return DB::transaction(function () use ($data, $idUsuario): array {
            $existing = DB::table('COMPROBANTE')
                ->where('receipt_request_id', $data['receipt_request_id'])
                ->lockForUpdate()
                ->first();
            if ($existing) {
                if ((int) $existing->id_usuario !== $idUsuario) {
                    throw new DomainException('RECEIPT_REQUEST_FORBIDDEN', 'La solicitud pertenece a otra sesión de caja.', 403);
                }
                $requestedClient = $data['id_cliente'] ?? null;
                $sameClient = $existing->id_cliente === null
                    ? $requestedClient === null
                    : $requestedClient !== null && (int) $existing->id_cliente === (int) $requestedClient;
                if ((int) $existing->id_pedido !== (int) $data['id_pedido']
                    || $existing->tipo !== $data['tipo']
                    || ! $sameClient) {
                    throw new DomainException('IDEMPOTENCY_CONFLICT', 'El identificador ya fue usado con datos distintos.', 409);
                }

                return [
                    'id_comprobante' => (int) $existing->id_comprobante,
                    'serie' => (string) $existing->serie,
                    'correlativo' => (int) $existing->correlativo,
                    'replayed' => true,
                ];
            }

            $pedido = DB::table('PEDIDO')
                ->where('id_pedido', $data['id_pedido'])
                ->lockForUpdate()
                ->first();

            if (! $pedido) {
                throw new DomainException('ORDER_NOT_FOUND', 'Pedido no encontrado.', 404);
            }
            if (! in_array($pedido->estado, ['ABIERTO', 'EN_PAGO'], true)) {
                throw new DomainException('ORDER_NOT_BILLABLE', 'El pedido no admite la emisión de comprobantes.', 409);
            }
            if (DB::table('COMPROBANTE')
                ->where('id_pedido', $data['id_pedido'])
                ->where('estado', 'EMITIDO')
                ->exists()) {
                throw new DomainException('RECEIPT_ALREADY_ISSUED', 'El pedido ya tiene un comprobante emitido.', 409);
            }

            if ($data['tipo'] === 'FACTURA') {
                $cliente = isset($data['id_cliente'])
                    ? DB::table('CLIENTE')->where('id_cliente', $data['id_cliente'])->first()
                    : null;
                if (! $cliente || $cliente->tipo_documento !== 'RUC' || ! preg_match('/^\d{11}$/', (string) $cliente->numero_documento)) {
                    throw new DomainException('INVOICE_RUC_REQUIRED', 'La factura requiere un cliente con RUC válido.', 422, [
                        'id_cliente' => ['Seleccione un cliente con RUC de 11 dígitos.'],
                    ]);
                }
            }

            $serieKey = match ($data['tipo']) {
                'BOLETA' => 'serie_boleta',
                'FACTURA' => 'serie_factura',
                'NOTA_VENTA' => 'serie_nota_venta',
                default => throw new DomainException('RECEIPT_TYPE_INVALID', 'Tipo de comprobante no admitido.', 422),
            };
            $serieParameter = DB::table('PARAMETRO_SISTEMA')
                ->where('clave', $serieKey)
                ->lockForUpdate()
                ->first();
            if (! $serieParameter || $serieParameter->valor === '') {
                throw new DomainException('RECEIPT_SERIES_NOT_CONFIGURED', 'La serie del comprobante no está configurada.', 500);
            }
            $igvParameter = DB::table('PARAMETRO_SISTEMA')
                ->where('clave', 'IGV')
                ->lockForUpdate()
                ->first();
            if (! $igvParameter || ! is_numeric($igvParameter->valor) || (float) $igvParameter->valor < 0 || (float) $igvParameter->valor > 100) {
                throw new DomainException('TAX_RATE_NOT_CONFIGURED', 'La tasa de impuesto no está configurada correctamente.', 500);
            }

            $cuenta = DB::table('vw_resumen_cuenta_pedido')
                ->where('id_pedido', $data['id_pedido'])
                ->first();
            if (! $cuenta || (float) $cuenta->total <= 0) {
                throw new DomainException('ORDER_TOTAL_INVALID', 'El pedido no tiene un total facturable.', 409);
            }

            $correlativo = (int) DB::table('COMPROBANTE')
                ->where('tipo', $data['tipo'])
                ->where('serie', $serieParameter->valor)
                ->max('correlativo') + 1;
            $igv = (float) $igvParameter->valor;

            $id = (int) DB::table('COMPROBANTE')->insertGetId([
                'id_pedido' => $data['id_pedido'],
                'receipt_request_id' => $data['receipt_request_id'],
                'id_cliente' => $data['id_cliente'] ?? null,
                'id_usuario' => $idUsuario,
                'tipo' => $data['tipo'],
                'impuestos' => $igv,
                'serie' => $serieParameter->valor,
                'correlativo' => $correlativo,
                'subtotal' => $cuenta->base_imponible,
                'igv' => $cuenta->impuestos,
                'total' => $cuenta->total,
                'estado' => 'EMITIDO',
            ]);
            if ($pedido->estado === 'ABIERTO') {
                DB::statement('SET @sipan_current_user_id = ?', [$idUsuario]);
                try {
                    DB::table('PEDIDO')
                        ->where('id_pedido', $data['id_pedido'])
                        ->update(['estado' => 'EN_PAGO', 'version' => DB::raw('version + 1')]);
                } finally {
                    DB::statement('SET @sipan_current_user_id = NULL');
                }
            }

            return [
                'id_comprobante' => $id,
                'serie' => $serieParameter->valor,
                'correlativo' => $correlativo,
                'replayed' => false,
            ];
        }, 3);
    }
}
