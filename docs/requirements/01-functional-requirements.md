# Functional Requirements

## Customer

- FR-01 Display Welcome Screen with live camera preview as background (landscape orientation).
- FR-02 Display branding "Fakultas Kopi Photobooth" on Welcome Screen.
- FR-03 Navigate to Tutorial Screen when customer presses MULAI.
- FR-04 Display Tutorial Screen with 5 steps: Bayar, Pilih Frame, Ambil Foto, Lihat Hasil, Download & Cetak.
- FR-05 Navigate to Payment Screen when customer presses LANJUT.
- FR-06 Display Xendit QRIS payment with QR code, nominal, and supported payment methods.
- FR-07 Receive verified payment status automatically via Xendit webhook (no manual button).
- FR-08 Start session automatically after payment is `PAID`.
- FR-09 Start a 5-minute session timer at Start Session (not at Welcome/Tutorial/Payment).
- FR-10 Display session timer in top-right corner starting from 05:00.
- FR-11 Require frame selection before photo capture.
- FR-12 Display selected frame with visual indicator (border/check/highlight).
- FR-13 Enter Photo Session after frame selection.
- FR-14 Display live camera preview in Photo Session.
- FR-15 Provide Mirror / No Mirror toggle in Photo Session.
- FR-16 Show 5-second countdown before each capture.
- FR-17 Capture photos from DSLR.
- FR-18 Display Photo Result screen after each capture with RETAKE and NEXT buttons.
- FR-19 Allow maximum 2 retakes per pose. Disable RETAKE button when limit reached.
- FR-20 Support multiple poses per frame based on frame configuration.
- FR-21 Select filter to apply to the final result after all poses are complete.
- FR-22 Generate final photobooth result with selected filter applied.
- FR-23 Display Final Result Screen with: photo preview, QR download, and Selesai button.
- FR-24 Automatically trigger print to Epson L8050 when Final Result Screen is shown.
- FR-25 Record print status: PRINTING → PRINT SUCCESS or PRINT FAILED.
- FR-26 Generate QR result linking to GIF, final result, and individual photos.
- FR-27 Finish session when customer presses Selesai.
- FR-28 Return to Welcome Screen after session finishes.
- FR-29 Handle session timeout (00:00) by auto-closing session and returning to Welcome.

## Admin

- FR-30 Manage events.
- FR-31 Manage frames (including number of poses per frame).
- FR-32 Manage filters (create, edit, delete, toggle active/inactive).
- FR-33 Edit Welcome Screen content.
- FR-34 Edit Tutorial Screen content.
- FR-35 Preview and publish screen content (Draft → Preview → Publish → Active).
- FR-36 Manage transactions.
- FR-37 Manage sessions and results.
- FR-38 Manage devices and printers.
- FR-39 View reports.
- FR-40 Manage users and roles.

## Canonical ordering

`Payment PAID → Start Session → Select Frame → Photo Session (Mirror/No Mirror) → 5-second Countdown → Capture → Photo Result (Retake/Next) → [repeat per pose] → Filter Selection → Final Result (Auto Print + QR) → Selesai → Finish → Welcome`

## No Email

**There is no email feature in this system.** No email input, no email button, no email API endpoint, no email service, no email database field anywhere in the customer flow or backend.
