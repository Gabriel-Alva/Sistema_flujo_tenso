<?php

namespace App\Modules\Catalog\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Catalog\Actions\ManageAdminCatalogAction;
use App\Modules\Catalog\Http\Requests\SaveAdminCatalogReferenceRequest;
use App\Modules\Catalog\Http\Requests\SaveAdminProductRequest;
use App\Modules\Catalog\Http\Requests\SaveAdminVariantRequest;
use App\Modules\Catalog\Http\Requests\SetAdminProductStateRequest;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminCatalogController extends Controller
{
    public function index(Request $request, ManageAdminCatalogAction $action): View
    {
        $filters = $request->validate([
            'q' => ['nullable', 'string', 'max:120'],
            'estado' => ['nullable', 'in:TODOS,ACTIVO,INACTIVO'],
        ]);
        $data = $action->index($filters['q'] ?? '', $filters['estado'] ?? 'TODOS');

        return view('pages.catalog.index', [...$data, 'filters' => $filters]);
    }

    public function save(SaveAdminProductRequest $request, ManageAdminCatalogAction $action): RedirectResponse
    {
        $action->save($request->validated());

        return redirect()->route('admin.catalog')->with('status', 'Producto guardado.');
    }

    public function setActive(
        SetAdminProductStateRequest $request,
        string $productId,
        ManageAdminCatalogAction $action,
    ): RedirectResponse {
        $action->setActive($productId, (bool) $request->validated('activo'));

        return redirect()->route('admin.catalog')->with('status', 'Estado del producto actualizado.');
    }

    public function saveVariant(
        SaveAdminVariantRequest $request,
        string $productId,
        ManageAdminCatalogAction $action,
    ): RedirectResponse {
        $action->saveVariant($productId, $request->validated());

        return redirect()->route('admin.catalog')->with('status', 'Variante guardada.');
    }

    public function saveReference(
        SaveAdminCatalogReferenceRequest $request,
        string $entity,
        ManageAdminCatalogAction $action,
    ): RedirectResponse {
        $action->saveReference($entity, $request->validated());

        return redirect()->route('admin.catalog')->with('status', 'Configuración del catálogo guardada.');
    }
}
