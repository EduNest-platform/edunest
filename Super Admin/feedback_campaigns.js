// Feedback Campaigns Management - Super Admin
let questions = [];
let campaigns = [];
let filteredCampaigns = [];
let allColleges = [];
let allSemesters = [];

// Initialize the page
document.addEventListener('DOMContentLoaded', function() {
    console.log('Feedback Campaigns - Initializing...');
    
    // Ensure we're on the feedback campaigns page
    if (!document.getElementById('campaignForm')) {
        console.log('Not on feedback campaigns page - skipping initialization');
        return;
    }
    
    // Initialize with proper error handling
    initializeFeedbackCampaigns();
});

// Initialize feedback campaigns with proper error handling
async function initializeFeedbackCampaigns() {
    console.log('Starting feedback campaigns initialization...');
    
    // Wait for supabaseClient to be available
    let attempts = 0;
    const maxAttempts = 10;
    
    while (!window.supabaseClient && attempts < maxAttempts) {
        console.log(`Waiting for supabaseClient... Attempt ${attempts + 1}/${maxAttempts}`);
        await new Promise(resolve => setTimeout(resolve, 500));
        attempts++;
    }
    
    if (!window.supabaseClient) {
        console.error('Failed to initialize: supabaseClient not available after', maxAttempts * 500, 'ms');
        showMsg('messageDisplay', 'Database connection failed. Please refresh the page.', true);
        return;
    }
    
    console.log('Supabase client available, initializing components...');
    
    try {
        // Check authentication
        checkSuperAdminAuth();
        
        // Initialize default questions
        initializeDefaultQuestions();
        
        // Load hierarchy for first step
        await loadHierarchyColleges();
        
        // Load existing campaigns
        await loadCampaigns();
        
        console.log('Feedback campaigns initialized successfully');
    } catch (error) {
        console.error('Error during initialization:', error);
        showMsg('messageDisplay', 'Failed to load campaign data. Please refresh the page.', true);
    }
}

// Check if user is super admin
function checkSuperAdminAuth() {
    const adminLoggedIn = sessionStorage.getItem('adminLoggedIn');
    if (!adminLoggedIn) {
        window.location.href = 'index.html';
        return;
    }
    
    // For now, allow any admin to access feedback campaigns
    // You can add stricter super admin checks later if needed
    console.log('Admin access granted for feedback campaigns');
}

// Initialize default feedback questions
function initializeDefaultQuestions() {
    const defaultQuestions = [
        'Has the Teacher covered entire Syllabus as prescribed by University/College/Board?',
        'Has the Teacher covered relevant topics beyond syllabus',
        'Effectiveness of Teacher in terms of: (a) Technical content/course content (b) Communication skills (c) Use of teaching aids',
        'Pace on which contents were covered',
        'Motivation and inspiration for students to learn',
        'Support for the development of Students\' skill: (i) Practical demonstration (ii) Hands on training',
        'Clarity of expectations of students',
        'Feedback provided on Students\' progress',
        'Willingness to offer help and advice to students'
    ];
    
    questions = defaultQuestions.map((text, index) => ({
        id: `q${index + 1}`,
        text: text,
        type: 'rating',
        scale: 5
    }));
    
    renderQuestions();
}

// Render questions list
function renderQuestions() {
    const questionsList = document.getElementById('questionsList');
    questionsList.innerHTML = '';
    
    questions.forEach((question, index) => {
        const questionDiv = document.createElement('div');
        questionDiv.className = 'question-item';
        questionDiv.innerHTML = `
            <div class="question-content">
                <span class="question-number">Q${index + 1}</span>
                <input type="text" value="${question.text}" onchange="updateQuestion(${index}, this.value)" placeholder="Enter question text">
                <span class="question-scale">1-5 Scale</span>
                <button type="button" class="btn-delete" onclick="removeQuestion(${index})" title="Remove Question">
                    <i class="fas fa-trash"></i>
                </button>
            </div>
        `;
        questionsList.appendChild(questionDiv);
    });
}

// Add new question
function addQuestion() {
    const newQuestion = {
        id: `q${questions.length + 1}`,
        text: '',
        type: 'rating',
        scale: 5
    };
    questions.push(newQuestion);
    renderQuestions();
}

// Update question text
function updateQuestion(index, newText) {
    questions[index].text = newText;
}

