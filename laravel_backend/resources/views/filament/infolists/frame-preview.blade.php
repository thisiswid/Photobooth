@php
    $state = $getState();
    $imageUrl = $state ? asset('storage/' . $state) : null;
@endphp

<div style="text-align: center; padding: 16px;">
    @if($imageUrl)
        <img
            src="{{ $imageUrl }}"
            alt="Frame Preview"
            style="max-height: 400px; max-width: 100%; object-fit: contain; background: repeating-conic-gradient(#e0e0e0 0% 25%, #fff 0% 50%) 0 0 / 20px 20px; border-radius: 8px; padding: 8px;"
        />
    @else
        <div style="padding: 40px; color: #999; border: 2px dashed #ddd; border-radius: 8px;">
            Belum ada gambar frame
        </div>
    @endif
</div>
