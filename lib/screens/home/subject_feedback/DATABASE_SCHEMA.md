# Feedback Data Table Schema

## Table: `feedback_data`

This table stores both feedback campaigns and student responses.

### Common Fields
- `id` - Primary key (UUID)
- `type` - Record type ('campaign' or 'response')
- `semester` - Semester identifier
- `created_at` - Timestamp
- `updated_at` - Timestamp

### Campaign Records (type: 'campaign')

**campaign_info** (JSONB):
```json
{
  "title": "Mid-term Feedback",
  "status": "active",
  "hierarchy": {
    "collegeName": "Example College",
    "branchName": "Computer Science",
    "semesterName": "5th Semester"
  },
  "questions": [
    {
      "id": "q1",
      "text": "How would you rate the teaching quality?",
      "type": "rating",
      "scale": 5
    }
  ]
}
```

### Response Records (type: 'response')

**response_info** (JSONB):
```json
{
  "campaign_id": "campaign-uuid",
  "subject_info": {
    "subject_id": "subject-uuid",
    "subject_name": "Data Structures",
    "subject_code": "CS301"
  },
  "student_info": {
    "semester": "5th Semester",
    "branch": "Computer Science",
    "college": "Example College"
  },
  "responses": [
    {
      "question_id": "q1",
      "question_text": "How would you rate the teaching quality?",
      "rating": 4,
      "comment": "Good teaching methods"
    }
  ],
  "submitted_at": "2024-01-15T10:30:00Z",
  "is_anonymous": true
}
```

## Subject-Specific Features

1. **Subject Identification**: Each response includes complete subject information (ID, name, code)
2. **Cross-Subject Analysis**: Admin can analyze feedback per subject across different campaigns
3. **Subject Filtering**: Responses can be filtered by subject for detailed analysis
4. **Subject Comparison**: Compare feedback across different subjects in the same semester

## Data Integrity

- Subject information is embedded in each response for data consistency
- Student hierarchy information ensures proper context
- Campaign ID links responses to specific feedback campaigns
- Anonymous responses protect student privacy while maintaining data utility
