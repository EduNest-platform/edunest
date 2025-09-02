// Admin Panel Caching System
// Provides intelligent caching for profile data and other frequently accessed information

class AdminCache {
  constructor() {
    this.profileCache = new Map();
    this.batchProfileCache = new Map();
    this.rosterCache = new Map();
    this.attendanceCache = new Map();
    
    // Cache TTL settings (in milliseconds)
    this.PROFILE_TTL = 5 * 60 * 1000; // 5 minutes for individual profiles
    this.BATCH_PROFILE_TTL = 3 * 60 * 1000; // 3 minutes for batch profiles
    this.ROSTER_TTL = 10 * 60 * 1000; // 10 minutes for class rosters
    this.ATTENDANCE_TTL = 2 * 60 * 1000; // 2 minutes for attendance data
    
    console.log('AdminCache initialized with TTL settings:', {
      profileTTL: this.PROFILE_TTL / 1000 + 's',
      batchProfileTTL: this.BATCH_PROFILE_TTL / 1000 + 's',
      rosterTTL: this.ROSTER_TTL / 1000 + 's',
      attendanceTTL: this.ATTENDANCE_TTL / 1000 + 's'
    });
  }

  // Profile caching methods
  cacheProfile(userId, profileData) {
    const cacheEntry = {
      data: profileData,
      timestamp: Date.now(),
      ttl: this.PROFILE_TTL
    };
    this.profileCache.set(userId, cacheEntry);
    console.log(`Cached profile for user: ${userId}`);
  }

  getProfile(userId) {
    const entry = this.profileCache.get(userId);
    if (!entry) return null;
    
    if (Date.now() - entry.timestamp > entry.ttl) {
      this.profileCache.delete(userId);
      console.log(`Profile cache expired for user: ${userId}`);
      return null;
    }
    
    console.log(`Profile cache hit for user: ${userId}`);
    return entry.data;
  }

  // Batch profile caching methods
  cacheBatchProfiles(userIds, profilesMap) {
    const cacheKey = userIds.sort().join(',');
    const cacheEntry = {
      data: profilesMap,
      timestamp: Date.now(),
      ttl: this.BATCH_PROFILE_TTL,
      userIds: userIds
    };
    this.batchProfileCache.set(cacheKey, cacheEntry);
    
    // Also cache individual profiles
    Object.entries(profilesMap).forEach(([userId, profile]) => {
      this.cacheProfile(userId, profile);
    });
    
    console.log(`Cached batch profiles for ${userIds.length} users`);
  }

  getBatchProfiles(userIds) {
    const cacheKey = userIds.sort().join(',');
    const entry = this.batchProfileCache.get(cacheKey);
    
    if (!entry) {
      console.log(`Batch profile cache miss for ${userIds.length} users`);
      return null;
    }
    
    if (Date.now() - entry.timestamp > entry.ttl) {
      this.batchProfileCache.delete(cacheKey);
      console.log(`Batch profile cache expired for ${userIds.length} users`);
      return null;
    }
    
    console.log(`Batch profile cache hit for ${userIds.length} users`);
    return entry.data;
  }

  // Class roster caching methods
  cacheClassRoster(rosterData, classId) {
    const cacheEntry = {
      data: rosterData,
      timestamp: Date.now(),
      ttl: this.ROSTER_TTL
    };
    this.rosterCache.set(classId, cacheEntry);
    console.log(`Cached roster for class: ${classId}`);
  }

  getClassRoster(classId) {
    const entry = this.rosterCache.get(classId);
    if (!entry) return null;
    
    if (Date.now() - entry.timestamp > entry.ttl) {
      this.rosterCache.delete(classId);
      console.log(`Roster cache expired for class: ${classId}`);
      return null;
    }
    
    console.log(`Roster cache hit for class: ${classId}`);
    return entry.data;
  }

  // Attendance data caching methods
  cacheAttendanceData(attendanceData, classId, dateKey) {
    const cacheKey = `${classId}_${dateKey}`;
    const cacheEntry = {
      data: attendanceData,
      timestamp: Date.now(),
      ttl: this.ATTENDANCE_TTL
    };
    this.attendanceCache.set(cacheKey, cacheEntry);
    console.log(`Cached attendance data for class: ${classId}, date: ${dateKey}`);
  }

  getAttendanceData(classId, dateKey) {
    const cacheKey = `${classId}_${dateKey}`;
    const entry = this.attendanceCache.get(cacheKey);
    
    if (!entry) return null;
    
    if (Date.now() - entry.timestamp > entry.ttl) {
      this.attendanceCache.delete(cacheKey);
      console.log(`Attendance cache expired for class: ${classId}, date: ${dateKey}`);
      return null;
    }
    
    console.log(`Attendance cache hit for class: ${classId}, date: ${dateKey}`);
    return entry.data;
  }

