// generate-topic-questions Edge Function
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)



// Helper: Get Gemini API key from env or ai_config table
async function getGeminiApiKey() {
  const envKey = Deno.env.get("GEMINI_API_KEY");
  if (envKey) {
  
    return envKey;
  }
  
  try {
  const { data, error } = await supabase
    .from("ai_config")
    .select("gemini_api_key, gemini_usage_count, id")
    .single();
    
    if (error) {
      console.error('[ERROR] Database error fetching AI config:', error);
      throw new Error("Failed to fetch AI configuration from database.");
    }
    
    if (!data || !data.gemini_api_key) {
      throw new Error("Gemini API key not configured in admin panel or environment variables.");
  }
    
    // Update usage count
  let usageCount = data.gemini_usage_count || 0;
  const id = data.id || 1;
    
    const { error: updateError } = await supabase
    .from("ai_config")
      .update({ 
        gemini_usage_count: usageCount + 1,
        updated_at: new Date().toISOString()
      })
    .eq("id", id);
    
    if (updateError) {
      console.warn('[WARN] Failed to update usage count:', updateError);
    } else {
  
    }
    
  
  return data.gemini_api_key;
  } catch (error) {
    console.error('[ERROR] Error in getGeminiApiKey:', error);
    throw error;
  }
}

// Helper: Call Gemini API with timeout and retry logic
async function callGemini(prompt: string, apiKey: string, retries: number = 2): Promise<any> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 45000); // 45s timeout
  
  try {
  
    const res = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.7,
            topK: 40,
            topP: 0.95,
            maxOutputTokens: 8192,
          },
        }),
        signal: controller.signal,
      }
    );
    
    clearTimeout(timeout);
    
    if (!res.ok) {
      const errorText = await res.text();
      console.error('[ERROR] Gemini API error response:', res.status, errorText);
      
      // Handle rate limiting
      if (res.status === 429) {
        throw new Error("Rate limit exceeded. Please try again in a few minutes.");
      }
      
      // Handle quota exceeded
      if (res.status === 403) {
        throw new Error("Daily quota exceeded. Please try again tomorrow or upgrade your plan.");
      }
      
      throw new Error(`Gemini API error (${res.status}): ${errorText}`);
    }
    
    const response = await res.json();

    return response;
  } catch (e) {
    clearTimeout(timeout);
    
    // Retry logic for network errors
    if (retries > 0 && (e.name === 'AbortError' || e.message.includes('fetch'))) {

      await new Promise(resolve => setTimeout(resolve, 1000)); // Wait 1 second
      return callGemini(prompt, apiKey, retries - 1);
    }
    
    throw e;
  }
}

// Utility: Strip Markdown code fences from Gemini response
function stripMarkdownCodeFences(text: string): string {
  return text.replace(/^```[a-zA-Z]*\n?|```$/gm, '').trim();
}

// Utility: Check for duplicate questions
function checkForDuplicates(questions: any[]): { hasDuplicates: boolean, duplicates: string[] } {
  const questionTexts = questions.map(q => q.question.toLowerCase().trim());
  const duplicates: string[] = [];
  
  for (let i = 0; i < questionTexts.length; i++) {
    for (let j = i + 1; j < questionTexts.length; j++) {
      if (questionTexts[i] === questionTexts[j]) {
        duplicates.push(questions[i].question);
      }
    }
  }
  
  return {
    hasDuplicates: duplicates.length > 0,
    duplicates
  };
}

