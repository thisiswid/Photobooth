# Customer Flow

## Canonical Flow

`Welcome (Live Camera) → Tutorial → Xendit Payment → PAID → Start Session → Select Frame → Photo Session (Mirror/No Mirror) → 5-second Countdown → Capture → Photo Result (Retake/Next) → [repeat per pose] → Filter Selection → Final Result (Auto Print + QR) → Selesai → Finish → Welcome`

```mermaid
flowchart TD
    A["Welcome\n(Live Camera)"] --> B["Tutorial"]
    B --> C["Xendit QRIS"]
    C --> D{"PAID?"}
    D -->|No| C
    D -->|Yes| E["Start Session\n+ Start Timer 05:00"]
    E --> F["Select Frame"]
    F --> G["Photo Session\n(Mirror / No Mirror)"]
    G --> H["Countdown 5s"]
    H --> I["Capture"]
    I --> J["Photo Result"]
    J --> K{"Retake?"}
    K -->|Yes < 2| H
    K -->|No / Limit| L{"More poses?"}
    L -->|Yes| G
    L -->|No| M["Filter Selection"]
    M --> N["Final Result\n(Auto Print + QR)"]
    N --> O["Selesai"]
    O --> P["Finish Session"]
    P --> A
```
