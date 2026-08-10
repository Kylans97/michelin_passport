import 'package:flutter/material.dart';
import '../../../core/widgets/app_button.dart';

/// The "Add Stay" action for Hotel Detail. Unlike RestaurantActions' visited
/// toggle, this is never a two-state toggle — a hotel can be stayed at many
/// times, so every tap opens Add Stay for a brand new historical row, never
/// "mark/unmark stayed".
class HotelActions extends StatelessWidget {
  final VoidCallback onTapAddStay;

  const HotelActions({super.key, required this.onTapAddStay});

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      icon: Icons.add_circle_outline_rounded,
      label: 'Add Stay',
      onTap: onTapAddStay,
    );
  }
}
