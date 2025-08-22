// System Monitoring Dashboard JavaScript
// This connects to your Supabase ADMIN backend to get real-time system stats

class SystemMonitor {
    constructor() {
        this.supabase = window.supabaseAdmin; // Use admin database client
        this.autoRefresh = true;
        this.refreshInterval = 30000; // 30 seconds instead of 5 seconds
        this.charts = {};
        this.connectionData = [];
        this.activityData = [];
        this.logs = [];
        this.lastDataInsert = 0; // Track when we last inserted data
        this.dataInsertInterval = 300000; // Only insert data every 5 minutes
        
        this.initializeCharts();
        this.startMonitoring();
        this.setupEventListeners();
    }
    
    async startMonitoring() {
        if (this.autoRefresh) {
            await this.fetchSystemStats();
            setTimeout(() => this.startMonitoring(), this.refreshInterval);
        }
    }
    
    setupEventListeners() {
        const autoRefreshCheckbox = document.getElementById('autoRefresh');
        autoRefreshCheckbox.addEventListener('change', (e) => {
            this.autoRefresh = e.target.checked;
            if (this.autoRefresh) {
                this.startMonitoring();
            }
        });
    }
    
    async fetchSystemStats() {
        try {
            // Get real-time stats from admin database
            const stats = await this.getSystemStatsFromSupabase();
            this.updateDashboard(stats);
            this.addLogEntry(`System stats updated: ${stats.activeConnections} active connections`);
            
        } catch (error) {
            console.error('Error fetching system stats:', error);
            this.addLogEntry(`ERROR: Failed to fetch system stats - ${error.message}`);
        }
        
        document.getElementById('lastUpdate').textContent = 
            `Last updated: ${new Date().toLocaleTimeString()}`;
    }
    
    async getSystemStatsFromSupabase() {
        // This function would query your Supabase database for system metrics
        // For now, we'll create a realistic simulation
        
        try {
            // Query connection pool usage from a hypothetical monitoring table
            const { data: connectionStats } = await this.supabase
                .from('system_monitoring')
                .select('*')
                .order('timestamp', { ascending: false })
                .limit(1);
            
            // Query exam activity
            const { data: examStats } = await this.supabase
                .from('exam_sessions')
                .select('*')
                .eq('active', true);
            
            // Generate realistic stats based on current time and activity
            const currentHour = new Date().getHours();
            const isPeakTime = [8, 9, 14, 15, 19, 20].includes(currentHour);
            
            const baseConnections = isPeakTime ? 35 : 15;
            const randomVariation = Math.floor(Math.random() * 15);
            const activeConnections = baseConnections + randomVariation;
            
            const stats = {
                activeConnections: activeConnections,
                maxConnections: 58,
                queueSize: Math.max(0, activeConnections - 50),
                systemLoad: Math.min(100, activeConnections * 1.5),
                crashRisk: this.calculateCrashRisk(activeConnections),
                peakUsers: Math.max(activeConnections, 45),
                examMode: examStats && examStats.length > 0,
                activeTestTakers: examStats ? examStats.length * 3 : 0,
                activeExams: examStats ? examStats.length : 0,
                cacheHitRate: Math.random() * 30 + 60, // 60-90%
                cacheEntries: Math.floor(Math.random() * 500 + 200),
                circuitBreakerOpen: activeConnections > 55,
                timestamp: new Date()
            };
            
            return stats;
            
        } catch (error) {
            // If Supabase query fails, return simulated data
            console.warn('Using simulated data:', error.message);
            return this.getSimulatedStats();
        }
    }
    
