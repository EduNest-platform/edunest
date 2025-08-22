// Feedback Campaigns Management
let questions = [];
let campaigns = [];

// Initialize the page
document.addEventListener('DOMContentLoaded', function() {
    console.log('Feedback Campaigns - Initializing...');
    checkSuperAdminAuth();
    initializeDefaultQuestions();
    loadCampaigns();
});

// Check if user is super admin
function checkSuperAdminAuth() {
    const adminLoggedIn = sessionStorage.getItem('adminLoggedIn');
    if (!adminLoggedIn) {
        window.location.href = 'index.html';
        return;
    }
    // Add super admin check here if needed
}

// Initialize default feedback questions
function initializeDefaultQuestions() {
    const defaultQuestions = [
        'Teaching Quality and Clarity',
        'Course Content and Organization', 
        'Professor\'s Knowledge of Subject',
        'Interaction and Availability',
        'Overall Satisfaction'
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

// Save campaign
async function saveCampaign(status) {
    try {
        // Validate form
        const title = document.getElementById('campaignTitle').value.trim();
        const semester = document.getElementById('semesterSelect').value;
        const startDate = document.getElementById('startDate').value;
        const endDate = document.getElementById('endDate').value;
        const description = document.getElementById('campaignDescription').value.trim();
        
        if (!title || !semester || !startDate || !endDate) {
            showMsg('messageDisplay', 'Please fill in all required fields', true);
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
        
        // Create campaign data
        const campaignData = {
            campaign_info: {
                type: "campaign",
                title: title,
                description: description,
                semester: semester,
                dates: {
                    start: startDate,
                    end: endDate
                },
                status: status,
                questions: questions.filter(q => q.text.trim()),
                created_by: sessionStorage.getItem('adminEmail') || 'super_admin'
            },
            type: "campaign",
            semester: semester
        };
        
        console.log('Saving campaign:', campaignData);
        
        const { data, error } = await window.supabaseClient
            .from('feedback_data')
            .insert(campaignData)
            .select();
        
        if (error) throw error;
        
        hideLoading();
        showMsg('messageDisplay', `Campaign ${status === 'active' ? 'created and activated' : 'saved as draft'} successfully!`, false);
        
        // Reset form
        resetForm();
        
        // Reload campaigns list
        setTimeout(() => {
            loadCampaigns();
        }, 1000);
        
    } catch (error) {
        hideLoading();
        console.error('Error saving campaign:', error);
        showMsg('messageDisplay', 'Error saving campaign: ' + error.message, true);
    }
}

// Reset form
function resetForm() {
    document.getElementById('campaignForm').reset();
    initializeDefaultQuestions();
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
    
    if (campaigns.length === 0) {
        campaignsList.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-comments"></i>
                <h3>No campaigns created yet</h3>
                <p>Create your first feedback campaign using the form above</p>
            </div>
        `;
        return;
    }
    
    campaignsList.innerHTML = campaigns.map(campaign => {
        const info = campaign.campaign_info;
        const statusColor = info.status === 'active' ? 'success' : 
                           info.status === 'draft' ? 'warning' : 'secondary';
        
        return `
            <div class="campaign-card">
                <div class="campaign-header">
                    <h3>${info.title}</h3>
                    <span class="status-badge status-${statusColor}">${info.status.toUpperCase()}</span>
                </div>
                <div class="campaign-details">
                    <div class="detail-item">
                        <i class="fas fa-graduation-cap"></i>
                        <span>${info.semester}</span>
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
                    ${info.status === 'draft' ? 
                        `<button class="btn-primary btn-sm" onclick="activateCampaign('${campaign.id}')">
                            <i class="fas fa-rocket"></i> Activate
                        </button>` : ''
                    }
                    ${info.status === 'active' ? 
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
        showLoading('Deleting campaign...');
        
        const { error } = await window.supabaseClient
            .from('feedback_data')
            .delete()
            .eq('id', campaignId);
        
        if (error) throw error;
        
        hideLoading();
        showMsg('messageDisplay', 'Campaign deleted successfully!', false);
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
