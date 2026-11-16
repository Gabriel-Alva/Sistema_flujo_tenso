@extends('layouts.admin')
@section('title', 'Resumen operativo')
@section('content')
<div class="stats">
    <article class="stat-card stat-card--tables">
        <div class="icon-wrap icon-wrap--pending"><x-icon name="salon" /></div>
        <strong>{{ $mesas_ocupadas ?? 0 }}</strong>
        <span>Mesas ocupadas</span>
    </article>
    <article class="stat-card stat-card--kitchen">
        <div class="icon-wrap icon-wrap--preparing"><x-icon name="kitchen" /></div>
        <strong>{{ $items_cocina ?? 0 }}</strong>
        <span>Ítems activos en cocina</span>
    </article>
    <article class="stat-card stat-card--cash">
        <div class="icon-wrap icon-wrap--ready"><x-icon name="cash" /></div>
        <strong>{{ $cajas_abiertas ?? 0 }}</strong>
        <span>Cajas abiertas</span>
    </article>
    <article class="stat-card stat-card--orders">
        <div class="icon-wrap icon-wrap--brand"><x-icon name="order" /></div>
        <strong>{{ $pedidos_abiertos ?? 0 }}</strong>
        <span>Pedidos en curso</span>
    </article>
</div>
<section class="dashboard-charts" aria-label="Gráficas del dashboard">
    <article class="chart-card chart-card--sales">
        <header class="chart-card__heading">
            <div>
                <p class="eyebrow">Últimos 7 días</p>
                <h2>Ventas emitidas</h2>
            </div>
            <span class="chart-tag chart-tag--sales"><x-icon name="reports" /> S/ {{ number_format((float) ($salesChartTotal ?? 0), 2) }}</span>
        </header>
        @if (count($salesChart ?? []))
            @php
                $salesColors = ['#E50935', '#D97706', '#2563EB', '#0F766E', '#7C3AED', '#C4A35A', '#DB2777'];
            @endphp
            <svg class="dashboard-chart" viewBox="0 0 640 220" role="img" aria-labelledby="sales-chart-title">
                <title id="sales-chart-title">Ventas por día en los últimos siete días</title>
                <line class="chart-gridline" x1="24" y1="48" x2="616" y2="48" />
                <line class="chart-gridline" x1="24" y1="108" x2="616" y2="108" />
                <line class="chart-gridline" x1="24" y1="168" x2="616" y2="168" />
                @foreach ($salesChart as $point)
                    @php
                        $barX = 39 + ($loop->index * 82);
                        $barY = 168 - $point['height'];
                        $barColor = $salesColors[$loop->index % count($salesColors)];
                    @endphp
                    <g>
                        <title>{{ $point['label'] }}: S/ {{ number_format($point['value'], 2) }}</title>
                        <rect x="{{ $barX }}" y="{{ $barY }}" width="46" height="{{ max($point['height'], 1) }}" rx="8" fill="{{ $barColor }}" />
                        <text class="chart-label" x="{{ $barX + 23 }}" y="197" text-anchor="middle">{{ $point['label'] }}</text>
                    </g>
                @endforeach
            </svg>
        @else
            <p class="chart-empty">No hay datos de ventas para graficar.</p>
        @endif
    </article>
    <article class="chart-card chart-card--orders">
        <header class="chart-card__heading">
            <div>
                <p class="eyebrow">Hoy</p>
                <h2>Estado de pedidos</h2>
            </div>
            <span class="chart-tag chart-tag--orders"><x-icon name="order" /> {{ array_sum(array_column($orderStatusChart ?? [], 'value')) }} pedidos</span>
        </header>
        <svg class="dashboard-chart dashboard-chart--orders" viewBox="0 0 620 210" role="img" aria-labelledby="orders-chart-title">
            <title id="orders-chart-title">Pedidos de hoy por estado</title>
            @foreach ($orderStatusChart ?? [] as $point)
                @php
                    $barY = 20 + ($loop->index * 44);
                    $barColor = match ($point['state']) {
                        'ABIERTO' => '#2563EB',
                        'EN_PAGO' => '#D97706',
                        'PAGADO' => '#16A34A',
                        default => '#6B7280',
                    };
                @endphp
                <g>
                    <text class="chart-label chart-label--state" x="8" y="{{ $barY + 15 }}">{{ $point['label'] }}</text>
                    <rect x="142" y="{{ $barY }}" width="370" height="22" rx="8" fill="#E7DFD2" />
                    @if ($point['width'] > 0)
                        <rect x="142" y="{{ $barY }}" width="{{ $point['width'] }}" height="22" rx="8" fill="{{ $barColor }}" />
                    @endif
                    <text class="chart-value" x="542" y="{{ $barY + 16 }}">{{ $point['value'] }}</text>
                </g>
            @endforeach
        </svg>
    </article>
</section>
<div class="panel-grid">
    <section class="panel panel--activity">
        <h2><x-icon name="reports" /> Actividad de hoy</h2>
        <p>{{ $pedidos_hoy ?? 0 }} pedidos registrados</p>
        <div class="metric">S/ {{ number_format((float) ($venta_hoy ?? 0), 2) }}</div>
        <p>Ventas con comprobantes emitidos</p>
    </section>
    <section class="panel panel--quick-access">
        <h2><x-icon name="refresh" /> Accesos rápidos</h2>
        <div class="actions">
            <a class="btn-secondary btn-secondary--blue" href="{{ route('admin.catalog') }}"><x-icon name="catalog" /> Administrar catálogo</a>
            <a class="btn-secondary btn-secondary--violet" href="{{ route('admin.staff') }}"><x-icon name="staff" /> Gestionar personal</a>
            <a class="btn-secondary btn-secondary--teal" href="{{ route('admin.finance') }}"><x-icon name="finance" /> Revisar cajas y ventas</a>
            <a class="btn-secondary btn-secondary--amber" href="{{ route('admin.parameters') }}"><x-icon name="settings" /> Parámetros del sistema</a>
        </div>
    </section>
</div>
@endsection
