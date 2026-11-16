@extends('layouts.admin')
@section('title', 'Parámetros del sistema')
@section('content')
<section class="panel">
    <div class="panel-heading">
        <div>
            <h2><x-icon name="settings" /> Configuración protegida</h2>
            <p>Los cambios quedan registrados en Auditoría. El acceso vence en {{ $unlockMinutes }} minutos.</p>
        </div>
        <form method="post" action="{{ route('admin.parameters.lock') }}">
            @csrf
            <button class="btn-secondary" type="submit">Bloquear ahora</button>
        </form>
    </div>
</section>

<section class="parameter-grid" aria-label="Parámetros configurables">
    @forelse ($parameters as $parameter)
        @php($modalId = 'parameter-edit-'.$loop->index)
        <article class="parameter-card">
            <div>
                <span class="parameter-card__key">{{ $parameter->clave }}</span>
                <h2>{{ $parameter->descripcion ?: 'Parámetro del sistema' }}</h2>
                <p class="parameter-card__value">{{ $parameter->valor }}</p>
            </div>
            <button class="btn-secondary" type="button" data-modal-open="{{ $modalId }}">Editar valor</button>
        </article>
        <dialog class="admin-modal" id="{{ $modalId }}" aria-labelledby="{{ $modalId }}-title"
            data-open-on-errors="{{ $errors->any() && old('_modal_id') === $modalId ? 'true' : 'false' }}">
            <section class="admin-modal__content admin-modal__content--compact">
                <header class="admin-modal__header">
                    <div>
                        <p class="eyebrow">{{ $parameter->clave }}</p>
                        <h2 id="{{ $modalId }}-title">{{ $parameter->descripcion ?: 'Editar parámetro' }}</h2>
                    </div>
                    <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
                </header>
                <form class="admin-form" method="post" action="{{ route('admin.parameters.update', $parameter->clave) }}">
                    @csrf
                    <input type="hidden" name="_modal_id" value="{{ $modalId }}">
                    <label class="field-wide">Valor
                        @if ($parameter->clave === 'IGV')
                            <input name="valor" type="number" min="0" max="100" step="0.01" value="{{ old('valor', $parameter->valor) }}" required>
                        @elseif ($parameter->clave === 'ruc')
                            <input name="valor" inputmode="numeric" pattern="[0-9]{11}" minlength="11" maxlength="11" value="{{ old('valor', $parameter->valor) }}" required>
                        @elseif (str_starts_with($parameter->clave, 'serie_'))
                            <input name="valor" pattern="[A-Za-z0-9]{4}" minlength="4" maxlength="4" value="{{ old('valor', $parameter->valor) }}" required>
                        @else
                            <input name="valor" maxlength="255" value="{{ old('valor', $parameter->valor) }}" required>
                        @endif
                    </label>
                    <div class="admin-modal__actions field-wide">
                        <button class="btn-secondary" type="button" data-modal-close>Cancelar</button>
                        <button class="btn-primary" type="submit">Guardar parámetro</button>
                    </div>
                </form>
            </section>
        </dialog>
    @empty
        <section class="panel empty-state">No hay parámetros disponibles para editar.</section>
    @endforelse
</section>
@endsection
