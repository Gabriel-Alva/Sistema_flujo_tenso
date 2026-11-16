@extends('layouts.admin')
@section('title', 'Personal y accesos')
@section('content')
<section class="panel">
    <div class="panel-heading">
        <div><h2><x-icon name="staff" /> Gestión de personal</h2><p>Crea accesos con contraseña hasheada y un único rol operativo.</p></div>
        <button class="btn-primary" type="button" data-modal-open="create-staff-modal">Crear cuenta</button>
    </div>
</section>
<dialog class="admin-modal" id="create-staff-modal" aria-labelledby="create-staff-title">
    <section class="admin-modal__content">
        <header class="admin-modal__header">
            <div><p class="eyebrow">Personal</p><h2 id="create-staff-title">Crear cuenta</h2></div>
            <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
        </header>
        <p>La contraseña se almacena como hash y el rol se asigna a una sola función operativa.</p>
        <form class="admin-form" method="post" action="{{ route('admin.staff.create') }}" data-staff-form>
            @csrf
            <label>ID persona
                <input name="id_persona" maxlength="20" required>
            </label>
            <label>Nombres
                <input name="nombres" maxlength="80" required>
            </label>
            <label>Primer apellido
                <input name="primer_apellido" maxlength="80" required>
            </label>
            <label>Segundo apellido
                <input name="segundo_apellido" maxlength="80">
            </label>
            <label>Tipo de documento
                <select name="tipo_documento">
                    <option value="">No especificado</option>
                    @foreach (['DNI', 'CE', 'PASAPORTE'] as $documentType)
                        <option value="{{ $documentType }}">{{ $documentType }}</option>
                    @endforeach
                </select>
            </label>
            <label>Número de documento
                <input name="numero_documento" maxlength="20">
            </label>
            <label>Teléfono
                <input name="telefono" maxlength="20">
            </label>
            <label>Correo
                <input type="email" name="email" maxlength="150">
            </label>
            <label>Usuario
                <input name="username" maxlength="80" autocomplete="off" required>
            </label>
            <label>Contraseña inicial
                <input type="password" name="password" minlength="12" maxlength="255" autocomplete="new-password" required>
            </label>
            <label>Rol
                <select name="rol" required>
                    <option value="MESERO">Mesero</option>
                    <option value="CAJERO">Cajero</option>
                    <option value="COCINERO">Cocinero</option>
                    <option value="ADMINISTRADOR">Administrador</option>
                </select>
            </label>
            <label>Estación de cocina <span class="muted">(solo para cocineros)</span>
                <select name="id_estacion">
                    <option value="">Selecciona estación</option>
                    @foreach ($stations as $station)
                        @if ($station->activa)
                            <option value="{{ $station->id_estacion }}">{{ $station->nombre }}</option>
                        @endif
                    @endforeach
                </select>
            </label>
            <div class="field-wide admin-modal__actions">
                <button class="btn-secondary" type="button" data-modal-close>Cancelar</button>
                <button class="btn-primary" type="submit">Crear usuario</button>
            </div>
        </form>
    </section>
</dialog>
<section class="panel">
    <div class="panel-heading">
        <div><h2>Personal registrado</h2><p>Desactivar impide nuevos accesos sin borrar el historial.</p></div>
    </div>
    <form class="filter-form" method="get" action="{{ route('admin.staff') }}">
        <label>Buscar usuario, nombre o documento
            <input name="q" value="{{ $filters['q'] ?? '' }}" maxlength="120">
        </label>
        <button class="btn-primary" type="submit">Buscar</button>
    </form>
    <div class="admin-table-wrap">
        <table class="admin-table">
            <thead><tr><th>Persona</th><th>Usuario</th><th>Rol</th><th>Contacto</th><th>Último acceso</th><th>Estado</th><th>Acción</th></tr></thead>
            <tbody>
            @forelse ($staff as $member)
                <tr>
                    <td><strong>{{ $member->nombres }} {{ $member->primer_apellido }} {{ $member->segundo_apellido }}</strong>
                        <small>{{ $member->tipo_documento }} {{ $member->numero_documento }}</small></td>
                    <td>{{ $member->username }}<small>{{ $member->id_persona }}</small></td>
                    <td>{{ $member->rol }}<small>{{ $member->estacion ?? '' }}</small></td>
                    <td>{{ $member->telefono ?? '—' }}<small>{{ $member->email ?? '' }}</small></td>
                    <td>{{ $member->ultimo_login ?? 'Nunca' }}</td>
                    <td><span class="status-pill {{ $member->activo ? '' : 'is-inactive' }}">{{ $member->activo ? 'Activo' : 'Inactivo' }}</span></td>
                    <td>
                        <form method="post" action="{{ route('admin.staff.state', $member->id_usuario) }}" data-confirm data-confirm-message="¿Confirmas el cambio de acceso de este usuario?">
                            @csrf
                            @method('patch')
                            <input type="hidden" name="activo" value="{{ $member->activo ? 0 : 1 }}">
                            <button class="btn-small {{ $member->activo ? 'btn-danger' : '' }}" type="submit"
                                @disabled((int) $member->id_usuario === (int) auth()->id() && $member->activo)>
                                {{ $member->activo ? 'Desactivar' : 'Activar' }}
                            </button>
                        </form>
                    </td>
                </tr>
            @empty
                <tr><td colspan="7" class="empty-state">No se encontraron usuarios.</td></tr>
            @endforelse
            </tbody>
        </table>
    </div>
</section>
@endsection
