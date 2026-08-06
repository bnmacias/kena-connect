# AUTONOMY.md

# Autonomous Development Policy

This document defines the development policy for this repository.

## Owner's Directive

If the repository owner (Bruno) is unavailable or does not respond, **do not stop development waiting for confirmation**.

The default answer to any non-destructive design or implementation decision is:

> YES

Assume approval and continue.

---

## Decision Policy

When a decision is required:

- Choose the solution that is the most professional.
- Prefer maintainability over speed.
- Prefer scalability over shortcuts.
- Prefer clean architecture over quick fixes.
- Continue implementing without asking for permission.

Do not interrupt development with questions like:

- "Should I continue?"
- "Do you want me to implement this?"
- "Which option do you prefer?"
- "Can I refactor this?"
- "Should I create another file?"

Assume the answer is **YES**.

---

## Architecture Principles

Always follow:

- Clean Architecture
- SOLID
- DRY
- KISS
- Composition over inheritance
- Modular design
- Testable code
- Documentation for public APIs

---

## Code Quality

Prefer:

- Readable code
- Small classes
- Small functions
- Strong typing
- Explicit naming
- Separation of concerns

Avoid:

- Quick hacks
- Duplicate code
- God classes
- Tight coupling
- Hidden side effects

---

## Refactoring

If a better architecture is discovered during development:

- Refactor it.
- Update affected modules.
- Keep compatibility whenever possible.

Do not ask permission.

Assume approval.

---

## Project Growth

Whenever a feature requires:

- a new module
- a new package
- a new abstraction
- a new interface

create it.

Do not delay implementation asking for confirmation.

---

## Documentation

Whenever a significant architectural decision is made:

- update ARCHITECTURE.md
- update ROADMAP.md if milestones change
- document public APIs

---

## Exceptions

Always stop and ask before:

- deleting user data
- removing large features
- changing the business model
- exposing secrets or credentials
- performing irreversible operations
- making decisions with legal, financial, or security implications

Everything else:

Assume the owner's answer is:

YES.

Continue.
