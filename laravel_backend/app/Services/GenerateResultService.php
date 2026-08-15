<?php

namespace App\Services;

use App\Models\Photo;
use App\Models\Result;
use App\Models\Session;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class GenerateResultService
{
    /**
     * Generate complete photobooth results for a session:
     * 1. High-Res Photo Strip PNG (with selected Frame & Filter)
     * 2. Looping Animated Stop-Motion GIF
     * 3. QR Token with 7 days expiration
     */
    public function generate(Session $session): Result
    {
        $qrToken = (string) Str::uuid();
        $expiresAt = now()->addDays(7);

        // 1. Generate Photo Strip PNG
        $stripPath = $this->generatePhotoStrip($session, $qrToken);

        // 2. Generate Animated GIF
        $gifPath = $this->generateAnimatedGif($session, $qrToken);

        // 3. Save or update Result
        return Result::updateOrCreate(
            ['session_id' => $session->id],
            [
                'final_url'  => $stripPath,
                'gif_url'    => $gifPath,
                'qr_token'   => $qrToken,
                'expires_at' => $expiresAt,
            ]
        );
    }

    /**
     * Composites photos into the frame template.
     */
    public function generatePhotoStrip(Session $session, string $token): string
    {
        $frame = $session->frame;
        $filter = $session->filter;
        $photos = $session->photos()->where('type', 'raw')->orderBy('id')->get();

        // 1. Determine canvas size from Frame PNG or standard fallback
        $frameImg = null;
        $canvasW = 1200;
        $canvasH = 1800;

        if ($frame && $frame->asset_url) {
            $frameFullPath = Storage::disk('public')->path($frame->asset_url);
            if (!file_exists($frameFullPath)) {
                $frameFullPath = public_path('storage/' . $frame->asset_url);
            }
            if (file_exists($frameFullPath)) {
                $frameImg = @imagecreatefrompng($frameFullPath);
                if ($frameImg) {
                    $canvasW = imagesx($frameImg);
                    $canvasH = imagesy($frameImg);
                    imagealphablending($frameImg, true);
                    imagesavealpha($frameImg, true);
                }
            }
        }

        // 2. Create blank truecolor canvas with cream/white background
        $canvas = imagecreatetruecolor($canvasW, $canvasH);
        imagealphablending($canvas, true);
        imagesavealpha($canvas, true);
        $bgColor = imagecolorallocate($canvas, 253, 251, 247); // Cream white
        imagefilledrectangle($canvas, 0, 0, $canvasW, $canvasH, $bgColor);

        // 3. Determine photo slots
        $slots = $this->resolveSlots($frame, $canvasW, $canvasH, $photos->count() ?: 3);

        // 4. Paste each photo into its slot with BoxFit.cover cropping and filter
        foreach ($slots as $i => $slot) {
            if ($i >= $photos->count()) {
                break;
            }
            $photoModel = $photos[$i];
            $photoImg = $this->loadPhotoGd($photoModel->file_url);

            if ($photoImg) {
                // Apply filter effect
                $this->applyFilter($photoImg, $filter);

                // Resize and crop to fill the slot proportionally (no distortion)
                $this->pasteProportional(
                    $canvas,
                    $photoImg,
                    $slot['x'],
                    $slot['y'],
                    $slot['w'],
                    $slot['h']
                );
                imagedestroy($photoImg);
            }
        }

        // 5. Overlay Frame PNG on top of photos
        if ($frameImg) {
            imagecopy($canvas, $frameImg, 0, 0, 0, 0, $canvasW, $canvasH);
            imagedestroy($frameImg);
        } else {
            // Draw decorative vintage border
            $borderColor = imagecolorallocate($canvas, 92, 58, 33);
            imagesetthickness($canvas, max(2, (int)($canvasW * 0.005)));
            imagerectangle($canvas, 2, 2, $canvasW - 3, $canvasH - 3, $borderColor);
        }

        // 6. Save final composite image
        $relPath = "results/strip_{$session->id}_{$token}.png";
        $fullDestPath = Storage::disk('public')->path($relPath);
        @mkdir(dirname($fullDestPath), 0755, true);

        imagepng($canvas, $fullDestPath, 8);
        imagedestroy($canvas);

        return $relPath;
    }

    /**
     * Generates a looping animated GIF from the captured session photos.
     */
    public function generateAnimatedGif(Session $session, string $token): string
    {
        $filter = $session->filter;
        $photos = $session->photos()->where('type', 'raw')->orderBy('id')->get();

        if ($photos->isEmpty()) {
            return '';
        }

        $targetW = 600;
        $targetH = 450;
        $frames = [];

        foreach ($photos as $photoModel) {
            $photoImg = $this->loadPhotoGd($photoModel->file_url);
            if ($photoImg) {
                $this->applyFilter($photoImg, $filter);

                $frameCanvas = imagecreatetruecolor($targetW, $targetH);
                $this->pasteProportional($frameCanvas, $photoImg, 0, 0, $targetW, $targetH);

                $frames[] = $frameCanvas;
                imagedestroy($photoImg);
            }
        }

        if (empty($frames)) {
            return '';
        }

        $gifEncoder = new GifEncoder($frames, 50, 0); // 500ms per frame, infinite loop
        $gifData = $gifEncoder->getAnimation();

        foreach ($frames as $f) {
            imagedestroy($f);
        }

        $relPath = "results/gif_{$session->id}_{$token}.gif";
        $fullDestPath = Storage::disk('public')->path($relPath);
        @mkdir(dirname($fullDestPath), 0755, true);

        file_put_contents($fullDestPath, $gifData);

        return $relPath;
    }

    /**
     * Resolve slot bounding boxes for any frame resolution.
     */
    private function resolveSlots($frame, int $canvasW, int $canvasH, int $poseCount): array
    {
        if ($frame && !empty($frame->layout_config['slots'])) {
            $dbSlots = $frame->layout_config['slots'];
            $maxRight = 0;
            $maxBottom = 0;
            foreach ($dbSlots as $s) {
                $maxRight = max($maxRight, $s['x'] + $s['w']);
                $maxBottom = max($maxBottom, $s['y'] + $s['h']);
            }
            $refW = $maxRight > 500 ? 1200.0 : $canvasW;
            $refH = $maxBottom > 800 ? 1800.0 : $canvasH;

            $slots = [];
            foreach ($dbSlots as $s) {
                $slots[] = [
                    'x' => (int) round(($s['x'] / $refW) * $canvasW),
                    'y' => (int) round(($s['y'] / $refH) * $canvasH),
                    'w' => (int) round(($s['w'] / $refW) * $canvasW),
                    'h' => (int) round(($s['h'] / $refH) * $canvasH),
                ];
            }
            return $slots;
        }

        // Dynamic auto-calculated slots
        $canvasRatio = $canvasW / $canvasH;
        $isVerticalStrip = $canvasRatio <= 0.45; // e.g. 189x567 or 1:3 ratio

        if ($isVerticalStrip) {
            $sideMargin = (int) round($canvasW * 0.055);
            $slotW = $canvasW - (2 * $sideMargin);
            $photoRatio = 4.0 / 2.99; // Standard photostrip 4:3 landscape photo
            $slotH = (int) round($slotW / $photoRatio);

            if (($poseCount * $slotH) > ($canvasH * 0.86)) {
                $slotH = (int) round(($canvasH * 0.82) / $poseCount);
            }

            $topPadding = (int) round($canvasH * 0.025);
            $remainingY = (int) round($canvasH * 0.96) - $topPadding - ($poseCount * $slotH);
            $gap = $poseCount > 1 ? max(4, (int) round($remainingY / ($poseCount - 0.5))) : 10;

            $slots = [];
            for ($i = 0; $i < $poseCount; $i++) {
                $top = $topPadding + ($i * ($slotH + $gap));
                $slots[] = ['x' => $sideMargin, 'y' => $top, 'w' => $slotW, 'h' => $slotH];
            }
            return $slots;
        } else {
            // Standard 4R Card
            $sideMargin = (int) round($canvasW * 0.05);
            $slotW = $canvasW - (2 * $sideMargin);
            $slotH = (int) round(($canvasH * 0.86) / $poseCount);
            $gap = (int) round(($canvasH * 0.06) / max(1, $poseCount));
            $topPadding = (int) round($canvasH * 0.04);

            $slots = [];
            for ($i = 0; $i < $poseCount; $i++) {
                $top = $topPadding + ($i * ($slotH + $gap));
                $slots[] = ['x' => $sideMargin, 'y' => $top, 'w' => $slotW, 'h' => $slotH];
            }
            return $slots;
        }
    }

    /**
     * Paste photo into destination rectangle with center-crop (BoxFit.cover) without distortion.
     */
    private function pasteProportional($dstImg, $srcImg, int $dx, int $dy, int $dw, int $dh): void
    {
        $sw = imagesx($srcImg);
        $sh = imagesy($srcImg);

        $srcAspect = $sw / $sh;
        $dstAspect = $dw / $dh;

        if ($srcAspect > $dstAspect) {
            // Source is wider -> crop sides
            $cropW = (int) round($sh * $dstAspect);
            $cropH = $sh;
            $srcX = (int) round(($sw - $cropW) / 2);
            $srcY = 0;
        } else {
            // Source is taller -> crop top/bottom
            $cropW = $sw;
            $cropH = (int) round($sw / $dstAspect);
            $srcX = 0;
            $srcY = (int) round(($sh - $cropH) / 2);
        }

        imagecopyresampled(
            $dstImg,
            $srcImg,
            $dx,
            $dy,
            $srcX,
            $srcY,
            $dw,
            $dh,
            $cropW,
            $cropH
        );
    }

    /**
     * Apply filter parameters to GD image.
     */
    private function applyFilter($img, $filter): void
    {
        if (!$filter || empty($filter->parameters)) {
            return;
        }

        $params = is_array($filter->parameters) ? $filter->parameters : json_decode($filter->parameters, true);
        if (!$params) return;

        $type = $params['type'] ?? '';
        $nameLower = strtolower($filter->name ?? '');

        if ($type === 'grayscale' || str_contains($nameLower, 'b&w') || str_contains($nameLower, 'monochrome')) {
            imagefilter($img, IMG_FILTER_GRAYSCALE);
            imagefilter($img, IMG_FILTER_CONTRAST, -10);
        } elseif ($type === 'sepia' || str_contains($nameLower, 'sepia') || str_contains($nameLower, 'vintage')) {
            imagefilter($img, IMG_FILTER_GRAYSCALE);
            imagefilter($img, IMG_FILTER_COLORIZE, 90, 55, 30);
            imagefilter($img, IMG_FILTER_BRIGHTNESS, 5);
        } elseif ($type === 'warm' || str_contains($nameLower, 'warm') || str_contains($nameLower, 'coffee')) {
            imagefilter($img, IMG_FILTER_COLORIZE, 35, 18, 0);
            imagefilter($img, IMG_FILTER_BRIGHTNESS, 8);
        } elseif ($type === 'cool' || str_contains($nameLower, 'cool') || str_contains($nameLower, 'mist') || str_contains($nameLower, 'blue')) {
            imagefilter($img, IMG_FILTER_COLORIZE, -10, 0, 35);
            imagefilter($img, IMG_FILTER_BRIGHTNESS, 5);
        } elseif ($type === 'soft' || str_contains($nameLower, 'soft') || str_contains($nameLower, 'pastel') || str_contains($nameLower, 'glow')) {
            imagefilter($img, IMG_FILTER_SMOOTH, 2);
            imagefilter($img, IMG_FILTER_BRIGHTNESS, 18);
            imagefilter($img, IMG_FILTER_CONTRAST, 5);
        } elseif ($type === 'contrast' || str_contains($nameLower, 'contrast') || str_contains($nameLower, 'vivid')) {
            imagefilter($img, IMG_FILTER_CONTRAST, -28);
            imagefilter($img, IMG_FILTER_BRIGHTNESS, 5);
        } elseif ($type === 'sunset' || str_contains($nameLower, 'sunset') || str_contains($nameLower, 'golden')) {
            imagefilter($img, IMG_FILTER_COLORIZE, 45, 20, -15);
            imagefilter($img, IMG_FILTER_BRIGHTNESS, 10);
        }
    }

    /**
     * Load photo into GD resource from local disk, storage, or URL.
     */
    private function loadPhotoGd(string $path)
    {
        // 1. Direct file on disk
        if (file_exists($path)) {
            return @imagecreatefromstring(file_get_contents($path));
        }

        // 2. Relative storage disk path
        $fullStoragePath = Storage::disk('public')->path($path);
        if (file_exists($fullStoragePath)) {
            return @imagecreatefromstring(file_get_contents($fullStoragePath));
        }

        // 3. Public storage symlink
        $fullPublicPath = public_path('storage/' . $path);
        if (file_exists($fullPublicPath)) {
            return @imagecreatefromstring(file_get_contents($fullPublicPath));
        }

        // 4. HTTP URL
        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            $content = @file_get_contents($path);
            if ($content) {
                return @imagecreatefromstring($content);
            }
        }

        return null;
    }
}
