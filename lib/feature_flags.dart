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

/// Stepping-stone PARKING at the third miss (archive the hard habit, build
/// a smaller one) — disabled. The product rule for a habit that keeps being
/// missed is one loop: ask why -> propose a change the user approves ->
/// after three approved changes that still fail the habit is deactivated
/// (kept, history intact) until the user restarts it. Parking competed with
/// that loop at the same third miss and skipped its three-chance limit.
/// Habits parked earlier still get the "it is back" offer; only NEW parking
/// is off. Flip to true to bring parking back.
const bool kSteppingStoneParkingEnabled = false;
