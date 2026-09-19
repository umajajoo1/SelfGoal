-- Phase 1 schema for the English fluency app.
-- This file is the single source of truth for the data model — see docs/adr/0002 for rationale.

-- ============================================================
-- EXTENSIONS
-- ============================================================
create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- ============================================================
-- 1. IDENTITY
-- ============================================================

-- auth.users (built into Supabase) holds the parent's login credentials.
-- This table only extends it with app-specific profile + consent fields.
create table public.parent_profiles (
  id                      uuid primary key references auth.users(id) on delete cascade,
  full_name               text not null,
  phone                   text,
  city                    text,
  consent_given_at        timestamptz,
  consent_ip              inet,
  consent_policy_version  text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create table public.children (
  id             uuid primary key default gen_random_uuid(),
  parent_id      uuid not null references public.parent_profiles(id) on delete cascade,
  full_name      text not null,
  nickname       text,
  date_of_birth  date not null,
  current_grade  smallint not null check (current_grade between 2 and 5),
  avatar_url     text,
  created_at     timestamptz not null default now()
);
create index idx_children_parent_id on public.children(parent_id);

-- ============================================================
-- 2. SKILL GRAPH & DIAGNOSTICS
-- ============================================================

create table public.skills (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null,
  category              text not null check (category in
                          ('phonics','vocabulary','grammar','reading_comprehension','speaking')),
  skill_level           smallint not null,           -- 1-50, independent of nominal grade
  prerequisite_skill_id uuid references public.skills(id),
  description           text
);

create table public.diagnostic_questions (
  id             uuid primary key default gen_random_uuid(),
  skill_id       uuid not null references public.skills(id),
  question_type  text not null check (question_type in ('mcq','tap_select','listen_choose')),
  content_json   jsonb not null,
  correct_answer jsonb not null,
  difficulty     smallint not null
);

create table public.diagnostic_sessions (
  id                    uuid primary key default gen_random_uuid(),
  child_id              uuid not null references public.children(id) on delete cascade,
  status                text not null default 'in_progress'
                          check (status in ('in_progress','completed','abandoned')),
  placement_skill_level smallint,
  started_at            timestamptz not null default now(),
  completed_at          timestamptz
);

create table public.diagnostic_responses (
  id                uuid primary key default gen_random_uuid(),
  session_id        uuid not null references public.diagnostic_sessions(id) on delete cascade,
  question_id       uuid not null references public.diagnostic_questions(id),
  child_answer      jsonb not null,
  is_correct        boolean not null,
  response_time_ms  integer,
  answered_at       timestamptz not null default now()
);
create index idx_diag_sessions_child on public.diagnostic_sessions(child_id);
create index idx_diag_responses_session on public.diagnostic_responses(session_id);

-- ============================================================
-- 3. CONTENT & MASTERY (spaced repetition)
-- ============================================================

create table public.content_items (
  id                 uuid primary key default gen_random_uuid(),
  skill_id           uuid not null references public.skills(id),
  title              text not null,
  type               text not null check (type in ('lesson','practice','story','game')),
  difficulty         smallint not null,
  age_theme          smallint not null check (age_theme between 2 and 5), -- illustration/topic band, NOT skill level
  content_json       jsonb not null,
  audio_url          text,           -- populated by the TTS adapter (cached)
  estimated_minutes  smallint,
  created_at         timestamptz not null default now()
);

create table public.skill_mastery (
  id                    uuid primary key default gen_random_uuid(),
  child_id              uuid not null references public.children(id) on delete cascade,
  skill_id              uuid not null references public.skills(id),
  mastery_score         smallint not null default 0 check (mastery_score between 0 and 100),
  status                text not null default 'not_started'
                          check (status in ('not_started','learning','mastered')),
  last_practiced_at     timestamptz,
  next_review_at        timestamptz,
  review_interval_days  smallint not null default 1,
  unique (child_id, skill_id)
);

create table public.content_attempts (
  id                uuid primary key default gen_random_uuid(),
  child_id          uuid not null references public.children(id) on delete cascade,
  content_item_id   uuid not null references public.content_items(id),
  score             smallint,
  attempts_count    smallint not null default 1,
  started_at        timestamptz not null default now(),
  completed_at      timestamptz
);
create index idx_mastery_child on public.skill_mastery(child_id);
create index idx_mastery_next_review on public.skill_mastery(next_review_at);
create index idx_attempts_child on public.content_attempts(child_id);

-- ============================================================
-- 4. SPEAKING & AI FEEDBACK
-- ============================================================

create table public.speaking_prompts (
  id                uuid primary key default gen_random_uuid(),
  skill_id          uuid not null references public.skills(id),
  prompt_text       text not null,
  sample_audio_url  text
);

create table public.speaking_submissions (
  id                uuid primary key default gen_random_uuid(),
  child_id          uuid not null references public.children(id) on delete cascade,
  prompt_id         uuid not null references public.speaking_prompts(id),
  audio_url         text not null,   -- private bucket, signed URL access only
  ai_feedback_json  jsonb,
  submitted_at      timestamptz not null default now(),
  reviewed_at       timestamptz
);
create index idx_speaking_child on public.speaking_submissions(child_id);

-- ============================================================
-- 5. GAMIFICATION & PARENT REPORTING
-- ============================================================

create table public.badges (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  description   text,
  icon_url      text,
  criteria_json jsonb not null
);

create table public.child_badges (
  id         uuid primary key default gen_random_uuid(),
  child_id   uuid not null references public.children(id) on delete cascade,
  badge_id   uuid not null references public.badges(id),
  earned_at  timestamptz not null default now(),
  unique (child_id, badge_id)
);

create table public.streaks (
  child_id              uuid primary key references public.children(id) on delete cascade,
  current_streak_days   smallint not null default 0,
  longest_streak_days   smallint not null default 0,
  last_activity_date    date
);

create table public.parent_reports (
  id              uuid primary key default gen_random_uuid(),
  child_id        uuid not null references public.children(id) on delete cascade,
  week_start_date date not null,
  report_json     jsonb not null,   -- root-cause gaps + home-practice suggestions
  generated_at    timestamptz not null default now(),
  viewed_at       timestamptz,
  unique (child_id, week_start_date)
);

-- ============================================================
-- 6. INFRASTRUCTURE / CACHING (backs the Decorator pattern, ADR-0004)
-- ============================================================

create table public.tts_cache (
  id          uuid primary key default gen_random_uuid(),
  text_hash   text not null unique,   -- sha256(text + voice + language)
  voice       text not null,
  language    text not null,
  audio_url   text not null,
  created_at  timestamptz not null default now()
);

create table public.audit_log (
  id             uuid primary key default gen_random_uuid(),
  actor_id       uuid,
  action         text not null,
  entity         text not null,
  entity_id      uuid,
  metadata_json  jsonb,
  created_at     timestamptz not null default now()
);

-- ============================================================
-- 7. CONSENT & PAYMENTS
-- ============================================================

create table public.consent_records (
  id              uuid primary key default gen_random_uuid(),
  parent_id       uuid not null references public.parent_profiles(id) on delete cascade,
  child_id        uuid references public.children(id) on delete cascade,
  consent_type    text not null check (consent_type in
                     ('account_tos','child_data_processing','marketing_email')),
  given_at        timestamptz not null default now(),
  ip_address      inet,
  policy_version  text not null
);

-- Phase 2 (not built in MVP, table reserved so schema doesn't need breaking changes later)
create table public.subscriptions (
  id                        uuid primary key default gen_random_uuid(),
  parent_id                 uuid not null references public.parent_profiles(id) on delete cascade,
  plan                      text not null,
  razorpay_subscription_id  text,
  status                    text not null check (status in ('active','past_due','cancelled')),
  current_period_end        timestamptz
);

-- ============================================================
-- ROW LEVEL SECURITY  (see docs/adr/0003-security-and-child-data-compliance.md)
-- ============================================================

-- Child-owned data
alter table public.parent_profiles      enable row level security;
alter table public.children             enable row level security;
alter table public.diagnostic_sessions  enable row level security;
alter table public.diagnostic_responses enable row level security;
alter table public.skill_mastery        enable row level security;
alter table public.content_attempts     enable row level security;
alter table public.speaking_submissions enable row level security;
alter table public.child_badges         enable row level security;
alter table public.streaks              enable row level security;
alter table public.parent_reports       enable row level security;
alter table public.consent_records      enable row level security;
alter table public.subscriptions        enable row level security;

-- Catalog / reference data
alter table public.skills               enable row level security;
alter table public.diagnostic_questions enable row level security;
alter table public.content_items        enable row level security;
alter table public.speaking_prompts     enable row level security;
alter table public.badges               enable row level security;

-- Server-only tables (RLS enabled with NO policies below = default deny for all client roles)
alter table public.tts_cache  enable row level security;
alter table public.audit_log  enable row level security;

-- --- Parent profile: only the parent themself ---
create policy "parent reads own profile" on public.parent_profiles
  for select using (auth.uid() = id);
create policy "parent updates own profile" on public.parent_profiles
  for update using (auth.uid() = id);

-- --- Children: scoped to owning parent ---
create policy "parent manages own children" on public.children
  for all using (auth.uid() = parent_id) with check (auth.uid() = parent_id);

-- --- Direct child_id tables ---
create policy "parent reads own child diagnostics" on public.diagnostic_sessions
  for select using (child_id in (select id from public.children where parent_id = auth.uid()));
create policy "parent inserts own child diagnostics" on public.diagnostic_sessions
  for insert with check (child_id in (select id from public.children where parent_id = auth.uid()));

create policy "parent reads own mastery" on public.skill_mastery
  for select using (child_id in (select id from public.children where parent_id = auth.uid()));

create policy "parent reads own attempts" on public.content_attempts
  for all using (child_id in (select id from public.children where parent_id = auth.uid()))
  with check (child_id in (select id from public.children where parent_id = auth.uid()));

create policy "parent reads own speaking submissions" on public.speaking_submissions
  for all using (child_id in (select id from public.children where parent_id = auth.uid()))
  with check (child_id in (select id from public.children where parent_id = auth.uid()));

create policy "parent reads own badges" on public.child_badges
  for select using (child_id in (select id from public.children where parent_id = auth.uid()));

create policy "parent reads own streaks" on public.streaks
  for select using (child_id in (select id from public.children where parent_id = auth.uid()));

create policy "parent reads own reports" on public.parent_reports
  for select using (child_id in (select id from public.children where parent_id = auth.uid()));

create policy "parent reads own consent" on public.consent_records
  for select using (parent_id = auth.uid());

create policy "parent reads own subscription" on public.subscriptions
  for select using (parent_id = auth.uid());

-- --- One-hop-removed table: diagnostic_responses joins through session_id ---
create policy "parent reads own child responses" on public.diagnostic_responses
  for select using (
    exists (
      select 1 from public.diagnostic_sessions s
      join public.children c on c.id = s.child_id
      where s.id = diagnostic_responses.session_id
        and c.parent_id = auth.uid()
    )
  );

-- --- Catalog tables: read-only for any signed-in user ---
create policy "authenticated read skills"    on public.skills               for select using (auth.role() = 'authenticated');
create policy "authenticated read questions" on public.diagnostic_questions for select using (auth.role() = 'authenticated');
create policy "authenticated read content"   on public.content_items        for select using (auth.role() = 'authenticated');
create policy "authenticated read prompts"   on public.speaking_prompts     for select using (auth.role() = 'authenticated');
create policy "authenticated read badges"    on public.badges               for select using (auth.role() = 'authenticated');
