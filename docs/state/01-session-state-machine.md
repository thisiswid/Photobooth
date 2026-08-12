# Session State Machine

```mermaid
stateDiagram-v2
    [*] --> WELCOME
    WELCOME --> TUTORIAL
    TUTORIAL --> PAYMENT_PENDING
    PAYMENT_PENDING --> PAYMENT_FAILED: Xendit failed
    PAYMENT_PENDING --> PAYMENT_PAID: Xendit webhook verified
    PAYMENT_FAILED --> PAYMENT_PENDING
    PAYMENT_PAID --> START_SESSION
    START_SESSION --> FRAME_SELECTION
    FRAME_SELECTION --> PHOTO_SESSION
    PHOTO_SESSION --> COUNTDOWN_5S
    COUNTDOWN_5S --> CAPTURE
    CAPTURE --> PHOTO_RESULT
    PHOTO_RESULT --> COUNTDOWN_5S: Retake (max 2 per pose)
    PHOTO_RESULT --> PHOTO_SESSION: Next pose
    PHOTO_RESULT --> FILTER_SELECTION: All poses done
    FILTER_SELECTION --> PROCESSING
    PROCESSING --> PRINTING
    PRINTING --> RESULT_SCREEN
    RESULT_SCREEN --> FINISHED: Tekan Selesai
    START_SESSION --> SESSION_TIMEOUT: 00:00
    FRAME_SELECTION --> SESSION_TIMEOUT: 00:00
    PHOTO_SESSION --> SESSION_TIMEOUT: 00:00
    COUNTDOWN_5S --> SESSION_TIMEOUT: 00:00
    CAPTURE --> SESSION_TIMEOUT: 00:00
    PHOTO_RESULT --> SESSION_TIMEOUT: 00:00
    FILTER_SELECTION --> SESSION_TIMEOUT: 00:00
    RESULT_SCREEN --> SESSION_TIMEOUT: 00:00
    SESSION_TIMEOUT --> FINISHED
    FINISHED --> WELCOME
```

## State Descriptions

| State | Description |
|-------|-------------|
| `WELCOME` | Welcome screen dengan live camera preview |
| `TUTORIAL` | Tutorial 5 langkah |
| `PAYMENT_PENDING` | QRIS ditampilkan, menunggu Xendit webhook |
| `PAYMENT_FAILED` | Pembayaran gagal, bisa retry |
| `PAYMENT_PAID` | Xendit webhook konfirmasi PAID |
| `START_SESSION` | Session dibuat, timer 05:00 dimulai |
| `FRAME_SELECTION` | Customer memilih frame |
| `PHOTO_SESSION` | Halaman kamera aktif (Mirror/No Mirror) |
| `COUNTDOWN_5S` | Countdown 5 detik sebelum capture |
| `CAPTURE` | DSLR mengambil foto |
| `PHOTO_RESULT` | Customer melihat hasil foto, bisa Retake atau Next |
| `FILTER_SELECTION` | Customer memilih filter setelah semua pose selesai |
| `PROCESSING` | Backend generate final result + GIF |
| `PRINTING` | Epson L8050 mencetak (otomatis) |
| `RESULT_SCREEN` | Final photo preview + QR download + tombol Selesai |
| `FINISHED` | Session ditutup, kembali ke Welcome |
| `SESSION_TIMEOUT` | Timer 00:00, session otomatis ditutup |

## No Email
There is no `SEND_EMAIL` state. No email anywhere in the state machine.
