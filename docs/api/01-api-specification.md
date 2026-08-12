# API Specification

## Customer

### Screen Content
- `GET /api/events/{event}/screen-content` — fetch active Welcome and Tutorial screen content

### Frames
- `GET /api/events/{event}/frames` — list active frames for an event (includes pose_count per frame)

### Filters
- `GET /api/events/{event}/filters` — list active filters for an event (used on Filter Selection screen)

### Payments
- `POST /api/payments` — create a new Xendit QRIS payment
- `GET /api/payments/{payment}/status` — poll payment status

### Sessions
- `POST /api/sessions` — create a new session (after payment PAID)
- `POST /api/sessions/{session}/frame` — set selected frame (mandatory before photo session)
- `POST /api/sessions/{session}/photos` — upload captured photos with selected filter
- `POST /api/sessions/{session}/finish` — finish session

  **Request body:** (no email field)
  ```json
  {}
  ```

  **Response:**
  ```json
  {
    "status": "finished"
  }
  ```

### Results
- `GET /api/results/{token}` — access Result Screen data: final_url, gif_url, individual photo URLs

## Xendit
- `POST /api/webhooks/xendit/payment` — Xendit payment webhook (authoritative payment confirmation)

The webhook is the **only** authoritative source for marking a payment as PAID.

## Admin

### Events & Frames
- `GET /api/admin/events`
- `POST /api/admin/events`
- `PUT /api/admin/events/{event}`
- `DELETE /api/admin/events/{event}`
- `GET /api/admin/frames`
- `POST /api/admin/frames`
- `PUT /api/admin/frames/{frame}`
- `DELETE /api/admin/frames/{frame}`

### Filters
- `GET /api/admin/filters`
- `POST /api/admin/filters`
- `PUT /api/admin/filters/{filter}`
- `DELETE /api/admin/filters/{filter}`
- `PATCH /api/admin/filters/{filter}/toggle`
- `POST /api/admin/filters/reorder`

### Screen Content Management
- `GET /api/admin/screens`
- `POST /api/admin/screens`
- `PUT /api/admin/screens/{screen}`
- `POST /api/admin/screens/{screen}/preview`
- `POST /api/admin/screens/{screen}/publish`

### Transactions & Sessions
- `GET /api/admin/transactions`
- `GET /api/admin/sessions`
- `GET /api/admin/sessions/{session}`

### Results
- `GET /api/admin/results`

### Devices & Printers
- `GET /api/admin/devices`
- `POST /api/admin/devices`
- `PUT /api/admin/devices/{device}`
- `GET /api/admin/printers`
- `PUT /api/admin/printers/{printer}`

### Reports
- `GET /api/admin/reports`

### Users & Roles
- `GET /api/admin/users`
- `POST /api/admin/users`
- `PUT /api/admin/users/{user}`
- `DELETE /api/admin/users/{user}`

## Result Screen contract

`GET /api/results/{token}` returns:
```json
{
  "final_url": "https://storage.../final.jpg",
  "gif_url": "https://storage.../animation.gif",
  "photos": [
    { "url": "https://storage.../photo_1.jpg" },
    { "url": "https://storage.../photo_2.jpg" }
  ],
  "expires_at": "2026-09-09T10:00:00Z"
}
```

## No Email
There is **no email endpoint** anywhere in this API. No `POST /api/sessions/{session}/send-email`, no email field in any request body.
