<?php

namespace App\Modules\Reporting\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Reporting\Actions\GetAdminDashboardAction;
use Illuminate\View\View;

class AdminDashboardController extends Controller
{
    public function __invoke(GetAdminDashboardAction $action): View
    {
        return view('pages.home.dashboard', $action->execute());
    }
}
