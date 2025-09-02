-- Create test_results table for storing MCQ test results
-- This table stores results from practice tests and assigned tests

create table public.test_results (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  subject_id text not null,
  subject_name text not null,
  chapter_id text not null,
  chapter_name text not null,
  difficulty text not null,
  total_questions integer not null,
  correct_answers integer not null,
  score integer not null,
  time_taken integer not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  test_title text null,
  constraint test_results_pkey primary key (id),
  constraint test_results_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint test_results_correct_answers_check check ((correct_answers >= 0)),
  constraint test_results_time_taken_check check ((time_taken >= 0)),
  constraint test_results_total_questions_check check ((total_questions > 0)),
  constraint test_results_score_check check (
    (
      (score >= 0)
      and (score <= 100)
    )
  ),
  constraint test_results_difficulty_check check (
    (
      difficulty = any (
        array[
          'beginner'::text,
          'intermediate'::text,
          'advanced'::text,
          'not_assigned'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

-- Create indexes for performance optimization
create index IF not exists idx_test_results_user_id on public.test_results using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_test_results_created_at on public.test_results using btree (created_at desc) TABLESPACE pg_default;

create index IF not exists idx_test_results_subject_id on public.test_results using btree (subject_id) TABLESPACE pg_default;

create index IF not exists idx_test_results_chapter_id on public.test_results using btree (chapter_id) TABLESPACE pg_default;

create index IF not exists idx_test_results_difficulty on public.test_results using btree (difficulty) TABLESPACE pg_default;

create index IF not exists idx_test_results_score on public.test_results using btree (score) TABLESPACE pg_default;

-- Create trigger for automatic updated_at timestamp
create trigger update_test_results_updated_at BEFORE
update on test_results for EACH row
execute FUNCTION update_updated_at_column ();

-- Enable RLS (Row Level Security)
alter table test_results enable row level security;

-- Create RLS policies
create policy "Users can view their own test results" on test_results
  for select using (auth.uid() = user_id);

create policy "Users can insert their own test results" on test_results
  for insert with check (auth.uid() = user_id);

create policy "Users can update their own test results" on test_results
  for update using (auth.uid() = user_id);

create policy "Users can delete their own test results" on test_results
  for delete using (auth.uid() = user_id);
