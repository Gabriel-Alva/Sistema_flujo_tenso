<?php

use App\Modules\Billing\Http\Controllers\CashSessionController;
use App\Modules\Billing\Http\Controllers\CashierDashboardController;
use App\Modules\Billing\Http\Controllers\PaymentController;
use App\Modules\Catalog\Http\Controllers\CatalogController;
use App\Modules\Identity\Http\Controllers\AuthController;
use App\Modules\Kitchen\Http\Controllers\KitchenController;
use App\Modules\Orders\Http\Controllers\OrderController;
use App\Modules\Salon\Http\Controllers\SalonController;
use Illuminate\Support\Facades\Route;

Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:5,1');
Route::post('/auth/refresh', [AuthController::class, 'refresh'])->middleware('throttle:10,1');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::middleware('role:MESERO')->group(function () {
        Route::get('/salon/zonas', [SalonController::class, 'zonas']);
        Route::get('/salon/mesas', [SalonController::class, 'mesas']);

        Route::get('/catalogo/categorias', [CatalogController::class, 'categorias']);
        Route::get('/catalogo/productos', [CatalogController::class, 'productos']);
        Route::get('/catalogo/modificadores', [CatalogController::class, 'modificadores']);
        Route::get('/pedidos/clientes', [OrderController::class, 'clientesDelivery']);
        Route::post('/pedidos', [OrderController::class, 'store']);
        Route::patch('/pedidos/{id}/cancelar', [OrderController::class, 'cancelar']);
        Route::patch('/pedidos/items/{id}/entregado', [OrderController::class, 'entregarItem']);
    });

    Route::middleware('role:MESERO,CAJERO,ADMINISTRADOR')->group(function () {
        Route::get('/pedidos', [OrderController::class, 'index']);
        Route::get('/pedidos/{id}', [OrderController::class, 'show']);
    });

    Route::middleware('role:COCINERO,ADMINISTRADOR')->group(function () {
        Route::get('/cocina/cola', [KitchenController::class, 'cola']);
        Route::patch('/cocina/items/{id}/estado', [KitchenController::class, 'cambiarEstado']);
    });

    Route::middleware('role:COCINERO')->patch(
        '/cocina/comandas/{id}/cancelar',
        [KitchenController::class, 'cancelarComanda'],
    );

    Route::middleware('role:CAJERO,ADMINISTRADOR')->group(function () {
        Route::get('/cuentas/{idPedido}', [PaymentController::class, 'cuenta']);
    });

    Route::middleware('role:CAJERO,ADMINISTRADOR')->group(function () {
        Route::get('/caja/dashboard', CashierDashboardController::class);
        Route::get('/caja/sesiones/actual', [CashSessionController::class, 'actual']);
        Route::post('/caja/sesiones', [CashSessionController::class, 'abrir']);
        Route::post('/caja/movimientos', [CashSessionController::class, 'movimiento']);
        Route::post('/caja/sesiones/{id}/cierre', [CashSessionController::class, 'cerrar']);
        Route::post('/comprobantes', [PaymentController::class, 'emitirComprobante']);
        Route::post('/pagos', [PaymentController::class, 'pagar']);
    });
});
