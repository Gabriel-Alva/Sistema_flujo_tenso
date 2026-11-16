@php($editing = $table !== null)
<form class="admin-form" method="post" action="{{ route('admin.salon.tables.save') }}">
    @csrf
    @if ($editing)
        <input type="hidden" name="id_mesa" value="{{ $table->id_mesa }}">
    @endif
    <label>Zona
        <select name="id_zona" required>
            @foreach ($zones as $zone)
                @if ($zone->activa || ($editing && (int) $table->id_zona === (int) $zone->id_zona))
                    <option value="{{ $zone->id_zona }}" @selected($editing && (int) $table->id_zona === (int) $zone->id_zona)>
                        {{ $zone->nombre }}{{ $zone->activa ? '' : ' (inactiva)' }}
                    </option>
                @endif
            @endforeach
        </select>
    </label>
    <label>Número
        <input type="number" name="numero" min="1" value="{{ $table->numero ?? '' }}" required>
    </label>
    <label>Capacidad
        <input type="number" name="capacidad" min="1" value="{{ $table->capacidad ?? 2 }}" required>
    </label>
    <label>Activa
        <select name="activa" required>
            <option value="1" @selected(!$editing || $table->activa)>Sí</option>
            <option value="0" @selected($editing && !$table->activa)>No</option>
        </select>
    </label>
    <button class="btn-primary" type="submit">{{ $editing ? 'Guardar mesa' : 'Crear mesa' }}</button>
</form>
