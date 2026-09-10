<?php

namespace App\Listeners;

use App\Models\ActivityLog;
use Illuminate\Auth\Events\Failed;
use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\Logout;
use Illuminate\Events\Dispatcher;

class LogAuthenticationEvents
{
    public function handleLogin(Login $event): void
    {
        $user = $event->user;
        ActivityLog::create([
            'user_id'     => $user->id,
            'cafe_id'     => $user->cafe_id,
            'action'      => 'login',
            'description' => "Pengguna {$user->name} ({$user->email}) berhasil login",
            'ip_address'  => request()->ip(),
            'user_agent'  => request()->userAgent(),
        ]);
    }

    public function handleFailed(Failed $event): void
    {
        $credentials = $event->credentials;
        $email = $credentials['email'] ?? 'unknown';

        ActivityLog::create([
            'user_id'     => $event->user?->id,
            'cafe_id'     => $event->user?->cafe_id,
            'action'      => 'failed_login',
            'description' => "Percobaan login gagal untuk email: {$email}",
            'properties'  => ['attempted_email' => $email],
            'ip_address'  => request()->ip(),
            'user_agent'  => request()->userAgent(),
        ]);
    }

    public function handleLogout(Logout $event): void
    {
        if ($event->user) {
            ActivityLog::create([
                'user_id'     => $event->user->id,
                'cafe_id'     => $event->user->cafe_id,
                'action'      => 'logout',
                'description' => "Pengguna {$event->user->name} ({$event->user->email}) logout",
                'ip_address'  => request()->ip(),
                'user_agent'  => request()->userAgent(),
            ]);
        }
    }

    public function subscribe(Dispatcher $events): array
    {
        return [
            Login::class  => 'handleLogin',
            Failed::class => 'handleFailed',
            Logout::class => 'handleLogout',
        ];
    }
}