// Utility: Validate and parse questions
function validateAndParseQuestions(text: string, expectedCount: number, difficultyLevel: string): any[] {
  try {
    const cleanText = stripMarkdownCodeFences(text);
    const questions = JSON.parse(cleanText);
    
    if (!Array.isArray(questions)) {
      throw new Error("Response is not an array");
    }
    
    if (questions.length === 0) {
      throw new Error("No questions generated");
    }
    
    if (questions.length !== expectedCount) {
      console.warn(`[WARN] Expected ${expectedCount} questions, got ${questions.length}`);
    }
    
    // Validate each question structure
    const validQuestions = questions.filter((q, index) => {
      if (!q.question || typeof q.question !== 'string') {
        console.warn(`[WARN] Question ${index + 1}: Missing or invalid question text`);
        return false;
      }
      
      if (!Array.isArray(q.options) || q.options.length !== 4) {
        console.warn(`[WARN] Question ${index + 1}: Must have exactly 4 options`);
        return false;
      }
      
      if (typeof q.correctAnswer !== 'number' || q.correctAnswer < 0 || q.correctAnswer > 3) {
        console.warn(`[WARN] Question ${index + 1}: correctAnswer must be 0, 1, 2, or 3`);
        return false;
      }
      
      // Validate that the correctAnswer points to a reasonable option
      const correctOption = q.options[q.correctAnswer];
      if (!correctOption || correctOption.trim().length === 0) {
        console.warn(`[WARN] Question ${index + 1}: correctAnswer points to empty option`);
        return false;
      }
      
      // Check for empty or invalid options
      const hasInvalidOptions = q.options.some((opt: string, optIndex: number) => {
        if (!opt || typeof opt !== 'string' || opt.trim().length === 0) {
          console.warn(`[WARN] Question ${index + 1}, Option ${optIndex + 1}: Empty or invalid option`);
          return true;
        }
        return false;
      });
      
      if (hasInvalidOptions) {
        return false;
      }
      
      return true;
    });
    
    if (validQuestions.length === 0) {
      throw new Error("No valid questions found in response");
    }
    
    // Check for duplicates
    const duplicateCheck = checkForDuplicates(validQuestions);
    if (duplicateCheck.hasDuplicates) {
      console.warn(`[WARN] Found ${duplicateCheck.duplicates.length} duplicate questions in ${difficultyLevel} level`);
      console.warn('[WARN] Duplicates:', duplicateCheck.duplicates);
    }
    
    // Validate difficulty appropriateness
    validQuestions.forEach((q, index) => {
      const questionText = q.question.toLowerCase();
      
      // Check for beginner-level questions in intermediate/advanced
      if (difficultyLevel !== 'beginner') {
        const beginnerPatterns = [
          'what is', 'define', 'which of the following is', 'identify', 'name'
        ];
        const isBeginnerQuestion = beginnerPatterns.some(pattern => 
          questionText.includes(pattern)
        );
        
        if (isBeginnerQuestion) {
          console.warn(`[WARN] Question ${index + 1} seems too basic for ${difficultyLevel} level: "${q.question}"`);
        }
      }
      
      // Check for advanced-level questions in beginner
      if (difficultyLevel === 'beginner') {
        const advancedPatterns = [
          'how would you', 'which approach is better', 'what are the implications', 
          'evaluate', 'compare', 'analyze', 'synthesize'
        ];
        const isAdvancedQuestion = advancedPatterns.some(pattern => 
          questionText.includes(pattern)
        );
        
        if (isAdvancedQuestion) {
          console.warn(`[WARN] Question ${index + 1} seems too complex for beginner level: "${q.question}"`);
        }
      }
    });
    
    return validQuestions;
  } catch (error) {
    console.error('[ERROR] Failed to parse questions:', error);
    throw new Error(`Failed to parse AI response: ${error.message}`);
  }
}

// Helper: Check for existing questions to avoid duplicates
async function checkExistingQuestions(topicId: string, difficulty: string): Promise<{ count: number, sampleQuestions: string[] }> {
  try {
    const { data: existingQuestions, error } = await supabase
      .from("questions")
      .select("question")
      .eq("topic_id", topicId)
      .eq("difficulty", difficulty)
      .limit(5);
    
    if (error) {
      console.warn('[WARN] Could not check existing questions:', error);
      return { count: 0, sampleQuestions: [] };
    }
    
    return {
      count: existingQuestions?.length || 0,
      sampleQuestions: existingQuestions?.map(q => q.question) || []
    };
  } catch (e) {
    console.warn('[WARN] Error checking existing questions:', e);
    return { count: 0, sampleQuestions: [] };
  }
}

