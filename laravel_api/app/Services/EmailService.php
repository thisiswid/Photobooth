<?php

namespace App\Services;

use App\Jobs\SendResultEmail;
use App\Models\PhotoSession;

/**
 * Handles email delivery of session results.
 * Delegates actual sending to a queued job so it never blocks the HTTP response.
 */
final class EmailService
{
    /**
     * Queue an email with links to the session's photos, strip, and GIF.
     */
    public function sendResults(string $email, string $sessionCode): void
    {
        $session = PhotoSession::where('session_code', $sessionCode)
                               ->with('photos')
                               ->firstOrFail();

        SendResultEmail::dispatch($session, $email);
    }
}
