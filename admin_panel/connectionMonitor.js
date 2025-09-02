/**
 * Premium Connection Monitor for EduNest Admin Panel
 * Provides elegant visual feedback for internet connectivity status
 */

class ConnectionMonitor {
  constructor() {
    this.isOnline = navigator.onLine;
    this.connectionQuality = 'good';
    this.lastPingTime = Date.now();
    this.pingInterval = null;
    this.statusIndicators = new Set();
    this.notifications = [];
    this.retryAttempts = 0;
    this.maxRetries = 3;
    
    this.init();
  }

  init() {
    // Create connection status UI
    this.createStatusIndicator();
    this.createConnectionToast();
    
    // Set up event listeners
    window.addEventListener('online', () => this.handleOnline());
    window.addEventListener('offline', () => this.handleOffline());
    
    // Start monitoring
    this.startPingMonitoring();
    this.updateStatus();
  }

  createStatusIndicator() {
    // Add connection status to existing footer or header
    const footer = document.querySelector('.footer-status') || document.querySelector('#connectionStatus');
    if (footer) {
      footer.innerHTML = `
        <div class="connection-indicator" id="connectionIndicator">
          <div class="connection-dot"></div>
          <span class="connection-text">Connected</span>
        </div>
      `;
    }

    // Add styles
    if (!document.getElementById('connectionMonitorStyles')) {
      const styles = document.createElement('style');
      styles.id = 'connectionMonitorStyles';
      styles.textContent = `
        .connection-indicator {
          display: flex;
          align-items: center;
          gap: 8px;
          font-size: 0.9em;
          font-weight: 500;
          transition: all 0.3s ease;
        }

        .connection-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: #10b981;
          box-shadow: 0 0 8px rgba(16, 185, 129, 0.4);
          animation: pulse-green 2s infinite;
          transition: all 0.3s ease;
        }

        .connection-dot.slow {
          background: #f59e0b;
          box-shadow: 0 0 8px rgba(245, 158, 11, 0.4);
          animation: pulse-yellow 2s infinite;
        }

        .connection-dot.offline {
          background: #ef4444;
          box-shadow: 0 0 8px rgba(239, 68, 68, 0.4);
          animation: pulse-red 2s infinite;
        }

        @keyframes pulse-green {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.7; transform: scale(1.1); }
        }

        @keyframes pulse-yellow {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.8; transform: scale(1.05); }
        }

        @keyframes pulse-red {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.9; transform: scale(1.02); }
        }

        .connection-toast {
          position: fixed;
          top: 20px;
          right: 20px;
          background: white;
          border-radius: 12px;
          padding: 16px 20px;
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
          border-left: 4px solid #10b981;
          z-index: 10000;
          transform: translateX(400px);
          transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
          max-width: 320px;
          backdrop-filter: blur(10px);
        }

        .connection-toast.show {
          transform: translateX(0);
        }

        .connection-toast.warning {
          border-left-color: #f59e0b;
          background: linear-gradient(135deg, #fef3c7 0%, #ffffff 100%);
        }

        .connection-toast.error {
          border-left-color: #ef4444;
          background: linear-gradient(135deg, #fee2e2 0%, #ffffff 100%);
        }

        .connection-toast.success {
          border-left-color: #10b981;
          background: linear-gradient(135deg, #d1fae5 0%, #ffffff 100%);
        }

        .toast-header {
          display: flex;
          align-items: center;
          gap: 8px;
          font-weight: 600;
          font-size: 0.95em;
          margin-bottom: 4px;
        }

        .toast-message {
          font-size: 0.9em;
          color: #6b7280;
          line-height: 1.4;
        }

        .offline-overlay {
          position: fixed;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          background: rgba(0, 0, 0, 0.8);
          backdrop-filter: blur(4px);
          z-index: 9999;
          display: flex;
          align-items: center;
          justify-content: center;
          opacity: 0;
          visibility: hidden;
          transition: all 0.3s ease;
        }

        .offline-overlay.show {
          opacity: 1;
          visibility: visible;
        }

        .offline-modal {
          background: white;
          border-radius: 16px;
          padding: 32px;
          text-align: center;
          max-width: 400px;
          margin: 20px;
          box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        }

        .offline-icon {
          font-size: 3em;
          margin-bottom: 16px;
          opacity: 0.8;
        }

        .offline-title {
          font-size: 1.5em;
          font-weight: 700;
          color: #1f2937;
          margin-bottom: 8px;
        }

        .offline-message {
          color: #6b7280;
          line-height: 1.5;
          margin-bottom: 24px;
        }

        .retry-btn {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          border: none;
          border-radius: 8px;
          padding: 12px 24px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.2s ease;
        }

        .retry-btn:hover {
          transform: translateY(-1px);
          box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
        }

        .retry-btn:disabled {
          opacity: 0.6;
          cursor: not-allowed;
          transform: none;
        }

        .connection-quality-bar {
          display: flex;
          align-items: center;
          gap: 2px;
          margin-left: 4px;
        }

        .quality-bar {
          width: 3px;
          height: 12px;
          background: #e5e7eb;
          border-radius: 1px;
          transition: all 0.3s ease;
        }

        .quality-bar.active {
          background: #10b981;
        }

        .quality-bar.slow {
          background: #f59e0b;
        }

        .quality-bar.poor {
          background: #ef4444;
        }
      `;
      document.head.appendChild(styles);
    }
  }

