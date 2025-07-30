import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS"
  };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() });
  }

  console.log('[link-community-admin] Function invoked');
  if (req.method !== 'POST') {
    console.log('[link-community-admin] Invalid method:', req.method);
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: corsHeaders() });
  }

  let email: string | undefined;
  let user_id: string | undefined;
  try {
    const body = await req.json();
    email = (body.email || '').toLowerCase();
    user_id = body.user_id;
    console.log('[link-community-admin] Parsed body:', { email, user_id });
  } catch (err) {
    console.error('[link-community-admin] Invalid JSON body:', err);
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), { status: 400, headers: corsHeaders() });
  }

  if (!email || !user_id) {
    console.error('[link-community-admin] Missing email or user_id');
    return new Response(JSON.stringify({ error: 'Missing email or user_id' }), { status: 400, headers: corsHeaders() });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  // Check if user_id exists in auth.users
  const { data: userData, error: userError } = await supabase
    .from('auth.users')
    .select('id, email')
    .eq('id', user_id)
    .maybeSingle();
  if (userError) {
    console.error('[link-community-admin] Error fetching auth user:', userError);
    return new Response(JSON.stringify({ error: userError }), { status: 500, headers: corsHeaders() });
  }
  if (!userData) {
    console.error('[link-community-admin] No auth user found for user_id:', user_id);
    return new Response(JSON.stringify({ error: 'No auth user found for user_id' }), { status: 404, headers: corsHeaders() });
  }
  console.log('[link-community-admin] Found auth user:', userData);

  // Find all pending admin rows for this email (case-insensitive)
  const { data, error } = await supabase
    .from('community_admins')
    .select('id, email')
    .eq('email', email)
    .is('user_id', null);

  if (error) {
    console.error('[link-community-admin] Error selecting community_admins:', error);
    return new Response(JSON.stringify({ error }), { status: 500, headers: corsHeaders() });
  }

  if (!data || data.length === 0) {
    console.log('[link-community-admin] No pending admin rows found for', email);
    return new Response(JSON.stringify({ message: 'No pending admin rows found.' }), { status: 200, headers: corsHeaders() });
  }

  const ids = data.map((row: any) => row.id);
  console.log('[link-community-admin] Updating rows:', ids, 'for email:', email);

  // Update all matching rows to set user_id
  const { error: updateError } = await supabase
    .from('community_admins')
    .update({ user_id })
    .in('id', ids);

  if (updateError) {
    console.error('[link-community-admin] Error updating community_admins:', updateError);
    return new Response(JSON.stringify({ error: updateError }), { status: 500, headers: corsHeaders() });
  }

  console.log('[link-community-admin] Admin linked successfully for', email, '->', user_id);
  return new Response(JSON.stringify({ message: 'Admin linked successfully.' }), { status: 200, headers: corsHeaders() });
}); 