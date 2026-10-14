<?php

$allowedOrigins = array_filter(array_map(
    'trim',
    explode(',', env(
        'CORS_ALLOWED_ORIGINS',
        'http://localhost:5000,http://127.0.0.1:5000',
    )),
));

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['*'],
    'allowed_origins' => $allowedOrigins,
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];
