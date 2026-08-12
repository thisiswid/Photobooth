# Final Result Flow

```mermaid
flowchart TD
    A["Filter Selection"] --> B["Apply Filter to Final Photos"]
    B --> C["Compose Final Photobooth Result"]
    C --> D["Generate GIF"]
    C --> E["Generate Individual Photos"]
    C --> F["Automatic Print → Epson L8050"]
    D --> G["Final Result Screen"]
    E --> G
    C --> G
    F --> G

    G --> H["Final Photo Preview"]
    G --> I["QR Code\n(GIF + Final Result + Individual Photos)"]
    G --> J["[ SELESAI ]"]

    J --> K["Finish Session"]
    K --> L["Welcome Screen"]
```

## Result Screen layout

```
┌──────────────────────┬──────────────────┐
│                      │                  │
│                      │   QR DOWNLOAD    │
│   FINAL PHOTO        │                  │
│     PREVIEW          │   [ QR CODE ]    │
│                      │                  │
│                      │ Scan untuk       │
│                      │ download hasil   │
└──────────────────────┴──────────────────┘

              [ ✓ SELESAI ]
```

- **Final Photo Preview** — composed photobooth strip with selected filter
- **QR Code** — links to `GET /api/results/{token}` for downloading GIF, final result, and individual photos
- **SELESAI button** — finishes session and returns to Welcome Screen
- **Print** — triggered **automatically** when this screen is shown (no print button)
- **No email** — results are accessed via QR Code only
