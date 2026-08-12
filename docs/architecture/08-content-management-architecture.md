# Content Management Architecture

```mermaid
flowchart LR
    Admin["Admin (Browser)"] --> FilamentPanel["Filament Admin Panel\n/admin/screen-configs"]
    FilamentPanel --> Editor["Welcome / Tutorial Editor\n(ScreenConfigResource)"]
    Editor --> Draft["Draft"]
    Draft --> Preview["Preview\n(Preview Action)"]
    Preview --> Publish["Publish\n(Publish Action)"]
    Publish --> Active["Active Content"]
    Active --> API["REST API\nGET /api/events/{event}/screen-content"]
    API --> App["Flutter Customer App"]
```

## Tutorial Steps
Tutorial has **5 steps** (stored as TUTORIAL_STEPS records):

| Step | Title | Description |
|------|-------|-------------|
| 1 | BAYAR | Scan QRIS untuk melakukan pembayaran |
| 2 | PILIH FRAME | Pilih frame favorit untuk foto kamu |
| 3 | AMBIL FOTO | Siapkan pose dan foto akan diambil setelah countdown |
| 4 | LIHAT HASIL | Lihat hasil foto dan pilih filter yang kamu suka |
| 5 | DOWNLOAD & CETAK | Scan QR untuk download hasil atau cetak foto |

Admin can edit these steps via the Tutorial Screen Editor in Filament.

## No Email
No email content, no email screen, no email management.
