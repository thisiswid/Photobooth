<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Services\PakasirService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Penerima webhook gateway pembayaran.
 *
 * Hanya Pakasir. Integrasi Xendit dilepas pada 9 September 2026 — route,
 * service, dan konfigurasinya dihapus, bukan sekadar dinonaktifkan, supaya
 * tidak ada jalur pelunasan kedua yang menganggur tanpa dijaga.
 */
class WebhookController extends Controller
{
    /**
     * Webhook Receiver untuk Pakasir.
     * URL: https://snaptechbooth.my.id/api/webhooks/pakasir
     *
     * Payload webhook Pakasir tidak bertanda tangan, jadi isinya tidak boleh
     * dipercaya untuk melunasi pembayaran. Webhook di sini hanya dipakai
     * sebagai pemicu: statusnya dikonfirmasi ulang ke API Pakasir lewat
     * panggilan ber-api_key sebelum apa pun ditandai lunas. Sebelumnya satu
     * POST tanpa autentikasi apa pun sudah cukup untuk melunasi pembayaran
     * mana pun.
     */
    public function pakasir(Request $request): JsonResponse
    {
        $data = $request->all();
        Log::info('Pakasir webhook received', $data);

        $orderId = $data['order_id'] ?? null;
        $status = strtolower($data['status'] ?? '');
        $project = $data['project'] ?? '';

        $expectedSlug = PakasirService::getSlug();

        // Slug yang tidak cocok ditolak, bukan sekadar dicatat.
        if (empty($expectedSlug) || $project !== $expectedSlug) {
            Log::warning("Pakasir webhook ditolak: project slug tidak cocok (dapat '{$project}').");
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        if (!$orderId) {
            return response()->json(['message' => 'Missing order_id'], 400);
        }

        // Pencocokan tepat saja. Fallback regex 'STB-(\d+)' -> Payment::find()
        // yang lama membuat siapa pun bisa menyasar pembayaran mana pun hanya
        // dengan menebak nomor urutnya.
        $payment = Payment::where('xendit_payment_id', $orderId)->first();

        if (!$payment) {
            Log::warning('Pakasir webhook payment record not found for order_id: ' . $orderId);
            return response()->json(['message' => 'Payment not found'], 200);
        }

        if (in_array($status, ['completed', 'paid', 'success'], true)) {
            // Konfirmasi ke gateway, jangan percaya payload.
            $confirmed = PakasirService::checkStatus($payment);

            if ($confirmed !== 'paid') {
                Log::warning("Pakasir webhook untuk Payment #{$payment->id} tidak terkonfirmasi saat dicek balik ke gateway.");
                return response()->json(['message' => 'Payment not confirmed by gateway'], 202);
            }
        } elseif (in_array($status, ['failed', 'expired', 'cancelled'], true)) {
            $payment->update(['status' => 'failed']);
        }

        return response()->json([
            'message'    => 'Webhook processed successfully',
            'payment_id' => $payment->id,
            'status'     => $payment->fresh()->status,
        ]);
    }
}
