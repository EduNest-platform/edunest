// File Management JavaScript

let currentSubjectId = null;
let currentSubjectName = '';
let allFiles = [];
let filesByType = {
    all: [],
    notes: [],
    pyq: [],
    assignment: [],
    lab_manuals: [],
    code: [],
    other: []
};
let currentFilter = 'all';

// --- Google Identity Services (GIS) Integration ---
let googleTokenClient = null;
let googleAccessToken = null;

// --- Google Drive Link Conversion Utility ---
function convertGoogleDriveLink(originalUrl) {
    // Check if it's a Google Drive view link
    const driveViewPattern = /https:\/\/drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)\/view/;
    const match = originalUrl.match(driveViewPattern);
    
    if (match) {
        const fileId = match[1];
        return `https://drive.google.com/uc?export=download&id=${fileId}`;
    }
    
    // If it's already a direct download link, return as is
    if (originalUrl.includes('uc?export=download')) {
        return originalUrl;
    }
    
    // If it's not a Google Drive link, return as is
    return originalUrl;
}

function isGoogleDriveLink(url) {
    return url.includes('drive.google.com');
}

function validateAndConvertFileUrl(fileUrl) {
    if (isGoogleDriveLink(fileUrl)) {
        const convertedUrl = convertGoogleDriveLink(fileUrl);
        if (convertedUrl !== fileUrl) {
            return convertedUrl;
        }
    }
    return fileUrl;
}

// --- Upload Modal Logic ---
function showUploadModalConnecting() {
    const modal = document.getElementById('uploadModal');
    document.getElementById('uploadConnecting').style.display = '';
    document.getElementById('uploadProgressState').style.display = 'none';
    modal.style.display = 'flex';
}
function showUploadModalProgress(percent, uploadedMB, totalMB, remainingMB, eta) {
    const modal = document.getElementById('uploadModal');
    document.getElementById('uploadConnecting').style.display = 'none';
    document.getElementById('uploadProgressState').style.display = '';
    modal.style.display = 'flex';
    document.getElementById('uploadBarInner').style.width = percent + '%';
    document.getElementById('uploadPercentBadge').textContent = percent + '%';
    document.getElementById('uploadedMB').textContent = uploadedMB + ' MB';
    document.getElementById('totalMB').textContent = totalMB + ' MB';
    document.getElementById('remainingMB').textContent = remainingMB + ' MB';
    document.getElementById('eta').textContent = eta;
}
function hideUploadModal() {
    const modal = document.getElementById('uploadModal');
    modal.style.display = 'none';
}

