<?php

namespace App\Services;

use App\Models\Event;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class FrameEditorSave
{
    public static function prepare(array $data, bool $master = false): array
    {
        $fail = fn (string $field, string $message) => throw ValidationException::withMessages(['data.' . $field => $message]);
        if (!$master) {
            $cafeId = auth()->user()?->cafe_id;
            $event = Event::find($data['event_id'] ?? null);
            if (!$event || ($cafeId && (int) $event->cafe_id !== (int) $cafeId)) {
                $fail('event_id', 'Pilih event milik cafe yang sesuai.');
            }
        }
        $disk = Storage::disk('public');
        $path = $data['asset_url'] ?? '';
        if (!is_string($path) || !$disk->exists($path)) {
            $fail('asset_url', 'Upload gambar terlebih dahulu dan tunggu sampai selesai.');
        }
        $info = @getimagesize($disk->path($path));
        if (!$info || $info[0] * $info[1] > 16000000) {
            $fail('asset_url', 'Gambar tidak valid atau melebihi 16 megapiksel.');
        }
        $config = $data['layout_config'] ?? [];
        $operations = $config['color_operations'] ?? [];
        if (!is_array($operations) || count($operations) > 30) {
            $fail('layout_config', 'Maksimal 30 perubahan warna.');
        }
        $image = @imagecreatefromstring($disk->get($path));
        if (!$image) $fail('asset_url', 'Gambar tidak dapat dibaca.');
        imagepalettetotruecolor($image);
        imagealphablending($image, false);
        imagesavealpha($image, true);
        foreach ($operations as $op) {
            if (!is_array($op) || !preg_match('/^#[0-9a-f]{6}$/i', $op['color'] ?? '') || !is_numeric($op['tolerance'] ?? null)) {
                $fail('layout_config', 'Perubahan warna tidak valid.');
            }
            $color = hexdec(substr($op['color'], 1));
            $tr = ($color >> 16) & 255; $tg = ($color >> 8) & 255; $tb = $color & 255;
            $tol = max(15, min(90, (int) $op['tolerance']));
            for ($y = 0; $y < $info[1]; $y++) {
                for ($x = 0; $x < $info[0]; $x++) {
                    $pixel = imagecolorat($image, $x, $y);
                    $r = ($pixel >> 16) & 255; $g = ($pixel >> 8) & 255; $b = $pixel & 255;
                    $match = !empty($op['chroma'])
                        ? (($g > 110 && $g > $r + 30 && $g > $b + 30) || ($r ** 2 + (255 - $g) ** 2 + $b ** 2 < 135 ** 2))
                        : (($r - $tr) ** 2 + ($g - $tg) ** 2 + ($b - $tb) ** 2 <= $tol ** 2);
                    if ($match) imagesetpixel($image, $x, $y, 0x7f000000);
                }
            }
        }
        $target = 'frames/edited_' . Str::uuid() . '.png';
        $disk->makeDirectory('frames');
        if (!imagepng($image, $disk->path($target))) $fail('asset_url', 'Gagal menyimpan gambar.');
        $detected = FrameSlotDetector::detectAlphaCutouts($disk->path($target), $info[0], $info[1]);
        $slots = $detected['slots'] ?? [];
        $type = $data['layout_type'] ?? 'single';
        $expected = match ($type) { 'double_6' => 6, 'double_8' => 8, default => null };
        if (!$slots || count($slots) > 8 || ($expected && count($slots) !== $expected)) {
            $disk->delete($target);
            $fail('layout_config', $expected ? "Layout ini memerlukan {$expected} lubang foto terpisah. Periksa kanvas." : 'Belum ditemukan 1–8 lubang foto transparan. Periksa kanvas sebelum menyimpan.');
        }
        $poses = $expected ? intdiv($expected, 2) : count($slots);
        $key = $data['right_column_order'] ?? 'scrambled_1';
        $order = range(0, $poses - 1);
        if ($key === 'reversed') $order = array_reverse($order);
        elseif ($key !== 'identical') {
            $shift = match ($key) { 'scrambled_2' => 2, 'scrambled_3' => 3, default => 1 } % $poses;
            $order = array_merge(array_slice($order, $poses - $shift), array_slice($order, 0, $poses - $shift));
        }
        // Do not infer duplicated camera poses merely from six/eight single slots.
        if ($expected) $slots = FrameSlotDetector::assignSlotPoses($slots, $type, $order, $poses);
        else {
            usort($slots, fn ($a, $b) => [$a['y'], $a['x']] <=> [$b['y'], $b['x']]);
            foreach ($slots as $i => &$slot) $slot['pose_index'] = $i;
            unset($slot);
        }
        $data['asset_url'] = $target;
        $data['pose_count'] = $poses;
        $data['layout_config'] = [
            'layout_type' => $type, 'slot_count' => count($slots), 'pose_count' => $poses,
            'right_column_order_key' => $key, 'right_column_order' => $order,
            'slots' => $slots, 'dimensions' => ['w' => $info[0], 'h' => $info[1]],
        ];
        unset($data['layout_type'], $data['right_column_order'], $data['use_ai_detection']);
        return $data;
    }
}
