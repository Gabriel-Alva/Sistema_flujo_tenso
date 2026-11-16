@extends('layouts.admin')
@section('title', 'Salón')
@section('content')
<div class="panel-grid">
    <section class="panel">
        <div class="panel-heading">
            <div>
                <h2><x-icon name="salon" /> Zonas</h2>
                <p>Las zonas ocupadas no se pueden desactivar hasta liberar sus mesas.</p>
            </div>
            <button class="btn-primary" type="button" data-modal-open="create-zone-modal">Agregar zona</button>
        </div>
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead><tr><th>Zona</th><th>Estado</th><th>Acciones</th></tr></thead>
                <tbody>
                @forelse ($zones as $zone)
                    @php($zoneModalId = 'zone-edit-'.$loop->index)
                    <tr>
                        <td><strong>{{ $zone->nombre }}</strong></td>
                        <td><span class="status-pill {{ $zone->activa ? '' : 'is-inactive' }}">{{ $zone->activa ? 'Activa' : 'Inactiva' }}</span></td>
                        <td>
                            <div class="table-actions">
                                <button class="btn-small" type="button" data-modal-open="{{ $zoneModalId }}">Editar</button>
                                <form method="post" action="{{ route('admin.salon.zones.save') }}" data-confirm data-confirm-message="{{ $zone->activa ? 'La zona no podrá desactivarse si tiene mesas ocupadas. ¿Continuar?' : '¿Deseas reactivar esta zona?' }}">
                                    @csrf
                                    <input type="hidden" name="id_zona" value="{{ $zone->id_zona }}">
                                    <input type="hidden" name="nombre" value="{{ $zone->nombre }}">
                                    <input type="hidden" name="activa" value="{{ $zone->activa ? 0 : 1 }}">
                                    <button class="btn-small {{ $zone->activa ? 'btn-danger' : '' }}" type="submit">
                                        {{ $zone->activa ? 'Desactivar' : 'Activar' }}
                                    </button>
                                </form>
                            </div>
                        </td>
                    </tr>
                @empty
                    <tr><td colspan="3" class="empty-state">No hay zonas registradas.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>
    </section>

    <section class="panel">
        <div class="panel-heading">
            <div><h2><x-icon name="table" /> Mesas</h2><p>Registra mesas y configura su capacidad y disponibilidad.</p></div>
            <button class="btn-primary" type="button" data-modal-open="create-table-modal">Registrar mesa</button>
        </div>
    </section>
</div>

<dialog class="admin-modal" id="create-zone-modal" aria-labelledby="create-zone-title">
    <section class="admin-modal__content admin-modal__content--compact">
        <header class="admin-modal__header">
            <div><p class="eyebrow">Salón</p><h2 id="create-zone-title">Agregar zona</h2></div>
            <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
        </header>
        <form class="admin-form" method="post" action="{{ route('admin.salon.zones.save') }}">
            @csrf
            <label class="field-wide">Nombre de la zona
                <input name="nombre" maxlength="50" required>
            </label>
            <input type="hidden" name="activa" value="1">
            <div class="admin-modal__actions field-wide">
                <button class="btn-secondary" type="button" data-modal-close>Cancelar</button>
                <button class="btn-primary" type="submit">Crear zona</button>
            </div>
        </form>
    </section>
</dialog>
<dialog class="admin-modal" id="create-table-modal" aria-labelledby="create-table-title">
    <section class="admin-modal__content admin-modal__content--compact">
        <header class="admin-modal__header">
            <div><p class="eyebrow">Salón</p><h2 id="create-table-title">Registrar mesa</h2></div>
            <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
        </header>
        @include('pages.salon._table-form', ['table' => null, 'zones' => $zones])
    </section>
</dialog>

<section class="panel">
    <h2>Mesas y estado operativo</h2>
    <div class="admin-table-wrap">
        <table class="admin-table">
            <thead><tr><th>Mesa</th><th>Zona</th><th>Capacidad</th><th>Estado</th><th>Pedido / mesero</th><th>Configuración</th></tr></thead>
            <tbody>
            @forelse ($tables as $table)
                @php($tableModalId = 'table-edit-'.$loop->index)
                <tr>
                    <td><strong>Mesa {{ $table->numero }}</strong><small>#{{ $table->id_mesa }}</small></td>
                    <td>{{ $table->zona ?? 'Sin zona' }}</td>
                    <td>{{ $table->capacidad }} personas</td>
                    <td><span class="status-pill {{ $table->activa ? '' : 'is-inactive' }}">{{ $table->estado }}</span></td>
                    <td>
                        {{ $table->id_pedido ? "Pedido #{$table->id_pedido}" : '—' }}
                        <small>{{ $table->nombre_mesero ?? '' }}{{ $table->minutos_ocupacion ? " · {$table->minutos_ocupacion} min" : '' }}</small>
                    </td>
                    <td><button class="btn-small" type="button" data-modal-open="{{ $tableModalId }}">Editar mesa</button></td>
                </tr>
            @empty
                <tr><td colspan="6" class="empty-state">No hay mesas registradas.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
</section>

@foreach ($zones as $zone)
    @php($zoneModalId = 'zone-edit-'.$loop->index)
    <dialog class="admin-modal" id="{{ $zoneModalId }}" aria-labelledby="{{ $zoneModalId }}-title">
        <section class="admin-modal__content admin-modal__content--compact">
            <header class="admin-modal__header">
                <div><p class="eyebrow">Editar zona</p><h2 id="{{ $zoneModalId }}-title">{{ $zone->nombre }}</h2></div>
                <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
            </header>
            <form class="admin-form" method="post" action="{{ route('admin.salon.zones.save') }}">
                @csrf
                <input type="hidden" name="id_zona" value="{{ $zone->id_zona }}">
                <label class="field-wide">Nombre
                    <input name="nombre" value="{{ $zone->nombre }}" maxlength="50" required>
                </label>
                <input type="hidden" name="activa" value="{{ $zone->activa ? 1 : 0 }}">
                <div class="admin-modal__actions field-wide">
                    <button class="btn-secondary" type="button" data-modal-close>Cancelar</button>
                    <button class="btn-primary" type="submit">Guardar zona</button>
                </div>
            </form>
        </section>
    </dialog>
@endforeach
@foreach ($tables as $table)
    @php($tableModalId = 'table-edit-'.$loop->index)
    <dialog class="admin-modal" id="{{ $tableModalId }}" aria-labelledby="{{ $tableModalId }}-title">
        <section class="admin-modal__content admin-modal__content--compact">
            <header class="admin-modal__header">
                <div><p class="eyebrow">Configuración</p><h2 id="{{ $tableModalId }}-title">Mesa {{ $table->numero }}</h2></div>
                <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
            </header>
            @include('pages.salon._table-form', ['table' => $table, 'zones' => $zones])
        </section>
    </dialog>
@endforeach
@endsection
