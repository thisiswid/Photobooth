# Business Rules

1. Payment must be verified as `PAID` before Start Session.
2. Payment verification is automatic via Xendit webhook — customer does NOT press any button.
3. Start Session begins the 5-minute timer.
4. Timer is NOT active during Welcome, Tutorial, or Payment screens.
5. Frame selection is mandatory before entering Photo Session.
6. Countdown before each capture is 5 seconds.
7. Maximum retake is 2 per pose/photo.
8. If frame requires multiple poses, each pose goes through the same Countdown → Capture → Preview → Retake/Next cycle.
9. After all poses are complete, customer selects a filter before proceeding to Final Result.
10. Print is triggered automatically when Final Result Screen is shown (Epson L8050).
11. Print status must be recorded: PRINTING → PRINT SUCCESS or PRINT FAILED.
12. If print fails, system informs operator without ending the session accidentally.
13. Final Result Screen contains: photo preview, QR download, and Selesai button only.
14. QR result contains GIF, final result, and individual photos.
15. **No email** — there is no email input, email button, email API, or email service anywhere in the system.
16. Customer presses Selesai to finish session and return to Welcome Screen.
17. Results are retained for 30 days.
18. Xendit webhook is the authoritative payment confirmation.
