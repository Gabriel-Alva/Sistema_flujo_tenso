@extends('layouts.admin')
@section('title', 'Finanzas y cajas')
@section('content')
<section class="panel">
    <h2><x-icon name="finance" /> Resumen de ventas y cierres</h2>
    <form class="filter-form" method="get" action="{{ route('admin.finance') }}">
        <label>Desde <input type="date" name="desde" value="{{ $desde }}" required></label>
        <label>Hasta <input type="date" name="hasta" value="{{ $hasta }}" required></label>
        <button class="btn-primary" type="submit">Consultar</button>
    </form>
</section>
<div class="stats">
    <article class="stat-card"><span>Comprobantes emitidos</span><strong>{{ $summary['comprobantes_emitidos'] ?? 0 }}</strong></article>
    <article class="stat-card"><span>Subtotal</span><strong>S/ {{ number_format((float) ($summary['subtotal'] ?? 0), 2) }}</strong></article>
    <article class="stat-card"><span>Impuestos</span><strong>S/ {{ number_format((float) ($summary['impuestos'] ?? 0), 2) }}</strong></article>
    <article class="stat-card"><span>Ventas</span><strong>S/ {{ number_format((float) ($summary['total_ventas'] ?? 0), 2) }}</strong></article>
</div>
<section class="panel">
    <h2>Pagos por medio</h2>
    <div class="stats">
        @foreach (['efectivo' => 'Efectivo', 'tarjeta' => 'Tarjeta', 'yape' => 'Yape', 'plin' => 'Plin', 'transferencia' => 'Transferencia'] as $key => $label)
            <article class="stat-card"><span>{{ $label }}</span><strong>S/ {{ number_format((float) ($summary[$key] ?? 0), 2) }}</strong></article>
        @endforeach
    </div>
</section>
<section class="panel">
    <div class="panel-heading">
        <div><h2>Comprobantes recientes</h2><p>Previsualiza el comprobante y sus productos antes de imprimir.</p></div>
    </div>
    <div class="receipt-list">
        @forelse ($receipts as $receipt)
            @php($receiptModalId = 'receipt-preview-'.$loop->index)
            <article class="receipt-list__item">
                <div>
                    <strong>{{ $receipt->tipo }} {{ $receipt->numero }}</strong>
                    <p>{{ $receipt->cliente ?: 'Consumidor final' }} · Pedido #{{ $receipt->id_pedido }}</p>
                </div>
                <small class="receipt-list__date">{{ $receipt->created_at }} · S/ {{ number_format((float) $receipt->total, 2) }}</small>
                <button class="btn-small" type="button" data-modal-open="{{ $receiptModalId }}">Previsualizar</button>
            </article>
            <dialog class="admin-modal" id="{{ $receiptModalId }}" aria-labelledby="{{ $receiptModalId }}-title">
                <section class="admin-modal__content">
                    <header class="admin-modal__header">
                        <div>
                            <p class="eyebrow">Previsualización de comprobante</p>
                            <h2 id="{{ $receiptModalId }}-title">{{ $receipt->tipo }} {{ $receipt->numero }}</h2>
                        </div>
                        <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
                    </header>
                    <article class="receipt-paper">
                        <header class="receipt-paper__header">
                            <h2>Chifa Sipán</h2>
                            <strong>{{ $receipt->tipo }} {{ $receipt->numero }}</strong>
                            <p>{{ $receipt->created_at }}</p>
                        </header>
                        <div class="receipt-paper__meta">
                            <div><strong>Cliente</strong><br>{{ $receipt->cliente ?: 'Consumidor final' }}</div>
                            <div><strong>Atendido por</strong><br>{{ $receipt->emitido_por }}</div>
                            <div><strong>Pedido</strong><br>#{{ $receipt->id_pedido }} · {{ $receipt->tipo_pedido }}</div>
                            <div><strong>Mesa</strong><br>{{ $receipt->numero_mesa ? 'Mesa '.$receipt->numero_mesa : 'No aplica' }}</div>
                            <div><strong>Medio(s) de pago</strong><br>{{ $receipt->medios_pago ?: 'Pendiente' }}</div>
                            <div><strong>Estado</strong><br>{{ $receipt->estado }}</div>
                        </div>
                        <table class="receipt-items">
                            <thead><tr><th>Producto</th><th>Cant.</th><th>Importe</th></tr></thead>
                            <tbody>
                            @forelse ($receipt->items as $item)
                                <tr>
                                    <td>
                                        {{ $item['nombre'] }}
                                        @if ($item['modificadores'])
                                            <small>{{ $item['modificadores'] }}</small>
                                        @endif
                                    </td>
                                    <td>{{ $item['cantidad'] }}</td>
                                    <td>S/ {{ number_format((float) $item['total'], 2) }}</td>
                                </tr>
                            @empty
                                <tr><td colspan="3" class="empty-state">No hay productos activos para mostrar.</td></tr>
                            @endforelse
                            </tbody>
                        </table>
                        <div class="receipt-totals">
                            <div><span>Subtotal</span><strong>S/ {{ number_format((float) $receipt->subtotal, 2) }}</strong></div>
                            <div><span>IGV</span><strong>S/ {{ number_format((float) $receipt->igv, 2) }}</strong></div>
                            <div class="receipt-total"><span>Total</span><strong>S/ {{ number_format((float) $receipt->total, 2) }}</strong></div>
                        </div>
                    </article>
                    <footer class="admin-modal__footer">
                        <button class="btn-secondary" type="button" data-modal-close>Cerrar</button>
                        <button class="btn-primary" type="button" data-print-receipt>Imprimir</button>
                    </footer>
                </section>
            </dialog>
        @empty
            <p class="empty-state">No hay comprobantes recientes para previsualizar.</p>
        @endforelse
    </div>
