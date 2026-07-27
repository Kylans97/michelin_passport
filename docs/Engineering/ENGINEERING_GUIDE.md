# Michelin Passport

## Engineering Guide

**Version:** 1.0  
**Status:** Active  
**Owner:** Engineering  
**Last Updated:** 27 July 2026

---

# Purpose

This document defines the engineering standards for Michelin Passport.

Its purpose is to ensure that the application remains clean, scalable, maintainable and consistent as it grows.

Every contributor should follow these principles before writing new code.

---

# Engineering Philosophy

Good software is not measured by how quickly it is built.

It is measured by how easily it can evolve.

Michelin Passport should remain understandable years after its first release.

Code should be written for the next developer, even if that developer is yourself.

---

# Engineering Principles

## Simplicity First

Always prefer the simplest solution that satisfies the requirements.

Avoid unnecessary abstractions.

Avoid premature optimisation.

Readable code is more valuable than clever code.

---

## Single Responsibility

Every class should have one clear responsibility.

Examples:

- Widgets render UI.
- Repositories access data.
- Services contain reusable business logic.
- Models represent data.
- Screens compose widgets.

---

## Separation of Concerns

Business logic should never live inside UI widgets.

Widgets display information.

Repositories retrieve information.

Services process information.

Each layer has a single responsibility.

---

## Build For Growth

Every feature should support future expansion.

Today's implementation should not limit tomorrow's possibilities.

Always think one version ahead.

---

## Consistency Over Preference

Consistency is more important than personal coding style.

If multiple valid solutions exist, choose the one already used within the project.

---

# Project Structure

The application follows a feature-first architecture.

```

lib/

assets/

core/
theme/
constants/
extensions/
utils/

features/

restaurants/
hotels/
visits/
profile/
explore/
wishlist/
friends/
dashboard/
globe/

repositories/

services/

models/

widgets/

```

Features should remain independent whenever possible.

---

# Models

Models represent data only.

Models should:

- be immutable
- contain no UI logic
- contain no database queries
- contain serialization methods

Models should never directly communicate with Supabase.

---

# Repositories

Repositories are responsible for all database communication.

Repositories:

- fetch data
- insert data
- update data
- delete data

Only repositories communicate with Supabase.

Screens, widgets and models should never execute database queries directly.

---

# Services

Services contain reusable application logic.

Examples:

- Image upload
- Authentication
- Location services
- Statistics calculations
- Award calculations

Services should not know anything about the user interface.

---

# Widgets

Widgets display data.

Widgets should remain as small as possible.

If a widget exceeds approximately 250 lines, consider splitting it into smaller components.

Widgets should never:

- contain SQL
- call Supabase directly
- perform complex calculations

---

# Screens

Screens compose widgets.

A screen should describe *what* is shown.

Individual widgets determine *how* it is shown.

---

# State Management

State should be predictable.

Business state should remain outside widgets.

Temporary UI state belongs inside widgets.

Persistent application state belongs inside dedicated state management.

---

# Naming Conventions

Files

restaurant_card.dart

restaurant_repository.dart

visit_statistics_service.dart

Classes

RestaurantCard

RestaurantRepository

VisitStatisticsService

Variables

restaurant

restaurantVisit

currentUser

Functions

loadRestaurants()

createVisit()

uploadPhoto()

Booleans

isVisited

hasPhotos

canEdit

shouldDisplay

---

# Error Handling

Errors should always be handled gracefully.

Users should receive helpful feedback.

Unexpected failures should never crash the application.

Log technical details.

Show user-friendly messages.

---

# Logging

Use structured logging.

Avoid random print statements.

Logging should help diagnose problems without exposing sensitive information.

---

# Asynchronous Code

Prefer async/await.

Avoid deeply nested Future chains.

Handle exceptions explicitly.

Never ignore failed Futures.

---

# Performance

Optimise only after measuring.

Premature optimisation creates unnecessary complexity.

Readable code is the default.

---

# Images

Images should never be stored inside the database.

Only store references.

Images belong in Supabase Storage.

Database tables store:

- storage path
- metadata
- ownership

---

# Networking

Every external request should have:

- timeout
- error handling
- retry strategy where appropriate

Network failures should degrade gracefully.

---

# Database Access

All database communication flows through repositories.

Correct:

Screen

↓

Repository

↓

Supabase

Incorrect:

Screen

↓

Supabase

---

# Testing Philosophy

The most important logic should be testable.

Repositories should be independently testable.

Business logic should not depend on UI.

---

# AI Generated Code

AI should accelerate development.

AI should never replace engineering judgement.

Every AI-generated contribution must be:

- understood
- reviewed
- tested
- consistent with the architecture

Never merge code that is not fully understood.

---

# Code Reviews

Before merging new functionality ask:

Does this follow the Product Vision?

Does this respect the Data Architecture?

Does this introduce unnecessary complexity?

Can this be understood in six months?

Does it make the application better?

---

# Git Workflow

Every meaningful change should be committed.

Commit messages should explain intent.

Examples:

feat: add hotel visit model

fix: resolve duplicate visit creation

refactor: simplify restaurant repository

docs: update engineering guide

Avoid generic messages such as:

update

changes

fixes

---

# Documentation

Complex decisions should always be documented.

Future developers should understand *why* a solution exists.

Comments explain intent.

Code explains implementation.

---

# Definition of Done

A feature is complete when:

✓ Product Vision respected

✓ Data Architecture respected

✓ Engineering Guide respected

✓ UI Guidelines respected

✓ No duplicated code introduced

✓ Documentation updated

✓ Tested

✓ Ready for future expansion

---

# Engineering Standard

Before writing code ask:

Can this be simpler?

Can this be reused?

Can this be understood?

Will this still make sense in five years?

If the answer is "No", rethink the implementation.

---

# North Star

> Michelin Passport is engineered for longevity.

> Every line of code should make the next version easier to build.
