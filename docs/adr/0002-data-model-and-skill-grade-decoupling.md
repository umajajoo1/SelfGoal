# ADR-0002: Data model & skill/grade decoupling

## Status
Accepted

## Date
2026-09-19

## Context
The product's core thesis is that a child's **nominal grade (2–5)** is not a reliable proxy for their **actual English skill level** — a class-5 child may need class-1-level phonics content, delivered with age-appropriate topics/illustrations rather than infantilized ones. The data model must let content selection and mastery tracking run independently of the grade shown on the child's profile.

## Decision
- `skills.skill_level` (1–50) is the axis that drives content selection, diagnostics, and mastery tracking — completely separate from `children.current_grade`.
- `content_items.age_theme` (2–5) independently drives illustration/topic banding, so a class-5 child doing class-1-level phonics still sees age-appropriate presentation.
- Children never authenticate directly — profiles live under a parent account (`parent_profiles` → `children`), which also keeps the security model simple (see [ADR-0003](0003-security-and-child-data-compliance.md)).
- Spaced repetition is modeled directly in the schema via `skill_mastery.next_review_at` + `review_interval_days`, rather than computed ad hoc in application code.
- The full schema (all tables, columns, constraints, indexes) is defined as executable code, not prose, in [supabase/migrations/0001_init.sql](../../supabase/migrations/0001_init.sql) — **that file is the single source of truth for the data model, this ADR only records the *why*.**

## Consequences
- Extra join complexity vs. a naive "grade = content" model, but this is what makes genuine remediation possible — it's the actual product thesis, not incidental complexity.
- Every schema change from here on is a new numbered file under `supabase/migrations/`, applied via `supabase db push` — never a hand-edit in the Supabase dashboard, so `main` always reflects the true schema history.

## Alternatives Considered
- **Grade-locked content** (skill_level = grade) — rejected: defeats the entire "true fluency regardless of nominal grade" premise.
- **Separate login accounts for children** — rejected: a bigger child-account security/compliance surface (password resets, phishing targeting a child) for no product benefit, since a parent always mediates access anyway.
