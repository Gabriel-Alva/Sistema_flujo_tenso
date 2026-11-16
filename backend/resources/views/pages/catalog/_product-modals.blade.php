<dialog class="admin-modal" id="create-product-modal" aria-labelledby="create-product-title"
    data-open-on-errors="{{ $errors->any() && old('_modal_id') === 'create-product-modal' ? 'true' : 'false' }}">
    <section class="admin-modal__content">
        <header class="admin-modal__header">
            <div><p class="eyebrow">Catálogo</p><h2 id="create-product-title">Agregar producto</h2></div>
            <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
        </header>
        @include('pages.catalog._product-form', ['product' => null, 'categories' => $categories, 'stations' => $stations, 'useOld' => true, 'modalId' => 'create-product-modal'])
    </section>
</dialog>

@foreach ($products as $product)
    @php
        $previewModalId = 'product-preview-'.$loop->index;
        $editModalId = 'product-edit-'.$loop->index;
    @endphp
    <dialog class="admin-modal" id="{{ $previewModalId }}" aria-labelledby="{{ $previewModalId }}-title">
        <section class="admin-modal__content">
            <header class="admin-modal__header">
                <div><p class="eyebrow">Previsualización de producto</p><h2 id="{{ $previewModalId }}-title">{{ $product->id_producto }}</h2></div>
                <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
            </header>
            <div class="product-preview">
                <figure class="product-image-editor" data-product-image-preview data-image-url="{{ $product->imagen_url }}">
                    <div class="product-preview__placeholder" data-image-preview-placeholder aria-live="polite">Sin imagen de producto.</div>
                    <img class="product-preview__image" data-image-preview alt="{{ $product->nombre }}" hidden>
                </figure>
                <div class="product-preview__details">
                    <div>
                        <span class="status-pill {{ $product->activo ? '' : 'is-inactive' }}">{{ $product->activo ? 'Disponible' : 'No disponible' }}</span>
                        <h3>{{ $product->nombre }}</h3>
                    </div>
                    <div class="product-preview__price">S/ {{ number_format((float) $product->precio_actual, 2) }}</div>
                    <div class="product-preview__meta">
                        <span class="status-pill">{{ $product->tipo }}</span>
                        <span class="status-pill">{{ $product->categoria ?? 'Sin categoría' }}</span>
                        @if ($product->requiere_preparacion)
                            <span class="status-pill">{{ $product->tiempo_prep_min }} min · {{ $product->estacion ?? 'Sin estación' }}</span>
                        @endif
                        @if ($product->volumen_ml)
                            <span class="status-pill">{{ $product->volumen_ml }} ml</span>
                        @endif
                    </div>
                    <p class="product-preview__description">{{ $product->descripcion ?: 'Este producto todavía no tiene una descripción.' }}</p>
                    @if ($product->tipo === 'PLATO' && count($variantsByProduct[$product->id_producto] ?? []))
                        <div>
                            <strong>Variantes</strong>
                            <ul>
                                @foreach ($variantsByProduct[$product->id_producto] as $variant)
                                    @if ($variant->activo)
                                        <li>{{ $variant->nombre }} · S/ {{ number_format((float) $variant->precio, 2) }}</li>
                                    @endif
                                @endforeach
                            </ul>
                        </div>
                    @endif
                </div>
            </div>
            <footer class="admin-modal__footer">
                <button class="btn-primary" type="button" data-modal-open="{{ $editModalId }}">Editar producto</button>
            </footer>
        </section>
    </dialog>
    <dialog class="admin-modal" id="{{ $editModalId }}" aria-labelledby="{{ $editModalId }}-title"
        data-open-on-errors="{{ $errors->any() && old('_modal_id') === $editModalId ? 'true' : 'false' }}">
        <section class="admin-modal__content">
            <header class="admin-modal__header">
                <div><p class="eyebrow">Editar producto</p><h2 id="{{ $editModalId }}-title">{{ $product->nombre }}</h2></div>
                <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
            </header>
            @include('pages.catalog._product-form', ['product' => $product, 'categories' => $categories, 'stations' => $stations, 'useOld' => false, 'modalId' => $editModalId])
            @if ($product->tipo === 'PLATO')
                <section class="variant-editor">
                    <h3>Variantes</h3>
                    @foreach ($variantsByProduct[$product->id_producto] ?? [] as $variant)
                        <form class="admin-form" method="post" action="{{ route('admin.catalog.variants.save', $product->id_producto) }}">
                            @csrf
                            <input type="hidden" name="id_variante" value="{{ $variant->id_variante }}">
                            <label>Nombre
                                <input name="nombre" value="{{ $variant->nombre }}" maxlength="40" required>
                            </label>
                            <label>Precio (S/)
                                <input type="number" name="precio" value="{{ $variant->precio }}" min="0" step="0.01" required>
                            </label>
                            <label>Estado
                                <select name="activo">
                                    <option value="1" @selected($variant->activo)>Activa</option>
                                    <option value="0" @selected(!$variant->activo)>Inactiva</option>
                                </select>
                            </label>
                            <button class="btn-small" type="submit">Guardar variante</button>
                        </form>
                    @endforeach
                    <form class="admin-form" method="post" action="{{ route('admin.catalog.variants.save', $product->id_producto) }}">
                        @csrf
                        <input type="hidden" name="activo" value="1">
                        <label>Nueva variante
                            <input name="nombre" maxlength="40" required>
                        </label>
                        <label>Precio (S/)
                            <input type="number" name="precio" min="0" step="0.01" required>
                        </label>
                        <button class="btn-small" type="submit">Agregar variante</button>
                    </form>
                </section>
            @endif
        </section>
    </dialog>
@endforeach