// Remove question
function removeQuestion(index) {
    if (questions.length <= 1) {
        showMsg('messageDisplay', 'At least one question is required', true);
        return;
    }
    questions.splice(index, 1);
    // Reassign IDs
    questions.forEach((q, i) => q.id = `q${i + 1}`);
    renderQuestions();
}

// Load existing campaigns
async function loadCampaigns() {
    try {
        showLoading('Loading campaigns...');
        
        const { data, error } = await window.supabaseClient
            .from('feedback_data')
            .select('*')
            .eq('type', 'campaign')
            .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        campaigns = data || [];
        filteredCampaigns = [...campaigns];
        populateFilterOptions();
        renderCampaigns();
        hideLoading();
        
    } catch (error) {
        hideLoading();
        console.error('Error loading campaigns:', error);
        showMsg('messageDisplay', 'Error loading campaigns: ' + error.message, true);
    }
}

// Render campaigns list
function renderCampaigns() {
    const campaignsList = document.getElementById('campaignsList');
    const campaignCount = document.getElementById('campaignCount');
    
    // Update count
    if (campaignCount) {
        campaignCount.textContent = `Showing ${filteredCampaigns.length} of ${campaigns.length} campaigns`;
    }
    
    if (filteredCampaigns.length === 0) {
        campaignsList.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-comments"></i>
                <h3>No campaigns created yet</h3>
                <p>Create your first feedback campaign using the form above</p>
            </div>
        `;
        return;
    }
    
    campaignsList.innerHTML = filteredCampaigns.map(campaign => {
        const info = campaign.campaign_info;
        
        // Check if campaign has expired
        const currentDate = new Date();
        const endDate = new Date(info.dates.end);
        const isExpired = endDate < currentDate;
        
        // Determine actual status (expired campaigns are always closed)
        const actualStatus = isExpired ? 'closed' : info.status;
        const statusColor = actualStatus === 'active' ? 'success' : 
                           actualStatus === 'draft' ? 'warning' : 'secondary';
        
        return `
            <div class="campaign-card">
                <div class="campaign-header">
                    <h3>${info.title}</h3>
                    <span class="status-badge status-${statusColor}">${actualStatus.toUpperCase()}</span>
                </div>
                <div class="campaign-details">
                    <div class="detail-item">
                        <i class="fas fa-university"></i>
                        <span>${info.hierarchy?.collegeName || 'N/A'}</span>
                    </div>
                    <div class="detail-item">
                        <i class="fas fa-graduation-cap"></i>
                        <span>${info.hierarchy?.semesterName || info.semester || 'N/A'}</span>
                    </div>
                    <div class="detail-item">
                        <i class="fas fa-calendar"></i>
                        <span>${formatDate(info.dates.start)} - ${formatDate(info.dates.end)}</span>
                    </div>
                    <div class="detail-item">
                        <i class="fas fa-question-circle"></i>
                        <span>${info.questions.length} questions</span>
                    </div>
                </div>
                ${info.description ? `<p class="campaign-description">${info.description}</p>` : ''}
                <div class="campaign-actions">
                    ${actualStatus === 'draft' ? 
                        `<button class="btn-primary btn-sm" onclick="activateCampaign('${campaign.id}')">
                            <i class="fas fa-rocket"></i> Activate
                        </button>` : ''
                    }
                    ${actualStatus === 'active' ? 
                        `<button class="btn-secondary btn-sm" onclick="deactivateCampaign('${campaign.id}')">
                            <i class="fas fa-pause"></i> Deactivate
                        </button>` : ''
                    }
                    <button class="btn-outline btn-sm" onclick="viewCampaignDetails('${campaign.id}')">
                        <i class="fas fa-eye"></i> View Details
                    </button>
                    <button class="btn-danger btn-sm" onclick="deleteCampaign('${campaign.id}')">
                        <i class="fas fa-trash"></i> Delete
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

// Format date for display
function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

// Activate campaign
async function activateCampaign(campaignId) {
    try {
        showLoading('Activating campaign...');
        
        const campaign = campaigns.find(c => c.id === campaignId);
        campaign.campaign_info.status = 'active';
        
        const { error } = await window.supabaseClient
            .from('feedback_data')
            .update({ campaign_info: campaign.campaign_info })
            .eq('id', campaignId);
        
        if (error) throw error;
        
        hideLoading();
        showMsg('messageDisplay', 'Campaign activated successfully!', false);
        loadCampaigns();
        
    } catch (error) {
        hideLoading();
        console.error('Error activating campaign:', error);
        showMsg('messageDisplay', 'Error activating campaign: ' + error.message, true);
    }
}

// Deactivate campaign
async function deactivateCampaign(campaignId) {
    try {
        showLoading('Deactivating campaign...');
        
        const campaign = campaigns.find(c => c.id === campaignId);
        campaign.campaign_info.status = 'closed';
        
        const { error } = await window.supabaseClient
            .from('feedback_data')
            .update({ campaign_info: campaign.campaign_info })
            .eq('id', campaignId);
        
        if (error) throw error;
        
        hideLoading();
        showMsg('messageDisplay', 'Campaign deactivated successfully!', false);
        loadCampaigns();
        
    } catch (error) {
        hideLoading();
        console.error('Error deactivating campaign:', error);
        showMsg('messageDisplay', 'Error deactivating campaign: ' + error.message, true);
    }
}

// Delete campaign
async function deleteCampaign(campaignId) {
    if (!confirm('Are you sure you want to delete this campaign? This will also delete all responses.')) {
        return;
    }
    
    try {
        showLoading('Deleting campaign and responses...');
        
        // First, delete all responses associated with this campaign
        console.log('Deleting responses for campaign:', campaignId);
        const { error: responseError } = await window.supabaseClient
            .from('feedback_data')
            .delete()
            .eq('type', 'response')
            .contains('response_info', { campaign_id: campaignId });
        
        if (responseError) {
            console.error('Error deleting responses:', responseError);
            // Continue with campaign deletion even if response deletion fails
        } else {
            console.log('Responses deleted successfully');
        }
        
        // Then delete the campaign itself
        console.log('Deleting campaign:', campaignId);
        const { error: campaignError } = await window.supabaseClient
            .from('feedback_data')
            .delete()
            .eq('id', campaignId);
        
        if (campaignError) throw campaignError;
        
        hideLoading();
        showMsg('messageDisplay', 'Campaign and all responses deleted successfully!', false);
        loadCampaigns();
        
    } catch (error) {
        hideLoading();
        console.error('Error deleting campaign:', error);
        showMsg('messageDisplay', 'Error deleting campaign: ' + error.message, true);
    }
}

// View campaign details
function viewCampaignDetails(campaignId) {
    const campaign = campaigns.find(c => c.id === campaignId);
    const info = campaign.campaign_info;
    
    const detailsHtml = `
        <div class="campaign-details-modal">
            <h3>${info.title}</h3>
            <p><strong>Semester:</strong> ${info.semester}</p>
            <p><strong>Duration:</strong> ${formatDate(info.dates.start)} - ${formatDate(info.dates.end)}</p>
            <p><strong>Status:</strong> ${info.status.toUpperCase()}</p>
            ${info.description ? `<p><strong>Description:</strong> ${info.description}</p>` : ''}
            
            <h4>Questions:</h4>
            <ol>
                ${info.questions.map(q => `<li>${q.text} (1-5 scale)</li>`).join('')}
            </ol>
            
            <button onclick="closeModal()" class="btn-primary">Close</button>
        </div>
    `;
    
    showModal(detailsHtml);
}

// Utility functions
function showLoading(text = 'Loading...') {
    const overlay = document.getElementById('loadingOverlay');
    const loadingText = document.getElementById('loadingText');
    if (overlay) overlay.classList.remove('hidden');
    if (loadingText) loadingText.textContent = text;
}

function hideLoading() {
    const overlay = document.getElementById('loadingOverlay');
    if (overlay) overlay.classList.add('hidden');
}

function showMsg(elementId, message, isError = false) {
    const msgElement = document.getElementById(elementId);
    if (msgElement) {
        msgElement.textContent = message;
        msgElement.className = `message-display ${isError ? 'error' : 'success'}`;
        msgElement.classList.remove('hidden');
        
        setTimeout(() => {
            msgElement.classList.add('hidden');
        }, 5000);
    }
}

function showModal(content) {
    const modal = document.createElement('div');
    modal.className = 'modal-overlay';
    modal.innerHTML = `
        <div class="modal-content">
            ${content}
        </div>
    `;
    document.body.appendChild(modal);
}

function closeModal() {
    const modal = document.querySelector('.modal-overlay');
    if (modal) {
        modal.remove();
    }
}

// Populate filter options based on existing campaigns
function populateFilterOptions() {
    // Extract unique colleges and semesters
    allColleges = [...new Set(campaigns.map(c => c.campaign_info.hierarchy?.collegeName).filter(Boolean))].sort();
    allSemesters = [...new Set(campaigns.map(c => c.campaign_info.hierarchy?.semesterName || c.campaign_info.semester).filter(Boolean))].sort();
    
    // Populate college filter
    const collegeSelect = document.getElementById('filterCollege');
    if (collegeSelect) {
        collegeSelect.innerHTML = '<option value="">All Colleges</option>';
        allColleges.forEach(college => {
            const option = document.createElement('option');
            option.value = college;
            option.textContent = college;
            collegeSelect.appendChild(option);
        });
    }
    
    // Populate semester filter
    const semesterSelect = document.getElementById('filterSemester');
    if (semesterSelect) {
        semesterSelect.innerHTML = '<option value="">All Semesters</option>';
        allSemesters.forEach(semester => {
            const option = document.createElement('option');
            option.value = semester;
            option.textContent = semester;
            semesterSelect.appendChild(option);
        });
    }
}

// Apply filters and sorting to campaigns
function applyCampaignFilters() {
    const collegeFilter = document.getElementById('filterCollege')?.value || '';
    const semesterFilter = document.getElementById('filterSemester')?.value || '';
    const statusFilter = document.getElementById('filterStatus')?.value || '';
    const sortBy = document.getElementById('sortBy')?.value || 'created_at_desc';
    
    // Filter campaigns
    filteredCampaigns = campaigns.filter(campaign => {
        const info = campaign.campaign_info;
        
        // College filter
        if (collegeFilter && info.hierarchy?.collegeName !== collegeFilter) {
            return false;
        }
        
        // Semester filter
        const campaignSemester = info.hierarchy?.semesterName || info.semester;
        if (semesterFilter && campaignSemester !== semesterFilter) {
            return false;
        }
        
        // Status filter
        if (statusFilter && info.status !== statusFilter) {
            return false;
        }
        
        return true;
    });
    
    // Sort campaigns
    filteredCampaigns.sort((a, b) => {
        const infoA = a.campaign_info;
        const infoB = b.campaign_info;
        
        switch (sortBy) {
            case 'created_at_asc':
                return new Date(infoA.created_at) - new Date(infoB.created_at);
            case 'created_at_desc':
                return new Date(infoB.created_at) - new Date(infoA.created_at);
            case 'title_asc':
                return infoA.title.localeCompare(infoB.title);
            case 'title_desc':
                return infoB.title.localeCompare(infoA.title);
            case 'college_asc':
                const collegeA = infoA.hierarchy?.collegeName || '';
                const collegeB = infoB.hierarchy?.collegeName || '';
                return collegeA.localeCompare(collegeB);
            case 'semester_asc':
                const semesterA = infoA.hierarchy?.semesterName || infoA.semester || '';
                const semesterB = infoB.hierarchy?.semesterName || infoB.semester || '';
                return semesterA.localeCompare(semesterB);
            case 'status_asc':
                return infoA.status.localeCompare(infoB.status);
            default:
                return new Date(infoB.created_at) - new Date(infoA.created_at);
        }
    });
    
    renderCampaigns();
}

// Clear all filters
function clearCampaignFilters() {
    document.getElementById('filterCollege').value = '';
    document.getElementById('filterSemester').value = '';
    document.getElementById('filterStatus').value = '';
    document.getElementById('sortBy').value = 'created_at_desc';
    
    filteredCampaigns = [...campaigns];
    renderCampaigns();
}

// New Two-Step Flow Functions

// Step 1: Load colleges for hierarchy selection
async function loadHierarchyColleges() {
    try {
        const { data: colleges, error } = await window.supabaseClient
            .from('colleges')
            .select('id, name')
            .order('name');
        
        if (error) throw error;
        
        const collegeSelect = document.getElementById('hierarchyCollegeSelect');
        collegeSelect.innerHTML = '<option value="">Select a college...</option>';
        
        colleges.forEach(college => {
            const option = document.createElement('option');
            option.value = college.id;
            option.textContent = college.name;
            collegeSelect.appendChild(option);
        });
        
    } catch (error) {
        console.error('Error loading colleges:', error);
        showMsg('messageDisplay', 'Error loading colleges: ' + error.message, true);
    }
}

// Load branches for selected college in hierarchy
async function loadHierarchyBranches() {
    const collegeId = document.getElementById('hierarchyCollegeSelect').value;
    const branchStep = document.getElementById('branchStep');
    const semesterStep = document.getElementById('semesterStep');
    const selectedHierarchy = document.getElementById('selectedHierarchy');
    
    // Hide subsequent steps
    semesterStep.style.display = 'none';
    selectedHierarchy.style.display = 'none';
    
    if (!collegeId) {
        branchStep.style.display = 'none';
        return;
    }
    
    try {
        const { data: branches, error } = await window.supabaseClient
            .from('branches')
            .select('id, name')
            .eq('college_id', collegeId)
            .order('name');
        
        if (error) throw error;
        
        const branchSelect = document.getElementById('hierarchyBranchSelect');
        branchSelect.innerHTML = '<option value="">Select a branch...</option>';
        
        branches.forEach(branch => {
            const option = document.createElement('option');
            option.value = branch.id;
            option.textContent = branch.name;
            branchSelect.appendChild(option);
        });
        
        // Show branch step with animation
        branchStep.style.display = 'block';
        setTimeout(() => branchStep.classList.add('visible'), 100);
        
    } catch (error) {
        console.error('Error loading branches:', error);
        showMsg('messageDisplay', 'Error loading branches: ' + error.message, true);
    }
}

// Load semesters for selected branch in hierarchy
async function loadHierarchySemesters() {
    const branchId = document.getElementById('hierarchyBranchSelect').value;
    const semesterStep = document.getElementById('semesterStep');
    const selectedHierarchy = document.getElementById('selectedHierarchy');
    
    // Hide subsequent steps
    selectedHierarchy.style.display = 'none';
    
    if (!branchId) {
        semesterStep.style.display = 'none';
        return;
    }
    
    try {
        const { data: semesters, error } = await window.supabaseClient
            .from('semesters')
            .select('id, name')
            .eq('branch_id', branchId)
            .order('name');
        
        if (error) throw error;
        
        const semesterSelect = document.getElementById('hierarchySemesterSelect');
        semesterSelect.innerHTML = '<option value="">Select a semester...</option>';
        
        semesters.forEach(semester => {
            const option = document.createElement('option');
            option.value = semester.id;
            option.textContent = semester.name;
            semesterSelect.appendChild(option);
        });
        
        // Show semester step with animation
        semesterStep.style.display = 'block';
        setTimeout(() => semesterStep.classList.add('visible'), 100);
        
    } catch (error) {
        console.error('Error loading semesters:', error);
        showMsg('messageDisplay', 'Error loading semesters: ' + error.message, true);
    }
}

// Show hierarchy selection summary
async function showCampaignCreation() {
    const collegeSelect = document.getElementById('hierarchyCollegeSelect');
    const branchSelect = document.getElementById('hierarchyBranchSelect');
    const semesterSelect = document.getElementById('hierarchySemesterSelect');
    const selectedHierarchy = document.getElementById('selectedHierarchy');
    const selectedPath = document.getElementById('selectedPath');
    
    if (!collegeSelect.value || !branchSelect.value || !semesterSelect.value) {
        selectedHierarchy.style.display = 'none';
        return;
    }
    
    // Build the hierarchy path
    const collegeName = collegeSelect.options[collegeSelect.selectedIndex].text;
    const branchName = branchSelect.options[branchSelect.selectedIndex].text;
    const semesterName = semesterSelect.options[semesterSelect.selectedIndex].text;
    
    selectedPath.innerHTML = `
        <i class="fas fa-university"></i> ${collegeName} 
        <i class="fas fa-arrow-right"></i> 
        <i class="fas fa-code-branch"></i> ${branchName} 
        <i class="fas fa-arrow-right"></i> 
        <i class="fas fa-calendar-alt"></i> ${semesterName}
    `;
    
    selectedHierarchy.style.display = 'block';
}

// Proceed to campaign creation
function proceedToCampaignCreation() {
    const collegeSelect = document.getElementById('hierarchyCollegeSelect');
    const branchSelect = document.getElementById('hierarchyBranchSelect');
    const semesterSelect = document.getElementById('hierarchySemesterSelect');
    
    // Hide hierarchy selection
    document.getElementById('hierarchySelection').style.display = 'none';
    
    // Show campaign creation
    document.getElementById('campaignCreation').style.display = 'block';
    
    // Update target info
    const collegeName = collegeSelect.options[collegeSelect.selectedIndex].text;
    const branchName = branchSelect.options[branchSelect.selectedIndex].text;
    const semesterName = semesterSelect.options[semesterSelect.selectedIndex].text;
    
    document.getElementById('targetInfo').innerHTML = `
        Target: ${collegeName} → ${branchName} → ${semesterName}
    `;
    
    // Store selected values for later use
    window.selectedHierarchy = {
        collegeId: collegeSelect.value,
        collegeName: collegeName,
        branchId: branchSelect.value,
        branchName: branchName,
        semesterId: semesterSelect.value,
        semesterName: semesterName
    };
}

// Go back to hierarchy selection
function backToHierarchySelection() {
    document.getElementById('hierarchySelection').style.display = 'block';
    document.getElementById('campaignCreation').style.display = 'none';
    
    // Clear form
    document.getElementById('campaignForm').reset();
}

// Updated save campaign function
async function saveCampaign(status) {
    try {
        // Validate form
        const title = document.getElementById('campaignTitle').value.trim();
        const startDate = document.getElementById('startDate').value;
        const endDate = document.getElementById('endDate').value;
        const description = document.getElementById('campaignDescription').value.trim();
        
        if (!title || !startDate || !endDate) {
            showMsg('messageDisplay', 'Please fill in all required fields', true);
            return;
        }
        
        if (!window.selectedHierarchy) {
            showMsg('messageDisplay', 'Please select target hierarchy first', true);
            return;
        }
        
        if (new Date(startDate) >= new Date(endDate)) {
            showMsg('messageDisplay', 'End date must be after start date', true);
            return;
        }
        
        if (questions.some(q => !q.text.trim())) {
            showMsg('messageDisplay', 'Please fill in all question texts', true);
            return;
        }
        
        showLoading('Creating campaign...');
        
        // Create optimized campaign data with only essential information
        const campaignData = {
            campaign_info: {
                title: title,
                description: description,
                semester: window.selectedHierarchy.semesterName,
                hierarchy: {
                    collegeId: window.selectedHierarchy.collegeId,
                    collegeName: window.selectedHierarchy.collegeName,
                    branchId: window.selectedHierarchy.branchId,
                    branchName: window.selectedHierarchy.branchName,
                    semesterId: window.selectedHierarchy.semesterId,
                    semesterName: window.selectedHierarchy.semesterName
                },
                dates: {
                    start: startDate,
                    end: endDate
                },
                status: status,
                questions: questions.filter(q => q.text.trim()).map(q => ({
                    id: q.id,
                    text: q.text,
                    type: 'rating',
                    scale: 5
                })),
                created_by: sessionStorage.getItem('adminEmail') || 'super_admin',
                created_at: new Date().toISOString()
            },
            type: "campaign",
            semester: window.selectedHierarchy.semesterName
        };
        
        console.log('Saving campaign:', campaignData);
        console.log('Campaign data size:', JSON.stringify(campaignData).length, 'characters');
        console.log('Questions array:', questions);
        console.log('Selected hierarchy:', window.selectedHierarchy);
        
        const { data, error } = await window.supabaseClient
            .from('feedback_data')
            .insert(campaignData)
            .select();
        
        if (error) throw error;
        
        hideLoading();
        showMsg('messageDisplay', `Campaign ${status === 'active' ? 'created and activated' : 'saved as draft'} successfully!`, false);
        
        // Reset form and go back to hierarchy selection
        document.getElementById('campaignForm').reset();
        backToHierarchySelection();
        
        // Reload campaigns
        await loadCampaigns();
        
    } catch (error) {
        hideLoading();
        console.error('Error saving campaign:', error);
        showMsg('messageDisplay', 'Error saving campaign: ' + error.message, true);
    }
}
