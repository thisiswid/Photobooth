# LumaBooth — Deployment Guide

## Overview

Two deployable components:
- `flutter_app/` — Android tablet kiosk app (Lenovo Legion Y700, **landscape**)
- `laravel_backend/` — Laravel REST API + Filament Admin Panel

---

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter | 3.22+ |
| PHP | 8.3+ (PHP Herd Full) |
| Composer | 2.x |
| PostgreSQL | 15+ |

---

## 1. Laravel Backend Setup

```bash
cd laravel_backend
composer install
cp .env.example .env
php artisan key:generate
createdb lumabooth
php artisan migrate --seed
php artisan storage:link
php artisan serve --port=8000
php artisan queue:work --queue=default
```

Default admin credentials after seeding:
- URL: `http://lumabooth.test/admin` (Herd) or `http://localhost:8000/admin`
- Email: `admin@lumabooth.com`
- Password: `password`

---

## 2. Filament Admin Panel

Access: `http://lumabooth.test/admin`

Available panels:
- Dashboard — stats, charts
- Events, Frames, Filters — content management
- Screen Management — Welcome & Tutorial editor (5 steps, Draft → Preview → Publish → Active)
- Transactions, Sessions, Results — operational data
- Devices, Printers — hardware management
- Reports — analytics widgets
- Users / Roles — via Filament Shield

---

## 3. Flutter App Setup

```bash
cd flutter_app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run --release
```

Update API URL in `lib/core/constants/app_constants.dart`:
```dart
static const String apiBaseUrlDev = 'http://10.0.2.2:8000/api'; // emulator
static const String apiBaseUrl = 'http://192.168.1.x:8000/api'; // real device
```

The app runs in **landscape** orientation on Lenovo Legion Y700.

---

## 4. Hardware Integration

### DSLR Camera
```
CameraService
├── connect()       — on app startup
├── checkStatus()   — on app startup
├── startPreview()  — entering Photo Session
├── capture()       — after 5-second countdown
└── disconnect()    — on session finish or timeout
```

### Epson L8050 Printer
```
PrinterService
├── connect()           — on app startup
├── checkStatus()       — on app startup
├── print(imageData)    — auto-triggered on Final Result Screen arrival
└── getPrintStatus()    — poll print status
```

---

## 5. Environment Variables (Laravel .env)

```env
APP_NAME=LumaBooth
APP_URL=https://your-domain.com

DB_CONNECTION=pgsql
DB_DATABASE=lumabooth

XENDIT_SECRET_KEY=xnd_production_...
XENDIT_WEBHOOK_TOKEN=...

FILESYSTEM_DISK=public
```

**No email configuration needed** — email is not part of this system.

---

## 6. Xendit Webhook Setup

Register webhook URL in Xendit dashboard:
```
https://your-domain.com/api/webhooks/xendit/payment
```

---

## 7. Scheduled Tasks

```bash
* * * * * php /path/to/laravel_backend/artisan schedule:run
```

Jobs:
- `lumabooth:cleanup` — daily at 2am, removes expired results (30-day retention)

---

## 8. Customer Flow Summary

```
Welcome (Live Camera) → Tutorial → QRIS Payment → [auto PAID]
→ Select Frame → Photo Session (Mirror/No Mirror)
→ Countdown 5s → Capture → Photo Result (Retake/Next)
→ [repeat per pose] → Filter → Final Result (Auto Print + QR)
→ Selesai → Welcome
```

---

## 9. Troubleshooting

| Issue | Solution |
|-------|----------|
| API timeout | Check IP in `app_constants.dart` |
| Camera not detected | Check USB cable, validate DSLR USB/SDK |
| Printer offline | Check Epson L8050 Android driver on Lenovo Legion Y700 |
| Session expired prematurely | Check server time sync |
| Upload fails | Check Cloud Storage credentials |
| QR not accessible | Ensure `APP_URL` is publicly accessible |
| Webhook not received | Check Xendit dashboard webhook URL and token |
| Filament login fails | Run `php artisan db:seed --class=AdminUserSeeder` |
