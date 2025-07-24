import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

function withCORS(response: Response) {
  const newHeaders = new Headers(response.headers);
  newHeaders.set("Access-Control-Allow-Origin", "*");
  newHeaders.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  newHeaders.set("Access-Control-Allow-Headers", "authorization, content-type");
  return new Response(response.body, {
    status: response.status,
    headers: newHeaders,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return withCORS(new Response(null, { status: 204 }));
  }

  // Require Authorization header
  const authHeader = req.headers.get("authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return withCORS(new Response(
      JSON.stringify({ code: 401, message: "Missing or invalid authorization header" }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    ));
  }

  const token = authHeader.replace("Bearer ", "");

  try {
    // Create Supabase client with service role key for admin operations
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    
    if (!supabaseUrl || !supabaseServiceKey) {
      return withCORS(new Response(
        JSON.stringify({ error: "Missing Supabase configuration" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      ));
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify the user's token and get user info
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    
    if (authError || !user) {
      return withCORS(new Response(
        JSON.stringify({ error: "Invalid or expired token" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      ));
    }

    const userId = user.id;

    // Delete user data from database tables
    try {
      // Delete test results
      const { error: testResultsError } = await supabase
        .from('test_results')
        .delete()
        .eq('user_id', userId);

      if (testResultsError) {
        console.error('Error deleting test results:', testResultsError);
      }

      // Delete profile
      const { error: profileError } = await supabase
        .from('profiles')
        .delete()
        .eq('id', userId);

      if (profileError) {
        console.error('Error deleting profile:', profileError);
      }

      // Delete any other user-related data here
      // For example, if you have other tables with user_id foreign keys

    } catch (dbError) {
      console.error('Database deletion error:', dbError);
      return withCORS(new Response(
        JSON.stringify({ error: "Failed to delete user data from database" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      ));
    }

    // Delete the user from Supabase Auth
    try {
      const { error: deleteUserError } = await supabase.auth.admin.deleteUser(userId);
      
      if (deleteUserError) {
        console.error('Error deleting user from auth:', deleteUserError);
        return withCORS(new Response(
          JSON.stringify({ error: "Failed to delete user account" }),
          { status: 500, headers: { "Content-Type": "application/json" } }
        ));
      }

      return withCORS(new Response(
        JSON.stringify({ 
          success: true, 
          message: "User account and all data deleted successfully" 
        }),
        { headers: { "Content-Type": "application/json" } }
      ));

    } catch (authDeleteError) {
      console.error('Auth deletion error:', authDeleteError);
      return withCORS(new Response(
        JSON.stringify({ error: "Failed to delete user from authentication" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      ));
    }

  } catch (error) {
    console.error('Unexpected error:', error);
    return withCORS(new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    ));
  }
}); 