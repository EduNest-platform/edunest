// Supabase Admin Auth client initialization (separate file)
const ADMIN_SUPABASE_URL = 'https://pfuzvpihupvhjshxiofn.supabase.co';
const ADMIN_SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmdXp2cGlodXB2aGpzaHhpb2ZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1Mjg1MjIsImV4cCI6MjA2NzEwNDUyMn0.WAPJG6iaxuCAM75yCRu6UOcck37XuilVoDJK3uwyx-k';

let adminInitializationAttempts = 0;
const maxAdminAttempts = 10;

function initializeSupabaseAdmin() {
  try {
    if (typeof window.supabase !== 'undefined') {
      window.supabaseAdmin = window.supabase.createClient(ADMIN_SUPABASE_URL, ADMIN_SUPABASE_KEY, {
        auth: { storageKey: 'supabase.admin' }
      });
    } else {
      adminInitializationAttempts++;
      if (adminInitializationAttempts < maxAdminAttempts) {
        setTimeout(initializeSupabaseAdmin, 200);
      }
    }
  } catch (error) {
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeSupabaseAdmin);
} else {
  initializeSupabaseAdmin();
} 