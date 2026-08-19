<?php

namespace App\Models;

use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable implements FilamentUser
{
    use HasFactory, Notifiable, HasApiTokens;

    protected $fillable = [
        'cafe_id',
        'name',
        'email',
        'password',
        'role', // 'super_admin', 'admin', 'operator', 'viewer'
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password'          => 'hashed',
        ];
    }

    public function cafe(): BelongsTo
    {
        return $this->belongsTo(Cafe::class);
    }

    public function isSuperAdmin(): bool
    {
        return $this->role === 'super_admin';
    }

    public function isCafeAdmin(): bool
    {
        return in_array($this->role, ['admin', 'operator', 'viewer']);
    }

    public function canAccessPanel(Panel $panel): bool
    {
        if ($panel->getId() === 'super_admin') {
            return $this->isSuperAdmin();
        }

        if ($panel->getId() === 'admin') {
            // Super admins or users with active cafe can access cafe panel
            if ($this->isSuperAdmin()) {
                return true;
            }

            if ($this->cafe_id && $this->cafe) {
                return $this->cafe->isSubscriptionActive();
            }

            return false;
        }

        return true;
    }
}
