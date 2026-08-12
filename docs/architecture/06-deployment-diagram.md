# Deployment Diagram

```mermaid
flowchart TB
    Tablet["Lenovo Legion Y700\nAndroid + Flutter (Landscape)"]
    DSLR["DSLR Camera"]
    Epson["Epson L8050"]

    subgraph CloudEnv["Cloud Environment"]
        LaravelApp["Laravel Application\n(REST API + Filament Admin Panel)"]
        DB[("PostgreSQL")]
        Storage[("Object / Cloud Storage")]
    end

    AdminBrowser["Admin (Browser)"]
    X["Xendit"]

    Tablet --> DSLR
    Tablet --> Epson
    Tablet -->|"/api/*"| LaravelApp
    AdminBrowser -->|"/admin/*"| LaravelApp
    LaravelApp --> DB
    LaravelApp --> Storage
    LaravelApp --> X
    X -->|Webhook| LaravelApp
```

## Notes
- Single Laravel deployment serves both `/api/*` and `/admin/*`
- No email service in deployment
- Flutter runs in **landscape** orientation on Lenovo Legion Y700
- Epson L8050 triggered automatically when Final Result Screen is shown
