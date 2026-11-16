@php
    $editing = $product !== null;
    $useOld = $useOld ?? false;
    $value = fn (string $key, mixed $fallback = null) => $useOld
        ? old($key, $fallback)
        : data_get($product, $key, $fallback);
    $modalId = $modalId ?? ($editing ? 'product-edit-'.$product->id_producto : 'create-product-modal');
@endphp
<form class="admin-form" method="post" action="{{ route('admin.catalog.products.save') }}">
    @csrf
    <input type="hidden" name="_modal_id" value="{{ $modalId }}">
    <label>Código
        <input name="id_producto" value="{{ $value('id_producto', '') }}" maxlength="15" required @readonly($editing)>
    </label>
    <label>Nombre
        <input name="nombre" value="{{ $value('nombre', '') }}" maxlength="120" required>
    </label>
    <label>Tipo
        @if ($editing)
            <input value="{{ $product->tipo }}" readonly>
            <input type="hidden" name="tipo" value="{{ $product->tipo }}">
        @else
            <select name="tipo" required>
                @foreach (['PLATO' => 'Plato', 'BEBIDA' => 'Bebida', 'OTRO' => 'Otro'] as $key => $label)
                    <option value="{{ $key }}" @selected($value('tipo', 'PLATO') === $key)>{{ $label }}</option>
                @endforeach
            </select>
        @endif
    </label>
    <label>Categoría <span class="muted">(requerida para platos)</span>
        <select name="id_categoria">
            <option value="">Selecciona categoría</option>
            @foreach ($categories as $category)
                @if ($category->activa || (int) $value('id_categoria') === (int) $category->id_categoria)
                    <option value="{{ $category->id_categoria }}" @selected((int) $value('id_categoria') === (int) $category->id_categoria)>
                        {{ $category->nombre }}{{ $category->activa ? '' : ' (inactiva)' }}
                    </option>
                @endif
            @endforeach
        </select>
    </label>
    <label>Precio (S/)
        <input type="number" name="precio_actual" value="{{ $value('precio_actual', '') }}" min="0" step="0.01" required>
    </label>
    <label>Tiempo de preparación (min)
        <input type="number" name="tiempo_prep_min" value="{{ $value('tiempo_prep_min', 0) }}" min="0" max="65535" required>
    </label>
    <label>Requiere preparación
        <select name="requiere_preparacion" required>
            <option value="1" @selected((string) $value('requiere_preparacion', 1) === '1')>Sí</option>
            <option value="0" @selected((string) $value('requiere_preparacion', 1) === '0')>No</option>
        </select>
    </label>
    <label>Estación de cocina <span class="muted">(requerida si requiere preparación)</span>
        <select name="id_estacion">
            <option value="">Selecciona estación</option>
            @foreach ($stations as $station)
                @if ($station->activa || (int) $value('id_estacion') === (int) $station->id_estacion)
                    <option value="{{ $station->id_estacion }}" @selected((int) $value('id_estacion') === (int) $station->id_estacion)>
                        {{ $station->nombre }}{{ $station->activa ? '' : ' (inactiva)' }}
                    </option>
                @endif
            @endforeach
        </select>
    </label>
    <label>Volumen (ml, bebidas)
        <input type="number" name="volumen_ml" value="{{ $value('volumen_ml', '') }}" min="1">
    </label>
    <label>Temperatura (bebidas)
        <select name="temperatura">
            <option value="">No aplica</option>
            @foreach (['HELADA', 'TEMPERATURA_AMBIENTE', 'CALIENTE'] as $temperature)
                <option value="{{ $temperature }}" @selected($value('temperatura') === $temperature)>{{ str_replace('_', ' ', $temperature) }}</option>
            @endforeach
        </select>
    </label>
    <label>Alcohólica (bebidas)
        <select name="es_alcoholica">
            <option value="">No aplica</option>
            <option value="1" @selected((string) $value('es_alcoholica') === '1')>Sí</option>
            <option value="0" @selected((string) $value('es_alcoholica') === '0')>No</option>
        </select>
    </label>
    <label class="field-wide">URL o ruta pública de imagen
        <input data-product-image-input type="text" name="imagen_url" value="{{ $value('imagen_url', '') }}" maxlength="255" placeholder="https://... o images/producto.jpg">
        <span class="form-help">Usa una URL HTTPS o una ruta relativa a la carpeta public.</span>
    </label>
    <figure class="field-wide product-image-editor" data-product-image-preview>
        <div class="product-preview__placeholder" data-image-preview-placeholder aria-live="polite">Agrega una URL para ver la imagen.</div>
        <img class="product-preview__image" data-image-preview alt="Vista previa de imagen del producto" hidden>
    </figure>
    <label class="field-wide">Descripción
        <textarea name="descripcion" maxlength="1000">{{ $value('descripcion', '') }}</textarea>
    </label>
    <div class="field-wide">
        <button class="btn-primary" type="submit">{{ $editing ? 'Guardar cambios' : 'Agregar producto' }}</button>
    </div>
</form>
