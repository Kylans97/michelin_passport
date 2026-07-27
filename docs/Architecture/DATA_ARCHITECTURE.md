# Michelin Passport

## Data Architecture

**Version:** 1.0  
**Status:** Active  
**Owner:** Engineering  
**Last Updated:** 27 July 2026

---

# Purpose

This document defines the core data architecture of Michelin Passport.

Its purpose is to ensure that every database change, new feature and software component follows the same architectural principles.

The architecture is designed to support decades of personal culinary memories while remaining scalable, maintainable and extensible.

This document is the technical foundation upon which the application is built.

---

# Architecture Philosophy

Michelin Passport is built around one simple idea:

> Experiences matter more than places.

Restaurants and hotels are destinations.

Visits are memories.

Everything within the architecture exists to preserve those memories without losing historical information.

---

# Core Principles

## Personal and Reference Data Are Always Separated

Reference data describes the world.

Personal data describes the user's experiences.

These should never be mixed.

Examples of reference data:

- Restaurant
- Hotel
- Michelin Awards
- Rankings
- Locations

Examples of personal data:

- Visits
- Ratings
- Notes
- Photos
- Wishlist
- Friends

---

## Every Experience Is Represented By A Visit

Visits are the most important entity in Michelin Passport.

Restaurants and hotels exist independently.

Users interact with them by creating visits.

A visit captures:

- date
- ratings
- notes
- photographs
- memories

Multiple visits to the same location are always supported.

---

## History Is Never Overwritten

Michelin Passport preserves history.

Stars change.

Hotels receive or lose Keys.

Rankings evolve.

None of these events should overwrite historical information.

Historical data should always be stored as new records.

---

## UUIDs Are Immutable

Every entity receives a UUID.

Once created, a UUID is never changed.

UUIDs remain stable across imports, migrations and future releases.

---

## Objective Data Comes First

Restaurants and hotels should only contain objective information.

Examples include:

- location
- coordinates
- contact details
- official websites
- Michelin URLs

Personal information belongs exclusively to visits.

---

## Every Entity Has One Responsibility

Each table exists for a single purpose.

Avoid storing unrelated information inside the same entity.

---

# Domain Model

```
Profile
│
├── RestaurantVisit
│        │
│        ├── VisitPhoto
│        └── Restaurant
│                │
│                ├── RestaurantAward
│                └── RestaurantRanking
│
├── HotelVisit
│        │
│        ├── VisitPhoto
│        └── Hotel
│                │
│                └── HotelAward
│
├── WishlistItem
└── Friendship
```

---

# Entity Definitions

## Profile

Represents a Michelin Passport user.

Contains user-specific information only.

Does not contain visit information directly.

---

## Restaurant

Stores objective information about a restaurant.

Responsibilities:

- location
- coordinates
- address
- Michelin URL
- Google Place ID
- official website

Never stores:

- ratings
- notes
- photographs
- visit history

---

## RestaurantVisit

Represents one personal dining experience.

Stores:

- visit date
- ratings
- notes
- companions
- dining type
- personal memories

Every restaurant may have unlimited visits.

---

## RestaurantAward

Stores Michelin award history.

Examples:

- Michelin Stars
- Green Star
- Bib Gourmand
- Michelin Selected

Each year creates a new record.

Historical records are never modified.

---

## RestaurantRanking

Stores rankings such as:

- World's 50 Best
- Asia's 50 Best
- La Liste
- Opinionated About Dining

Rankings remain historically available.

---

## Hotel

Stores objective hotel information.

Contains:

- location
- coordinates
- contact details
- Michelin Guide information

Does not contain personal experiences.

---

## HotelVisit

Represents one hotel stay.

Stores:

- check-in
- check-out
- ratings
- notes
- photographs

Multiple stays are supported.

---

## HotelAward

Stores Michelin Key history.

Supports:

- One Key
- Two Keys
- Three Keys

Historical records are never removed.

---

## VisitPhoto

Photographs belong to visits.

Not restaurants.

Not hotels.

This preserves the context of every photograph.

---

## WishlistItem

Represents future travel plans.

Supports both restaurants and hotels.

Does not represent completed visits.

---

## Friendship

Stores relationships between Michelin Passport users.

Designed to support future social features.

---

# Relationships

Profile

↓

RestaurantVisit

↓

Restaurant

↓

RestaurantAward

↓

RestaurantRanking

RestaurantVisit

↓

VisitPhoto

Profile

↓

HotelVisit

↓

Hotel

↓

HotelAward

HotelVisit

↓

VisitPhoto

Profile

↓

WishlistItem

Profile

↓

Friendship

---

# Data Lifecycle

Reference data evolves.

Personal data accumulates.

Reference data:

Restaurant

↓

Award changes

↓

New Award record

↓

Restaurant remains unchanged

Personal data:

RestaurantVisit

↓

User adds notes

↓

User adds photos

↓

User creates another visit

↓

Nothing is overwritten

---

# Historical Data

Michelin Passport treats historical information as permanent.

Example:

Restaurant

2024 → ★★

2025 → ★★★

2026 → ★★★

Three historical records remain available.

No previous record is ever replaced.

The same applies to:

- Michelin Keys
- World's 50 Best
- Green Stars
- Bib Gourmand

---

# Naming Conventions

Primary Keys

id

Foreign Keys

restaurant_id

hotel_id

profile_id

visit_id

award_id

ranking_id

Timestamps

created_at

updated_at

deleted_at

Coordinates

latitude

longitude

External identifiers

google_place_id

michelin_url

official_website

---

# Future Expansion

The architecture is intentionally designed to support future additions without major redesign.

Examples include:

- Chef profiles
- Signature dishes
- Wine programmes
- Michelin Keys
- Bib Gourmand
- Michelin Selected
- OAD
- La Liste
- Travel itineraries
- AI recommendations
- Shared trips
- Timeline
- Globe visualisation
- Collections
- Achievement badges

Future features should extend the architecture rather than replace it.

---

# Data Quality Principles

Every piece of data should satisfy the following requirements.

Accuracy

Information must be verifiable.

Consistency

Formatting should remain identical throughout the database.

Completeness

Unknown values remain empty rather than guessed.

Traceability

External sources should be identifiable wherever possible.

Integrity

Relationships between entities must remain valid.

Longevity

The architecture should remain maintainable for many years.

---

# Engineering Rule

Every database modification should answer the following questions:

Does this preserve historical information?

Does this separate reference data from personal data?

Does this introduce unnecessary duplication?

Will this still make sense ten years from now?

If the answer to any of these questions is "No", the design should be reconsidered.

---

# North Star

> Michelin Passport is not designed to remember restaurants.

> It is designed to preserve experiences.
