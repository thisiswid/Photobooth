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
        $filter = $session->filter;

        // 1. Generate Filtered Photo Strip PNG
        $stripPath = $this->generatePhotoStrip($session, $qrToken, $filter, '');

        // 2. Generate Original / Raw (Unfiltered) Photo Strip PNG
        $rawStripPath = $filter
            ? $this->generatePhotoStrip($session, $qrToken, null, '_raw')
            : $stripPath;

        // 3. Generate Animated GIF & MP4 Motion Video
        $gifPath = $this->generateAnimatedGif($session, $qrToken);
        $videoPath = $this->generateShortVideo($session, $qrToken);

        // 4. Save or update Result
        return Result::updateOrCreate(
            ['session_id' => $session->id],
            [
                'final_url'     => $stripPath,
                'raw_final_url' => $rawStripPath,
                'gif_url'       => $gifPath,
                'video_url'     => $videoPath,
                'qr_token'      => $qrToken,
                'expires_at'    => $expiresAt,
            ]
        );
    }

    /**
     * Composites photos into the frame template.
     */
    public function generatePhotoStrip(Session $session, string $token, $filter = null, string $suffix = ''): string
    {
        $frame = $session->frame;
        $filter = $filter ?? ($suffix === '_raw' ? null : $session->filter);
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
            if ($photos->isEmpty()) {
                break;
            }
            $mappedPoseIndex = $slot['pose_index'] ?? ($i % $photos->count());
            if ($mappedPoseIndex >= $photos->count()) {
                $mappedPoseIndex = $mappedPoseIndex % $photos->count();
            }
            $photoModel = $photos[$mappedPoseIndex];
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
        $relPath = "results/strip_{$session->id}_{$token}{$suffix}.png";
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
     * Generates a high-quality looping MP4 short video (Instagram / TikTok / WhatsApp ready)
     * using FFmpeg with H.264 encoding and faststart.
     */
    public function generateShortVideo(Session $session, string $token): string
    {
        $filter = $session->filter;
        $photos = $session->photos()->where('type', 'raw')->orderBy('id')->get();

        if ($photos->isEmpty()) {
            return '';
        }

        $relPath = "results/video_{$session->id}_{$token}.mp4";
        $fullDestPath = Storage::disk('public')->path($relPath);
        @mkdir(dirname($fullDestPath), 0755, true);

        $tempDir = storage_path("app/public/temp_video_{$session->id}_{$token}");
        @mkdir($tempDir, 0755, true);

        // Prepare frame sequence repeated 3 times (3x Boomerang cycle for longer story video)
        $photoList = $photos->values();
        $count = $photoList->count();
        $baseSeq = [];
        for ($i = 0; $i < $count; $i++) {
            $baseSeq[] = $i;
        }
        if ($count > 2) {
            for ($i = $count - 2; $i > 0; $i--) {
                $baseSeq[] = $i; // Boomerang effect
            }
        }

        $seq = [];
        for ($repeat = 0; $repeat < 3; $repeat++) {
            foreach ($baseSeq as $p) {
                $seq[] = $p;
            }
        }

        $frameIdx = 0;
        foreach ($seq as $pIdx) {
            if (!isset($photoList[$pIdx])) continue;

            $photoImg = $this->loadPhotoGd($photoList[$pIdx]->file_url);
            if ($photoImg) {
                $this->applyFilter($photoImg, $filter);

                $frameCanvas = imagecreatetruecolor(1080, 1440);
                $bgColor = imagecolorallocate($frameCanvas, 20, 20, 20);
                imagefilledrectangle($frameCanvas, 0, 0, 1080, 1440, $bgColor);

                $this->pasteProportional($frameCanvas, $photoImg, 0, 0, 1080, 1440);

                imagejpeg($frameCanvas, "$tempDir/frame_{$frameIdx}.jpg", 90);
                imagedestroy($frameCanvas);
                imagedestroy($photoImg);
                $frameIdx++;
            }
        }

        if ($frameIdx === 0) {
            @rmdir($tempDir);
            return '';
        }

        // Run FFmpeg: 2 frames per second (0.5s per pose) encoded to ultra-compatible H.264
        $cmd = "ffmpeg -y -framerate 2 -i \"$tempDir/frame_%d.jpg\" -c:v libx264 -preset fast -crf 22 -pix_fmt yuv420p -movflags +faststart \"$fullDestPath\" 2>&1";
        exec($cmd, $output, $returnCode);

        // Cleanup temporary frames
        array_map('unlink', glob("$tempDir/*.*"));
        @rmdir($tempDir);

        return $returnCode === 0 ? $relPath : '';
    }

    /**
     * Resolve slot bounding boxes for any frame resolution and layout type.
     */
    private function resolveSlots($frame, int $canvasW, int $canvasH, int $poseCount): array
    {
        $layoutConfig = $frame && is_array($frame->layout_config) ? $frame->layout_config : [];
        $layoutType = $layoutConfig['layout_type'] ?? 'single';
        $rightOrder = $layoutConfig['right_column_order'] ?? null;

        // 1. Explicit DB Slots
        if (!empty($layoutConfig['slots'])) {
            $dbSlots = $layoutConfig['slots'];
            $maxRight = 0;
            $maxBottom = 0;
            foreach ($dbSlots as $s) {
                $maxRight = max($maxRight, $s['x'] + $s['w']);
                $maxBottom = max($maxBottom, $s['y'] + $s['h']);
            }
            $isNormalized = ($maxRight <= 1.05 && $maxBottom <= 1.05);

            $refW = $isNormalized ? 1.0 : ($layoutConfig['dimensions']['w'] ?? ($maxRight > 500 ? $maxRight : $canvasW));
            $refH = $isNormalized ? 1.0 : ($layoutConfig['dimensions']['h'] ?? ($maxBottom > 800 ? $maxBottom : $canvasH));

            $slots = [];
            foreach ($dbSlots as $i => $s) {
                $slots[] = [
                    'x'          => (int) round(($s['x'] / $refW) * $canvasW),
                    'y'          => (int) round(($s['y'] / $refH) * $canvasH),
                    'w'          => (int) round(($s['w'] / $refW) * $canvasW),
                    'h'          => (int) round(($s['h'] / $refH) * $canvasH),
                    'pose_index' => $s['pose_index'] ?? ($i % max(1, $poseCount)),
                ];
            }
            return $slots;
        }

        // 2. Double Strip 6 Slots (2 Columns × 3 Rows from 3 Poses)
        if ($layoutType === 'double_6' || ($poseCount === 3 && ($canvasW / $canvasH) >= 0.55)) {
            $rightOrder = $rightOrder ?: [2, 0, 1]; // Pose 3, Pose 1, Pose 2
            $colW = (int) round($canvasW * 0.42);
            $slotH = (int) round($canvasH * 0.265);
            $leftColX = (int) round($canvasW * 0.055);
            $rightColX = (int) round($canvasW * 0.525);
            $topPadding = (int) round($canvasH * 0.04);
            $gapY = (int) round($canvasH * 0.035);

            $slots = [];
            // Left Column (Poses 0, 1, 2)
            for ($r = 0; $r < 3; $r++) {
                $top = $topPadding + ($r * ($slotH + $gapY));
                $slots[] = ['x' => $leftColX, 'y' => $top, 'w' => $colW, 'h' => $slotH, 'pose_index' => $r];
            }
            // Right Column (Mapped Poses e.g. 2, 0, 1)
            for ($r = 0; $r < 3; $r++) {
                $top = $topPadding + ($r * ($slotH + $gapY));
                $pIndex = isset($rightOrder[$r]) ? $rightOrder[$r] : ($r % max(1, $poseCount));
                $slots[] = ['x' => $rightColX, 'y' => $top, 'w' => $colW, 'h' => $slotH, 'pose_index' => $pIndex];
            }
            return $slots;
        }

        // 3. Double Strip 8 Slots (2 Columns × 4 Rows from 4 Poses)
        if ($layoutType === 'double_8' || ($poseCount === 4 && ($canvasW / $canvasH) >= 0.55)) {
            $rightOrder = $rightOrder ?: [3, 0, 1, 2]; // Pose 4, Pose 1, Pose 2, Pose 3
            $colW = (int) round($canvasW * 0.42);
            $slotH = (int) round($canvasH * 0.20);
            $leftColX = (int) round($canvasW * 0.055);
            $rightColX = (int) round($canvasW * 0.525);
            $topPadding = (int) round($canvasH * 0.035);
            $gapY = (int) round($canvasH * 0.025);

            $slots = [];
            // Left Column (Poses 0, 1, 2, 3)
            for ($r = 0; $r < 4; $r++) {
                $top = $topPadding + ($r * ($slotH + $gapY));
                $slots[] = ['x' => $leftColX, 'y' => $top, 'w' => $colW, 'h' => $slotH, 'pose_index' => $r];
            }
            // Right Column (Mapped Poses)
            for ($r = 0; $r < 4; $r++) {
                $top = $topPadding + ($r * ($slotH + $gapY));
                $pIndex = isset($rightOrder[$r]) ? $rightOrder[$r] : ($r % max(1, $poseCount));
                $slots[] = ['x' => $rightColX, 'y' => $top, 'w' => $colW, 'h' => $slotH, 'pose_index' => $pIndex];
            }
            return $slots;
        }

        // 4. Dynamic Vertical Strip (1:3 or 2x6 inch)
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
                $slots[] = ['x' => $sideMargin, 'y' => $top, 'w' => $slotW, 'h' => $slotH, 'pose_index' => $i];
            }
            return $slots;
        } else {
            // Standard 4R Card Single Column
            $sideMargin = (int) round($canvasW * 0.05);
            $slotW = $canvasW - (2 * $sideMargin);
            $slotH = (int) round(($canvasH * 0.86) / $poseCount);
            $gap = (int) round(($canvasH * 0.06) / max(1, $poseCount));
            $topPadding = (int) round($canvasH * 0.04);

            $slots = [];
            for ($i = 0; $i < $poseCount; $i++) {
                $top = $topPadding + ($i * ($slotH + $gap));
                $slots[] = ['x' => $sideMargin, 'y' => $top, 'w' => $slotW, 'h' => $slotH, 'pose_index' => $i];
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
