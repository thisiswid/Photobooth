<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Photobooth Application Configuration
    |--------------------------------------------------------------------------
    */

    'session_duration_minutes' => env('SESSION_DURATION_MINUTES', 10),
    'gallery_expiry_days'      => env('GALLERY_EXPIRY_DAYS', 30),
    'max_photos_per_session'   => env('MAX_PHOTOS_PER_SESSION', 10),
    'storage_driver'           => env('STORAGE_DRIVER', 'local'),
    'gallery_base_url'         => env('GALLERY_BASE_URL', 'https://gallery.fakultaskopi.com'),

    'printer' => [
        'default'         => env('PRINTER_NAME', 'default'),
        'timeout_seconds' => env('PRINTER_TIMEOUT', 30),
    ],

    'cloudflare_r2' => [
        'bucket'     => env('R2_BUCKET', ''),
        'account_id' => env('R2_ACCOUNT_ID', ''),
        'access_key' => env('R2_ACCESS_KEY', ''),
        'secret_key' => env('R2_SECRET_KEY', ''),
        'endpoint'   => env('R2_ENDPOINT', ''),
    ],
];
