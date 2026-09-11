<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ActivityLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'cafe_id',
        'action',
        'subject_type',
        'subject_id',
        'description',
        'properties',
        'ip_address',
        'user_agent',
    ];

    protected $casts = [
        'properties' => 'array',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function cafe(): BelongsTo
    {
        return $this->belongsTo(Cafe::class);
    }

    /**
     * Helper static method untuk mencatat log aktivitas dengan cepat
     */
    public static function record(
        string $action,
        string $description,
        ?Model $subject = null,
        ?array $properties = null,
        ?int $cafeId = null,
        ?int $userId = null
    ): self {
        $user = auth()->user();
        $finalUserId = $userId ?? $user?->id;
        $finalCafeId = $cafeId ?? $user?->cafe_id;

        if (!$finalCafeId && $subject && isset($subject->cafe_id)) {
            $finalCafeId = $subject->cafe_id;
        }

        return static::create([
            'user_id'      => $finalUserId,
            'cafe_id'      => $finalCafeId,
            'action'       => $action,
            'subject_type' => $subject ? get_class($subject) : null,
            'subject_id'   => $subject ? $subject->getKey() : null,
            'description'  => $description,
            'properties'   => $properties,
            'ip_address'   => request()->ip(),
            'user_agent'   => request()->userAgent(),
        ]);
    }
}
