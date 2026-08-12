# Admin Architecture

```mermaid
flowchart TD
    ADMIN["Admin (Browser)"] --> FILAMENT["Laravel + Filament PHP\nAdmin Panel"]

    FILAMENT --> DASH["Dashboard\n(Stats, Charts)"]
    FILAMENT --> EVENTS["Events\n(CRUD)"]
    FILAMENT --> FRAMES["Frames\n(CRUD + Upload + pose_count)"]
    FILAMENT --> FILTERS["Filters\n(CRUD + Thumbnail + Reorder)"]
    FILAMENT --> SCREENS["Screen Management\n(Welcome & Tutorial)"]
    FILAMENT --> TX["Transactions\n(View + Filter)"]
    FILAMENT --> SESS["Sessions\n(View + Detail)"]
    FILAMENT --> PHOTOS["Photos / Results\n(View)"]
    FILAMENT --> DEV["Devices\n(CRUD)"]
    FILAMENT --> PRINTER["Printers\n(CRUD)"]
    FILAMENT --> REPORT["Reports\n(Widgets + Charts)"]
    FILAMENT --> USERS["Users / Roles\n(CRUD + Filament Shield)"]
    FILAMENT --> SETTINGS["Settings"]

    SCREENS --> WELCOME["Welcome Screen Editor"]
    SCREENS --> TUTORIAL["Tutorial Screen Editor\n(5 steps)"]
    WELCOME --> PUBLISH["Draft → Preview → Publish → Active"]
    TUTORIAL --> PUBLISH

    FILTERS --> FILTER_LIST["Filter List"]
    FILTER_LIST --> FILTER_CREATE["Create Filter\n(name, thumbnail, parameters)"]
    FILTER_LIST --> FILTER_EDIT["Edit Filter"]
    FILTER_LIST --> FILTER_TOGGLE["Toggle Active / Inactive"]
    FILTER_LIST --> FILTER_ORDER["Reorder (sort_order)"]
```

## Filament Resources

| Resource | Description |
|----------|-------------|
| `EventResource` | CRUD events, toggle active |
| `FrameResource` | CRUD frames, upload asset_url, set pose_count, toggle active |
| `FilterResource` | CRUD filters, upload thumbnail_url, toggle active, reorder |
| `ScreenConfigResource` | Welcome/Tutorial editor + Preview/Publish actions |
| `SessionResource` | View-only, detail with photos + result + print jobs |
| `TransactionResource` | View payment records |
| `ResultResource` | View final results, QR tokens |
| `DeviceResource` | CRUD devices |
| `PrinterResource` | CRUD printers |
| `UserResource` | CRUD users + Filament Shield roles |

## No Email
No email management in admin panel.
