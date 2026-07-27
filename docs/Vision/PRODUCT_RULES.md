# Michelin Passport

# Product Rules

**Version:** 1.0  
**Status:** Active  
**Owner:** Product  
**Last Updated:** 27 July 2026

---

# Purpose

This document defines the functional rules that govern Michelin Passport.

These rules ensure that every feature behaves consistently and that future development remains aligned with the product vision.

Whenever a new feature is introduced, it should follow the principles defined in this document.

---

# Product Philosophy

Michelin Passport is a personal archive.

It is not a restaurant guide.

It is not a review platform.

It is not a social network.

Every product decision should strengthen the user's personal culinary journey.

---

# Core Rule

Experiences belong to the user.

Reference data belongs to the world.

The two should never become dependent on one another.

---

# Restaurants

A restaurant exists independently of the user.

Restaurants contain only objective information.

Examples:

- Name
- Address
- Coordinates
- Cuisine
- Michelin information
- Official website

Restaurants never contain:

- Personal ratings
- Notes
- Visit history
- Favourite status

---

# Hotels

Hotels follow exactly the same principles as restaurants.

Hotels describe destinations.

Visits describe experiences.

---

# Visits

A visit represents one real experience.

Every visit is independent.

Users may create:

- multiple visits
- visits on consecutive days
- multiple visits in the same year

Visits are never merged automatically.

---

# Visit Date

A visit should represent the actual dining or stay date.

If the exact date is unknown, users may enter an approximate date.

The application should make it clear that the date is estimated.

---

# Personal Ratings

Ratings belong to visits.

Never to restaurants.

A restaurant can have many different personal ratings over time.

The application should preserve every rating.

---

# Notes

Notes belong to individual visits.

Users should be able to look back and understand exactly what happened during that experience.

Notes should never overwrite previous memories.

---

# Photos

Photos belong to visits.

Never directly to restaurants or hotels.

The same restaurant can therefore contain completely different memories from different visits.

---

# Wishlists

A wishlist represents future intentions.

Wishlist items never become visits automatically.

A user explicitly decides when a wishlist item becomes a visit.

---

# Favourites

Favourite status represents the user's opinion.

It should never depend on Michelin awards or rankings.

Users define their own favourites.

---

# Historical Awards

Awards are historical records.

If Michelin changes an award:

Create a new award record.

Never overwrite previous history.

The application should always be capable of displaying awards exactly as they existed during any given year.

---

# Rankings

Rankings follow the same principle.

Historical rankings remain visible.

The current ranking is simply the latest record.

---

# Closed Restaurants

Closed restaurants remain visible.

Users should never lose memories because a restaurant closed.

Closed restaurants should be clearly identified but remain fully accessible.

---

# Relocated Restaurants

If a restaurant moves but remains the same establishment, it should retain its identity.

Address information may change.

Historical visits remain linked.

---

# Renamed Restaurants

A restaurant may change its name.

Historical visits remain connected to the same restaurant identity.

Historical names may be preserved where appropriate.

---

# Deleted Visits

Deleting a visit is a user action.

Deleting a visit never deletes:

- restaurant data
- hotel data
- awards
- rankings

---

# Privacy

Every visit belongs exclusively to its owner.

Sharing should always be explicit.

Nothing is public by default.

---

# Statistics

Statistics should celebrate experiences.

They should never encourage competition.

Metrics should focus on:

- places visited
- countries explored
- Michelin stars experienced
- years of memories

Avoid creating pressure through rankings or streaks.

---

# Social Features

Social features exist to inspire.

Never to compare.

The application should encourage discovery rather than competition.

---

# Notifications

Notifications should provide value.

Avoid unnecessary reminders.

Every notification should answer one question:

"Will the user appreciate receiving this?"

If not, do not send it.

---

# Offline Behaviour

Previously loaded memories should remain accessible whenever possible.

Users should always feel that their archive belongs to them.

---

# AI Features

Artificial intelligence should assist.

It should never replace the user's own memories.

AI may:

- suggest
- organise
- summarise

AI should never invent or alter personal experiences.

---

# Future Features

New features should strengthen one or more of these pillars:

- Preserve memories
- Encourage exploration
- Improve organisation
- Enhance reflection

If a feature does none of these, it probably does not belong in Michelin Passport.

---

# Product Decision Framework

Before introducing any feature, ask:

Does it preserve memories?

Does it respect the user's ownership?

Does it reduce complexity?

Does it support long-term use?

Would we still build this feature in ten years?

If any answer is "No", reconsider the feature.

---

# Michelin Passport Standard

Every product decision should make the application feel more personal, more timeless and more meaningful.

Never busier.

Never louder.

Never more complicated.

---

# North Star

> Michelin Passport is not collecting restaurants.

> It is preserving a lifetime of extraordinary experiences.