</section>
<section class="panel">
    <h2>Saldos de pedidos abiertos</h2>
    <div class="admin-table-wrap">
        <table class="admin-table">
            <thead><tr><th>Pedido</th><th>Tipo</th><th>Fecha</th><th>Mesero</th><th>Total</th><th>Pagado</th><th>Saldo</th></tr></thead>
            <tbody>
            @forelse ($balances as $balance)
                <tr>
                    <td>#{{ $balance->id_pedido }}<small>{{ $balance->estado }}{{ $balance->id_mesa ? " · Mesa {$balance->id_mesa}" : '' }}</small></td>
                    <td>{{ $balance->tipo }}</td>
                    <td>{{ $balance->fecha }}</td>
                    <td>{{ $balance->mesero }}</td>
                    <td>S/ {{ number_format((float) $balance->total, 2) }}</td>
                    <td>S/ {{ number_format((float) $balance->total_pagado, 2) }}</td>
                    <td><strong>S/ {{ number_format((float) $balance->saldo_pendiente, 2) }}</strong></td>
                </tr>
            @empty
                <tr><td colspan="7" class="empty-state">No hay pedidos con saldo pendiente.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
</section>
<section class="panel">
    <h2>Arqueos de caja</h2>
    <div class="admin-table-wrap">
        <table class="admin-table">
            <thead><tr><th>Cajero / sesión</th><th>Estado</th><th>Apertura / cierre</th><th>Base</th><th>Efectivo</th><th>Otros ingresos</th><th>Egresos</th><th>Saldo teórico</th></tr></thead>
            <tbody>
            @forelse ($sessions as $session)
                <tr>
                    <td>{{ $session->cajero }}<small>{{ $session->username }} · #{{ $session->id_caja_sesion }}</small></td>
                    <td>{{ $session->estado }}</td>
                    <td>{{ $session->apertura_en }}<small>{{ $session->cierre_en ?? 'Sesión abierta' }}</small></td>
                    <td>S/ {{ number_format((float) $session->monto_apertura, 2) }}</td>
                    <td>S/ {{ number_format((float) $session->total_efectivo, 2) }}</td>
                    <td>S/ {{ number_format((float) $session->movimientos_ingreso, 2) }}</td>
                    <td>S/ {{ number_format((float) $session->movimientos_egreso, 2) }}</td>
                    <td><strong>S/ {{ number_format((float) $session->saldo_teorico_gaveta, 2) }}</strong></td>
                </tr>
            @empty
                <tr><td colspan="8" class="empty-state">No hay sesiones en ese rango.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
</section>
@endsection
