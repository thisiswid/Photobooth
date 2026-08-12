# Screen Management Use Cases

```mermaid
flowchart LR
    A((Admin))
    W((Welcome Screen))
    T((Tutorial Screen))
    D((Draft))
    P((Preview))
    PUB((Publish))
    ACT((Active))

    A --> W
    A --> T
    W --> D
    T --> D
    D --> P
    P --> PUB
    PUB --> ACT
```

## Lifecycle
`Draft → Preview → Publish → Active`

- **Draft**: Admin edits content, not visible to customers.
- **Preview**: Admin can preview how it looks on the Flutter app before publishing.
- **Publish**: Content is pushed to Active.
- **Active**: Flutter app fetches and displays this version.
