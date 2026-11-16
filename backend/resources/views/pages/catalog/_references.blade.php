<section class="panel">
    <div class="panel-heading">
        <div><h2>Referencias de carta y cocina</h2><p>Gestiona categorías, estaciones, modificadores y prioridades.</p></div>
        <button class="btn-secondary" type="button" data-modal-open="catalog-references-modal">Administrar referencias</button>
    </div>
</section>
<dialog class="admin-modal" id="catalog-references-modal" aria-labelledby="catalog-references-title">
    <section class="admin-modal__content">
        <header class="admin-modal__header">
            <div><p class="eyebrow">Catálogo</p><h2 id="catalog-references-title">Referencias de carta y cocina</h2></div>
            <button class="icon-button" type="button" data-modal-close aria-label="Cerrar">×</button>
        </header>
        <p>Las referencias históricas se conservan; desactiva elementos que ya no deban usarse en nuevos pedidos.</p>
        <div class="panel-grid reference-grid">
        <section class="reference-group">
            <h3>Categorías</h3>
            <form class="inline-form" method="post" action="{{ route('admin.catalog.references.save', 'category') }}">
                @csrf
                <input name="nombre" maxlength="60" placeholder="Nueva categoría" required>
                <input type="hidden" name="activa" value="1">
                <button class="btn-small" type="submit">Agregar</button>
            </form>
            @foreach ($categories as $category)
                <form class="inline-form" method="post" action="{{ route('admin.catalog.references.save', 'category') }}">
                    @csrf
                    <input type="hidden" name="id_categoria" value="{{ $category->id_categoria }}">
                    <input name="nombre" value="{{ $category->nombre }}" maxlength="60" required>
                    <select name="activa">
                        <option value="1" @selected($category->activa)>Activa</option>
                        <option value="0" @selected(!$category->activa)>Inactiva</option>
                    </select>
                    <button class="btn-small" type="submit">Guardar</button>
                </form>
            @endforeach
        </section>
        <section class="reference-group">
            <h3>Estaciones de cocina</h3>
            <form class="inline-form" method="post" action="{{ route('admin.catalog.references.save', 'station') }}">
                @csrf
                <input name="nombre" maxlength="50" placeholder="Nueva estación" required>
                <input type="hidden" name="activa" value="1">
                <button class="btn-small" type="submit">Agregar</button>
            </form>
            @foreach ($stations as $station)
                <form class="inline-form" method="post" action="{{ route('admin.catalog.references.save', 'station') }}">
                    @csrf
                    <input type="hidden" name="id_estacion" value="{{ $station->id_estacion }}">
                    <input name="nombre" value="{{ $station->nombre }}" maxlength="50" required>
                    <select name="activa">
                        <option value="1" @selected($station->activa)>Activa</option>
                        <option value="0" @selected(!$station->activa)>Inactiva</option>
                    </select>
                    <button class="btn-small" type="submit">Guardar</button>
                </form>
            @endforeach
        </section>
        <section class="reference-group">
            <h3>Modificadores</h3>
            <form class="inline-form" method="post" action="{{ route('admin.catalog.references.save', 'modifier') }}">
                @csrf
                <input name="nombre" maxlength="80" placeholder="Nuevo modificador" required>
                <input type="number" name="precio_extra" min="0" step="0.01" value="0" required>
                <input type="hidden" name="activo" value="1">
                <button class="btn-small" type="submit">Agregar</button>
            </form>
            @foreach ($modifiers as $modifier)
                <form class="inline-form" method="post" action="{{ route('admin.catalog.references.save', 'modifier') }}">
                    @csrf
                    <input type="hidden" name="id_modificador" value="{{ $modifier->id_modificador }}">
                    <input name="nombre" value="{{ $modifier->nombre }}" maxlength="80" required>
                    <input type="number" name="precio_extra" value="{{ $modifier->precio_extra }}" min="0" step="0.01" required>
                    <select name="activo">
                        <option value="1" @selected($modifier->activo)>Activo</option>
                        <option value="0" @selected(!$modifier->activo)>Inactivo</option>
                    </select>
                    <button class="btn-small" type="submit">Guardar</button>
                </form>
            @endforeach
        </section>
        <section class="reference-group">
            <h3>Prioridades de cocina</h3>
            <form class="inline-form" method="post" action="{{ route('admin.catalog.references.save', 'priority') }}">
                @csrf
                <input name="id_prioridad" maxlength="12" placeholder="Código" required>
                <input name="prioridad" maxlength="10" placeholder="Etiqueta" required>
                <input type="color" name="color_hex" value="#E50935" required>
                <input type="hidden" name="activa" value="1">
                <button class="btn-small" type="submit">Agregar</button>
            </form>
            @foreach ($priorities as $priority)
                <form class="inline-form" method="post" action="{{ route('admin.catalog.references.save', 'priority') }}">
                    @csrf
                    <input name="id_prioridad" value="{{ $priority->id_prioridad }}" maxlength="12" readonly>
                    <input name="prioridad" value="{{ $priority->prioridad }}" maxlength="10" required>
                    <input type="color" name="color_hex" value="{{ $priority->color_hex }}" required>
                    <select name="activa">
                        <option value="1" @selected($priority->activa)>Activa</option>
                        <option value="0" @selected(!$priority->activa)>Inactiva</option>
                    </select>
                    <button class="btn-small" type="submit">Guardar</button>
                </form>
            @endforeach
        </section>
        </div>
    </section>
</dialog>
