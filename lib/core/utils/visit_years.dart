import '../../models/visit.dart';

/// Every year with at least one visit among [visits], newest first. Never
/// hardcoded — derived from the actual visited_on values — and shared by
/// any feature that offers a year filter (Passport, Rankings, ...).
List<int> availableVisitYears(Iterable<Visit> visits) {
  final years = visits.map((v) => v.visitedOn.year).toSet().toList();
  years.sort((a, b) => b.compareTo(a));
  return years;
}
