# Payment Flow

```mermaid
sequenceDiagram
    actor Customer
    participant App as Flutter
    participant API as Laravel
    participant X as Xendit
    participant DB as PostgreSQL

    Customer->>App: Continue from Tutorial
    App->>API: Create payment
    API->>DB: Save PENDING
    API->>X: Create QRIS
    X-->>API: QRIS payload
    API-->>App: Display QRIS + nominal
    Note over App: Customer TIDAK perlu tekan tombol apapun.<br/>Sistem menunggu webhook dari Xendit.
    Customer->>X: Scan & Pay via smartphone
    X->>API: Payment webhook
    API->>API: Verify webhook
    API->>DB: Set PAID
    App->>API: Poll payment status
    API-->>App: PAID
    App->>App: Auto-navigate to Frame Selection
    App->>App: Start 5-minute timer (05:00)
```

## Notes
- Customer tidak perlu menekan tombol "Sudah Bayar" atau apapun.
- Sistem otomatis lanjut ke Frame Selection setelah webhook diterima.
- Timer 5 menit **dimulai di sini**, bukan di Welcome/Tutorial.
