// Admin Panel Cache Manager - Optimized for Performance
// Reduces API calls and improves user experience

class AdminCacheManager {
  constructor() {
    this.caches = new Map();
    this.defaultTTL = 5 * 60 * 1000; // 5 minutes
    this.maxCacheSize = 50; // Maximum number of cache entries
    this.compressionEnabled = true;
    
    // Initialize cache cleanup
    this.startCleanupTimer();
    
    console.log('AdminCacheManager initialized');
  }

  // Generate cache key
  generateKey(type, params = {}) {
    const sortedParams = Object.keys(params)
      .sort()
      .map(key => `${key}:${params[key]}`)
      .join('|');
    return `${type}${sortedParams ? `_${sortedParams}` : ''}`;
  }

  // Compress data for storage
  compress(data) {
    if (!this.compressionEnabled) return data;
    try {
      return JSON.stringify(data);
    } catch (error) {
      console.warn('Cache compression failed:', error);
      return data;
    }
  }

  // Decompress data from storage
  decompress(data) {
    if (!this.compressionEnabled) return data;
    try {
      return typeof data === 'string' ? JSON.parse(data) : data;
    } catch (error) {
      console.warn('Cache decompression failed:', error);
      return data;
    }
  }

  // Set cache entry
  set(type, data, params = {}, ttl = null) {
    try {
      const key = this.generateKey(type, params);
      const expiresAt = Date.now() + (ttl || this.defaultTTL);
      
      const cacheEntry = {
        data: this.compress(data),
        expiresAt,
        createdAt: Date.now(),
        accessCount: 0,
        lastAccessed: Date.now(),
        type,
        params
      };

      this.caches.set(key, cacheEntry);
      
      // Enforce cache size limit
      if (this.caches.size > this.maxCacheSize) {
        this.evictOldest();
      }

      console.log(`Cache SET: ${key} (expires in ${Math.round((ttl || this.defaultTTL) / 1000)}s)`);
      return true;
    } catch (error) {
      console.error('Cache set error:', error);
      return false;
    }
  }

  // Get cache entry
  get(type, params = {}) {
    try {
      const key = this.generateKey(type, params);
      const entry = this.caches.get(key);

      if (!entry) {
        console.log(`Cache MISS: ${key}`);
        return null;
      }

      if (Date.now() > entry.expiresAt) {
        this.caches.delete(key);
        console.log(`Cache EXPIRED: ${key}`);
        return null;
      }

      // Update access statistics
      entry.accessCount++;
      entry.lastAccessed = Date.now();

      console.log(`Cache HIT: ${key} (accessed ${entry.accessCount} times)`);
      return this.decompress(entry.data);
    } catch (error) {
      console.error('Cache get error:', error);
      return null;
    }
  }

  // Check if cache entry exists and is valid
  has(type, params = {}) {
    const key = this.generateKey(type, params);
    const entry = this.caches.get(key);
    return entry && Date.now() <= entry.expiresAt;
  }

  // Invalidate specific cache entry
  invalidate(type, params = {}) {
    const key = this.generateKey(type, params);
    const deleted = this.caches.delete(key);
    if (deleted) {
      console.log(`Cache INVALIDATED: ${key}`);
    }
    return deleted;
  }

  // Invalidate all cache entries of a specific type
  invalidateType(type) {
    let count = 0;
    for (const [key, entry] of this.caches.entries()) {
      if (entry.type === type) {
        this.caches.delete(key);
        count++;
      }
    }
    console.log(`Cache INVALIDATED TYPE: ${type} (${count} entries)`);
    return count;
  }

  // Clear all cache
  clear() {
    const count = this.caches.size;
    this.caches.clear();
    console.log(`Cache CLEARED: ${count} entries removed`);
    return count;
  }

  // Evict oldest entries when cache is full
  evictOldest() {
    let oldestKey = null;
    let oldestTime = Date.now();

    for (const [key, entry] of this.caches.entries()) {
      if (entry.lastAccessed < oldestTime) {
        oldestTime = entry.lastAccessed;
        oldestKey = key;
      }
    }

    if (oldestKey) {
      this.caches.delete(oldestKey);
      console.log(`Cache EVICTED: ${oldestKey}`);
    }
  }

