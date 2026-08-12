<?php

namespace App\Services;

use App\Models\PhotoSession;
use Illuminate\Support\Facades\Storage;

/**
 * Generates the composite photo-strip image and GIF animation.
 * Phase 1: mock implementation — returns placeholder paths.
 * Phase 2: replace with real image-processing library (e.g. Intervention Image).
 */
final class GenerateResultService
{
    /**
     * Generate the photo strip for a session.
     *
     * @return string  Relative storage path to the generated strip.
     */
    public function generateStrip(PhotoSession $session): string
    {
        // Phase 1: copy a placeholder so the path is real on disk
        $destPath = "sessions/{$session->session_code}/strip.jpg";

        // In Phase 2, composite real photos onto the frame template here
        Storage::disk('local')->put($destPath, '');

        return $destPath;
    }

    /**
     * Generate an animated GIF from the session's individual photos.
     *
     * @return string  Relative storage path to the GIF.
     */
    public function generateGif(PhotoSession $session): string
    {
        $destPath = "sessions/{$session->session_code}/animation.gif";

        // In Phase 2, use Imagick or GD to build real GIF frames
        Storage::disk('local')->put($destPath, '');

        return $destPath;
    }

    /**
     * Return the individual photo paths for a session, ordered by capture time.
     *
     * @return string[]
     */
    public function getSessionPhotos(PhotoSession $session): array
    {
        return $session->photos()
                       ->where('photo_type', 'individual')
                       ->orderBy('captured_at')
                       ->pluck('file_path')
                       ->toArray();
    }
}
