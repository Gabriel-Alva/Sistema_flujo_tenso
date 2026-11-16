<?php

use App\Modules\Billing\Http\Controllers\AdminFinanceController;
use App\Modules\Catalog\Http\Controllers\AdminCatalogController;
use App\Modules\Identity\Http\Controllers\AdminAuthController;
use App\Modules\Identity\Http\Controllers\AdminStaffController;
use App\Modules\Reporting\Http\Controllers\AdminAuditController;
use App\Modules\Reporting\Http\Controllers\AdminDashboardController;
use App\Modules\Reporting\Http\Controllers\AdminReportsController;
use App\Modules\Salon\Http\Controllers\AdminSalonController;
use App\Modules\Settings\Http\Controllers\AdminParametersController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => redirect()->route('login'));
Route::get('/login', [AdminAuthController::class, 'showLogin'])->name('login');
Route::post('/login', [AdminAuthController::class, 'login'])->middleware('throttle:5,1');

Route::middleware(['auth', 'role:ADMINISTRADOR'])->group(function () {
    Route::post('/logout', [AdminAuthController::class, 'logout'])->name('logout');
    Route::get('/admin', AdminDashboardController::class)->name('admin.dashboard');
    Route::get('/admin/catalogo', [AdminCatalogController::class, 'index'])->name('admin.catalog');
    Route::post('/admin/catalogo/productos', [AdminCatalogController::class, 'save'])->name('admin.catalog.products.save');
    Route::post('/admin/catalogo/productos/{productId}/variantes', [AdminCatalogController::class, 'saveVariant'])
        ->name('admin.catalog.variants.save');
    Route::post('/admin/catalogo/referencias/{entity}', [AdminCatalogController::class, 'saveReference'])
        ->name('admin.catalog.references.save');
    Route::patch('/admin/catalogo/productos/{productId}/estado', [AdminCatalogController::class, 'setActive'])
        ->name('admin.catalog.products.state');
    Route::get('/admin/salon', [AdminSalonController::class, 'index'])->name('admin.salon');
    Route::post('/admin/salon/zonas', [AdminSalonController::class, 'saveZone'])->name('admin.salon.zones.save');
    Route::post('/admin/salon/mesas', [AdminSalonController::class, 'saveTable'])->name('admin.salon.tables.save');
    Route::get('/admin/personal', [AdminStaffController::class, 'index'])->name('admin.staff');
    Route::post('/admin/personal', [AdminStaffController::class, 'create'])->name('admin.staff.create');
    Route::patch('/admin/personal/{userId}/estado', [AdminStaffController::class, 'setActive'])
        ->name('admin.staff.state');
    Route::get('/admin/finanzas', AdminFinanceController::class)->name('admin.finance');
    Route::get('/admin/auditoria', [AdminAuditController::class, 'index'])->name('admin.audit');
    Route::get('/admin/reportes', AdminReportsController::class)->name('admin.reports');
    Route::get('/admin/parametros', [AdminParametersController::class, 'index'])->name('admin.parameters');
    Route::post('/admin/parametros/acceso', [AdminParametersController::class, 'unlock'])
        ->middleware('throttle:5,1')
        ->name('admin.parameters.unlock');
    Route::post('/admin/parametros/bloquear', [AdminParametersController::class, 'lock'])
        ->name('admin.parameters.lock');
    Route::post('/admin/parametros/{key}', [AdminParametersController::class, 'update'])
        ->where('key', '[A-Za-z0-9_]+')
        ->name('admin.parameters.update');
});
