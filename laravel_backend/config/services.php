<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'xendit' => [
        'secret_key'    => env('XENDIT_SECRET_KEY'),
        'webhook_token' => env('XENDIT_WEBHOOK_TOKEN'),
    ],

    'pakasir' => [
        'slug'    => env('PAKASIR_SLUG', 'snaptechbooth'),
        'api_key' => env('PAKASIR_API_KEY', 'UNDovg8HAySBJSyOUiC3DcyNvwmkC8x1'),
    ],

    'openagentic' => [
        'key'      => env('OPENAGENTIC_API_KEY'),
        'base_url' => env('OPENAGENTIC_BASE_URL', 'https://openagentic.id/api/v1'),
        'model'    => env('OPENAGENTIC_MODEL', 'claude-sonnet-4.6'),
    ],

    'gemini' => [
        'key'      => env('GEMINI_API_KEY'),
    ],

];
