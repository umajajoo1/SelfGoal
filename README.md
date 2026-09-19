# SelfGoal — English Fluency App (CBSE, Class 2–5)

B2C EdTech app that builds genuine English fluency for struggling CBSE class 2–5 students — content is matched to a child's actual skill level, not their nominal grade.

## Status
Pre-scaffold planning stage. See [Next steps](#next-steps).

## Architecture
Rendered diagram: [docs/diagrams/architecture.html](docs/diagrams/architecture.html) (open directly in a browser).

## Design decisions (ADR log)
| ADR | Title | Status |
|---|---|---|
| [0001](docs/adr/0001-tech-stack-selection.md) | Tech stack selection | Accepted |
| [0002](docs/adr/0002-data-model-and-skill-grade-decoupling.md) | Data model & skill/grade decoupling | Accepted |
| [0003](docs/adr/0003-security-and-child-data-compliance.md) | Security & child data compliance | Accepted |
| [0004](docs/adr/0004-design-patterns-and-scalability.md) | Design patterns & scalability | Accepted |

New architectural decisions get a new numbered file in `docs/adr/` (use [the template](docs/adr/0000-adr-template.md)). Past ADRs are never edited after acceptance — supersede them with a new one instead.

## Data model
The schema is defined as executable code, not prose: [supabase/migrations/0001_init.sql](supabase/migrations/0001_init.sql). Apply it with the Supabase CLI (see Getting Started below).

## Security
See [SECURITY.md](SECURITY.md).

## Tech stack
Next.js (TypeScript, Tailwind, App Router) · Supabase (Postgres + Auth + Storage) · Vercel · Google Gemini API · Google Cloud Text-to-Speech · Razorpay (Phase 2)

## Getting started
```powershell
# Scaffold the app (not yet run)
npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --use-npm --no-turbopack
npm install @supabase/supabase-js @supabase/ssr @google/generative-ai zod

# Apply the schema to a Supabase project
npx supabase init
npx supabase link --project-ref <dev-project-ref>
npx supabase db push
```

## Next steps
- [ ] Create the GitHub repo
- [ ] Create two Supabase projects (dev + prod)
- [ ] Get a Gemini API key
- [ ] Get Google Cloud TTS credentials
- [ ] Decide parent auth method (recommend magic-link/OTP)
- [ ] Run the scaffold command above
