# Complete Architecture

```mermaid
flowchart TB
    subgraph Customer["Customer / Booth (Landscape)"]
        W["Welcome\n(Live Camera)"]
        T["Tutorial"]
        P["Xendit Payment"]
        S["Start Session\n5-minute timer"]
        F["Select Frame"]
        PS["Photo Session\nMirror / No Mirror\n5-second countdown"]
        PR["Photo Result\nRetake / Next"]
        FI["Filter Selection"]
        R["Final Result\n(Auto Print + QR)"]
        E["Selesai → Finish"]
    end

    subgraph LaravelApp["Laravel Application (single deployment)"]
        API["REST API /api/*"]
        FILAMENT["Filament Admin Panel /admin/*"]
        PAY["Payment Service"]
        SES["Session Service"]
        CONTENT["Screen Content Service"]
        FILTER_SVC["Filter Service"]
        RESULT["Result Service"]
    end

    AdminBrowser["Admin (Browser)"]
    DB[("PostgreSQL")]
    STORAGE[("Cloud Storage")]
    X["Xendit"]
    DSLR["DSLR"]
    EPSON["Epson L8050"]

    W --> T --> P --> S --> F --> PS --> PR --> FI --> R --> E
    PR -->|Next pose| PS
    E -->|Return to Welcome| W
    P --> PAY --> X
    X -->|Webhook| PAY
    S --> SES
    F --> API
    FI --> FILTER_SVC
    PS --> DSLR
    R --> RESULT
    R -->|Auto Print| EPSON
    API --> DB
    API --> STORAGE
    API --> CONTENT
    API --> RESULT
    AdminBrowser --> FILAMENT
    FILAMENT --> DB
    FILAMENT --> STORAGE
```

## Final Result Screen

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

| Element | Behaviour |
|---------|-----------|
| Final Photo Preview | Composed photobooth strip with selected filter |
| QR Code | Links to `GET /api/results/{token}` — download GIF, final result, individual photos |
| Auto Print | Epson L8050 triggered automatically on screen arrival |
| **Selesai** button | Calls `POST /sessions/{session}/finish` → Welcome Screen |

**No email. No Kirim button. No email input.**