  createConnectionToast() {
    const toast = document.createElement('div');
    toast.id = 'connectionToast';
    toast.className = 'connection-toast';
    document.body.appendChild(toast);

    // Create offline overlay
    const overlay = document.createElement('div');
    overlay.id = 'offlineOverlay';
    overlay.className = 'offline-overlay';
    overlay.innerHTML = `
      <div class="offline-modal">
        <div class="offline-icon">📡</div>
        <div class="offline-title">Connection Lost</div>
        <div class="offline-message">
          Please check your internet connection. Your work is automatically saved locally.
        </div>
        <button class="retry-btn" onclick="window.connectionMonitor.retryConnection()">
          Retry Connection
        </button>
      </div>
    `;
    document.body.appendChild(overlay);
  }

  async startPingMonitoring() {
    // For development/local environments, use less frequent checks and simpler logic
    const isDevelopment = window.location.hostname === 'localhost' || 
                         window.location.hostname === '127.0.0.1' ||
                         window.location.protocol === 'file:';

    if (isDevelopment) {
      // In development, just use navigator.onLine and check less frequently
      this.pingInterval = setInterval(() => {
        this.connectionQuality = navigator.onLine ? 'good' : 'offline';
        this.updateStatus();
      }, 30000); // Check every 30 seconds in development
      
      // Initial status
      this.connectionQuality = navigator.onLine ? 'good' : 'offline';
      this.updateStatus();
    } else {
      // In production, use full ping monitoring
      this.pingInterval = setInterval(async () => {
        await this.checkConnectionQuality();
      }, 10000); // Check every 10 seconds

      // Initial check
      await this.checkConnectionQuality();
    }
  }

  async checkConnectionQuality() {
    if (!navigator.onLine) {
      this.connectionQuality = 'offline';
      this.updateStatus();
      return;
    }

    try {
      const startTime = Date.now();
      
      // Try multiple ping endpoints for better reliability
      const pingEndpoints = [
        // Try current domain first
        window.location.origin + '/?' + Date.now(),
        // Fallback to reliable external endpoints
        'https://www.google.com/favicon.ico?' + Date.now(),
        'https://httpbin.org/status/200?' + Date.now()
      ];

      let response = null;
      let pingTime = 0;

      // Try endpoints in order
      for (const endpoint of pingEndpoints) {
        try {
          const controller = new AbortController();
          const timeoutId = setTimeout(() => controller.abort(), 5000);
          
          response = await fetch(endpoint, {
            method: 'HEAD',
            cache: 'no-cache',
            mode: 'no-cors', // Allow cross-origin for external endpoints
            signal: controller.signal
          });
          
          clearTimeout(timeoutId);
          pingTime = Date.now() - startTime;
          break; // Success, exit loop
        } catch (fetchError) {
          // Continue to next endpoint
          continue;
        }
      }

      this.lastPingTime = pingTime;

      // Determine connection quality based on ping time
      if (pingTime > 0) {
        if (pingTime < 500) {
          this.connectionQuality = 'good';
        } else if (pingTime < 2000) {
          this.connectionQuality = 'slow';
        } else {
          this.connectionQuality = 'poor';
        }
        this.retryAttempts = 0;
      } else {
        throw new Error('All ping endpoints failed');
      }
    } catch (error) {
      // Only log warning if we're not already offline
      if (this.connectionQuality !== 'offline') {
        console.warn('Connection check failed, using navigator.onLine status');
      }
      
      this.retryAttempts++;
      
      // Use navigator.onLine as fallback
      if (navigator.onLine) {
        // If browser says we're online but ping failed, mark as poor connection
        this.connectionQuality = this.retryAttempts >= this.maxRetries ? 'poor' : 'slow';
      } else {
        this.connectionQuality = 'offline';
      }
    }

    this.updateStatus();
  }

