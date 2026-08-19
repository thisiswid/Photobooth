# Printer Hardware

Target printer: **Epson L8050** (Photo Printer 6-Color).

## Connectivity Methods
1. **Wi-Fi / Network Print (Recommended)**:
   - Lenovo Legion Y700 and Epson L8050 connected to the same local Wi-Fi router or Wi-Fi Direct.
   - Requires **Epson Print Enabler** or **Mopria Print Service** active in Android Settings $\rightarrow$ Connected Devices $\rightarrow$ Printing.
2. **USB OTG**:
   - USB-B cable to USB-C OTG hub connected to tablet.

## Paper & Output Format
- **Format**: Standard 4R (4 x 6 inch / 100mm x 148mm) or 2x 2x6 inch Photo Strips.
- **Media**: Glossy / Silky Photo Paper with Borderless printing.

Application abstraction:

```text
PrinterService
├── getAvailablePrinters() — lists all discovered network/system printers
├── findEpsonPrinter()     — auto-locates Epson L8050 printer
└── printPhotoBytes(...)   — formats 4R document and sends print job directly
```
