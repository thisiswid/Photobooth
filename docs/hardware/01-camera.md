# Camera Hardware

Target camera integration: **Sony ZV-E10** connected to **Lenovo Legion Y700** (Android Tablet).

## Connectivity Methods
1. **USB Video Capture Card (Recommended)**:
   - Sony ZV-E10 Micro-HDMI $\rightarrow$ USB Video Capture Card (Cam Link) $\rightarrow$ Lenovo Legion Y700 Type-C port.
   - Zero latency, Clean HDMI out 1080p/60fps, plug & play via UVC standard external camera.
2. **USB-C Direct (USB Streaming Mode)**:
   - USB-C to USB-C cable from Sony ZV-E10 to tablet.
   - Camera Menu: `Shooting/Network` $\rightarrow$ `USB Streaming` activated.

## Camera Configuration on Sony ZV-E10
- **Auto Power OFF Temp**: High (prevents thermal shutdown on kiosk 24/7).
- **Focus Mode**: AF-C (Continuous Auto Focus) with Face/Eye Priority ON.
- **HDMI Info. Display**: OFF (Clean HDMI feed without OSD icons).
- **Power**: AC dummy battery (NP-FW50) or USB PD power hub.

Application abstraction:

```text
CameraService
├── getBestCamera()   — prioritizes external Sony ZV-E10 over front/back tablet camera
├── createController() — initializes high-resolution controller
```