// Helper: Detect topic type based on content
function detectTopicType(topicName: string, topicContent: string): 'engineering' | 'coding' | 'general' {
  const engineeringKeywords = [
    'compiler', 'lexical', 'syntax', 'semantic', 'parser', 'token', 'grammar',
    'automata', 'finite', 'state', 'machine', 'regular', 'expression',
    'algorithm', 'complexity', 'big o', 'time complexity', 'space complexity',
    'data structure', 'linked list', 'tree', 'graph', 'sorting', 'searching',
    'database', 'sql', 'normalization', 'indexing', 'transaction',
    'operating system', 'process', 'thread', 'scheduling', 'memory',
    'computer network', 'protocol', 'tcp', 'ip', 'routing', 'switching',
    'digital logic', 'boolean', 'gate', 'circuit', 'flip flop', 'register',
    'microprocessor', 'assembly', 'instruction', 'pipeline', 'cache',
    'software engineering', 'sdlc', 'waterfall', 'agile', 'testing'
  ];
  
  const codingKeywords = [
    'programming', 'code', 'coding', 'developer', 'software', 'application',
    'web development', 'frontend', 'backend', 'api', 'rest', 'json',
    'javascript', 'python', 'java', 'c++', 'c#', 'php', 'ruby', 'go',
    'react', 'angular', 'vue', 'node.js', 'express', 'django', 'flask',
    'html', 'css', 'bootstrap', 'jquery', 'ajax', 'websocket',
    'mobile app', 'android', 'ios', 'flutter', 'react native',
    'git', 'github', 'version control', 'deployment', 'ci/cd',
    'docker', 'kubernetes', 'aws', 'azure', 'cloud computing',
    'machine learning', 'ai', 'data science', 'pandas', 'numpy',
    'interview', 'leetcode', 'hackerrank', 'competitive programming'
  ];
  
  const combinedText = (topicName + ' ' + topicContent).toLowerCase();
  
  const engineeringScore = engineeringKeywords.filter(keyword => 
    combinedText.includes(keyword)
  ).length;
  
  const codingScore = codingKeywords.filter(keyword => 
    combinedText.includes(keyword)
  ).length;
  
  if (engineeringScore > codingScore && engineeringScore >= 2) {
    return 'engineering';
  } else if (codingScore > engineeringScore && codingScore >= 2) {
    return 'coding';
  } else {
    return 'general';
  }
}