// --- Replace uploadToGoogleDrive to use modal ---
async function uploadToGoogleDrive(file) {
    showUploadModalConnecting();
    try {
        if (!window.supabaseAdmin || !window.supabaseAdmin.auth) {
            showMessage('Internal error: Authentication client not initialized. Please refresh the page.', 'error');
            throw new Error('Supabase Admin client not initialized');
        }
        const formData = new FormData();
        formData.append('file', file);
        formData.append('fileName', file.name);
        const { data: { session } } = await window.supabaseAdmin.auth.getSession();
        const accessToken = session?.access_token;
        return await new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            xhr.open('POST', 'https://pfuzvpihupvhjshxiofn.functions.supabase.co/google-drive');
            if (accessToken) {
                xhr.setRequestHeader('Authorization', `Bearer ${accessToken}`);
            }
            let startTime = null;
            xhr.upload.onprogress = function (event) {
                if (!startTime) startTime = Date.now();
                if (event.lengthComputable) {
                    const percent = Math.round((event.loaded / event.total) * 100);
                    const uploadedMB = (event.loaded / 1024 / 1024).toFixed(2);
                    const totalMB = (event.total / 1024 / 1024).toFixed(2);
                    const remainingMB = ((event.total - event.loaded) / 1024 / 1024).toFixed(2);
                    const elapsed = (Date.now() - startTime) / 1000; // seconds
                    const speed = event.loaded / elapsed; // bytes/sec
                    const remaining = event.total - event.loaded;
                    const eta = speed > 0 ? (remaining / speed) : 0;
                    const etaStr = eta > 0 ? formatTime(eta) : '--';
                    showUploadModalProgress(percent, uploadedMB, totalMB, remainingMB, etaStr);
                }
            };
            xhr.onloadstart = function () {
                showUploadModalConnecting();
            };
            xhr.onreadystatechange = function () {
                if (xhr.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
                    // Switch to progress state as soon as upload starts
                    showUploadModalProgress(0, '0.00', (file.size / 1024 / 1024).toFixed(2), (file.size / 1024 / 1024).toFixed(2), '--');
                }
            };
            xhr.onload = function () {
                hideUploadModal();
                if (xhr.status === 200) {
                    showMessage('File uploaded successfully to Google Drive!', 'success');
                    try {
                        const data = JSON.parse(xhr.responseText);
                        resolve({ fileUrl: data.fileUrl, fileId: data.fileId });
                    } catch (e) {
                        reject('Invalid response from server');
                    }
                } else {
                    let errorText = xhr.responseText || xhr.statusText;
                    showMessage('Google Drive upload failed: ' + errorText, 'error');
                    reject('Google Drive upload failed: ' + errorText);
                }
            };
            xhr.onerror = function () {
                hideUploadModal();
                showMessage('Upload failed: Network error', 'error');
                reject('Network error');
            };
            xhr.onabort = function () {
                hideUploadModal();
                showMessage('Upload cancelled.', 'error');
                reject('Upload cancelled');
            };
            xhr.send(formData);
        });
    } catch (error) {
        hideUploadModal();
        showMessage('Upload failed: ' + (error.message || error), 'error');
        throw error;
    }
}

function setLoadingText(text) {
    const loadingText = document.getElementById('loadingText');
    if (loadingText) loadingText.textContent = text;
}

