-- Execute this SQL in your Supabase database

CREATE TABLE IF NOT EXISTS public.feedback_data (
  id uuid not null default gen_random_uuid (),
  type character varying(50) not null,
  semester character varying(100) null,
  campaign_info jsonb null,
  response_info jsonb null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint feedback_data_pkey primary key (id)
) TABLESPACE pg_default;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_feedback_data_type on public.feedback_data using btree (type) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_feedback_data_semester on public.feedback_data using btree (semester) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_feedback_data_created_at on public.feedback_data using btree (created_at desc) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_feedback_data_campaign_status on public.feedback_data using gin (((campaign_info -> 'status'::text))) TABLESPACE pg_default
WHERE ((type)::text = 'campaign'::text);

CREATE INDEX IF NOT EXISTS idx_feedback_data_campaign_hierarchy on public.feedback_data using gin (((campaign_info -> 'hierarchy'::text))) TABLESPACE pg_default
WHERE ((type)::text = 'campaign'::text);

CREATE INDEX IF NOT EXISTS idx_feedback_data_response_campaign on public.feedback_data using gin (((response_info -> 'campaign_id'::text))) TABLESPACE pg_default
WHERE ((type)::text = 'response'::text);

-- Create updated_at trigger (if the function exists)
CREATE TRIGGER update_feedback_data_updated_at BEFORE UPDATE ON feedback_data 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
