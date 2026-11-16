@extends('layouts.admin')
@section('title', 'Catálogo')
@section('content')
<section class="panel">
    <div class="panel-heading">
        <div>
            <h2><x-icon name="catalog" /> Carta y productos</h2>
            <p>Administra disponibilidad y precios sin alterar el histórico de comandas.</p>
        </div>
    </div>
    <form class="filter-form" method="get" action="{{ route('admin.catalog') }}">
        <label>Buscar por código o nombre
            <input name="q" value="{{ $filters['q'] ?? '' }}" maxlength="120">
        </label>
        <label>Estado
            <select name="estado">
                @foreach (['TODOS' => 'Todos', 'ACTIVO' => 'Activos', 'INACTIVO' => 'Inactivos'] as $value => $label)
                    <option value="{{ $value }}" @selected(($filters['estado'] ?? 'TODOS') === $value)>{{ $label }}</option>
                @endforeach
            </select>
        </label>
        <button class="btn-primary" type="submit">Filtrar</button>
    </form>
</section>

<section class="panel">
    <div class="panel-heading">
        <div><h2>Productos</h2><p>Crea productos y revisa cómo se mostrarán en el catálogo.</p></div>
        <button class="btn-primary" type="button" data-modal-open="create-product-modal">Agregar producto</button>
    </div>
</section>
<section class="panel">
    <h2>Productos registrados <span class="muted">({{ count($products) }})</span></h2>
    @if (count($products) === 0)
        <p class="empty-state">No hay productos para los filtros seleccionados.</p>
    @else
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead>
                <tr><th>Producto</th><th>Tipo / categoría</th><th>Precio</th><th>Preparación</th><th>Estado</th><th>Acciones</th></tr>
                </thead>
                <tbody>
                @foreach ($products as $product)
                    @php
                        $previewModalId = 'product-preview-'.$loop->index;
                        $editModalId = 'product-edit-'.$loop->index;
                    @endphp
                    <tr>
                        <td>
                            <strong>{{ $product->nombre }}</strong>
                            <small>{{ $product->id_producto }}</small>
                        </td>
                        <td>{{ $product->tipo }}<small>{{ $product->categoria ?? 'Sin categoría' }}</small></td>
                        <td>S/ {{ number_format((float) $product->precio_actual, 2) }}</td>
                        <td>{{ $product->requiere_preparacion ? "{$product->tiempo_prep_min} min · ".($product->estacion ?? 'Sin estación') : 'No requiere' }}</td>
                        <td><span class="status-pill {{ $product->activo ? '' : 'is-inactive' }}">{{ $product->activo ? 'Activo' : 'Inactivo' }}</span></td>
                        <td>
                            <div class="table-actions">
                                <button class="btn-small btn-small--info" type="button" data-modal-open="{{ $previewModalId }}">Vista previa</button>
                                <button class="btn-small btn-small--edit" type="button" data-modal-open="{{ $editModalId }}">Editar</button>
                                <form method="post" action="{{ route('admin.catalog.products.state', $product->id_producto) }}" data-confirm data-confirm-message="{{ $product->activo ? 'Este producto dejará de aparecer como disponible. ¿Deseas continuar?' : 'El producto volverá a estar disponible. ¿Deseas continuar?' }}">
                                    @csrf
                                    @method('patch')
                                    <input type="hidden" name="activo" value="{{ $product->activo ? 0 : 1 }}">
                                    <button class="btn-small {{ $product->activo ? 'btn-danger' : 'btn-small--success' }}" type="submit">
                                        {{ $product->activo ? 'Desactivar' : 'Activar' }}
                                    </button>
                                </form>
                            </div>
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    @endif
</section>

@include('pages.catalog._product-modals', compact('products', 'categories', 'stations', 'variantsByProduct'))
@include('pages.catalog._references', compact('categories', 'stations', 'modifiers', 'priorities'))
@endsection
