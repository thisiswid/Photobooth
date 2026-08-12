# Customer Use Cases

```mermaid
flowchart LR
    C((Customer))
    C --> W((View Welcome\nLive Camera))
    C --> T((View Tutorial))
    C --> P((Pay via Xendit QRIS))
    C --> S((Start Session))
    C --> F((Select Frame))
    C --> MR((Toggle Mirror / No Mirror))
    C --> PH((Take Photo))
    C --> RT((Retake max 2x per pose))
    C --> NX((Next Pose))
    C --> FI((Select Filter))
    C --> PR((Auto Print via Epson L8050))
    C --> QR((Scan Result QR))
    C --> D1((Download GIF))
    C --> D2((Download Final Result))
    C --> D3((Download Individual Photos))
    C --> SL((Selesai — Finish Session))
```

## Notes
- Welcome Screen menampilkan live camera preview sebagai background.
- Payment verification otomatis via Xendit webhook — customer tidak perlu tekan tombol apapun.
- Photo Result screen muncul setelah setiap capture — customer bisa Retake (max 2) atau Next.
- Jika frame punya multiple pose, cycle Countdown→Capture→Photo Result berulang per pose.
- Filter Selection setelah semua pose selesai.
- Print otomatis saat Final Result Screen ditampilkan.
- Final Result Screen berisi: photo preview, QR download, tombol Selesai.
- **Tidak ada email** di seluruh flow customer.
