# EduNest Functions Documentation

## Overview
EduNest uses Supabase Edge Functions for serverless backend operations, including AI-powered question generation, Google Drive integration, and automated content processing.

## Edge Functions Architecture

### Technology Stack
- **Runtime:** Deno
- **Language:** TypeScript
- **Framework:** Supabase Edge Functions
- **AI Services:** Hugging Face API
- **Storage:** Supabase Storage + Google Drive
- **Database:** PostgreSQL (via Supabase)

### Function Structure
```
supabase/functions/
├── generate-topic-questions/    # AI question generation
├── google-drive/               # Google Drive integration
└── google-drive-delete/        # Google Drive cleanup
```

## Function Documentation

### 1. Generate Topic Questions (`generate-topic-questions`)

#### Purpose
Automatically generates multiple-choice questions from topic content using AI.

#### Endpoint
```
POST /functions/v1/generate-topic-questions
```

#### Request Body
```typescript
interface GenerateQuestionsRequest {
  topic_id: string;           // UUID of the topic
  question_count: number;     // Number of questions (5-20)
  difficulty: 'easy' | 'medium' | 'hard';  // Difficulty level
}
```

#### Response
```typescript
interface GenerateQuestionsResponse {
  questions: Question[];
  success: boolean;
  message?: string;
}

interface Question {
  question: string;           // Question text
  option_a: string;          // Option A
  option_b: string;          // Option B
  option_c: string;          // Option C
  option_d: string;          // Option D
  correctanswer: number;     // 0-3 (A=0, B=1, C=2, D=3)
  difficulty: string;        // Difficulty level
}
```

#### Implementation Details

##### AI Integration
```typescript
// Hugging Face API configuration
const HF_API_URL = "https://api-inference.huggingface.co/models/";
const MODEL_NAME = "microsoft/DialoGPT-medium";

// Generate questions using AI
async function generateQuestionsWithAI(topicContent: string, count: number, difficulty: string) {
  const prompt = createQuestionPrompt(topicContent, count, difficulty);
  
  const response = await fetch(`${HF_API_URL}${MODEL_NAME}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${HF_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ inputs: prompt }),
  });
  
  return processAIResponse(response);
}
```

##### Content Processing
```typescript
// Extract topic content from database
async function getTopicContent(topicId: string) {
  const { data, error } = await supabase
    .from('topics')
    .select('content, name')
    .eq('id', topicId)
    .single();
    
  if (error) throw new Error(`Topic not found: ${topicId}`);
  return data;
}

// Process AI response into structured questions
function processAIResponse(aiResponse: string): Question[] {
  // Parse AI response and extract questions
  const questions = parseQuestionsFromAI(aiResponse);
  
  // Validate question structure
  return questions.filter(validateQuestion);
}
```

##### Database Operations
```typescript
// Save generated questions to database
async function saveQuestions(questions: Question[], topicId: string) {
  const questionsToInsert = questions.map(q => ({
    ...q,
    topic_id: topicId,
    created_at: new Date().toISOString(),
  }));
  
  const { data, error } = await supabase
    .from('questions')
    .insert(questionsToInsert);
    
  if (error) throw new Error(`Failed to save questions: ${error.message}`);
  return data;
}
```

#### Error Handling
```typescript
// Comprehensive error handling
try {
  // Validate input parameters
  validateRequest(request);
  
  // Generate questions
  const questions = await generateQuestionsWithAI(content, count, difficulty);
  
  // Save to database
  await saveQuestions(questions, topicId);
  
  return { questions, success: true };
} catch (error) {
  console.error('Question generation failed:', error);
  return {
    questions: [],
    success: false,
    message: error.message
  };
}
```

#### Usage Examples

##### Flutter/Dart
```dart
// Generate questions from Flutter app
Future<List<Question>> generateQuestions({
  required String topicId,
  required int questionCount,
  required String difficulty,
}) async {
  final response = await supabase.functions.invoke(
    'generate-topic-questions',
    body: {
      'topic_id': topicId,
      'question_count': questionCount,
      'difficulty': difficulty,
    },
  );
  
  if (response.status != 200) {
    throw Exception('Failed to generate questions');
  }
  
  return List<Question>.from(response.data['questions']);
}
```

##### JavaScript/Admin Panel
```javascript
// Generate questions from admin panel
async function generateQuestions(topicId, questionCount, difficulty) {
  const { data, error } = await supabase.functions.invoke(
    'generate-topic-questions',
    {
      body: {
        topic_id: topicId,
        question_count: questionCount,
        difficulty: difficulty,
      }
    }
  );
  
  if (error) {
    console.error('Generation failed:', error);
    return null;
  }
  
  return data.questions;
}
```

### 2. Google Drive Integration (`google-drive`)

#### Purpose
Handles file uploads to Google Drive as backup storage and provides file management capabilities.

#### Endpoint
```
POST /functions/v1/google-drive
```

#### Request Body
```typescript
interface GoogleDriveRequest {
  action: 'upload' | 'download' | 'list' | 'delete';
  file_data?: string;        // Base64 encoded file data
  file_name?: string;        // File name
  file_id?: string;         // Google Drive file ID
  folder_id?: string;       // Google Drive folder ID
}
```

#### Response
```typescript
interface GoogleDriveResponse {
  success: boolean;
  file_id?: string;
  file_url?: string;
  files?: DriveFile[];
  message?: string;
}

