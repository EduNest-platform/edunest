-- Create user_fcm_tokens table for storing FCM tokens
-- This table manages Firebase Cloud Messaging tokens for push notifications

CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  fcm_token text NOT NULL,
  device_type text NULL,
  device_info jsonb NULL,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT user_fcm_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT user_fcm_tokens_user_id_fcm_token_key UNIQUE (user_id, fcm_token),
  CONSTRAINT user_fcm_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id 
ON public.user_fcm_tokens USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_active 
ON public.user_fcm_tokens USING btree (is_active) 
TABLESPACE pg_default
WHERE (is_active = true);

-- Create trigger for automatic updated_at timestamp
CREATE TRIGGER update_user_fcm_tokens_updated_at 
BEFORE UPDATE ON user_fcm_tokens 
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

-- Add RLS policies for security
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own FCM tokens
CREATE POLICY "Users can manage their own FCM tokens" ON public.user_fcm_tokens
FOR ALL USING (auth.uid() = user_id);

-- Policy: Service role can manage all FCM tokens (for notifications)
CREATE POLICY "Service role can manage all FCM tokens" ON public.user_fcm_tokens
FOR ALL USING (auth.role() = 'service_role');
