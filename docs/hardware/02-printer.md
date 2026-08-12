# Printer Hardware

Target printer: **Epson L8050**.

Application abstraction:

```text
PrinterService
├── connect()
├── checkStatus()
├── print(imageData)
└── getPrintStatus()
```

## Usage in flow
- `connect()` + `checkStatus()` — on app startup
- `print(imageData)` — triggered automatically when Result Screen is shown
- The Print button on the Result Screen calls `print()` again for reprints
- `getPrintStatus()` — polls print job status for feedback to customer

The exact Android connectivity/driver method should be validated on the Lenovo Legion Y700 before implementation.
