-- Create FCM tokens table for storing user device tokens
CREATE TABLE public.user_fcm_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  fcm_token text NOT NULL,
  device_type text NULL, -- 'android', 'ios', 'web'
  device_info jsonb NULL, -- Additional device information
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT user_fcm_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT user_fcm_tokens_user_id_fcm_token_key UNIQUE (user_id, fcm_token),
  CONSTRAINT user_fcm_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX idx_user_fcm_tokens_user_id ON public.user_fcm_tokens USING btree (user_id);
CREATE INDEX idx_user_fcm_tokens_active ON public.user_fcm_tokens USING btree (is_active) WHERE is_active = true;

-- Enable RLS (Row Level Security)
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can manage their own FCM tokens" ON public.user_fcm_tokens
  FOR ALL USING (auth.uid() = user_id);

-- Create function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_user_fcm_tokens_updated_at 
  BEFORE UPDATE ON public.user_fcm_tokens 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions
GRANT ALL ON public.user_fcm_tokens TO authenticated;
GRANT ALL ON public.user_fcm_tokens TO service_role;
