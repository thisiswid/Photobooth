# LumaBooth Documentation

## Canonical Customer Flow

```text
Welcome Screen (Live Camera)
→ Tutorial Screen
→ Xendit QRIS Payment
→ Payment PAID
→ Start Session
→ Select Frame
→ Photo Session (Mirror / No Mirror)
→ 5-second Countdown
→ Capture
→ Photo Result (Preview)
→ Retake maximum 2x per pose
→ [repeat for each pose]
→ Filter Selection
→ Final Result (Preview + QR Download + Auto Print)
→ Klik Selesai
→ Finish Session
→ Welcome Screen
```

## Session Rules
- Session duration: **5 minutes**.
- The 5-minute timer starts when **Start Session** begins, after payment is verified.
- Timer is NOT active during Welcome, Tutorial, or Payment screens.
- **Frame selection is mandatory before the photo session**.
- Countdown before every capture: **5 seconds**.
- Maximum retake: **2 times per pose**.
- Payment `PAID` must be verified by the backend from Xendit (webhook).
- Customer does NOT need to press any button after payment — system auto-detects.
- After all captures are accepted, customer selects a **filter** to apply to the final result.
- The **Result Screen** contains: final photo preview, QR download, and Selesai button.
- Print is triggered **automatically** when Result Screen is shown (Epson L8050).
- QR provides GIF, final result, and individual photos.
- Customer presses **Selesai** to finish session and return to Welcome Screen.
- **No email** — results are accessed via QR Code only.
- Results are retained for 30 days.

## Admin
Admin Panel is built with **Laravel + Filament PHP**, served from the same Laravel backend codebase.

Admin manages: Events, Frames, Filters, Transactions, Sessions, Photos/Results, Devices, Printers, Reports, Users/Roles, Settings, and Welcome/Tutorial Screen Content.

Screen content lifecycle: `Draft → Preview → Publish → Active`

## Hardware
- Lenovo Legion Y700 Android tablet (landscape orientation)
- DSLR camera
- Epson L8050 printer

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Customer App | Flutter (Android, Lenovo Legion Y700) |
| Admin Panel | Laravel + Filament PHP |
| Backend API | Laravel 13 REST API |
| Database | PostgreSQL |
| Storage | Cloud Storage |
| Payment | Xendit QRIS |

---

## Multi-Tenant & Dynamic Provisioning (SnapTechBooth)
- [Arsitektur Multi-Tenant Kiosk](file:///c:/PROJECT/Photobooth/docs/architecture/10-snaptech-multi-tenant-kiosk.md)
- [Alur Provisioning & Onboarding Mesin](file:///c:/PROJECT/Photobooth/docs/flows/06-device-provisioning-and-tenant-onboarding.md)
- [Arsitektur APK Flutter Kiosk](file:///c:/PROJECT/Photobooth/docs/architecture/09-flutter-kiosk-apk-architecture.md)

