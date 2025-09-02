/**
 * Centralized Authentication Manager for Admin Panel
 * Provides persistent session caching to reduce excessive Supabase auth requests
 */

class AuthManager {
  constructor() {
    this.sessionCache = null;
    this.cacheExpiry = null;
    this.cacheDuration = 5 * 60 * 1000; // 5 minutes
    this.storageKey = 'edunest_admin_session';
    this.listeners = new Set();
    
    // Load cached session on initialization
    this.loadCachedSession();
  }

  /**
   * Load session from localStorage if valid
   */
  loadCachedSession() {
    try {
      const cached = localStorage.getItem(this.storageKey);
      if (cached) {
        const { session, expiry } = JSON.parse(cached);
        if (Date.now() < expiry) {
          this.sessionCache = session;
          this.cacheExpiry = expiry;
          console.log('AuthManager: Loaded valid cached session');
          return;
        }
      }
    } catch (error) {
      console.warn('AuthManager: Error loading cached session:', error);
    }
    
    // Clear invalid cache
    this.clearCache();
  }

  /**
   * Save session to localStorage
   */
  saveCachedSession(session) {
    try {
      const expiry = Date.now() + this.cacheDuration;
      const cacheData = { session, expiry };
      
      localStorage.setItem(this.storageKey, JSON.stringify(cacheData));
      this.sessionCache = session;
      this.cacheExpiry = expiry;
      
      console.log('AuthManager: Session cached successfully');
    } catch (error) {
      console.warn('AuthManager: Error saving session to cache:', error);
    }
  }

  /**
   * Clear cached session
   */
  clearCache() {
    localStorage.removeItem(this.storageKey);
    this.sessionCache = null;
    this.cacheExpiry = null;
    console.log('AuthManager: Cache cleared');
  }

  /**
   * Check if cached session is valid
   */
  isCacheValid() {
    return this.sessionCache && this.cacheExpiry && Date.now() < this.cacheExpiry;
  }

  /**
   * Wait for Supabase clients to be initialized
   */
  async waitForSupabaseClients() {
    let attempts = 0;
    const maxAttempts = 50;
    
    while ((!window.supabaseAdmin && !window.supabaseClient) && attempts < maxAttempts) {
      await new Promise(resolve => setTimeout(resolve, 100));
      attempts++;
    }
    
    if (!window.supabaseAdmin && !window.supabaseClient) {
      throw new Error('Supabase clients not initialized after timeout');
    }
  }

  /**
   * Get current user with caching
   * @param {boolean} forceRefresh - Force refresh from Supabase
   * @returns {Promise<Object|null>} User object or null
   */
  async getCurrentUser(forceRefresh = false) {
    // Return cached session if valid and not forcing refresh
    if (!forceRefresh && this.isCacheValid()) {
      console.log('AuthManager: Returning cached user session');
      return this.sessionCache;
    }

    try {
      console.log('AuthManager: Fetching fresh user session from Supabase');
      
      // Wait for Supabase clients to be available
      await this.waitForSupabaseClients();
      
      // Check connection status before making requests
      if (window.connectionMonitor) {
        const connectionStatus = window.connectionMonitor.getConnectionStatus();
        if (!connectionStatus.isOnline) {
          throw new Error('No internet connection');
        }
      }
      
      // Try admin client first
      let user = null;
      let error = null;

      if (window.supabaseAdmin) {
        const { data: { user: adminUser }, error: adminError } = await window.supabaseAdmin.auth.getUser();
        if (adminUser && !adminError) {
          user = adminUser;
        } else {
          error = adminError;
        }
      }

      // Fallback to regular client if admin fails
      if (!user && window.supabaseClient) {
        const { data: { user: regularUser }, error: regularError } = await window.supabaseClient.auth.getUser();
        if (regularUser && !regularError) {
          user = regularUser;
        } else {
          error = regularError || error;
        }
      }

      // Final fallback: use session storage data if available
      if (!user && sessionStorage.getItem('adminLoggedIn') === 'true') {
        const adminEmail = sessionStorage.getItem('adminEmail');
        const adminId = sessionStorage.getItem('adminId');
        if (adminEmail && adminId) {
          console.log('AuthManager: Using session storage fallback');
          user = {
            id: adminId,
            email: adminEmail,
            fallback: true
          };
        }
      }

      if (user) {
        // Cache the successful result (but not fallback data)
        if (!user.fallback) {
          this.saveCachedSession(user);
        }
        this.notifyListeners(user);
        return user;
      } else {
        console.error('AuthManager: Failed to get user:', error);
        this.clearCache();
        this.notifyListeners(null);
        return null;
      }
    } catch (error) {
      console.error('AuthManager: Error fetching user:', error);
      
      // Try session storage fallback on error
      if (sessionStorage.getItem('adminLoggedIn') === 'true') {
        const adminEmail = sessionStorage.getItem('adminEmail');
        const adminId = sessionStorage.getItem('adminId');
        if (adminEmail && adminId) {
          console.log('AuthManager: Using session storage fallback after error');
          const fallbackUser = {
            id: adminId,
            email: adminEmail,
            fallback: true
          };
          this.notifyListeners(fallbackUser);
          return fallbackUser;
        }
      }
      
      this.clearCache();
      this.notifyListeners(null);
      return null;
    }
  }

  /**
   * Add listener for auth state changes
   */
  addListener(callback) {
    this.listeners.add(callback);
  }

  /**
   * Remove listener
   */
  removeListener(callback) {
    this.listeners.delete(callback);
  }

  /**
   * Notify all listeners of auth state change
   */
  notifyListeners(user) {
    this.listeners.forEach(callback => {
      try {
        callback(user);
      } catch (error) {
        console.error('AuthManager: Error in listener callback:', error);
      }
    });
  }

  /**
   * Sign out and clear cache
   */
  async signOut() {
    try {
      if (window.supabaseAdmin) {
        await window.supabaseAdmin.auth.signOut();
      }
      if (window.supabaseClient) {
        await window.supabaseClient.auth.signOut();
      }
    } catch (error) {
      console.error('AuthManager: Error during sign out:', error);
    }
    
    this.clearCache();
    this.notifyListeners(null);
  }

  /**
   * Refresh session (force fetch from Supabase)
   */
  async refreshSession() {
    return await this.getCurrentUser(true);
  }

  /**
   * Get cached user without making API call
   */
  getCachedUser() {
    return this.isCacheValid() ? this.sessionCache : null;
  }
}

// Create global instance
window.authManager = new AuthManager();

// Set up auth state change listener to keep cache in sync
if (window.supabaseAdmin) {
  window.supabaseAdmin.auth.onAuthStateChange((event, session) => {
    console.log('AuthManager: Auth state changed:', event);
    if (event === 'SIGNED_OUT' || event === 'TOKEN_REFRESHED') {
      if (event === 'SIGNED_OUT') {
        window.authManager.clearCache();
        window.authManager.notifyListeners(null);
      } else if (event === 'TOKEN_REFRESHED' && session?.user) {
        window.authManager.saveCachedSession(session.user);
        window.authManager.notifyListeners(session.user);
      }
    }
  });
}

console.log('AuthManager: Initialized successfully');
