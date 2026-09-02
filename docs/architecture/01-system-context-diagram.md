# System Context Diagram

```mermaid
flowchart LR
    Customer["Customer"]
    Admin["Admin"]
    App["SnapTechBooth Customer App\nFlutter / Lenovo Legion Y700\n(Landscape)"]
    AdminPanel["SnapTechBooth Admin Panel\nLaravel + Filament PHP"]
    API["SnapTechBooth Backend\nLaravel REST API"]
    DB[("PostgreSQL")]
    Storage[("Cloud Storage")]
    Xendit["Xendit Payment Gateway"]
    Camera["DSLR Camera"]
    Printer["Epson L8050"]

    Customer --> App
    Admin --> AdminPanel
    App --> API
    AdminPanel --> API
    AdminPanel -.->|"same Laravel app"| API
    API --> DB
    API --> Storage
    API --> Xendit
    App --> Camera
    App --> Printer
    Xendit -->|Payment Webhook| API
```

## Notes
- Admin Panel and REST API are the **same Laravel application**.
- No email service in the system.

## Actors
| Actor | Description |
|-------|-------------|
| Customer | Uses the Flutter kiosk app on Lenovo Legion Y700 (landscape) |
| Admin | Manages events, frames, filters, screens, transactions, reports via Filament admin panel |
| Xendit | Payment gateway — sends PAID webhook to backend |
| DSLR | Captures photos triggered by Flutter app |
| Epson L8050 | Prints final result automatically when Result Screen is shown |