interface DriveFile {
  id: string;
  name: string;
  mimeType: string;
  size: number;
  createdTime: string;
  webViewLink: string;
}
```

#### Implementation Details

##### Google Drive API Setup
```typescript
// Google Drive API configuration
import { google } from 'npm:googleapis';

const SCOPES = ['https://www.googleapis.com/auth/drive.file'];
const CREDENTIALS = JSON.parse(Deno.env.get('GOOGLE_DRIVE_CREDENTIALS') || '{}');

// Initialize Google Drive client
function initializeDriveClient() {
  const auth = new google.auth.GoogleAuth({
    credentials: CREDENTIALS,
    scopes: SCOPES,
  });
  
  return google.drive({ version: 'v3', auth });
}
```

##### File Upload
```typescript
// Upload file to Google Drive
async function uploadToDrive(fileData: string, fileName: string, folderId?: string) {
  const drive = initializeDriveClient();
  
  const fileMetadata = {
    name: fileName,
    parents: folderId ? [folderId] : undefined,
  };
  
  const media = {
    mimeType: getMimeType(fileName),
    body: fileData,
  };
  
  const response = await drive.files.create({
    requestBody: fileMetadata,
    media: media,
    fields: 'id, name, webViewLink',
  });
  
  return {
    file_id: response.data.id,
    file_url: response.data.webViewLink,
    success: true,
  };
}
```

##### File Management
```typescript
// List files in Google Drive
async function listDriveFiles(folderId?: string) {
  const drive = initializeDriveClient();
  
  const response = await drive.files.list({
    q: folderId ? `'${folderId}' in parents` : undefined,
    fields: 'files(id, name, mimeType, size, createdTime, webViewLink)',
  });
  
  return {
    files: response.data.files || [],
    success: true,
  };
}

// Download file from Google Drive
async function downloadFromDrive(fileId: string) {
  const drive = initializeDriveClient();
  
  const response = await drive.files.get({
    fileId: fileId,
    alt: 'media',
  });
  
  return {
    file_data: response.data,
    success: true,
  };
}
```

#### Error Handling
```typescript
// Handle Google Drive errors
try {
  const drive = initializeDriveClient();
  // ... drive operations
} catch (error) {
  console.error('Google Drive error:', error);
  return {
    success: false,
    message: `Drive operation failed: ${error.message}`,
  };
}
```

### 3. Google Drive Delete (`google-drive-delete`)

#### Purpose
Safely deletes files from Google Drive and maintains storage cleanup.

#### Endpoint
```
POST /functions/v1/google-drive-delete
```

#### Request Body
```typescript
interface DeleteRequest {
  file_id: string;           // Google Drive file ID
  confirm_delete: boolean;   // Safety confirmation
}
```

#### Implementation
```typescript
// Delete file from Google Drive
async function deleteFromDrive(fileId: string) {
  const drive = initializeDriveClient();
  
  await drive.files.delete({
    fileId: fileId,
  });
  
  return {
    success: true,
    message: 'File deleted successfully',
  };
}
```

## Database Functions

### Row Level Security (RLS) Policies

#### User Profiles
```sql
-- Users can only access their own profile
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);
```

#### Academic Data
```sql
-- Users can view academic data for their college/branch
CREATE POLICY "Users can view academic data" ON subjects
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.college = subjects.college_id
    )
  );
