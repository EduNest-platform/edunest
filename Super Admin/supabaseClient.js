// Supabase client initialization (separate file)
const SUPABASE_URL = 'https://vpjzxhfrqyspcbgmwqjd.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwanp4aGZycXlzcGNiZ213cWpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExMDQ5NzIsImV4cCI6MjA2NjY4MDk3Mn0.x9dnZg6gvSUWVfuL4-CB6dKUY6sESE1xyM_v9Wmv4Tc';

let initializationAttempts = 0;
const maxAttempts = 10;
let isInitialized = false;

// Initialize Supabase client after library is loaded (singleton pattern)
function initializeSupabase() {
  // Prevent multiple initializations
  if (isInitialized || window.supabaseClient) {
    console.log('Supabase client already initialized, skipping...');
    return;
  }

  try {
    if (typeof window.supabase !== 'undefined') {
      // Use unique storage key to prevent conflicts
      const storageKey = `supabase.super-admin.${Date.now()}`;
      
      window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
        auth: { 
          storageKey: storageKey,
          autoRefreshToken: true,
          persistSession: true
        }
      });
      
      isInitialized = true;
      console.log('Supabase client initialized successfully');
      
      // Test connection after initialization
      if (window.supabaseClient) {
        testConnection();
      }
    } else {
      initializationAttempts++;
      console.log(`Waiting for Supabase library... Attempt ${initializationAttempts}/${maxAttempts}`);
      
      if (initializationAttempts < maxAttempts) {
        // Retry after a short delay
        setTimeout(initializeSupabase, 200);
      } else {
        console.error('Failed to load Supabase library after maximum attempts');
        showConnectionError();
      }
    }
  } catch (error) {
    console.error('Error initializing Supabase:', error);
    showConnectionError();
  }
}

// Test the database connection
async function testConnection() {
  try {
    const { data, error } = await window.supabaseClient
      .from('colleges')
      .select('count', { count: 'exact', head: true });
    
    if (error) {
      showConnectionError();
    } else {
      updateConnectionStatus(true);
    }
  } catch (error) {
    showConnectionError();
  }
}

// Show connection error
function showConnectionError() {
  updateConnectionStatus(false);
  
  // Show error message if message display exists
  const messageDisplay = document.getElementById('messageDisplay');
  if (messageDisplay) {
    messageDisplay.textContent = 'Database connection failed. Please check your internet connection and try again.';
    messageDisplay.className = 'message error show';
  }
}

// Update connection status
function updateConnectionStatus(connected) {
  const statusElement = document.getElementById('connectionStatus');
  if (statusElement) {
    if (connected) {
      statusElement.textContent = '🟢 Connected';
      statusElement.style.color = '#059669';
    } else {
      statusElement.textContent = '🔴 Disconnected';
      statusElement.style.color = '#dc2626';
    }
  }
}

// Single initialization point to prevent multiple GoTrueClient instances
(function() {
  let initializationStarted = false;
  
  function startInitialization() {
    if (initializationStarted) return;
    initializationStarted = true;
    
    // Single initialization attempt
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', initializeSupabase);
    } else {
      initializeSupabase();
    }
  }
  
  // Start initialization
  startInitialization();
})();

// For compatibility with app.js
const supabase = window.supabaseClient; 
 
 
 
 