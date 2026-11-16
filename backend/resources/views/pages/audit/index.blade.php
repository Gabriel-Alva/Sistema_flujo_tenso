@extends('layouts.admin')
@section('title', 'Auditoría')
@section('content')
<section class="panel">
    <h2><x-icon name="audit" /> Bitácora inmutable</h2>
    <p>Consulta cambios registrados por triggers y acciones administrativas. No se permite editar ni borrar esta bitácora.</p>
    <form class="filter-form" method="get" action="{{ route('admin.audit') }}">
        <label>Buscar usuario, tabla o registro
            <input name="q" value="{{ $filters['q'] ?? '' }}" maxlength="120">
        </label>
        <label>Desde <input type="date" name="desde" value="{{ $filters['desde'] }}" required></label>
        <label>Hasta <input type="date" name="hasta" value="{{ $filters['hasta'] }}" required></label>
        <button class="btn-primary" type="submit">Filtrar</button>
    </form>
    <div class="admin-table-wrap">
        <table class="admin-table">
            <thead><tr><th>Fecha</th><th>Actor</th><th>Entidad</th><th>Acción</th><th>Antes</th><th>Después</th></tr></thead>
            <tbody>
            @forelse ($entries as $entry)
                @php
                    $beforeModalId = 'audit-before-'.$entry->id_auditoria;
                    $afterModalId = 'audit-after-'.$entry->id_auditoria;
                @endphp
                <tr>
                    <td>{{ $entry->fecha }}<small>#{{ $entry->id_auditoria }}</small></td>
                    <td>{{ $entry->nombre_completo ?: $entry->username ?: 'Sistema' }}<small>{{ $entry->username ?? '' }}</small></td>
                    <td>{{ $entry->tabla }}<small>{{ $entry->id_registro }}</small></td>
                    <td>{{ ['I' => 'Alta', 'U' => 'Cambio', 'D' => 'Baja'][$entry->accion] ?? $entry->accion }}</td>
                    <td>
                        @if ($entry->datos_antes)
                            <button class="btn-small" type="button" data-modal-open="{{ $beforeModalId }}">Ver detalle</button>
                        @else
                            —
                        @endif
                    </td>
                    <td>
                        @if ($entry->datos_despues)
                            <button class="btn-small" type="button" data-modal-open="{{ $afterModalId }}">Ver detalle</button>
                        @else
                            —
                        @endif
                    </td>
                </tr>
            @empty
                <tr><td colspan="6" class="empty-state">No se encontraron eventos para ese filtro.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
    @foreach ($entries as $entry)
        @foreach (['antes' => $entry->datos_antes, 'despues' => $entry->datos_despues] as $moment => $data)
            @if ($data)
                @php($modalId = 'audit-'.$moment.'-'.$entry->id_auditoria)
                <dialog class="admin-modal" id="{{ $modalId }}" aria-labelledby="{{ $modalId }}-title">
                    <section class="admin-modal__content admin-modal__content--compact">
                        <header class="admin-modal__header">
                            <div>
                                <p class="eyebrow">Auditoría · #{{ $entry->id_auditoria }}</p>
                                <h2 id="{{ $modalId }}-title">Datos {{ $moment }}</h2>
                            </div>
                            <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
                        </header>
                        <pre class="audit-json">{{ json_encode(json_decode($data), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) }}</pre>
                    </section>
                </dialog>
            @endif
        @endforeach
    @endforeach
    <div class="pagination">
        @if ($page > 1)
            <a class="btn-secondary" href="{{ route('admin.audit', [...$filters, 'page' => $page - 1]) }}">Anterior</a>
        @else
            <span></span>
        @endif
        <span class="muted">Página {{ $page }} · {{ count($entries) }} eventos</span>
        @if (count($entries) === 50)
            <a class="btn-secondary" href="{{ route('admin.audit', [...$filters, 'page' => $page + 1]) }}">Siguiente</a>
        @endif
    </div>
</section>
@endsection
