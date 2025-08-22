// Subject-based Feedback Analytics for Admin Panel
// File: admin_panel/subject_feedback_analytics.js

class SubjectFeedbackAnalytics {
    constructor(supabaseClient) {
        this.supabase = supabaseClient;
    }

    /**
     * Fetch all feedback responses for a specific subject
     * @param {string} subjectId - The subject ID
     * @param {string} subjectCode - The subject code (optional, for additional filtering)
     * @param {string} semester - Semester filter (optional)
     * @param {string} branch - Branch filter (optional)
     * @param {string} college - College filter (optional)
     * @returns {Promise<Array>} Array of feedback responses
     */
    async getFeedbackBySubject(subjectId, filters = {}) {
        try {
            let query = this.supabase
                .from('feedback_data')
                .select('*')
                .eq('type', 'response');

            // Filter by subject ID using JSON path
            if (subjectId) {
                query = query.filter('response_info->subject_info->>subject_id', 'eq', subjectId);
            }

            // Additional filters
            if (filters.subjectCode) {
                query = query.filter('response_info->subject_info->>subject_code', 'eq', filters.subjectCode);
            }

            if (filters.semester) {
                query = query.eq('semester', filters.semester);
            }

            if (filters.branch) {
                query = query.filter('response_info->student_info->>branch', 'eq', filters.branch);
            }

            if (filters.college) {
                query = query.filter('response_info->student_info->>college', 'eq', filters.college);
            }

            // Add date range filter if provided
            if (filters.startDate) {
                query = query.gte('created_at', filters.startDate);
            }

            if (filters.endDate) {
                query = query.lte('created_at', filters.endDate);
            }

            // Order by creation date (newest first)
            query = query.order('created_at', { ascending: false });

            const { data, error } = await query;

            if (error) {
                throw error;
            }

            return data.map(response => ({
                ...response,
                response_info: typeof response.response_info === 'string' 
                    ? JSON.parse(response.response_info) 
                    : response.response_info
            }));

        } catch (error) {
            console.error('Error fetching feedback by subject:', error);
            throw error;
        }
    }

    /**
     * Get aggregated analytics for a subject
     * @param {string} subjectId - The subject ID
     * @param {Object} filters - Additional filters
     * @returns {Promise<Object>} Analytics data
     */
    async getSubjectAnalytics(subjectId, filters = {}) {
        try {
            const responses = await this.getFeedbackBySubject(subjectId, filters);
            
            if (responses.length === 0) {
                return {
                    totalResponses: 0,
                    averageRatings: {},
                    ratingDistribution: {},
                    subjectInfo: null,
                    responsesByDate: [],
                    comments: []
                };
            }

            // Extract subject info from first response
            const subjectInfo = responses[0].response_info.subject_info;

            // Calculate analytics
            const analytics = {
                totalResponses: responses.length,
                subjectInfo: subjectInfo,
                averageRatings: {},
                ratingDistribution: {},
                responsesByDate: this.groupResponsesByDate(responses),
                comments: this.extractComments(responses),
                campaignBreakdown: this.getCampaignBreakdown(responses)
            };

            // Calculate average ratings and distribution for each question
            const allQuestions = this.getAllQuestions(responses);
            
            allQuestions.forEach(questionId => {
                const ratings = this.getRatingsForQuestion(responses, questionId);
                analytics.averageRatings[questionId] = {
                    questionText: this.getQuestionText(responses, questionId),
                    average: this.calculateAverage(ratings),
                    count: ratings.length
                };
                analytics.ratingDistribution[questionId] = this.getRatingDistribution(ratings);
            });

            return analytics;

        } catch (error) {
            console.error('Error getting subject analytics:', error);
            throw error;
        }
    }