  updateStatus() {
    const indicator = document.getElementById('connectionIndicator');
    const dot = indicator?.querySelector('.connection-dot');
    const text = indicator?.querySelector('.connection-text');

    if (!indicator) return;

    // Update visual indicator
    dot.className = 'connection-dot';
    
    switch (this.connectionQuality) {
      case 'good':
        text.textContent = '🟢 Connected';
        break;
      case 'slow':
        dot.classList.add('slow');
        text.textContent = '🟡 Slow Connection';
        break;
      case 'poor':
        dot.classList.add('slow');
        text.textContent = '🟠 Poor Connection';
        break;
      case 'offline':
        dot.classList.add('offline');
        text.textContent = '🔴 Offline';
        break;
    }

    // Show/hide offline overlay
    const overlay = document.getElementById('offlineOverlay');
    if (overlay) {
      if (this.connectionQuality === 'offline') {
        overlay.classList.add('show');
      } else {
        overlay.classList.remove('show');
      }
    }
  }

  handleOnline() {
    console.log('Connection restored');
    this.isOnline = true;
    this.retryAttempts = 0;
    this.checkConnectionQuality();
    this.showToast('🟢 Connection Restored', 'You\'re back online!', 'success');
  }

  handleOffline() {
    console.log('Connection lost');
    this.isOnline = false;
    this.connectionQuality = 'offline';
    this.updateStatus();
    this.showToast('🔴 Connection Lost', 'Working offline. Data will sync when reconnected.', 'error');
  }

  showToast(title, message, type = 'success') {
    const toast = document.getElementById('connectionToast');
    if (!toast) return;

    toast.className = `connection-toast ${type}`;
    toast.innerHTML = `
      <div class="toast-header">${title}</div>
      <div class="toast-message">${message}</div>
    `;

    toast.classList.add('show');

    // Auto-hide after 4 seconds
    setTimeout(() => {
      toast.classList.remove('show');
    }, 4000);
  }

  async retryConnection() {
    const btn = document.querySelector('.retry-btn');
    if (btn) {
      btn.disabled = true;
      btn.textContent = 'Checking...';
    }

    // For development environments, just check navigator.onLine
    const isDevelopment = window.location.hostname === 'localhost' || 
                         window.location.hostname === '127.0.0.1' ||
                         window.location.protocol === 'file:';

    if (isDevelopment) {
      this.connectionQuality = navigator.onLine ? 'good' : 'offline';
      this.updateStatus();
    } else {
      await this.checkConnectionQuality();
    }

    setTimeout(() => {
      if (btn) {
        btn.disabled = false;
        btn.textContent = 'Retry Connection';
      }
    }, 2000);
  }

  getConnectionStatus() {
    return {
      isOnline: this.isOnline,
      quality: this.connectionQuality,
      pingTime: this.lastPingTime
    };
  }

  destroy() {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
    }
    
    window.removeEventListener('online', this.handleOnline);
    window.removeEventListener('offline', this.handleOffline);
  }
}

// Initialize connection monitor when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  window.connectionMonitor = new ConnectionMonitor();
});

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ConnectionMonitor;
}

console.log('ConnectionMonitor: Initialized successfully');
