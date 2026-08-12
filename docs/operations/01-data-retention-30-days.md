# Data Retention

- Photo files (raw + final): 30 days
- GIF files: 30 days
- Final result: 30 days
- QR result access: valid while result is retained (30 days from session finish)
- After 30 days, scheduled cleanup deletes expired media and related result references from Cloud Storage and the RESULTS table.

## Scheduled cleanup
A background job runs daily and removes:
1. `RESULTS` records where `expires_at < now()`
2. Associated files from Cloud Storage (`final_url`, `gif_url`, individual photo URLs)
3. `PHOTOS` records linked to expired sessions