  // Batch profile fetching with caching
  async batchGetUserProfiles(userIds, forceRefresh = false) {
    if (!userIds || userIds.length === 0) return {};
    
    // Check cache first unless force refresh
    if (!forceRefresh) {
      const cachedProfiles = this.getBatchProfiles(userIds);
      if (cachedProfiles) {
        return cachedProfiles;
      }
    }
    
    try {
      console.log(`Fetching batch profiles for ${userIds.length} users from database`);
      
      // Fetch profiles from database
      const { data: profiles, error } = await window.supabaseClient
        .from('profiles')
        .select('id, full_name, email, student_id, profile_image_url')
        .in('id', userIds);
      
      if (error) throw error;
      
      // Convert to map format
      const profilesMap = {};
      profiles.forEach(profile => {
        profilesMap[profile.id] = profile;
      });
      
      // Cache the results
      this.cacheBatchProfiles(userIds, profilesMap);
      
      console.log(`Successfully fetched and cached ${profiles.length} profiles`);
      return profilesMap;
      
    } catch (error) {
      console.error('Error in batch profile fetch:', error);
      throw error;
    }
  }

  // Cache invalidation methods
  invalidateProfile(userId) {
    this.profileCache.delete(userId);
    
    // Also invalidate any batch caches containing this user
    for (const [key, entry] of this.batchProfileCache.entries()) {
      if (entry.userIds.includes(userId)) {
        this.batchProfileCache.delete(key);
        console.log(`Invalidated batch cache containing user: ${userId}`);
      }
    }
    
    console.log(`Invalidated profile cache for user: ${userId}`);
  }

  invalidateClassRoster(classId) {
    this.rosterCache.delete(classId);
    console.log(`Invalidated roster cache for class: ${classId}`);
  }

  invalidateAttendanceData(classId, dateKey = null) {
    if (dateKey) {
      const cacheKey = `${classId}_${dateKey}`;
      this.attendanceCache.delete(cacheKey);
      console.log(`Invalidated attendance cache for class: ${classId}, date: ${dateKey}`);
    } else {
      // Invalidate all attendance data for this class
      for (const key of this.attendanceCache.keys()) {
        if (key.startsWith(`${classId}_`)) {
          this.attendanceCache.delete(key);
        }
      }
      console.log(`Invalidated all attendance cache for class: ${classId}`);
    }
  }

  // Clear all caches
  clearAll() {
    this.profileCache.clear();
    this.batchProfileCache.clear();
    this.rosterCache.clear();
    this.attendanceCache.clear();
    console.log('All caches cleared');
  }

  // Get cache statistics
  getCacheStats() {
    return {
      profiles: this.profileCache.size,
      batchProfiles: this.batchProfileCache.size,
      rosters: this.rosterCache.size,
      attendance: this.attendanceCache.size,
      total: this.profileCache.size + this.batchProfileCache.size + 
             this.rosterCache.size + this.attendanceCache.size
    };
  }

  // Cleanup expired entries
  cleanup() {
    const now = Date.now();
    let cleaned = 0;
    
    // Clean profile cache
    for (const [key, entry] of this.profileCache.entries()) {
      if (now - entry.timestamp > entry.ttl) {
        this.profileCache.delete(key);
        cleaned++;
      }
    }
    
    // Clean batch profile cache
    for (const [key, entry] of this.batchProfileCache.entries()) {
      if (now - entry.timestamp > entry.ttl) {
        this.batchProfileCache.delete(key);
        cleaned++;
      }
    }
    
    // Clean roster cache
    for (const [key, entry] of this.rosterCache.entries()) {
      if (now - entry.timestamp > entry.ttl) {
        this.rosterCache.delete(key);
        cleaned++;
      }
    }
    
    // Clean attendance cache
    for (const [key, entry] of this.attendanceCache.entries()) {
      if (now - entry.timestamp > entry.ttl) {
        this.attendanceCache.delete(key);
        cleaned++;
      }
    }
    
    if (cleaned > 0) {
      console.log(`Cleaned up ${cleaned} expired cache entries`);
    }
  }
}

// Initialize global admin cache
window.adminCache = new AdminCache();

// Periodic cleanup every 5 minutes
setInterval(() => {
  window.adminCache.cleanup();
}, 5 * 60 * 1000);

console.log('Admin Cache system initialized and ready');