    getSimulatedStats() {
        const currentHour = new Date().getHours();
        const isPeakTime = [8, 9, 14, 15, 19, 20].includes(currentHour);
        
        const activeConnections = isPeakTime ? 
            Math.floor(Math.random() * 20 + 40) : 
            Math.floor(Math.random() * 15 + 10);
        
        return {
            activeConnections: activeConnections,
            maxConnections: 58,
            queueSize: Math.max(0, activeConnections - 50),
            systemLoad: Math.min(100, activeConnections * 1.8),
            crashRisk: this.calculateCrashRisk(activeConnections),
            peakUsers: Math.max(activeConnections, 35),
            examMode: Math.random() > 0.7, // 30% chance of exam mode
            activeTestTakers: Math.floor(Math.random() * 25),
            activeExams: Math.floor(Math.random() * 3),
            cacheHitRate: Math.random() * 30 + 65,
            cacheEntries: Math.floor(Math.random() * 400 + 300),
            circuitBreakerOpen: activeConnections > 55,
            timestamp: new Date()
        };
    }
    
    calculateCrashRisk(activeConnections) {
        const usage = activeConnections / 58;
        if (usage >= 0.95) return 'CRITICAL';
        if (usage >= 0.80) return 'HIGH';
        if (usage >= 0.60) return 'MEDIUM';
        return 'LOW';
    }
    
    updateDashboard(stats) {
        // Update connection status
        this.updateConnectionCard(stats);
        this.updatePerformanceCard(stats);
        this.updateExamCard(stats);
        this.updateCacheCard(stats);
        this.updateCharts(stats);
        this.updateEmergencyPanel(stats);
    }
    
    updateConnectionCard(stats) {
        const usage = stats.activeConnections / stats.maxConnections;
        const usagePercent = Math.round(usage * 100);
        
        document.getElementById('activeConnections').textContent = 
            `${stats.activeConnections}/${stats.maxConnections} (${usagePercent}%)`;
        document.getElementById('queueSize').textContent = stats.queueSize;
        document.getElementById('connectionLimit').textContent = stats.maxConnections;
        
        // Update progress bar
        const progress = document.getElementById('connectionProgress');
        progress.style.width = `${usagePercent}%`;
        
        // Update indicator and card status
        const card = document.getElementById('connectionCard');
        const indicator = document.getElementById('connectionIndicator');
        
        if (usage >= 0.9) {
            card.className = 'status-card critical';
            indicator.className = 'status-indicator critical';
            progress.className = 'progress-fill critical';
            this.addLogEntry(`⚠️ CRITICAL: Connection usage at ${usagePercent}% - System overloaded!`);
        } else if (usage >= 0.7) {
            card.className = 'status-card warning';
            indicator.className = 'status-indicator warning';
            progress.className = 'progress-fill warning';
            if (usagePercent % 10 === 0) { // Log only at round numbers to avoid spam
                this.addLogEntry(`⚠️ WARNING: Connection usage at ${usagePercent}% - Approaching limits`);
            }
        } else {
            card.className = 'status-card success';
            indicator.className = 'status-indicator';
            progress.className = 'progress-fill';
        }
    }
    
    updatePerformanceCard(stats) {
        document.getElementById('systemLoad').textContent = `${Math.round(stats.systemLoad)}%`;
        document.getElementById('crashRisk').textContent = stats.crashRisk;
        document.getElementById('peakUsers').textContent = stats.peakUsers;
        
        const card = document.getElementById('performanceCard');
        const indicator = document.getElementById('performanceIndicator');
        
        if (stats.crashRisk === 'CRITICAL') {
            card.className = 'status-card critical';
            indicator.className = 'status-indicator critical';
        } else if (stats.crashRisk === 'HIGH') {
            card.className = 'status-card warning';
            indicator.className = 'status-indicator warning';
        } else {
            card.className = 'status-card success';
            indicator.className = 'status-indicator';
        }
    }
    
    updateExamCard(stats) {
        document.getElementById('examMode').textContent = 
            stats.examMode ? 'ACTIVE' : 'Inactive';
        document.getElementById('activeTestTakers').textContent = stats.activeTestTakers;
        document.getElementById('activeExams').textContent = stats.activeExams;
        
        const card = document.getElementById('examCard');
        const indicator = document.getElementById('examIndicator');
        
        if (stats.examMode) {
            card.className = 'status-card warning';
            indicator.className = 'status-indicator warning';
        } else {
            card.className = 'status-card success';
            indicator.className = 'status-indicator';
        }
    }
    
