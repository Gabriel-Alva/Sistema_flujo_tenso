<?php

namespace App\Modules\Identity\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Identity\Actions\ManageAdminStaffAction;
use App\Modules\Identity\Http\Requests\CreateAdminStaffRequest;
use App\Modules\Identity\Http\Requests\SetAdminUserStateRequest;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminStaffController extends Controller
{
    public function index(Request $request, ManageAdminStaffAction $action): View
    {
        $filters = $request->validate(['q' => ['nullable', 'string', 'max:120']]);
        $data = $action->index($filters['q'] ?? '');

        return view('pages.staff.index', [...$data, 'filters' => $filters]);
    }

    public function create(CreateAdminStaffRequest $request, ManageAdminStaffAction $action): RedirectResponse
    {
        $action->create($request->validated());

        return redirect()->route('admin.staff')->with('status', 'Usuario creado correctamente.');
    }

    public function setActive(
        SetAdminUserStateRequest $request,
        int $userId,
        ManageAdminStaffAction $action,
    ): RedirectResponse {
        $action->setActive($userId, (bool) $request->validated('activo'));

        return redirect()->route('admin.staff')->with('status', 'Estado del usuario actualizado.');
    }
}
