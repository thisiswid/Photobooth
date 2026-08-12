<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

/**
 * Abstracts file storage across local (dev) and Cloudflare R2 (prod).
 * Swap the driver via STORAGE_DRIVER in .env — all callers stay the same.
 */
final class StorageService
{
    public function __construct(
        private readonly string $disk = 'local'
    ) {}

    /**
     * Store an uploaded file and return its relative storage path.
     */
    public function store(UploadedFile $file, string $directory): string
    {
        return $file->store($directory, $this->disk);
    }

    /**
     * Return the full public URL for a stored path.
     */
    public function url(string $path): string
    {
        return Storage::disk($this->disk)->url($path);
    }

    /**
     * Delete a single file by its relative path.
     */
    public function delete(string $path): void
    {
        Storage::disk($this->disk)->delete($path);
    }

    /**
     * Delete an entire directory and all its contents.
     */
    public function deleteDirectory(string $path): void
    {
        Storage::disk($this->disk)->deleteDirectory($path);
    }

    /**
     * Check whether a file exists.
     */
    public function exists(string $path): bool
    {
        return Storage::disk($this->disk)->exists($path);
    }
}
