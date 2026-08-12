<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Photo;
use App\Models\PhotoSession;
use App\Http\Requests\UploadPhotoRequest;
use App\Http\Resources\PhotoResource;
use App\Services\StorageService;
use Illuminate\Http\JsonResponse;

class PhotoController extends Controller
{
    public function __construct(private readonly StorageService $storage) {}

    /**
     * Upload a photo and attach it to the session.
     */
    public function upload(UploadPhotoRequest $request, string $code): JsonResponse
    {
        $session = PhotoSession::where('session_code', $code)
                               ->where('payment_status', 'paid')
                               ->firstOrFail();

        if ($session->is_expired) {
            return response()->json([
                'success' => false,
                'data'    => null,
                'message' => 'Sesi telah berakhir.',
            ], 422);
        }

        $file = $request->file('photo');
        $path = $this->storage->store(
            $file,
            "sessions/{$session->session_code}/photos"
        );

        $photo = Photo::create([
            'session_id'  => $session->id,
            'file_path'   => $path,
            'photo_type'  => 'individual',
            'file_size'   => $file->getSize(),
            'mime_type'   => $file->getMimeType(),
            'captured_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'data'    => new PhotoResource($photo),
            'message' => 'Foto berhasil diunggah.',
        ], 201);
    }

    /**
     * List all photos for a session.
     */
    public function index(string $code): JsonResponse
    {
        $session = PhotoSession::where('session_code', $code)->firstOrFail();
        $photos  = $session->photos()->orderBy('captured_at')->get();

        return response()->json([
            'success' => true,
            'data'    => PhotoResource::collection($photos),
            'message' => 'OK',
        ]);
    }

    /**
     * Delete a specific photo.
     */
    public function destroy(int $id): JsonResponse
    {
        $photo = Photo::findOrFail($id);
        $this->storage->delete($photo->file_path);
        $photo->delete();

        return response()->json([
            'success' => true,
            'data'    => null,
            'message' => 'Foto dihapus.',
        ]);
    }
}