  // Cleanup expired entries
  cleanup() {
    const now = Date.now();
    let cleanedCount = 0;

    for (const [key, entry] of this.caches.entries()) {
      if (now > entry.expiresAt) {
        this.caches.delete(key);
        cleanedCount++;
      }
    }

    if (cleanedCount > 0) {
      console.log(`Cache CLEANUP: ${cleanedCount} expired entries removed`);
    }
    return cleanedCount;
  }

  // Start automatic cleanup timer
  startCleanupTimer() {
    setInterval(() => {
      this.cleanup();
    }, 2 * 60 * 1000); // Cleanup every 2 minutes
  }

  // Get cache statistics
  getStats() {
    const now = Date.now();
    let totalSize = 0;
    let expiredCount = 0;
    const typeStats = {};

    for (const [key, entry] of this.caches.entries()) {
      totalSize++;
      
      if (now > entry.expiresAt) {
        expiredCount++;
      }

      if (!typeStats[entry.type]) {
        typeStats[entry.type] = { count: 0, totalAccess: 0 };
      }
      typeStats[entry.type].count++;
      typeStats[entry.type].totalAccess += entry.accessCount;
    }

    return {
      totalEntries: totalSize,
      expiredEntries: expiredCount,
      maxSize: this.maxCacheSize,
      typeBreakdown: typeStats,
      compressionEnabled: this.compressionEnabled
    };
  }

  // Preload common data
  async preloadCommonData(classId, subjectName) {
    console.log('Preloading common data for class:', classId);
    
    try {
      // Preload class roster if not cached
      if (!this.has('class_roster', { classId })) {
        const { data: rosters } = await window.supabaseClient
          .from('class_rosters')
          .select('*')
          .eq('class_id', classId);
        
        if (rosters) {
          this.set('class_roster', rosters, { classId }, 10 * 60 * 1000); // 10 minutes
        }
      }

      // Preload assignment marks if not cached
      if (!this.has('assignment_marks', { classId })) {
        const { data: marks } = await window.supabaseClient
          .from('class_assignment_marks')
          .select('*')
          .eq('class_id', classId);
        
        if (marks) {
          this.set('assignment_marks', marks, { classId }, 8 * 60 * 1000); // 8 minutes
        }
      }

      console.log('Preloading completed for class:', classId);
    } catch (error) {
      console.error('Preloading failed:', error);
    }
  }
}

// Specialized cache methods for common operations
AdminCacheManager.prototype.cacheStudents = function(students, classId) {
  return this.set('students', students, { classId }, 10 * 60 * 1000);
};

AdminCacheManager.prototype.getStudents = function(classId) {
  return this.get('students', { classId });
};

AdminCacheManager.prototype.cacheAssignmentMarks = function(marks, classId) {
  return this.set('assignment_marks', marks, { classId }, 8 * 60 * 1000);
};

AdminCacheManager.prototype.getAssignmentMarks = function(classId) {
  return this.get('assignment_marks', { classId });
};

AdminCacheManager.prototype.cacheAttendanceData = function(attendance, classId, date) {
  return this.set('attendance', attendance, { classId, date }, 15 * 60 * 1000);
};

AdminCacheManager.prototype.getAttendanceData = function(classId, date) {
  return this.get('attendance', { classId, date });
};

AdminCacheManager.prototype.cacheClassRoster = function(roster, classId) {
  return this.set('class_roster', roster, { classId }, 10 * 60 * 1000);
};

AdminCacheManager.prototype.getClassRoster = function(classId) {
  return this.get('class_roster', { classId });
};

// Global cache instance
window.adminCache = new AdminCacheManager();

// Cache event listeners for debugging
window.addEventListener('beforeunload', () => {
  const stats = window.adminCache.getStats();
  console.log('Final cache stats:', stats);
});

console.log('AdminCacheManager loaded and ready');