Deno.serve(async (req) => {
  const startTime = Date.now();
  
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
        'Access-Control-Max-Age': '86400',
      },
    });
  }


  
  let topic_id: string | undefined;
  let question_count: number = 3;
  let difficulty_level: string = 'intermediate';
  
  try {
    const body = await req.json();
    topic_id = body.topic_id;
    question_count = body.question_count || 3;
    difficulty_level = body.difficulty_level || 'intermediate';
    
  
    
    // Enhanced validation
    if (!topic_id || typeof topic_id !== 'string') {
      throw new Error("topic_id is required and must be a string");
    }
    
    if (typeof question_count !== 'number' || question_count < 1 || question_count > 20) {
      throw new Error("question_count must be a number between 1 and 20");
    }
    
    const validDifficulties = ['beginner', 'intermediate', 'advanced'];
    if (!validDifficulties.includes(difficulty_level)) {
      throw new Error("difficulty_level must be one of: beginner, intermediate, advanced");
    }
  } catch (e) {
    console.error('[ERROR] Error parsing request body:', e);
    return new Response(JSON.stringify({ 
      error: "Invalid request parameters", 
      details: e.message,
      timestamp: new Date().toISOString()
    }), { 
      status: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
      }
    });
  }

  // Fetch topic content with enhanced error handling
  let topic;
  try {
    const { data, error: topicError } = await supabase
    .from("topics")
      .select("name, content, subject_id")
    .eq("id", topic_id)
    .single();
    
    if (topicError) {
      console.error('[ERROR] Topic fetch error:', topicError);
      return new Response(JSON.stringify({ 
        error: "Topic not found", 
        details: topicError.message,
        timestamp: new Date().toISOString()
      }), { 
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
        }
      });
  }
    
    topic = data;
  } catch (error) {
    console.error('[ERROR] Database connection error:', error);
    return new Response(JSON.stringify({ 
      error: "Database connection failed", 
      details: error.message,
      timestamp: new Date().toISOString()
    }), { 
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
      }
    });
  }
  
  if (!topic.content || topic.content.trim().length === 0) {
    console.warn('[WARN] Topic content is empty for topic_id:', topic_id);
    return new Response(JSON.stringify({ 
      error: "Topic content is empty", 
      details: "Cannot generate questions from empty content",
      timestamp: new Date().toISOString()
    }), { 
      status: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
      }
    });
  }
  
  if (topic.content.length < 50) {
    console.warn('[WARN] Topic content is very short, AI results may be poor. Length:', topic.content.length);
  }
  
  

  // Get Gemini API key
  let geminiApiKey = "";
  try {
    geminiApiKey = await getGeminiApiKey();

  } catch (e) {
    console.error('[ERROR] Error getting Gemini API key:', e);
    return new Response(JSON.stringify({ 
      error: "AI configuration error", 
      details: e.message,
      timestamp: new Date().toISOString()
    }), { 
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
      }
    });
  }

  // Check for existing questions to provide context
  const existingQuestions = await checkExistingQuestions(topic_id, difficulty_level);
  if (existingQuestions.count > 0) {
    console.log(`[INFO] Found ${existingQuestions.count} existing ${difficulty_level} questions for topic ${topic_id}`);
  }

  // Detect topic type
  const topicType = detectTopicType(topic.name, topic.content);
  console.log(`[INFO] Detected topic type: ${topicType} for topic: ${topic.name}`);

  // Enhanced Gemini prompt with better structure and difficulty differentiation
  const geminiPrompt = `
You are an expert educational AI specializing in creating high-quality multiple-choice questions (MCQs) for academic assessments.

TASK: Generate ${question_count} MCQ questions based on the provided topic content.

TOPIC INFORMATION:
- Topic Name: ${topic.name}
- Topic Content: ${topic.content}
- Difficulty Level: ${difficulty_level.toUpperCase()}
- Topic Type: ${topicType.toUpperCase()}

TOPIC TYPE DETECTION:
Based on the topic content, determine if this is:
1. ENGINEERING TOPIC (Computer Science, Electronics, Mechanical, etc.)
2. CODING/PROGRAMMING TOPIC (Programming languages, algorithms, software development)
3. GENERAL ACADEMIC TOPIC (Other subjects)

DETECTED TOPIC TYPE: ${topicType.toUpperCase()}

DIFFICULTY GUIDELINES - CREATE DISTINCT QUESTIONS FOR EACH LEVEL:

BEGINNER LEVEL QUESTIONS:
- Focus on basic definitions and fundamental concepts
- Simple recall and identification questions
- "What is..." and "Which of the following is..." type questions
- Basic tool and component identification
- Simple phase identification in processes
- Avoid complex relationships or applications
- Examples: "What is a compiler?", "Which phase does X?", "What tool is used for Y?"

INTERMEDIATE LEVEL QUESTIONS:
- Focus on applications and relationships between concepts
- "How does..." and "Why is..." type questions
- Practical scenarios and use cases
- Relationships between different components
- Process understanding and workflow questions
- Error handling and optimization concepts

FOR ENGINEERING TOPICS (Intermediate):
- Include 3-4 GATE-style questions with specific years (similar to actual GATE exam questions)
- Questions similar to what appears in GATE Computer Science/IT papers
- Focus on problem-solving and application
- Include numerical problems where appropriate
- Only GATE-style questions should end with year references: "(GATE 2023)", "(GATE 2022)", "(GATE 2021)", "(GATE 2020)"
- Examples: "In a compiler, if the lexical analyzer uses a buffer of size 512 bytes, what is the maximum number of characters that can be looked ahead? (GATE 2023)"

FOR CODING TOPICS (Intermediate):
- Include interview-style questions
- Questions similar to what tech companies ask
- Focus on practical programming scenarios
- Include company-specific question styles
- Examples: "Google Interview: Given a string, write an algorithm to find the longest palindromic substring. What is the time complexity?"

ADVANCED LEVEL QUESTIONS:
- Focus on complex scenarios and critical analysis
- Synthesis of multiple concepts
- Evaluation and comparison questions
- Deep understanding of mechanisms
- Problem-solving scenarios
- Trade-offs and design decisions

FOR ENGINEERING TOPICS (Advanced):
- Include 3-4 complex GATE questions with specific years (similar to actual GATE exam questions)
- Questions requiring deep theoretical understanding
- Algorithm analysis and optimization
- Research-oriented questions
- Only GATE-style questions should end with year references: "(GATE 2023)", "(GATE 2022)", "(GATE 2021)", "(GATE 2020)"
- Examples: "Consider a compiler that uses a two-pass approach. If the first pass takes O(n) time and the second pass takes O(n log n) time, what is the overall time complexity? (GATE 2023)"

FOR CODING TOPICS (Advanced):
- Include senior-level interview questions
- System design questions
- Questions from top tech companies (Google, Amazon, Microsoft, etc.)
- Focus on scalability and optimization
- Examples: "Amazon Senior SDE Interview: Design a distributed cache system that can handle 1 million requests per second. What are the key challenges and how would you address them?"

QUESTION REQUIREMENTS:
1. Each question must have exactly 4 options (A, B, C, D)
2. Only one option should be correct
3. All options should be plausible and well-written
4. Questions should test understanding, not just memorization
5. Use clear, concise language appropriate for the difficulty level
6. Avoid ambiguous or confusing wording
7. Ensure questions are directly related to the provided content
8. Make questions ${difficulty_level}-level appropriate
9. AVOID creating questions that would be suitable for other difficulty levels
10. Ensure each question tests a different aspect of the topic

SPECIAL FORMATTING REQUIREMENTS:

FOR ENGINEERING TOPICS (Intermediate & Advanced):
- Include 3-4 GATE-style questions with specific year references: "(GATE 2023)", "(GATE 2022)", "(GATE 2021)", "(GATE 2020)"
- NEVER use just "(GATE)" - always include the year for GATE questions
- Rotate between recent years: 2023, 2022, 2021, 2020
- Other questions should be regular academic questions without year references
- For numerical questions, ensure all calculations are accurate
- Include problem-solving steps where relevant
- Examples: "What is the time complexity of lexical analysis in a compiler? (GATE 2023)"

FOR CODING TOPICS (Intermediate & Advanced):
- Add company references at the END of questions: "(Google Interview)", "(Amazon SDE)", "(Microsoft)", "(Meta)"
- Include position levels: "(Senior SDE)", "(Software Engineer)", "(Tech Lead)"
- For coding questions, include code snippets where appropriate
- Focus on practical implementation scenarios
- Examples: "Given an array, find the maximum subarray sum. What is the time complexity? (Google Interview)"

QUALITY REQUIREMENTS:
- Questions must be factually accurate
- Correct answers must be unambiguous
- All distractors (wrong options) must be plausible
- Questions should not overlap with basic definitions if generating intermediate/advanced
- Questions should not be too complex if generating beginner level
- GATE questions should match the actual GATE exam pattern
- Interview questions should reflect real company interview styles

RESPONSE FORMAT:
Return ONLY a valid JSON array with this exact structure:
[
  {
    "question": "What is the time complexity of lexical analysis in a compiler? (GATE 2023)",
    "options": ["Option A text", "Option B text", "Option C text", "Option D text"],
    "correctAnswer": 0
  }
]

IMPORTANT:
- correctAnswer should be 0, 1, 2, or 3 (corresponding to A, B, C, D)
- The correctAnswer index MUST point to the actually correct option
- Double-check that the correctAnswer index matches the correct option text
- Do not include any explanations, markdown, or additional text
- Ensure the JSON is valid and properly formatted
- Focus on the specific content provided in the topic
- Generate exactly ${question_count} questions
- Make each question unique and appropriate for ${difficulty_level} level
- Avoid questions that could be beginner-level if generating intermediate/advanced
- Avoid questions that could be intermediate-level if generating beginner
- For engineering topics, include GATE-style questions for intermediate/advanced
- For coding topics, include interview-style questions for intermediate/advanced
- VERIFY: Before returning, ensure each correctAnswer index (0-3) points to the correct option
- For engineering topics (intermediate/advanced), include 3-4 GATE-style questions with year references like "(GATE 2023)", "(GATE 2022)", "(GATE 2021)", or "(GATE 2020)"

Generate ${question_count} ${difficulty_level}-level questions now:`;

  let questions;
  try {

    const geminiResponse = await callGemini(geminiPrompt, geminiApiKey);
    
    let text = geminiResponse.candidates?.[0]?.content?.parts?.[0]?.text || "";
    if (!text) {
      throw new Error("Empty response from Gemini API");
    }
    
    questions = validateAndParseQuestions(text, question_count, difficulty_level);
  } catch (e) {
    console.error('[ERROR] AI generation failed:', e);
    return new Response(JSON.stringify({ 
      error: "AI generation failed", 
      details: e.message,
      timestamp: new Date().toISOString()
    }), { 
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
      }
    });
  }

  const endTime = Date.now();
  const processingTime = endTime - startTime;


  
  return new Response(
    JSON.stringify({
      topic: topic.name,
      topic_id: topic_id,
      subject_id: topic.subject_id,
      topic_type: topicType,
      questions,
      difficulty_level,
      question_count: questions.length,
      processing_time_ms: processingTime,
      existing_questions_count: existingQuestions.count,
      warnings: {
        has_duplicates: checkForDuplicates(questions).hasDuplicates,
        existing_questions_found: existingQuestions.count > 0
      },
      status: "success",
      timestamp: new Date().toISOString()
    }),
    { 
      headers: { 
        "Content-Type": "application/json",
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
      } 
    }
  );
}); 