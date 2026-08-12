# Component Diagram

```mermaid
flowchart LR
    subgraph Flutter["Customer App (Flutter, Landscape)"]
        Welcome["Welcome Screen\n(Live Camera)"]
        Tutorial["Tutorial Screen"]
        Payment["Payment Screen"]
        Start["Start Session"]
        Frame["Frame Selection"]
        Photo["Photo Session\n(Mirror/No Mirror)"]
        PhotoResult["Photo Result\n(Retake/Next)"]
        Filter["Filter Selection"]
        Result["Final Result Screen\n(QR + Selesai)"]
        CameraSvc["CameraService"]
        PrinterSvc["PrinterService"]
    end

    subgraph Backend["Laravel Application"]
        subgraph API["REST API (/api/*)"]
            ScreenAPI["Screen Content API"]
            PaymentAPI["Payment API"]
            SessionAPI["Session API"]
            FrameAPI["Frame API"]
            FilterAPI["Filter API"]
            ResultAPI["Result API"]
            Webhook["Xendit Webhook"]
        end
        subgraph AdminPanel["Filament Admin Panel (/admin/*)"]
            EventRes["EventResource"]
            FrameRes["FrameResource"]
            FilterRes["FilterResource"]
            ScreenRes["ScreenConfigResource"]
            SessionRes["SessionResource"]
            TxRes["TransactionResource"]
            UserRes["UserResource + Shield"]
            ReportWidgets["Report Widgets"]
        end
    end

    DB[("PostgreSQL")]
    Storage[("Cloud Storage")]
    X["Xendit"]
    DSLR["DSLR"]
    Epson["Epson L8050"]
    AdminBrowser["Admin (Browser)"]

    Welcome --> Tutorial --> Payment --> Start --> Frame --> Photo --> PhotoResult
    PhotoResult -->|Retake| Photo
    PhotoResult -->|Next pose| Photo
    PhotoResult -->|All done| Filter --> Result
    Payment --> PaymentAPI
    PaymentAPI --> X
    X --> Webhook --> PaymentAPI
    Start --> SessionAPI
    Frame --> FrameAPI
    Photo --> CameraSvc --> DSLR
    Result -->|Auto Print| PrinterSvc --> Epson
    Result -->|Selesai| SessionAPI
    Flutter --> API
    API --> DB
    API --> Storage
    AdminBrowser --> AdminPanel
    AdminPanel --> DB
    AdminPanel --> Storage
```

## No Email
No email component, no email service, no email API anywhere in this diagram.

## Result Screen
| Element | Behaviour |
|---------|-----------|
| QR Code | Links to `GET /api/results/{token}` — GIF, final result, individual photos |
| Auto Print | `PrinterService` → Epson L8050 on screen arrival |
| **Selesai** | `POST /sessions/{session}/finish` → Welcome |