function formatTime(seconds) {
    seconds = Math.round(seconds);
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins > 0 ? mins + 'm ' : ''}${secs}s`;
}

// Initialize page
document.addEventListener('DOMContentLoaded', function() {
    loadContext();
    loadFiles();
    setupEventListeners();

    // Always update tag dropdown and show/hide on load
    const fileType = document.getElementById('fileType').value;
    const tagGroup = document.getElementById('tagSelectorGroup');
    if (fileType) {
        tagGroup.style.display = '';
        updateTagDropdown();
    } else {
        tagGroup.style.display = 'none';
    }

    document.getElementById('fileType').addEventListener('change', () => {
        updateTagDropdown();
        currentTags = [];
        renderSelectedTags();
        const fileType = document.getElementById('fileType').value;
        const tagGroup = document.getElementById('tagSelectorGroup');
        if (fileType) {
            tagGroup.style.display = '';
        } else {
            tagGroup.style.display = 'none';
        }
    });
    document.getElementById('addTagBtn').addEventListener('click', () => {
        const dropdown = document.getElementById('tagDropdown');
        const customInput = document.getElementById('customTagInput');
        let tag = customInput.value.trim() || dropdown.value;
        if (tag && !currentTags.includes(tag)) {
            currentTags.push(tag);
            renderSelectedTags();
        }
        customInput.value = '';
    });
    document.getElementById('customTagInput').addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            document.getElementById('addTagBtn').click();
            e.preventDefault();
        }
    });

    // Disable upload button until supabaseAdmin is ready
    const uploadBtn = document.querySelector('.submit-btn');
    uploadBtn.disabled = true;
    function checkSupabaseAdminReady() {
        if (window.supabaseAdmin && window.supabaseAdmin.auth) {
            uploadBtn.disabled = false;
        } else {
            setTimeout(checkSupabaseAdminReady, 100);
        }
    }
    checkSupabaseAdminReady();

    // Make file input container clickable
    const fileInputContainer = document.getElementById('fileInputContainer');
    const fileInput = document.getElementById('fileInput');
    if (fileInputContainer && fileInput) {
        fileInputContainer.addEventListener('click', function(e) {
            // Only trigger if not clicking the hidden input directly
            if (e.target !== fileInput) {
                fileInput.click();
            }
        });
        fileInputContainer.setAttribute('tabindex', '0');
        fileInputContainer.setAttribute('role', 'button');
        fileInputContainer.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' || e.key === ' ') {
                fileInput.click();
                e.preventDefault();
            }
        });
    }
});

// Load context from sessionStorage
function loadContext() {
    const subjectData = sessionStorage.getItem('selectedSubject');
    if (subjectData) {
        const subject = JSON.parse(subjectData);
        currentSubjectId = subject.id;
        currentSubjectName = subject.name;
        
        // Update context display
        document.getElementById('contextCollege').textContent = subject.college || 'College';
        document.getElementById('contextBranch').textContent = subject.branch || 'Branch';
        document.getElementById('contextSemester').textContent = subject.semester || 'Semester';
        document.getElementById('contextSubject').textContent = subject.name;
        
        // Update descriptions
        document.getElementById('uploadDescription').textContent = 
            `Upload notes, PYQ, and other study materials for ${subject.name}`;
        document.getElementById('filesListDescription').textContent = 
            `Manage uploaded files for ${subject.name}`;
    } else {
        showMessage('No subject selected. Please go back and select a subject.', 'error');
    }
}

// Setup event listeners
function setupEventListeners() {
    // File input change
    const fileInput = document.getElementById('fileInput');
    fileInput.addEventListener('change', handleFileSelect);
    
    // Filter tabs
    const filterTabs = document.querySelectorAll('.filter-tab');
    filterTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            const filter = this.dataset.filter;
            setActiveFilter(filter);
        });
    });
    
    // Search functionality
    const searchInput = document.getElementById('fileSearchInput');
    if (searchInput) {
        searchInput.addEventListener('input', function() {
            filterFilesBySearch(this.value);
        });
    }
}

// Handle file selection
function handleFileSelect(event) {
    const file = event.target.files[0];
    if (file) {
        const fileInfo = document.getElementById('fileInfo');
        const fileName = document.getElementById('selectedFileName');
        const fileSize = document.getElementById('selectedFileSize');
        const storageIndicator = document.getElementById('storageIndicator');
        
        fileName.textContent = file.name;
        fileSize.textContent = formatFileSize(file.size);
        
        // Determine storage provider
        const isLargeFile = file.size > 5 * 1024 * 1024; // 5MB
        if (isLargeFile) {
            storageIndicator.textContent = '☁️ Will be stored in Google Drive';
            storageIndicator.className = 'storage-indicator google-drive';
        } else {
            storageIndicator.textContent = '📁 Will be stored in Supabase';
            storageIndicator.className = 'storage-indicator supabase';
        }
        
        fileInfo.style.display = 'flex';
    }
}

// Upload file
async function uploadFile() {
    if (!currentSubjectId) {
        showMessage('No subject selected.', 'error');
        return;
    }
    // Disable upload button to prevent duplicate submissions
    const uploadBtn = document.querySelector('.submit-btn');
    if (uploadBtn) uploadBtn.disabled = true;
    try {
        const fileName = document.getElementById('fileName').value.trim();
        const fileDescription = document.getElementById('fileDescription').value.trim();
        const fileType = document.getElementById('fileType').value;
        let fileTags = Array.isArray(currentTags) ? currentTags : [];
        fileTags = fileTags.map(tag => tag.toString());
        if (!fileTags.length) {
            showMessage('Please add at least one tag before uploading.', 'error');
            return;
        }
        const fileInput = document.getElementById('fileInput');
        
        if (!fileName || !fileType || !fileInput.files[0]) {
            showMessage('Please fill in all required fields and select a file.', 'error');
            return;
        }
        
        const file = fileInput.files[0];
        const isLargeFile = file.size > 5 * 1024 * 1024; // 5MB
        
        let fileUrl;
        let storageProvider;
        let gdriveFileId = null;
        if (isLargeFile) {
            // Upload to Google Drive
            try {
                const gdriveResult = await uploadToGoogleDrive(file);
                fileUrl = gdriveResult.fileUrl;
                gdriveFileId = gdriveResult.fileId;
                storageProvider = 'google-drive';
                // Note: File permissions are automatically set to "Anyone with the link can view"
            } catch (googleError) {
                
                // Check if file is within Supabase limit (50MB)
                if (file.size <= 50 * 1024 * 1024) {
                    fileUrl = await uploadToSupabase(file);
                    storageProvider = 'supabase';
                    showMessage('Google Drive unavailable. File uploaded to Supabase instead.', 'warning');
                } else {
                    throw new Error('File too large for Supabase (>50MB) and Google Drive is unavailable. Please try again or compress the file.');
                }
            }
        } else {
            // Upload to Supabase Storage
            fileUrl = await uploadToSupabase(file);
            storageProvider = 'supabase';
        }
        
        // Convert Google Drive links to direct download links
        const convertedFileUrl = validateAndConvertFileUrl(fileUrl);
        
        // Save file record to database
        const { data, error } = await window.supabaseClient
            .from('files')
            .insert({
                name: fileName,
                description: fileDescription,
                file_type: fileType,
                file_url: convertedFileUrl,
                file_size: file.size,
                mime_type: file.type,
                storage_provider: storageProvider,
                subject_id: currentSubjectId,
                uploaded_by: 'Admin',
                tags: fileTags,
                gdrive_file_id: gdriveFileId
            });
        
        if (error) {
            throw error;
        }
        
        showMessage('File uploaded successfully!', 'success');
        resetForm();
        loadFiles();
        
    } catch (error) {
        console.error('Upload error details:', error);
        console.error('Error type:', typeof error);
        console.error('Error keys:', Object.keys(error));
        console.error('Error stringified:', JSON.stringify(error, null, 2));
        
        // Create a more detailed error message
        let errorMessage = 'Upload failed';
        
        if (error.message) {
            errorMessage += ': ' + error.message;
        } else if (error.details) {
            errorMessage += ': ' + error.details;
        } else if (error.hint) {
            errorMessage += ': ' + error.hint;
        } else if (error.error_description) {
            errorMessage += ': ' + error.error_description;
        } else if (error.error) {
            errorMessage += ': ' + error.error;
        } else if (typeof error === 'string') {
            errorMessage += ': ' + error;
        } else {
            errorMessage += ': ' + (error.toString ? error.toString() : 'Unknown error occurred');
        }
        
        // Add specific error handling for common issues
        if (errorMessage.includes('bucket') || errorMessage.includes('storage')) {
            errorMessage += ' - Please check if Supabase storage bucket is configured';
        } else if (errorMessage.includes('permission') || errorMessage.includes('unauthorized')) {
            errorMessage += ' - Please check your API credentials';
        } else if (errorMessage.includes('network') || errorMessage.includes('fetch')) {
            errorMessage += ' - Please check your internet connection';
        } else if (errorMessage.includes('Google Drive')) {
            errorMessage += ' - Please check Google Drive API configuration';
        }
        
        showMessage(errorMessage, 'error');
    } finally {
        // Re-enable upload button
        if (uploadBtn) uploadBtn.disabled = false;
    }
}

// Sanitize filename to remove emojis and unsupported characters
function sanitizeFileName(name) {
    // Remove emojis and most non-ASCII symbols, allow basic punctuation, spaces, dashes, underscores, and parentheses
    // Replace anything not a-z, A-Z, 0-9, space, dot, dash, underscore, or parentheses with _
    return name.replace(/[^\w\s.\-()@]/gi, '_');
}

// Supabase upload modal logic
function showSupabaseUploadModal() {
    const modal = document.getElementById('supabaseUploadModal');
    if (modal) modal.style.display = 'flex';
}
function hideSupabaseUploadModal() {
    const modal = document.getElementById('supabaseUploadModal');
    if (modal) modal.style.display = 'none';
}

// Upload to Supabase Storage
async function uploadToSupabase(file) {
    let sanitized = sanitizeFileName(file.name);
    if (sanitized !== file.name) {
        showMessage('Some special characters or emojis were removed from the filename for compatibility.', 'warning');
    }
    const fileName = `${Date.now()}_${sanitized}`;
    try {
        const { data, error } = await window.supabaseClient.storage
            .from('edunest-files')
            .upload(fileName, file);
        if (error) {
            throw error;
        }
        const { data: urlData } = window.supabaseClient.storage
            .from('edunest-files')
            .getPublicUrl(fileName);
        return urlData.publicUrl;
    } catch (error) {
        throw error;
    } finally {
        hideSupabaseUploadModal();
    }
}

// Load files from database
async function loadFiles() {
    if (!currentSubjectId) return;
    
    try {
        const { data, error } = await window.supabaseClient
            .from('files')
            .select('*')
            .eq('subject_id', currentSubjectId)
            .order('created_at', { ascending: false });
        
        if (error) {
            throw error;
        }
        
        allFiles = data || [];
        
        // Organize files by type for better performance
        organizeFilesByType();
        updateFileStats();
        renderFiles();
        
    } catch (error) {
        showMessage('Failed to load files: ' + error.message, 'error');
    }
}

// Organize files by type for efficient filtering
function organizeFilesByType() {
    // Reset all type arrays
    filesByType = {
        all: allFiles,
        notes: [],
        pyq: [],
        assignment: [],
        lab_manuals: [],
        code: [],
        other: []
    };
    
    // Categorize files by type
    allFiles.forEach(file => {
        if (filesByType[file.file_type]) {
            filesByType[file.file_type].push(file);
        } else {
            filesByType.other.push(file);
        }
    });
}

// Update file statistics
function updateFileStats() {
    const totalFiles = allFiles.length;
    const notesCount = filesByType.notes.length;
    const pyqCount = filesByType.pyq.length;
    const assignmentCount = filesByType.assignment.length;
    const labManualsCount = filesByType.lab_manuals.length;
    const codeCount = filesByType.code.length;
    const otherCount = filesByType.other.length;
    
    document.getElementById('fileCount').textContent = totalFiles;
    document.getElementById('notesCount').textContent = notesCount;
    
    // Update additional stats if elements exist
    const pyqCountElement = document.getElementById('pyqCount');
    if (pyqCountElement) pyqCountElement.textContent = pyqCount;
    
    // Add more detailed stats
    updateDetailedStats({
        notes: notesCount,
        pyq: pyqCount,
        assignment: assignmentCount,
        lab_manuals: labManualsCount,
        code: codeCount,
        other: otherCount
    });
}

// Update detailed statistics display
function updateDetailedStats(stats) {
    // You can add more detailed stats here
}

// Render files list
function renderFiles() {
    const fileList = document.getElementById('fileList');
    const emptyState = document.getElementById('emptyState');
    
    const filesToShow = filesByType[currentFilter] || [];
    
    if (filesToShow.length === 0) {
        fileList.innerHTML = '';
        emptyState.classList.remove('hidden');
        
        // Update empty state message based on filter
        const emptyStateTitle = document.querySelector('#emptyState h3');
        const emptyStateDesc = document.querySelector('#emptyState p');
        
        if (currentFilter === 'all') {
            emptyStateTitle.textContent = 'No Files Found';
            emptyStateDesc.textContent = 'Start by uploading your first file above.';
        } else {
            const typeLabel = getFileTypeLabel(currentFilter);
            emptyStateTitle.textContent = `No ${typeLabel} Files`;
            emptyStateDesc.textContent = `No ${typeLabel.toLowerCase()} files found. Upload some ${typeLabel.toLowerCase()} files above.`;
        }
        return;
    }
    
    emptyState.classList.add('hidden');
    
    fileList.innerHTML = filesToShow.map(file => `
        <div class="file-card">
            <div class="file-info">
                <div class="file-card-title-row">
                    <span class="file-icon">${getFileIcon(file.file_type)}</span>
                    <span class="file-name">${file.name}</span>
                </div>
                <p class="file-description">${file.description || 'No description'}</p>
                <div class="file-tags">${renderTags(file.tags)}</div>
                <div class="file-meta">
                    <span class="file-type">${getFileTypeLabel(file.file_type)}</span>
                    <span class="file-size">${formatFileSize(file.file_size)}</span>
                    <span class="storage-provider">${getStorageProviderIcon(file.storage_provider)}</span>
                </div>
                <div class="file-actions">
                    <button onclick="deleteFile('${file.id}')" class="action-btn delete">
                        🗑️ Delete
                    </button>
                    ${file.storage_provider === 'google-drive' ? `
                        <button onclick="checkGoogleDriveFileExists('${file.id}')" class="action-btn check-drive">
                            ✅ Check Deletion
                        </button>
                    ` : ''}
                </div>
            </div>
        </div>
    `).join('');
}

// Filter files (now uses pre-organized arrays)
function filterFiles(files, filter) {
    return filesByType[filter] || [];
}

// Set active filter
function setActiveFilter(filter) {
    currentFilter = filter;
    
    // Update active tab
    document.querySelectorAll('.filter-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    document.querySelector(`[data-filter="${filter}"]`).classList.add('active');
    
    // Clear search input when switching filters
    const searchInput = document.getElementById('fileSearchInput');
    if (searchInput) {
        searchInput.value = '';
    }
    
    renderFiles();
}

// Get files by type (public function for external use)
function getFilesByType(type) {
    return filesByType[type] || [];
}

// Get all files
function getAllFiles() {
    return allFiles;
}

// Get file count by type
function getFileCountByType(type) {
    return filesByType[type] ? filesByType[type].length : 0;
}

// Get file icon
function getFileIcon(fileType) {
    const icons = {
        'notes': '📝',
        'pyq': '📋',
        'assignment': '📄',
        'lab_manuals': '🧪',
        'code': '💻',
        'other': '📁'
    };
    return icons[fileType] || '📁';
}

// Get file type label
function getFileTypeLabel(fileType) {
    const labels = {
        'notes': 'Notes',
        'pyq': 'PYQ',
        'assignment': 'Assignment',
        'lab_manuals': 'Lab Manuals',
        'code': 'Code',
        'other': 'Other'
    };
    return labels[fileType] || 'Other';
}

// Get storage provider icon
function getStorageProviderIcon(provider) {
    const icons = {
        'supabase': '📁 Supabase',
        'google-drive': '☁️ Google Drive'
    };
    return icons[provider] || '📁';
}

// Format file size
function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Delete file
async function deleteFile(fileId) {
    // Find the file object to get gdrive_file_id and storage_provider
    const file = allFiles.find(f => f.id === fileId);
    if (!confirm('Are you sure you want to delete this file?')) return;
    try {
        // If Google Drive file, delete from Google Drive first
        if (file && file.storage_provider === 'google-drive' && file.gdrive_file_id) {
            const { data: { session } } = await window.supabaseAdmin.auth.getSession();
            const accessToken = session?.access_token;
            const response = await fetch('https://pfuzvpihupvhjshxiofn.functions.supabase.co/google-drive-delete', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    ...(accessToken ? { 'Authorization': `Bearer ${accessToken}` } : {})
                },
                body: JSON.stringify({ fileId: file.gdrive_file_id })
            });
            const result = await response.json();
            if (!response.ok || !result.success) {
                showMessage('Failed to delete file from Google Drive: ' + (result.error || response.statusText), 'error');
                throw new Error(result.error || 'Google Drive delete failed');
            }
        }
        // Delete from Supabase DB
        const { error } = await window.supabaseClient
            .from('files')
            .delete()
            .eq('id', fileId);
        if (error) {
            throw error;
        }
        showMessage('File deleted successfully!', 'success');
        loadFiles();
    } catch (error) {
        showMessage('Failed to delete file: ' + error.message, 'error');
    }
}

// Reset form
function resetForm() {
    document.getElementById('fileName').value = '';
    document.getElementById('fileDescription').value = '';
    document.getElementById('fileType').value = '';
    document.getElementById('fileInput').value = '';
    document.getElementById('fileInfo').style.display = 'none';
}

// Show message
function showMessage(message, type = 'info') {
    const msgElement = document.getElementById('fileMsg');
    msgElement.textContent = message;
    msgElement.className = `message ${type} show`;
    
    setTimeout(() => {
        msgElement.classList.remove('show');
    }, 5000);
}

// Search files by name or description
function filterFilesBySearch(query) {
    query = query.trim().toLowerCase();
    
    if (!query) {
        // If no search query, show files based on current filter
        renderFiles();
        return;
    }
    
    // Get files from current filter
    const filesToSearch = filesByType[currentFilter] || [];
    
    // Filter files by search query
    const searchResults = filesToSearch.filter(file =>
        (file.name || '').toLowerCase().includes(query) ||
        (file.description || '').toLowerCase().includes(query)
    );
    
    // Render search results
    renderSearchResults(searchResults, query);
}

// Render search results
function renderSearchResults(files, query) {
    const fileList = document.getElementById('fileList');
    const emptyState = document.getElementById('emptyState');
    
    if (files.length === 0) {
        fileList.innerHTML = '';
        emptyState.classList.remove('hidden');
        
        const emptyStateTitle = document.querySelector('#emptyState h3');
        const emptyStateDesc = document.querySelector('#emptyState p');
        
        emptyStateTitle.textContent = 'No Files Found';
        emptyStateDesc.textContent = `No files found matching "${query}". Try a different search term.`;
        return;
    }
    
    emptyState.classList.add('hidden');
    
    fileList.innerHTML = files.map(file => `
        <div class="file-card">
            <div class="file-info">
                <div class="file-card-title-row">
                    <span class="file-icon">${getFileIcon(file.file_type)}</span>
                    <span class="file-name">${highlightSearchTerm(file.name, query)}</span>
                </div>
                <p class="file-description">${file.description ? highlightSearchTerm(file.description, query) : 'No description'}</p>
                <div class="file-tags">${renderTags(file.tags)}</div>
                <div class="file-meta">
                    <span class="file-type">${getFileTypeLabel(file.file_type)}</span>
                    <span class="file-size">${formatFileSize(file.file_size)}</span>
                    <span class="storage-provider">${getStorageProviderIcon(file.storage_provider)}</span>
                </div>
                <div class="file-actions">
                    <button onclick="deleteFile('${file.id}')" class="action-btn delete">
                        🗑️ Delete
                    </button>
                </div>
            </div>
        </div>
    `).join('');
}

// Highlight search terms in text
function highlightSearchTerm(text, query) {
    if (!query || !text) return text;
    const regex = new RegExp(`(${query})`, 'gi');
    return text.replace(regex, '<mark>$1</mark>');
}

// Fix permissions for existing Google Drive files
async function fixGoogleDrivePermissions(fileUrl) {
    if (!googleAccessToken) {
        showMessage('Google Drive authentication required. Please refresh the page and try again.', 'error');
        return false;
    }

    const fileId = extractGoogleDriveFileId(fileUrl);
    if (!fileId) {
        showMessage('Could not extract file ID from Google Drive URL.', 'error');
        return false;
    }

    try {
        await setFilePermissions(fileId, googleAccessToken);
        showMessage('File permissions updated successfully!', 'success');
        return true;
    } catch (error) {
        showMessage('Failed to update file permissions: ' + error.message, 'error');
        return false;
    }
}

// Helper to render tags as chips
function renderTags(tags) {
    if (!tags || !tags.length) return '';
    return tags.map(tag => `<span class="tag">${tag}</span>`).join(' ');
}

const TAG_SUGGESTIONS = {
    notes: [
        "Lecture", "Handwritten", "Summary", "2023", "2022", "PDF", "Scanned", "Typed", "Important", "Revision", "Full Syllabus", "Short Notes"
    ],
    pyq: [
        "2023", "2022", "2021", "Final", "Mid", "With Solutions", "Without Solutions", "Easy", "Medium", "Hard", "Complete Paper", "Section A", "Section B"
    ],
    assignment: [
        "Active", "Completed", "Overdue", "Group", "Individual", "Submitted", "Pending", "Graded", "Ungraded", "Short", "Long", "Coding", "Theory"
    ],
    lab_manuals: [
        "Experiment 1", "Experiment 2", "Experiment 3", "Beginner", "Intermediate", "Advanced", "With Code", "Without Code", "Observation", "Result", "Viva", "Practice"
    ],
    code: [
        "C++", "Java", "Python", "JavaScript", "Beginner", "Intermediate", "Advanced", "Algorithm", "Data Structure", "OOP", "DSA", "Project", "Script"
    ],
    other: [
        "Misc", "Reference", "Important", "Notice", "Timetable", "Schedule", "Resource", "General"
    ]
};

let currentTags = [];

function updateTagDropdown() {
    const fileType = document.getElementById('fileType').value;
    const dropdown = document.getElementById('tagDropdown');
    dropdown.innerHTML = '';
    (TAG_SUGGESTIONS[fileType] || []).forEach(tag => {
        const option = document.createElement('option');
        option.value = tag;
        option.textContent = tag;
        dropdown.appendChild(option);
    });
}

function renderSelectedTags() {
    const container = document.getElementById('selectedTags');
    container.innerHTML = currentTags.map(tag =>
        `<span class="tag">${tag} <span class="remove-tag" data-tag="${tag}">&times;</span></span>`
    ).join(' ');
    // Remove tag on click
    container.querySelectorAll('.remove-tag').forEach(el => {
        el.onclick = () => {
            currentTags = currentTags.filter(t => t !== el.dataset.tag);
            renderSelectedTags();
        };
    });
}

async function checkGoogleDriveFileExists(fileId) {
    const file = allFiles.find(f => f.id == fileId);
    if (!file || !file.gdrive_file_id) {
        showMessage('No Google Drive file ID found for this file.', 'error');
        return;
    }
    try {
        const { data: { session } } = await window.supabaseAdmin.auth.getSession();
        const accessToken = session?.access_token;
        const response = await fetch('https://pfuzvpihupvhjshxiofn.functions.supabase.co/google-drive-delete', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...(accessToken ? { 'Authorization': `Bearer ${accessToken}` } : {})
            },
            body: JSON.stringify({ fileId: file.gdrive_file_id, checkOnly: true })
        });
        const result = await response.json();
        if (response.ok && result.exists) {
            showMessage('File exists in Google Drive.', 'success');
        } else if (response.ok && result.notFound) {
            showMessage('File does NOT exist in Google Drive.', 'warning');
        } else {
            showMessage('Could not check file: ' + (result.error || response.statusText), 'error');
        }
    } catch (error) {
        showMessage('Error checking file: ' + (error.message || error), 'error');
    }
} 