/// Events V2 Discovery Taxonomy Phase A/B — one row from `public.
/// event_tags`, the curated theme taxonomy (Wine, Winemaker, Wild/Game,
/// Guest Chef, Four Hands, Charity in V1). [slug] is the stable machine
/// identifier every query/filter keys on — never [name] (the display
/// label), which may be relabeled later without touching any assignment
/// or filter state (see the Phase A pre-apply doc's own tag-governance
/// section for why `slug` exists as a separate column from `name`).
class EventTag {
  final String id;
  final String slug;
  final String name;

  const EventTag({required this.id, required this.slug, required this.name});

  factory EventTag.fromJson(Map<String, dynamic> json) => EventTag(
    id: json['id'].toString(),
    slug: json['slug'] as String,
    name: json['name'] as String,
  );

  @override
  bool operator ==(Object other) => other is EventTag && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