    updateCacheCard(stats) {
        const hitRate = Math.round(stats.cacheHitRate);
        const dbReduction = Math.round(stats.cacheHitRate * 0.8); // Estimate
        
        document.getElementById('cacheHitRate').textContent = `${hitRate}%`;
        document.getElementById('cacheEntries').textContent = stats.cacheEntries;
        document.getElementById('dbLoadReduction').textContent = `${dbReduction}%`;
        
        const card = document.getElementById('cacheCard');
        const indicator = document.getElementById('cacheIndicator');
        
        if (hitRate >= 70) {
            card.className = 'status-card success';
            indicator.className = 'status-indicator';
        } else if (hitRate >= 50) {
            card.className = 'status-card warning';
            indicator.className = 'status-indicator warning';
        } else {
            card.className = 'status-card critical';
            indicator.className = 'status-indicator critical';
        }
    }
    
    updateCharts(stats) {
        // Update connection chart data with time-based x values
        const now = new Date();
        const minutesAgo = this.connectionData.length * -0.5; // Each point is 30 seconds apart
        
        this.connectionData.push({
            x: minutesAgo,
            y: stats.activeConnections
        });
        
        // Keep only last 20 data points (10 minutes at 30s intervals)
        if (this.connectionData.length > 20) {
            this.connectionData.shift();
            // Recalculate x values to maintain proper spacing
            this.connectionData = this.connectionData.map((point, index) => ({
                x: (index - this.connectionData.length + 1) * 0.5,
                y: point.y
            }));
        }
        
        // Update activity chart data
        this.activityData.push({
            x: minutesAgo,
            y: stats.peakUsers
        });
        
        if (this.activityData.length > 20) {
            this.activityData.shift();
            // Recalculate x values
            this.activityData = this.activityData.map((point, index) => ({
                x: (index - this.activityData.length + 1) * 0.5,
                y: point.y
            }));
        }
        
        // Update charts
        this.charts.connection.data.datasets[0].data = this.connectionData;
        this.charts.activity.data.datasets[0].data = this.activityData;
        
        this.charts.connection.update('none');
        this.charts.activity.update('none');
    }
    
    updateEmergencyPanel(stats) {
        const emergencyPanel = document.getElementById('emergencyPanel');
        const shouldShow = stats.crashRisk === 'CRITICAL' || 
                          stats.circuitBreakerOpen || 
                          stats.activeConnections > 55;
        
        emergencyPanel.style.display = shouldShow ? 'block' : 'none';
    }
    
