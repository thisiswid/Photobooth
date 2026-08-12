# Database Schema

## SESSIONS
Required fields:
- `started_at`
- `expires_at`
- `finished_at`
- `retake_count`
- `frame_id`
- `filter_id`
- `selected_filter`
- `status`

Timer:
`expires_at = started_at + 5 minutes`

Order:
`PAYMENT_PAID → START_SESSION → FRAME_SELECTION → PHOTO_SESSION → FILTER_SELECTION → PROCESSING → RESULT_SCREEN`

### Status values
| Value | Description |
|-------|-------------|
| `pending` | Session created, payment not yet confirmed |
| `active` | Payment PAID, session in progress |
| `processing` | Generating final result + GIF |
| `result_ready` | Result Screen displayed |
| `finished` | Selesai pressed, session closed |
| `timeout` | 5-minute timer expired |

## No email field
There is **no `email` field** in the SESSIONS table or any other table. Email is not part of this system.

## FILTERS
| Field | Description |
|-------|-------------|
| `name` | Display name shown to customer |
| `thumbnail_url` | Preview image shown on Filter Selection screen |
| `parameters` | Filter processing parameters |
| `sort_order` | Display order on Filter Selection screen |
| `active` | Only active filters are returned by customer API |

## SCREEN_CONFIGS
Stores Welcome/Tutorial versions and publication status.
`status` values: `draft`, `preview`, `published`, `active`

## TUTORIAL_STEPS
Stores ordered Tutorial steps (sort_order ascending).
5 steps: Bayar, Pilih Frame, Ambil Foto, Lihat Hasil, Download & Cetak.

## RESULTS
- `final_url`: composed photobooth strip with selected filter applied
- `gif_url`: animated GIF of all captures
- `qr_token`: token used in `GET /api/results/{token}` to access downloads
- `expires_at`: 30 days from session finish

## PHOTOS
- `type` values: `raw` (original DSLR capture), `final` (filter-applied)

## Retention
Photos, GIFs, and final results are retained for 30 days.