```

#### Test Results
```sql
-- Users can only access their own test results
CREATE POLICY "Users can view own test results" ON test_results
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own test results" ON test_results
  FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### Database Triggers

#### Automatic Timestamps
```sql
-- Update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_profiles_updated_at 
  BEFORE UPDATE ON profiles 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### File Cleanup
```sql
-- Clean up orphaned files when records are deleted
CREATE OR REPLACE FUNCTION cleanup_orphaned_files()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete files from storage when records are removed
  DELETE FROM storage.objects 
  WHERE name = OLD.file_url;
  
  RETURN OLD;
END;
$$ language 'plpgsql';

CREATE TRIGGER cleanup_files_on_delete
  AFTER DELETE ON files
  FOR EACH ROW EXECUTE FUNCTION cleanup_orphaned_files();
```

## Storage Functions

### File Upload Validation
```typescript
// Validate file uploads
function validateFileUpload(file: File): boolean {
  const maxSize = 50 * 1024 * 1024; // 50MB
  const allowedTypes = ['pdf', 'docx', 'pptx', 'jpg', 'png'];
  
  if (file.size > maxSize) {
    throw new Error('File size exceeds 50MB limit');
  }
  
  const fileExtension = file.name.split('.').pop()?.toLowerCase();
  if (!allowedTypes.includes(fileExtension || '')) {
    throw new Error('File type not allowed');
  }
  
  return true;
}
```

### File Processing
```typescript
// Process uploaded files
async function processUploadedFile(file: File, subjectId: string) {
  // Validate file
  validateFileUpload(file);
  
  // Generate unique filename
  const fileName = `${Date.now()}_${file.name}`;
  const filePath = `subjects/${subjectId}/${fileName}`;
  
  // Upload to Supabase Storage
  const { data, error } = await supabase.storage
    .from('edunest-files')
    .upload(filePath, file);
    
  if (error) throw error;
  
  // Create database record
  const { data: fileRecord, error: dbError } = await supabase
    .from('files')
    .insert({
      name: file.name,
      subject_id: subjectId,
      file_type: getFileType(file.name),
      file_url: data.path,
      file_size: file.size,
    });
    
  if (dbError) throw dbError;
  
  return fileRecord;
}
```

## Security Functions

### Input Validation
```typescript
// Validate function inputs
function validateFunctionInput(input: any, schema: any): boolean {
  try {
    // Validate against schema
    const validation = schema.validate(input);
    if (validation.error) {
      throw new Error(`Validation failed: ${validation.error.message}`);
    }
    return true;
  } catch (error) {
    throw new Error(`Input validation failed: ${error.message}`);
  }
}

// Usage example
const questionSchema = {
  topic_id: Joi.string().uuid().required(),
  question_count: Joi.number().min(1).max(20).required(),
  difficulty: Joi.string().valid('easy', 'medium', 'hard').required(),
};
```

### Rate Limiting
```typescript
// Implement rate limiting
async function checkRateLimit(userId: string, functionName: string): Promise<boolean> {
  const key = `rate_limit:${functionName}:${userId}`;
  const limit = getRateLimit(functionName);
  
  const current = await redis.get(key);
  if (current && parseInt(current) >= limit) {
    throw new Error('Rate limit exceeded');
  }
  
  await redis.incr(key);
  await redis.expire(key, 3600); // 1 hour
  
  return true;
}

function getRateLimit(functionName: string): number {
  const limits = {
    'generate-topic-questions': 10,  // 10 requests per hour
    'google-drive': 50,              // 50 requests per hour
    'google-drive-delete': 20,       // 20 requests per hour
  };
  
  return limits[functionName] || 10;
}
```

## Monitoring & Logging

### Function Logging
```typescript
// Comprehensive logging
function logFunctionExecution(
  functionName: string,
  userId: string,
  action: string,
  details: any
) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    function: functionName,
    user_id: userId,
    action: action,
    details: details,
    environment: Deno.env.get('ENVIRONMENT') || 'development',
  };
  
  console.log(JSON.stringify(logEntry));
  
  // Send to monitoring service
  sendToMonitoring(logEntry);
}
```

### Performance Monitoring
```typescript
// Monitor function performance
async function monitorPerformance<T>(
  functionName: string,
  operation: () => Promise<T>
): Promise<T> {
  const startTime = Date.now();
  
  try {
    const result = await operation();
    const duration = Date.now() - startTime;
    
    logPerformance(functionName, duration, 'success');
    return result;
  } catch (error) {
    const duration = Date.now() - startTime;
    logPerformance(functionName, duration, 'error', error.message);
    throw error;
  }
}
```

## Deployment

### Function Deployment
```bash
# Deploy all functions
supabase functions deploy

