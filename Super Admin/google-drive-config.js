// Google Drive API Configuration
// Replace these values with your actual Google Drive API credentials

const GOOGLE_DRIVE_CONFIG = {
    // API key and Client ID are now managed securely by the Supabase Edge Function backend
    apiKey: '', // Managed by backend
    clientId: '', // Managed by backend
    clientSecret: '', // Leave empty for web applications
    
    // Folder ID where files will be stored (optional)
    // To get a folder ID: Right-click on a Google Drive folder → Share → Copy link → Extract the folder ID from the URL
    folderId: '', // Optional: Add a specific folder ID if you want files in a particular folder
    
    // File size limit for Google Drive (in bytes) - 50MB
    maxFileSize: 50 * 1024 * 1024,
    
    // Supported file types
    supportedTypes: [
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain',
        'image/jpeg',
        'image/png',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation'
    ]
};

// Export for use in other files
window.GOOGLE_DRIVE_CONFIG = GOOGLE_DRIVE_CONFIG;

// Instructions for setup:
// 1. API key and Client ID are now managed by the backend (Supabase Edge Function)
// 2. Do not include sensitive credentials in frontend code

// 1. Go to https://console.cloud.google.com/
// 2. Create a new project or select existing one
// 3. Enable Google Drive API
// 4. Create API Key and OAuth 2.0 Client ID
// 5. Replace the placeholder values above with your actual credentials
// 6. For production, add your actual domain to authorized origins 