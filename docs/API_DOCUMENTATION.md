# EduNest API Documentation

## Overview
The EduNest API is built on Supabase and provides authentication, data management, and AI-powered features for the educational platform.

## Base URL
```
https://pfuzvpihupvhjshxiofn.supabase.co
```

## Authentication
All API requests require authentication using Supabase JWT tokens.

### Headers
```
Authorization: Bearer <jwt_token>
apikey: <supabase_anon_key>
```

## Database Schema

### Tables

#### 1. profiles
Stores user profile information.

**Columns:**
- `id` (uuid, primary key) - User ID from auth
- `full_name` (text) - User's full name
- `email` (text) - User's email address
- `college` (text) - User's college name
- `branch` (text) - User's branch/department
- `semester` (text) - User's semester
- `profile_image_url` (text) - Profile image URL
- `created_at` (timestamp) - Record creation time
- `updated_at` (timestamp) - Last update time

**Endpoints:**
- `GET /profiles?id=eq.{user_id}` - Get user profile
- `POST /profiles` - Create user profile
- `PATCH /profiles?id=eq.{user_id}` - Update user profile

#### 2. colleges
Stores college information.

**Columns:**
- `id` (uuid, primary key)
- `name` (text) - College name
- `code` (text) - College code
- `created_at` (timestamp)

**Endpoints:**
- `GET /colleges` - List all colleges
- `POST /colleges` - Create new college
- `DELETE /colleges?id=eq.{college_id}` - Delete college

#### 3. branches
Stores branch/department information.

**Columns:**
- `id` (uuid, primary key)
- `name` (text) - Branch name
- `college_id` (uuid, foreign key) - Reference to colleges.id
- `created_at` (timestamp)

**Endpoints:**
- `GET /branches?college_id=eq.{college_id}` - Get branches by college
- `POST /branches` - Create new branch

#### 4. semesters
Stores semester information.

**Columns:**
- `id` (uuid, primary key)
- `name` (text) - Semester name
- `branch_id` (uuid, foreign key) - Reference to branches.id
- `created_at` (timestamp)

**Endpoints:**
- `GET /semesters?branch_id=eq.{branch_id}` - Get semesters by branch
- `POST /semesters` - Create new semester

#### 5. subjects
Stores subject information.

**Columns:**
- `id` (uuid, primary key)
- `name` (text) - Subject name
- `code` (text) - Subject code
- `semester_id` (uuid, foreign key) - Reference to semesters.id
- `description` (text) - Subject description
- `created_at` (timestamp)

**Endpoints:**
- `GET /subjects?semester_id=eq.{semester_id}` - Get subjects by semester
- `POST /subjects` - Create new subject

#### 6. topics
Stores topic information for subjects.

**Columns:**
- `id` (uuid, primary key)
- `name` (text) - Topic name
- `subject_id` (uuid, foreign key) - Reference to subjects.id
- `content` (text) - Topic content
- `created_at` (timestamp)

**Endpoints:**
- `GET /topics?subject_id=eq.{subject_id}` - Get topics by subject
- `POST /topics` - Create new topic

#### 7. questions
Stores MCQ questions.

**Columns:**
- `id` (uuid, primary key)
- `topic_id` (uuid, foreign key) - Reference to topics.id
- `question` (text) - Question text
- `option_a` (text) - Option A
- `option_b` (text) - Option B
- `option_c` (text) - Option C
- `option_d` (text) - Option D
- `correctanswer` (integer) - Correct answer (0-3)
- `difficulty` (text) - Difficulty level (easy/medium/hard)
- `created_at` (timestamp)

**Endpoints:**
- `GET /questions?topic_id=eq.{topic_id}&difficulty=eq.{difficulty}` - Get questions by topic and difficulty
- `POST /questions` - Create new question

#### 8. test_results
Stores user test results.

**Columns:**
- `id` (uuid, primary key)
- `user_id` (uuid, foreign key) - Reference to profiles.id
- `subject_id` (uuid, foreign key) - Reference to subjects.id
- `chapter_id` (uuid, foreign key) - Reference to topics.id
- `difficulty` (text) - Test difficulty
- `score` (integer) - User's score
- `total_questions` (integer) - Total questions in test
- `time_taken` (integer) - Time taken in seconds
- `created_at` (timestamp)

**Endpoints:**
- `GET /test_results?user_id=eq.{user_id}` - Get user's test results
- `POST /test_results` - Save test result

#### 9. attendance_records
Stores attendance records.

