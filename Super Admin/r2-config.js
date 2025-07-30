// Cloudflare R2 Configuration
// Replace these values with your actual Cloudflare R2 credentials

const R2_CONFIG = {
    // Your Cloudflare R2 endpoint (found in your R2 dashboard)
    endpoint: 'https://your-account-id.r2.cloudflarestorage.com',
    
    // Your R2 bucket name
    bucketName: 'edunest-files',
    
    // Your R2 access key ID (create in R2 dashboard)
    accessKeyId: 'your-access-key-id',
    
    // Your R2 secret access key (create in R2 dashboard)
    secretAccessKey: 'your-secret-access-key',
    
    // Public URL for your R2 bucket (if you have a custom domain)
    publicUrl: 'https://your-custom-domain.com' // Optional: use custom domain for public access
};

// Export for use in other files
window.R2_CONFIG = R2_CONFIG; 