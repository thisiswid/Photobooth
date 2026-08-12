# ERD

```mermaid
erDiagram
    EVENTS ||--o{ SESSIONS : has
    EVENTS ||--o{ FRAMES : offers
    EVENTS ||--o{ FILTERS : offers
    EVENTS ||--o{ SCREEN_CONFIGS : configures
    SCREEN_CONFIGS ||--o{ TUTORIAL_STEPS : contains
    FRAMES ||--o{ SESSIONS : selected_by
    FILTERS ||--o{ SESSIONS : applied_to
    SESSIONS ||--o{ PHOTOS : contains
    SESSIONS ||--o| RESULTS : produces
    SESSIONS ||--o| PAYMENTS : has
    SESSIONS ||--o| PRINT_JOBS : creates
    EVENTS ||--o{ DEVICES : uses

    EVENTS {
        bigint id PK
        string name
        datetime starts_at
        datetime ends_at
        boolean active
    }

    FRAMES {
        bigint id PK
        bigint event_id FK
        string name
        string asset_url
        int pose_count
        boolean active
    }

    FILTERS {
        bigint id PK
        bigint event_id FK
        string name
        string thumbnail_url
        string parameters
        int sort_order
        boolean active
    }

    SCREEN_CONFIGS {
        bigint id PK
        bigint event_id FK
        string screen_type
        string status
        string title
        string description
        string background_url
        string button_text
        int version
    }

    TUTORIAL_STEPS {
        bigint id PK
        bigint screen_config_id FK
        int sort_order
        string title
        string description
        string image_url
        boolean active
    }

    SESSIONS {
        bigint id PK
        bigint event_id FK
        bigint frame_id FK
        bigint filter_id FK
        bigint device_id FK
        string status
        string selected_filter
        int retake_count
        datetime started_at
        datetime expires_at
        datetime finished_at
    }

    PAYMENTS {
        bigint id PK
        bigint session_id FK
        string xendit_payment_id
        decimal amount
        string status
        datetime paid_at
    }

    PHOTOS {
        bigint id PK
        bigint session_id FK
        string type
        string file_url
    }

    RESULTS {
        bigint id PK
        bigint session_id FK
        string final_url
        string gif_url
        string qr_token
        datetime expires_at
    }

    PRINT_JOBS {
        bigint id PK
        bigint session_id FK
        string printer
        string status
        datetime printed_at
    }

    DEVICES {
        bigint id PK
        bigint event_id FK
        string name
        string platform
        string status
    }
```

## Critical relationships

- `SESSIONS.frame_id` must be set during **Frame Selection**, before Photo Session starts.
- `SESSIONS.filter_id` is set during **Filter Selection**, after all captures are accepted.
- `FRAMES.pose_count` determines how many photos are taken per session.
- `expires_at = started_at + 5 minutes`.
- `RESULTS` stores final_url, gif_url, and qr_token — presented on the single Result Screen.
- **No email field** anywhere in the schema.
