import 'restaurant.dart';

class VisitedRestaurant {
  final Restaurant restaurant;
  final double? personalRating;
  final String? notes;
  final DateTime? visitedAt;

  const VisitedRestaurant({
    required this.restaurant,
    this.personalRating,
    this.notes,
    this.visitedAt,
  });
}
