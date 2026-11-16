@extends('layouts.admin')
@section('title', 'Reportes de ventas')
@section('content')
<section class="panel">
    <h2><x-icon name="reports" /> Ventas por fecha y comprobante</h2>
    <form class="filter-form" method="get" action="{{ route('admin.reports') }}">
        <label>Desde <input type="date" name="desde" value="{{ $desde }}" required></label>
        <label>Hasta <input type="date" name="hasta" value="{{ $hasta }}" required></label>
        <button class="btn-primary" type="submit">Generar reporte</button>
    </form>
    <div class="admin-table-wrap">
        <table class="admin-table">
            <thead><tr><th>Fecha</th><th>Tipo de comprobante</th><th>Cantidad</th><th>Subtotal</th><th>Impuestos</th><th>Total</th></tr></thead>
            <tbody>
            @forelse ($sales as $row)
                <tr>
                    <td>{{ $row->fecha }}</td>
                    <td>{{ $row->tipo }}</td>
                    <td>{{ $row->comprobantes }}</td>
                    <td>S/ {{ number_format((float) $row->subtotal, 2) }}</td>
                    <td>S/ {{ number_format((float) $row->impuestos, 2) }}</td>
                    <td><strong>S/ {{ number_format((float) $row->total, 2) }}</strong></td>
                </tr>
            @empty
                <tr><td colspan="6" class="empty-state">No hay ventas emitidas en ese periodo.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    <p class="muted">Reporte de comprobantes emitidos. Las anulaciones no se incluyen en el total.</p>
</section>
@endsection
