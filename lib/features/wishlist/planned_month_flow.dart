import 'package:flutter/material.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/booking_window.dart';
import '../notifications/push_prompt_sheet.dart';
import '../notifications/push_service.dart';
import 'widgets/planned_month_sheet.dart';

/// What [askPlannedMonth] ended with.
class PlannedMonthOutcome {
  /// Whether the month was set, changed or cleared.
  final bool changed;

  /// The member's plan after it, with when that month opens; null when
  /// there is no month (skipped, cleared, or the save failed).
  final WishlistPlan? plan;

  /// A short line for a snackbar, or null when nothing needs saying.
  final String? message;
  final bool isError;

  const PlannedMonthOutcome({
    this.changed = false,
    this.plan,
    this.message,
    this.isError = false,
  });
}

/// Asks "When would you like to go?" for a restaurant already on the
/// wishlist, saves the answer and reads back when that month opens. Used
/// right after a restaurant is saved and from its wishlist card. When the
/// month has a known opening still to come, this is the moment push
/// matters, so it offers notifications the way a first follow does
/// (once, never at launch — PushService).
Future<PlannedMonthOutcome> askPlannedMonth(
  BuildContext context, {
  required WishlistRepository repository,
  required String restaurantId,
  required String restaurantName,
  DateTime? initial,
}) async {
  final choice = await showPlannedMonthSheet(
    context,
    restaurantName: restaurantName,
    initial: initial,
  );
  if (choice == null) return const PlannedMonthOutcome();
  final month = switch (choice) {
    PlannedMonthSet(:final month) => month,
    PlannedMonthCleared() => null,
  };
  try {
    await repository.setPlannedMonth(restaurantId: restaurantId, month: month);
  } catch (_) {
    return const PlannedMonthOutcome(
      message: 'Could not save the month. Please try again.',
      isError: true,
    );
  }
  if (month == null) {
    return const PlannedMonthOutcome(changed: true, message: 'Month cleared');
  }
  WishlistPlan? plan;
  try {
    plan = (await repository.loadPlans())[restaurantId];
  } catch (_) {
    // The month is saved; the card reads its status on the next load.
  }
  if (plan != null &&
      plan.status == BookingStatus.upcoming &&
      plan.remindersEnabled &&
      context.mounted) {
    await PushService.instance.askAfter(
      context,
      BookingReminderPrompt(restaurantName),
    );
  }
  return PlannedMonthOutcome(
    changed: true,
    plan: plan,
    message: 'Saved for ${monthYear(month)}',
  );
}
