<?php

namespace App\Modules\Salon\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Salon\Actions\ManageAdminSalonAction;
use App\Modules\Salon\Http\Requests\SaveAdminTableRequest;
use App\Modules\Salon\Http\Requests\SaveAdminZoneRequest;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\View;

class AdminSalonController extends Controller
{
    public function index(ManageAdminSalonAction $action): View
    {
        return view('pages.salon.index', $action->index());
    }

    public function saveZone(SaveAdminZoneRequest $request, ManageAdminSalonAction $action): RedirectResponse
    {
        $action->saveZone($request->validated());

        return redirect()->route('admin.salon')->with('status', 'Zona guardada.');
    }

    public function saveTable(SaveAdminTableRequest $request, ManageAdminSalonAction $action): RedirectResponse
    {
        $action->saveTable($request->validated());

        return redirect()->route('admin.salon')->with('status', 'Mesa guardada.');
    }
}
