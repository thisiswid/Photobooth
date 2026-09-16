<?php

namespace App\Services;

use Carbon\CarbonImmutable;
use DateTimeInterface;

class PakasirSettlementService
{
    public const TIMEZONE = 'Asia/Jakarta';

    public static function dueAt(DateTimeInterface|string|null $paidAt = null): CarbonImmutable
    {
        $paidAt = $paidAt
            ? CarbonImmutable::parse($paidAt)->setTimezone(self::TIMEZONE)
            : CarbonImmutable::now(self::TIMEZONE);

        return $paidAt->addDay()->startOfDay()->setHour(12)->utc();
    }

    public static function attributes(
        int|float|string $amount,
        ?string $paymentMethod,
        bool $isSimulated,
        DateTimeInterface|string|null $paidAt = null,
    ): array {
        $method = strtolower(trim($paymentMethod ?: 'qris'));
        $requiresSettlement = ! $isSimulated
            && (int) round((float) $amount) > 0
            && str_starts_with($method, 'qris');

        if (! $requiresSettlement) {
            return [
                'settlement_status' => 'not_applicable',
                'settlement_due_at' => null,
                'settled_at' => null,
            ];
        }

        $dueAt = self::dueAt($paidAt);
        $isSettled = $dueAt->isPast();

        return [
            'settlement_status' => $isSettled ? 'settled' : 'pending',
            'settlement_due_at' => $dueAt,
            'settled_at' => $isSettled ? $dueAt : null,
        ];
    }
}
