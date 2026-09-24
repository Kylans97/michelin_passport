import 'passport_stamp_item.dart';

/// What a stamp shows instead of/alongside its date — Michelin stars for a
/// restaurant, Keys for a hotel, or the event type for an event. Exactly
/// one of the three ever applies to a given [PassportStampItem]; null
/// means "draw no award row at all" (a restaurant/hotel visit with no
/// stars/Keys at that visit — see [PassportStampItem] subclasses' own
/// `stars`/`keys` doc comments for why 0 and null are treated the same
/// way here).
sealed class StampAward {
  const StampAward();
}

class StarsAward extends StampAward {
  final int count;
  const StarsAward(this.count);
}

class KeysAward extends StampAward {
  final int count;
  const KeysAward(this.count);
}

class EventTypeAward extends StampAward {
  final String label;
  const EventTypeAward(this.label);
}

/// The award to paint on [item]'s stamp — see [StampAward]'s own doc
/// comment for the null case.
StampAward? stampAwardFor(PassportStampItem item) => switch (item) {
  RestaurantStampItem(:final stars) =>
    (stars != null && stars > 0) ? StarsAward(stars) : null,
  HotelStampItem(:final keys) =>
    (keys != null && keys > 0) ? KeysAward(keys) : null,
  EventStampItem(:final eventTypeLabel) => EventTypeAward(eventTypeLabel),
};
