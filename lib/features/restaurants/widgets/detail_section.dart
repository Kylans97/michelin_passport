// `DetailCard`/`SectionLabel` moved to `core/widgets/detail_card.dart` as
// genuine shared design-system components — they were already being
// imported from this restaurant-namespaced file by the hotels feature
// (hotel_info_card.dart, hotel_restaurants_card.dart, hotel_stays_card.dart)
// and photos feature, which was itself a sign they belonged in core, not
// under restaurants/. Re-exported here so none of those existing imports
// need to change.
export '../../../core/widgets/detail_card.dart';
