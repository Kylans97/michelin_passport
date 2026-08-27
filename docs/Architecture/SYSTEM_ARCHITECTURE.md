# Mantelier Architecture

## Purpose

This document describes the overall software architecture of Mantelier.

The goal is to keep the project scalable, maintainable and easy to extend as new functionality is introduced.

---

# Architecture Principles

The project follows the following principles:

- Clean architecture
- Separation of concerns
- Reusable components
- Repository pattern
- Feature-first structure
- Scalable database design

---

# Technology Stack

Frontend
- Flutter
- Dart

Backend
- Supabase
- PostgreSQL
- Supabase Storage
- Supabase Authentication

Development
- Git
- GitHub
- VS Code

---

# Application Layers

lib/

core/
Shared utilities and reusable components.

models/
Data models.

repositories/
Communication with Supabase.

features/

Each feature contains its own:

- screens
- widgets
- services
- providers (future)

assets/

Images and icons.

---

# Database

The database is managed through SQL migrations stored inside:

supabase/migrations

Data imports are stored inside:

supabase/imports

---

# Future Architecture

Planned additions include:

- Offline support
- Caching
- Image optimisation
- Notifications
- AI recommendations
- Friend system
- Travel planning
- Statistics engine

---

# Guiding Principle

Every architectural decision should improve one or more of the following:

- User experience
- Performance
- Scalability
- Maintainability