**Columns:**
- `id` (uuid, primary key)
- `user_id` (uuid, foreign key) - Reference to profiles.id
- `subject_id` (text) - Subject code
- `date` (date) - Attendance date
- `status` (text) - Attendance status (present/absent)
- `created_at` (timestamp)

**Endpoints:**
- `GET /attendance_records?user_id=eq.{user_id}` - Get user's attendance
- `POST /attendance_records` - Create attendance record

#### 10. files
Stores file information.

**Columns:**
- `id` (uuid, primary key)
- `name` (text) - File name
- `subject_id` (uuid, foreign key) - Reference to subjects.id
- `file_type` (text) - File type (notes/assignments/lab_manuals)
- `file_url` (text) - File URL
- `file_size` (integer) - File size in bytes
- `created_at` (timestamp)

**Endpoints:**
- `GET /files?subject_id=eq.{subject_id}&file_type=eq.{file_type}` - Get files by subject and type
- `POST /files` - Create file record

#### 11. syllabus_timetable
Stores syllabus and timetable information.

**Columns:**
- `id` (uuid, primary key)
- `semester_id` (uuid, foreign key) - Reference to semesters.id
- `syllabus_file_url` (text) - Syllabus file URL
- `syllabus_text` (text) - Extracted syllabus text
- `timetable_file_url` (text) - Timetable file URL
- `created_at` (timestamp)

**Endpoints:**
- `GET /syllabus_timetable?semester_id=eq.{semester_id}` - Get syllabus/timetable by semester
- `POST /syllabus_timetable` - Create syllabus/timetable record

#### 12. ai_config
Stores AI configuration.

**Columns:**
- `id` (uuid, primary key)
- `huggingface_token` (text) - Hugging Face API token
- `created_at` (timestamp)

**Endpoints:**
- `GET /ai_config` - Get AI configuration
- `POST /ai_config` - Update AI configuration

## Storage Buckets

### 1. edunest-files
Stores educational files (notes, assignments, lab manuals).

**Operations:**
- `POST /storage/v1/object/upload` - Upload file
- `GET /storage/v1/object/public/{file_path}` - Download file
- `DELETE /storage/v1/object/{file_path}` - Delete file

### 2. profile-images
Stores user profile images.

**Operations:**
- `POST /storage/v1/object/upload` - Upload profile image
- `GET /storage/v1/object/public/{file_path}` - Get profile image

## Edge Functions

### 1. generate-topic-questions
Generates MCQ questions using AI.

**Endpoint:** `POST /functions/v1/generate-topic-questions`

**Request Body:**
```json
{
  "topic_id": "uuid",
  "question_count": 10,
  "difficulty": "easy"
}
```

**Response:**
```json
{
  "questions": [
    {
      "question": "Question text",
      "option_a": "Option A",
      "option_b": "Option B",
      "option_c": "Option C",
      "option_d": "Option D",
      "correctanswer": 0
    }
  ]
}
```

### 2. google-drive
Handles Google Drive integration.

**Endpoint:** `POST /functions/v1/google-drive`

**Request Body:**
```json
{
  "action": "upload",
  "file_data": "base64_encoded_file",
  "file_name": "filename.pdf"
}
```

## Error Codes

| Code | Description |
|------|-------------|
| 400 | Bad Request - Invalid parameters |
| 401 | Unauthorized - Invalid or missing token |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found - Resource not found |
| 500 | Internal Server Error |

## Rate Limits

- **Authentication:** 10 requests per minute
- **Database queries:** 100 requests per minute
- **File uploads:** 50 requests per minute
- **AI generation:** 5 requests per minute

## SDK Usage

### Flutter/Dart
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// Get user profile
final profile = await supabase
  .from('profiles')
  .select()
  .eq('id', user.id)
  .single();

// Upload file
final file = File('path/to/file.pdf');
final response = await supabase.storage
  .from('edunest-files')
  .upload('path/to/upload', file);
```

### JavaScript
```javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(url, key);

// Get subjects
const { data, error } = await supabase
  .from('subjects')
  .select('*')
  .eq('semester_id', semesterId);
```

## Security

### Row Level Security (RLS)
All tables have RLS policies enabled:

- Users can only access their own data
- Admins can access all data
- Public access is restricted

### Authentication
- JWT-based authentication
- Token refresh mechanism
- Session management

### Data Validation
- Input validation on all endpoints
- SQL injection protection
- XSS protection

## Monitoring

### Logs
- Request/response logs
- Error tracking
- Performance metrics

### Analytics
- API usage statistics
- User activity tracking
- Performance monitoring

## Support

For API support and questions:
- Email: support@edunest.com
- Documentation: https://docs.edunest.com
- GitHub Issues: https://github.com/edunest/api/issues 