# Deploy specific function
supabase functions deploy generate-topic-questions

# Deploy with secrets
supabase secrets set HF_TOKEN=your_token_here
supabase secrets set GOOGLE_DRIVE_CREDENTIALS='{"type": "service_account", ...}'
```

### Environment Configuration
```typescript
// Environment variables
const ENV = {
  HF_TOKEN: Deno.env.get('HF_TOKEN'),
  GOOGLE_DRIVE_CREDENTIALS: Deno.env.get('GOOGLE_DRIVE_CREDENTIALS'),
  SUPABASE_URL: Deno.env.get('SUPABASE_URL'),
  SUPABASE_ANON_KEY: Deno.env.get('SUPABASE_ANON_KEY'),
  ENVIRONMENT: Deno.env.get('ENVIRONMENT') || 'development',
};
```

## Testing

### Unit Tests
```typescript
// Test question generation
Deno.test("Generate questions from topic content", async () => {
  const topicContent = "Flutter is a UI framework for building apps.";
  const questions = await generateQuestionsWithAI(topicContent, 5, "easy");
  
  assertEquals(questions.length, 5);
  assert(questions.every(q => q.question && q.option_a && q.option_b));
});
```

### Integration Tests
```typescript
// Test complete function flow
Deno.test("Complete question generation flow", async () => {
  const request = {
    topic_id: "test-topic-id",
    question_count: 3,
    difficulty: "easy"
  };
  
  const response = await generateTopicQuestions(request);
  
  assertEquals(response.success, true);
  assertEquals(response.questions.length, 3);
});
```

## Error Handling

### Common Errors
```typescript
// Handle common function errors
function handleFunctionError(error: any): FunctionResponse {
  if (error.message.includes('rate limit')) {
    return {
      success: false,
      message: 'Too many requests. Please try again later.',
      code: 'RATE_LIMIT_EXCEEDED'
    };
  }
  
  if (error.message.includes('authentication')) {
    return {
      success: false,
      message: 'Authentication failed. Please log in again.',
      code: 'AUTHENTICATION_ERROR'
    };
  }
  
  if (error.message.includes('validation')) {
    return {
      success: false,
      message: 'Invalid input parameters.',
      code: 'VALIDATION_ERROR'
    };
  }
  
  return {
    success: false,
    message: 'An unexpected error occurred.',
    code: 'INTERNAL_ERROR'
  };
}
```

## Support & Maintenance

### Debugging
```typescript
// Enable debug mode
const DEBUG = Deno.env.get('DEBUG') === 'true';

function debugLog(message: string, data?: any) {
  if (DEBUG) {
    console.log(`[DEBUG] ${message}`, data);
  }
}
```

### Health Checks
```typescript
// Function health check
export async function healthCheck() {
  try {
    // Check database connection
    const { data, error } = await supabase
      .from('profiles')
      .select('count')
      .limit(1);
      
    if (error) throw error;
    
    // Check AI service
    const aiResponse = await testAIService();
    
    return {
      status: 'healthy',
      database: 'connected',
      ai_service: aiResponse ? 'available' : 'unavailable',
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    return {
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString(),
    };
  }
}
```

## Future Enhancements

### Planned Features
- **Batch Processing:** Process multiple requests efficiently
- **Caching Layer:** Cache AI responses for better performance
- **Advanced Analytics:** Detailed usage and performance metrics
- **Webhook Support:** Real-time notifications for events

### Technical Improvements
- **Function Optimization:** Reduce cold start times
- **Memory Management:** Optimize memory usage
- **Error Recovery:** Automatic retry mechanisms
- **Scalability:** Handle increased load efficiently 