# Camera Hardware

Target camera integration is a DSLR connected to the Lenovo Legion Y700.

Application abstraction:

```text
CameraService
├── connect()
├── checkStatus()
├── startPreview()
├── capture()
└── disconnect()
```

## Usage in flow
- `connect()` + `checkStatus()` — on app startup
- `startPreview()` — when entering Photo Session screen
- `capture()` — triggered after 5-second countdown
- `disconnect()` — on session finish or timeout

The exact USB/SDK/bridge mechanism should be validated against the selected DSLR model before implementation.
