/// Single source of truth for "soft" feature toggles — code stays in
/// the tree (no deleted screens, models, sync codecs) but UI entry
/// points are gated so we can re-enable a feature with a one-line
/// flip and a `flutter build`.
///
/// Routine — disabled at launch. The Up Next section, the Routine
/// bottom-nav tab, and the tutorial steps for Routine are all hidden
/// when [kRoutineEnabled] is false. The routine_repository, sync
/// codec, badge counting that touches routines, and routine Hive box
/// all keep working in the background so we don't lose anyone's data.
/// Flip to true to bring the feature back without grepping the
/// codebase.
const bool kRoutineEnabled = false;

/// Streak Freeze — disabled at launch. Streak counts + flames + all
/// streak-related stats stay fully intact; only the *freeze* layer
/// on top is hidden (the FreezeBadge in headers, the freeze modal,
/// the "prompt to spend a freeze on a missed day" nudge, the
/// freeze-earned banners on ranking milestones). FreezeService,
/// UserProfile.freezesAvailable, Habit.frozenDates, and the sync
/// codec that carries those still exist so a user's freeze state
/// isn't destroyed by shipping this. Flip [kStreakFreezeEnabled]
/// to true to bring the feature back with no other code changes.
const bool kStreakFreezeEnabled = false;