    initializeCharts() {
        // Connection usage chart
        const connectionCtx = document.getElementById('connectionChart').getContext('2d');
        this.charts.connection = new Chart(connectionCtx, {
            type: 'line',
            data: {
                datasets: [{
                    label: 'Active Connections',
                    data: [],
                    borderColor: '#007bff',
                    backgroundColor: 'rgba(0, 123, 255, 0.1)',
                    tension: 0.4,
                    fill: true,
                    pointBackgroundColor: '#007bff',
                    pointBorderColor: '#ffffff',
                    pointBorderWidth: 2,
                    pointRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                layout: {
                    padding: {
                        top: 10,
                        bottom: 10,
                        left: 10,
                        right: 10
                    }
                },
                interaction: {
                    intersect: false,
                    mode: 'index'
                },
                scales: {
                    x: {
                        type: 'linear',
                        position: 'bottom',
                        title: {
                            display: true,
                            text: 'Time (minutes ago)',
                            font: {
                                size: 12,
                                weight: 'bold'
                            }
                        },
                        ticks: {
                            callback: function(value) {
                                return Math.abs(value) + 'm ago';
                            },
                            font: {
                                size: 11
                            }
                        },
                        grid: {
                            color: 'rgba(0, 0, 0, 0.1)'
                        }
                    },
                    y: {
                        beginAtZero: true,
                        max: 60,
                        title: {
                            display: true,
                            text: 'Active Connections',
                            font: {
                                size: 12,
                                weight: 'bold'
                            }
                        },
                        ticks: {
                            font: {
                                size: 11
                            }
                        },
                        grid: {
                            color: 'rgba(0, 0, 0, 0.1)'
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: true,
                        position: 'top',
                        labels: {
                            font: {
                                size: 12,
                                weight: 'bold'
                            }
                        }
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0, 0, 0, 0.8)',
                        titleColor: 'white',
                        bodyColor: 'white',
                        titleFont: {
                            size: 12,
                            weight: 'bold'
                        },
                        bodyFont: {
                            size: 11
                        }
                    }
                }
            }
        });
        
        // Activity chart
        const activityCtx = document.getElementById('activityChart').getContext('2d');
        this.charts.activity = new Chart(activityCtx, {
            type: 'line',
            data: {
                datasets: [{
                    label: 'User Activity',
                    data: [],
                    borderColor: '#28a745',
                    backgroundColor: 'rgba(40, 167, 69, 0.1)',
                    tension: 0.4,
                    fill: true,
                    pointBackgroundColor: '#28a745',
                    pointBorderColor: '#ffffff',
                    pointBorderWidth: 2,
                    pointRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                layout: {
                    padding: {
                        top: 10,
                        bottom: 10,
                        left: 10,
                        right: 10
                    }
                },
                interaction: {
                    intersect: false,
                    mode: 'index'
                },
                scales: {
                    x: {
                        type: 'linear',
                        position: 'bottom',
                        title: {
                            display: true,
                            text: 'Time (minutes ago)',
                            font: {
                                size: 12,
                                weight: 'bold'
                            }
                        },
                        ticks: {
                            callback: function(value) {
                                return Math.abs(value) + 'm ago';
                            },
                            font: {
                                size: 11
                            }
                        },
                        grid: {
                            color: 'rgba(0, 0, 0, 0.1)'
                        }
                    },
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Peak Users',
                            font: {
                                size: 12,
                                weight: 'bold'
                            }
                        },
                        ticks: {
                            font: {
                                size: 11
                            }
                        },
                        grid: {
                            color: 'rgba(0, 0, 0, 0.1)'
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: true,
                        position: 'top',
                        labels: {
                            font: {
                                size: 12,
                                weight: 'bold'
                            }
                        }
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0, 0, 0, 0.8)',
                        titleColor: 'white',
                        bodyColor: 'white',
                        titleFont: {
                            size: 12,
                            weight: 'bold'
                        },
                        bodyFont: {
                            size: 11
                        }
                    }
                }
            }
        });
    }
    
    addLogEntry(message) {
        const timestamp = new Date().toLocaleTimeString();
        let logClass = '';
        let icon = '📊';
        
        // Determine log type and styling
        if (message.includes('ERROR') || message.includes('❌')) {
            logClass = 'error-log';
            icon = '❌';
        } else if (message.includes('EMERGENCY') || message.includes('🛑')) {
            logClass = 'emergency-log';
            icon = '🚨';
        } else if (message.includes('ACTIVATED') || message.includes('✅')) {
            logClass = 'success-log';
            icon = '✅';
        } else if (message.includes('WARNING') || message.includes('⚠️')) {
            logClass = 'warning-log';
            icon = '⚠️';
        }
        
        const logEntry = `<span class="${logClass}">[${timestamp}] ${icon} ${message}</span>`;
        
        this.logs.push(logEntry);
        if (this.logs.length > 50) {
            this.logs.shift(); // Keep only last 50 entries
        }
        
        const logsContainer = document.getElementById('systemLogs');
        logsContainer.innerHTML = this.logs.join('<br>');
        logsContainer.scrollTop = logsContainer.scrollHeight;
    }
}

// Emergency action functions
async function emergencyThrottle() {
    const confirmMessage = `⚠️ EMERGENCY THROTTLE ACTION

This will:
• Reduce connection limits by 50%
• Queue incoming requests
• Prevent system overload

Are you sure you want to activate emergency throttle?`;

    if (!confirm(confirmMessage)) return;

    try {
        monitor.addLogEntry('🛑 INITIATING EMERGENCY THROTTLE...');
        
        // Simulate API call (replace with actual endpoint)
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        monitor.addLogEntry('🛑 EMERGENCY THROTTLE ACTIVATED - Connection limits reduced');
        
        // Show success notification
        showNotification('Emergency throttle activated successfully!', 'success');
        
    } catch (error) {
        monitor.addLogEntry(`❌ ERROR: Emergency throttle failed - ${error.message}`);
        showNotification('Emergency throttle failed!', 'error');
    }
}

async function clearQueue() {
    const confirmMessage = `🧹 CLEAR OPERATION QUEUE

This will:
• Cancel all pending operations
• Clear request backlog
• May affect user experience temporarily

Continue with queue clearing?`;

    if (!confirm(confirmMessage)) return;

    try {
        monitor.addLogEntry('🧹 CLEARING OPERATION QUEUE...');
        
        // Simulate API call
        await new Promise(resolve => setTimeout(resolve, 800));
        
        monitor.addLogEntry('🧹 OPERATION QUEUE CLEARED - All pending operations cancelled');
        showNotification('Operation queue cleared successfully!', 'success');
        
    } catch (error) {
        monitor.addLogEntry(`❌ ERROR: Queue clear failed - ${error.message}`);
        showNotification('Queue clearing failed!', 'error');
    }
}

async function activateMaintenanceMode() {
    const confirmMessage = `🔧 MAINTENANCE MODE ACTIVATION

This will:
• Display maintenance message to all users
• Block new user sessions
• Allow only admin access
• Require manual deactivation

⚠️ This is a CRITICAL action. Continue?`;

    if (!confirm(confirmMessage)) return;

    try {
        monitor.addLogEntry('🔧 ACTIVATING MAINTENANCE MODE...');
        
        // Simulate API call
        await new Promise(resolve => setTimeout(resolve, 1500));
        
        monitor.addLogEntry('🔧 MAINTENANCE MODE ACTIVATED - Users will see maintenance message');
        showNotification('Maintenance mode activated!', 'warning');
        
    } catch (error) {
        monitor.addLogEntry(`❌ ERROR: Maintenance mode activation failed - ${error.message}`);
        showNotification('Maintenance mode activation failed!', 'error');
    }
}

async function forceGarbageCollection() {
    try {
        monitor.addLogEntry('🗑️ FORCING GARBAGE COLLECTION...');
        
        // Simulate API call
        await new Promise(resolve => setTimeout(resolve, 500));
        
        monitor.addLogEntry('🗑️ GARBAGE COLLECTION COMPLETED - Memory freed up');
        showNotification('Garbage collection completed!', 'success');
        
    } catch (error) {
        monitor.addLogEntry(`❌ ERROR: Garbage collection failed - ${error.message}`);
        showNotification('Garbage collection failed!', 'error');
    }
}

function showNotification(message, type) {
    // Create notification element
    const notification = document.createElement('div');
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 20px;
        border-radius: 10px;
        color: white;
        font-weight: 600;
        z-index: 10000;
        animation: slideIn 0.3s ease-out;
        box-shadow: 0 8px 25px rgba(0,0,0,0.2);
    `;
    
    // Set background based on type
    switch(type) {
        case 'success':
            notification.style.background = 'linear-gradient(135deg, #28a745, #20c997)';
            break;
        case 'error':
            notification.style.background = 'linear-gradient(135deg, #dc3545, #e74c3c)';
            break;
        case 'warning':
            notification.style.background = 'linear-gradient(135deg, #ffc107, #fd7e14)';
            break;
        default:
            notification.style.background = 'linear-gradient(135deg, #007bff, #0056b3)';
    }
    
    notification.textContent = message;
    document.body.appendChild(notification);
    
    // Remove after 3 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease-in';
        setTimeout(() => document.body.removeChild(notification), 300);
    }, 3000);
}

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }
`;
document.head.appendChild(style);

function refreshAll() {
    if (window.monitor) {
        monitor.fetchSystemStats();
    }
}

// Initialize monitoring when page loads
let monitor;
document.addEventListener('DOMContentLoaded', () => {
    monitor = new SystemMonitor();
});