    /**
     * Get all subjects that have feedback responses
     * @param {Object} filters - Filters for semester, branch, college
     * @returns {Promise<Array>} Array of subjects with response counts
     */
    async getSubjectsWithFeedback(filters = {}) {
        try {
            const responses = await this.getFeedbackBySubject(null, filters);
            
            // Group by subject
            const subjectMap = new Map();
            
            responses.forEach(response => {
                const subjectInfo = response.response_info.subject_info;
                const key = subjectInfo.subject_id;
                
                if (!subjectMap.has(key)) {
                    subjectMap.set(key, {
                        ...subjectInfo,
                        responseCount: 0,
                        latestResponse: response.created_at
                    });
                }
                
                subjectMap.get(key).responseCount++;
            });

            return Array.from(subjectMap.values())
                .sort((a, b) => b.responseCount - a.responseCount);

        } catch (error) {
            console.error('Error getting subjects with feedback:', error);
            throw error;
        }
    }

    // Helper methods
    getAllQuestions(responses) {
        const questions = new Set();
        responses.forEach(response => {
            response.response_info.responses.forEach(r => {
                questions.add(r.question_id);
            });
        });
        return Array.from(questions);
    }

    getRatingsForQuestion(responses, questionId) {
        const ratings = [];
        responses.forEach(response => {
            const questionResponse = response.response_info.responses.find(r => r.question_id === questionId);
            if (questionResponse) {
                ratings.push(questionResponse.rating);
            }
        });
        return ratings;
    }

    getQuestionText(responses, questionId) {
        for (const response of responses) {
            const questionResponse = response.response_info.responses.find(r => r.question_id === questionId);
            if (questionResponse) {
                return questionResponse.question_text;
            }
        }
        return questionId;
    }

    calculateAverage(ratings) {
        if (ratings.length === 0) return 0;
        const sum = ratings.reduce((total, rating) => total + rating, 0);
        return Math.round((sum / ratings.length) * 100) / 100;
    }

    getRatingDistribution(ratings) {
        const distribution = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
        ratings.forEach(rating => {
            distribution[rating] = (distribution[rating] || 0) + 1;
        });
        return distribution;
    }

    groupResponsesByDate(responses) {
        const dateMap = new Map();
        responses.forEach(response => {
            const date = new Date(response.created_at).toISOString().split('T')[0];
            dateMap.set(date, (dateMap.get(date) || 0) + 1);
        });
        
        return Array.from(dateMap.entries())
            .map(([date, count]) => ({ date, count }))
            .sort((a, b) => new Date(a.date) - new Date(b.date));
    }

    extractComments(responses) {
        const comments = [];
        responses.forEach(response => {
            response.response_info.responses.forEach(r => {
                if (r.comment && r.comment.trim()) {
                    comments.push({
                        questionId: r.question_id,
                        questionText: r.question_text,
                        comment: r.comment,
                        rating: r.rating,
                        submittedAt: response.created_at
                    });
                }
            });
        });
        return comments.sort((a, b) => new Date(b.submittedAt) - new Date(a.submittedAt));
    }

    getCampaignBreakdown(responses) {
        const campaignMap = new Map();
        responses.forEach(response => {
            const campaignId = response.response_info.campaign_id;
            campaignMap.set(campaignId, (campaignMap.get(campaignId) || 0) + 1);
        });
        
        return Array.from(campaignMap.entries())
            .map(([campaignId, count]) => ({ campaignId, count }));
    }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = SubjectFeedbackAnalytics;
}

// Usage example:
/*
const analytics = new SubjectFeedbackAnalytics(supabaseClient);

// Get all feedback for a specific subject
const subjectFeedback = await analytics.getFeedbackBySubject('d8cafff3-c1fd-4aee-bb70-4fd19fefcfd9');

// Get analytics for a subject with filters
const subjectAnalytics = await analytics.getSubjectAnalytics('d8cafff3-c1fd-4aee-bb70-4fd19fefcfd9', {
    semester: '5th Semester',
    branch: 'Computer Engineering',
    college: 'Niamt Ranchi',
    startDate: '2025-08-01',
    endDate: '2025-08-31'
});

// Get all subjects with feedback
const subjectsWithFeedback = await analytics.getSubjectsWithFeedback({
    semester: '5th Semester'
});
*/
