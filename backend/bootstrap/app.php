<?php

use App\Core\Exceptions\DomainException;
use App\Core\Http\Middleware\CheckRoleContext;
use App\Core\Http\Middleware\ForceJsonResponse;
use App\Core\Http\Middleware\SecurityHeadersCsp;
use App\Console\Commands\CreateSipanUser;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Route;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
        then: function () {
            Route::middleware(['api', ForceJsonResponse::class])
                ->prefix('api/v1')
                ->group(base_path('routes/api_v1.php'));
        },
    )
    ->withCommands([CreateSipanUser::class])
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->append(SecurityHeadersCsp::class);
        $middleware->alias([
            'role' => CheckRoleContext::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        $exceptions->render(function (DomainException $e, Request $request) {
            return response()->json([
                'code' => $e->errorCode,
                'message' => $e->getMessage(),
                'field_errors' => $e->fieldErrors,
                'request_id' => $request->header('X-Request-Id', (string) Str::uuid()),
            ], $e->getStatusCode());
        });

        $exceptions->render(function (ValidationException $e, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            return response()->json([
                'code' => 'VALIDATION_ERROR',
                'message' => 'Datos inválidos.',
                'field_errors' => $e->errors(),
                'request_id' => $request->header('X-Request-Id', (string) Str::uuid()),
            ], 422);
        });
    })->create();
