<?php

namespace App\Models;

/**
 * @deprecated Use \App\Models\Session instead.
 *
 * PhotoSession was the original model from the pre-refactor codebase.
 * All new code should reference Session, which maps to the `photo_sessions`
 * table with the correct ERD fields (no email, no package_id, no layout_id,
 * no sticker_ids).
 *
 * This class is kept temporarily so existing references don't break during
 * the migration. Remove once all callers are updated to use Session.
 */
class PhotoSession extends Session
{
    // Intentionally empty — inherits everything from Session.
    // No email, no package, no layout, no stickers.
}
