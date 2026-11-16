<?php

return [
    'paths' => ['api/*', 'sanctum/csrf-cookie'],
    'allowed_methods' => ['GET', 'POST', 'PATCH', 'OPTIONS'],
    'allowed_origins' => array_values(array_filter(array_map('trim', explode(',', env(
        'CORS_ALLOWED_ORIGINS',
        'http://localhost:5173,http://localhost:5174'
    ))))),
    'allowed_origins_patterns' => env('APP_ENV', 'production') === 'local'
        ? ['#^http://(localhost|127\.0\.0\.1)(:\d+)?$#']
        : [],
    'allowed_headers' => ['Accept', 'Authorization', 'Content-Type', 'X-Client-Type', 'X-Request-Id'],
    'exposed_headers' => ['X-Request-Id'],
    'max_age' => 600,
    'supports_credentials' => true,
];
