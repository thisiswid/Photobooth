# Sequence — Welcome & Tutorial Content

```mermaid
sequenceDiagram
    actor Admin
    participant FilamentPanel as Filament Admin Panel
    participant Laravel as Laravel App
    participant DB as PostgreSQL
    participant App as Flutter

    Admin->>FilamentPanel: Open /admin/screen-configs
    Admin->>FilamentPanel: Edit Welcome or Tutorial content
    FilamentPanel->>Laravel: Save via ScreenConfigResource
    Laravel->>DB: Store as Draft
    Admin->>FilamentPanel: Click Preview action
    Laravel->>DB: Set status = preview
    Admin->>FilamentPanel: Click Publish action
    Laravel->>DB: Set status = active (replace previous)
    App->>Laravel: GET /api/events/{event}/screen-content
    Laravel->>DB: Fetch active screen config + tutorial steps
    Laravel-->>App: Welcome/Tutorial content (including 5 tutorial steps)
```

## Tutorial Steps API Response
```json
{
  "welcome": { "title": "...", "description": "...", "button_text": "MULAI" },
  "tutorial": {
    "title": "...",
    "button_text": "LANJUT",
    "tutorial_steps": [
      { "sort_order": 1, "title": "BAYAR", "description": "Scan QRIS untuk melakukan pembayaran." },
      { "sort_order": 2, "title": "PILIH FRAME", "description": "Pilih frame favorit untuk foto kamu." },
      { "sort_order": 3, "title": "AMBIL FOTO", "description": "Siapkan pose dan foto akan diambil setelah countdown." },
      { "sort_order": 4, "title": "LIHAT HASIL", "description": "Lihat hasil foto dan pilih filter yang kamu suka." },
      { "sort_order": 5, "title": "DOWNLOAD & CETAK", "description": "Scan QR untuk download hasil atau cetak foto." }
    ]
  }
}
```
