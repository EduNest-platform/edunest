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
function validateAndParseQuestions(text: string, expectedCount: number, practiceMode: string): { questions: any[], note?: string } {
  try {
    const cleanText = stripMarkdownCodeFences(text);
    const parsed = JSON.parse(cleanText);

    let questions: any[];
    let note: string | undefined;

    // Handle different response formats
    if (Array.isArray(parsed)) {
      // Old format: direct array of questions
      questions = parsed;
    } else if (parsed.questions && Array.isArray(parsed.questions)) {
      // New format: object with questions array and optional note
      questions = parsed.questions;
      note = parsed.note;
    } else {
      throw new Error("Response format is invalid");
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
      console.warn(`[WARN] Found ${duplicateCheck.duplicates.length} duplicate questions in ${practiceMode} mode`);
      console.warn('[WARN] Duplicates:', duplicateCheck.duplicates);
    }

    // Validate practice mode appropriateness
    validQuestions.forEach((q, index) => {
      const questionText = q.question.toLowerCase();

      // Check for competitive mode requirements
      if (practiceMode === 'competitive') {
        const hasCompetitiveMarkers = questionText.includes('gate') ||
          questionText.includes('ese') ||
          questionText.includes('isro') ||
          questionText.includes('drdo') ||
          questionText.includes('barc') ||
          /\(\w+\s+\d{4}\)/.test(q.question); // Year reference pattern

        if (!hasCompetitiveMarkers) {
          console.warn(`[WARN] Question ${index + 1} may not be competitive exam style: "${q.question}"`);
        }
      }

      // Check for career mode requirements
      if (practiceMode === 'career') {
        const hasCareerMarkers = questionText.includes('interview') ||
          questionText.includes('practical') ||
          questionText.includes('real-world') ||
          questionText.includes('industry');

        if (!hasCareerMarkers && !q.question.includes('Google') && !q.question.includes('Amazon') && !q.question.includes('Microsoft')) {
          console.warn(`[WARN] Question ${index + 1} may not be career-focused: "${q.question}"`);
        }
      }
    });

    return { questions: validQuestions, note };
  } catch (error) {
    console.error('[ERROR] Failed to parse questions:', error);
    throw new Error(`Failed to parse AI response: ${error.message}`);
  }
}

// Helper: Check for existing questions to avoid duplicates
async function checkExistingQuestions(topicId: string, practiceMode: string): Promise<{ count: number, sampleQuestions: string[] }> {
  try {
    const { data: existingQuestions, error } = await supabase
      .from("questions")
      .select("question")
      .eq("topic_id", topicId)
      .eq("practice_mode", practiceMode)
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

// Helper: Detect topic type and engineering branch based on content
function detectTopicType(topicName: string, topicContent: string): { type: 'engineering' | 'coding' | 'hybrid_cs_coding' | 'cs_with_interviews' | 'general', branch?: string } {
  // Computer Science & Information Technology
  const csKeywords = [
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

  // Electrical Engineering
  const eeKeywords = [
    'electrical', 'power system', 'transformer', 'generator', 'motor', 'transmission',
    'distribution', 'voltage', 'current', 'resistance', 'capacitance', 'inductance',
    'circuit analysis', 'network theory', 'control system', 'feedback', 'pid',
    'electromagnetic', 'magnetic field', 'electric field', 'electromagnetic induction',
    'ac circuit', 'dc circuit', 'three phase', 'single phase', 'power factor',
    'electrical machine', 'synchronous', 'asynchronous', 'induction motor',
    'electrical measurement', 'instrumentation', 'transducer', 'sensor'
  ];

  // Electronics & Communication Engineering
  const eceKeywords = [
    'electronics', 'communication', 'signal processing', 'digital signal processing',
    'analog circuit', 'digital circuit', 'amplifier', 'oscillator', 'filter',
    'modulation', 'demodulation', 'am', 'fm', 'pm', 'psk', 'qpsk', 'fsk',
    'antenna', 'wave propagation', 'microwave', 'optical fiber', 'satellite',
    'mobile communication', 'cellular', 'wireless', 'bluetooth', 'wifi',
    'vlsi', 'ic design', 'layout', 'fabrication', 'semiconductor', 'diode',
    'transistor', 'mosfet', 'bjt', 'op-amp', 'adc', 'dac', 'microcontroller'
  ];

  // Mechanical Engineering
  const meKeywords = [
    'mechanical', 'thermodynamics', 'heat transfer', 'fluid mechanics', 'hydraulics',
    'pneumatics', 'strength of materials', 'mechanics of materials', 'stress',
    'strain', 'elasticity', 'plasticity', 'machine design', 'kinematics',
    'dynamics', 'vibration', 'automobile', 'engine', 'turbine', 'pump',
    'compressor', 'refrigeration', 'air conditioning', 'manufacturing',
    'machining', 'welding', 'casting', 'forging', 'materials science',
    'metallurgy', 'composite', 'ceramic', 'polymer', 'mechanical properties'
  ];

  // Civil Engineering
  const ceKeywords = [
    'civil', 'structural', 'concrete', 'steel', 'reinforcement', 'beam',
    'column', 'slab', 'foundation', 'soil mechanics', 'geotechnical',
    'surveying', 'transportation', 'highway', 'bridge', 'dam', 'tunnel',
    'water resources', 'hydrology', 'irrigation', 'environmental',
    'wastewater', 'air pollution', 'construction', 'project management',
    'building', 'architecture', 'design', 'analysis', 'stability'
  ];

  // Chemical Engineering
  const cheKeywords = [
    'chemical', 'reaction engineering', 'process control', 'unit operation',
    'distillation', 'absorption', 'adsorption', 'extraction', 'crystallization',
    'fluid dynamics', 'heat exchanger', 'reactor', 'catalyst', 'kinetics',
    'thermodynamics', 'phase equilibrium', 'mass transfer', 'heat transfer',
    'polymer', 'petroleum', 'refinery', 'biochemical', 'fermentation',
    'separation', 'filtration', 'centrifugation', 'evaporation', 'drying'
  ];

  // Production & Industrial Engineering
  const piKeywords = [
    'production', 'industrial', 'manufacturing', 'production planning', 'inventory',
    'quality control', 'statistical process control', 'spc', 'six sigma', 'lean',
    'operations research', 'linear programming', 'simulation', 'optimization', 'queuing',
    'work study', 'method study', 'time study', 'motion study', 'ergonomics',
    'facility layout', 'plant layout', 'material handling', 'conveyor', 'crane',
    'supply chain', 'logistics', 'procurement', 'warehousing', 'distribution',
    'maintenance', 'reliability', 'preventive maintenance', 'predictive maintenance',
    'automation', 'robotics', 'cnc', 'cad', 'cam', 'cim', 'flexible manufacturing',
    'just in time', 'jit', 'kanban', 'toyota production system', 'tps',
    'industrial engineering', 'work measurement', 'standard time', 'productivity',
    'capacity planning', 'aggregate planning', 'master production schedule', 'mrp'
  ];

  // General Engineering (common across branches)
  const generalEngineeringKeywords = [
    'engineering', 'design', 'analysis', 'calculation', 'formula', 'equation',
    'theory', 'principle', 'law', 'model', 'simulation', 'optimization',
    'efficiency', 'performance', 'specification', 'standard', 'code',
    'safety', 'reliability', 'maintenance', 'inspection', 'testing',
    'quality', 'control', 'measurement', 'instrumentation', 'automation'
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

  // Calculate scores for each engineering branch
  const csScore = csKeywords.filter(keyword => combinedText.includes(keyword)).length;
  const eeScore = eeKeywords.filter(keyword => combinedText.includes(keyword)).length;
  const eceScore = eceKeywords.filter(keyword => combinedText.includes(keyword)).length;
  const meScore = meKeywords.filter(keyword => combinedText.includes(keyword)).length;
  const ceScore = ceKeywords.filter(keyword => combinedText.includes(keyword)).length;
  const cheScore = cheKeywords.filter(keyword => combinedText.includes(keyword)).length;
  const piScore = piKeywords.filter(keyword => combinedText.includes(keyword)).length;
  const generalEngineeringScore = generalEngineeringKeywords.filter(keyword => combinedText.includes(keyword)).length;

  const codingScore = codingKeywords.filter(keyword => combinedText.includes(keyword)).length;

  // Determine the dominant engineering branch
  const branchScores = [
    { branch: 'CS', score: csScore },
    { branch: 'EE', score: eeScore },
    { branch: 'ECE', score: eceScore },
    { branch: 'ME', score: meScore },
    { branch: 'CE', score: ceScore },
    { branch: 'CHE', score: cheScore },
    { branch: 'PI', score: piScore }
  ];

  const dominantBranch = branchScores.reduce((max, current) =>
    current.score > max.score ? current : max
  );

  const totalEngineeringScore = csScore + eeScore + eceScore + meScore + ceScore + cheScore + piScore + generalEngineeringScore;

  // Check for hybrid CS + Coding topics
  if (dominantBranch.branch === 'CS' && csScore >= 2 && codingScore >= 2) {
    return {
      type: 'hybrid_cs_coding',
      branch: 'CS'
    };
  } else if (dominantBranch.branch === 'CS' && csScore >= 2) {
    // Core CS subjects that are frequently asked in interviews
    return {
      type: 'cs_with_interviews',
      branch: 'CS'
    };
  } else if (totalEngineeringScore > codingScore && totalEngineeringScore >= 2) {
    return {
      type: 'engineering',
      branch: dominantBranch.score >= 2 ? dominantBranch.branch : 'General'
    };
  } else if (codingScore > totalEngineeringScore && codingScore >= 2) {
    return { type: 'coding' };
  } else {
    return { type: 'general' };
  }
}

Deno.serve(async (req) => {
  const startTime = Date.now();

  // CORS headers for all responses
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
    'Access-Control-Max-Age': '86400',
  };

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }



  let topic_id: string | undefined;
  let question_count: number = 3;
  let difficulty_level: string = 'intermediate';
  let practice_mode: string = 'academic';

  try {
    const body = await req.json();
    topic_id = body.topic_id;
    question_count = body.question_count || 3;
    difficulty_level = body.difficulty_level || 'intermediate';
    practice_mode = body.practice_mode || 'academic';



    // Enhanced validation
    if (!topic_id || typeof topic_id !== 'string') {
      throw new Error("topic_id is required and must be a string");
    }

    if (typeof question_count !== 'number' || question_count < 1 || question_count > 25) {
      throw new Error("question_count must be a number between 1 and 25");
    }

    const validDifficulties = ['beginner', 'intermediate', 'advanced'];
    if (!validDifficulties.includes(difficulty_level)) {
      throw new Error("difficulty_level must be one of: beginner, intermediate, advanced");
    }

    const validPracticeModes = ['academic', 'competitive', 'career'];
    if (!validPracticeModes.includes(practice_mode)) {
      throw new Error("practice_mode must be one of: academic, competitive, career");
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
        ...corsHeaders,
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
          ...corsHeaders,
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
        ...corsHeaders,
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
        ...corsHeaders,
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
        ...corsHeaders,
      }
    });
  }

  // Check for existing questions to provide context
  const existingQuestions = await checkExistingQuestions(topic_id, practice_mode);
  if (existingQuestions.count > 0) {
    console.log(`[INFO] Found ${existingQuestions.count} existing ${practice_mode} questions for topic ${topic_id}`);
  }

  // Detect topic type and engineering branch
  const topicAnalysis = detectTopicType(topic.name, topic.content);
  const topicType = topicAnalysis.type;
  const engineeringBranch = topicAnalysis.branch;
  console.log(`[INFO] Detected topic type: ${topicType}${engineeringBranch ? ` (${engineeringBranch})` : ''} for topic: ${topic.name}`);

  // Enhanced Gemini prompt with quality focus and GATE topic detection
  const geminiPrompt = `
You are an expert educational AI specializing in creating high-quality multiple-choice questions (MCQs) for academic assessments.

TASK: Generate ${question_count} MCQ questions based on the provided topic content.

TOPIC INFORMATION:
- Topic Name: ${topic.name}
- Topic Content: ${topic.content}
- Practice Mode: ${practice_mode.toUpperCase()}
- Topic Type: ${topicType.toUpperCase()}${engineeringBranch ? ` (${engineeringBranch} Branch)` : ''}

QUALITY ASSURANCE REQUIREMENTS:
1. Each question must be directly derived from the provided topic content
2. Questions should test deep understanding, not just memorization
3. All options must be plausible and technically accurate
4. Avoid ambiguous wording or trick questions
5. Ensure questions are appropriate for engineering students

TOPIC TYPE DETECTION:
Based on the topic content, determine if this is:
1. ENGINEERING TOPIC (Computer Science, Electrical, Electronics, Mechanical, Civil, Chemical, etc.)
2. CODING/PROGRAMMING TOPIC (Programming languages, algorithms, software development)
3. GENERAL ACADEMIC TOPIC (Other subjects)

DETECTED TOPIC TYPE: ${topicType.toUpperCase()}${engineeringBranch ? ` (${engineeringBranch} Branch)` : ''}

GATE TOPIC DETECTION:
First, determine if this topic is part of the GATE syllabus for ${engineeringBranch || 'engineering'} branch.

GATE SYLLABUS KEYWORDS BY BRANCH:
- CS: Data Structures, Algorithms, Operating Systems, DBMS, Computer Networks, Compiler Design, Software Engineering, Digital Logic, Computer Organization
- EE: Circuit Theory, Control Systems, Electrical Machines, Power Systems, Analog/Digital Electronics, Electromagnetic Fields
- ECE: Signals & Systems, Electronic Devices, Analog/Digital Circuits, Communication Systems, Control Systems, Electromagnetics
- ME: Thermodynamics, Fluid Mechanics, Heat Transfer, Machine Design, Manufacturing, Materials Science
- CE: Structural Engineering, Geotechnical, Transportation, Water Resources, Environmental Engineering
- CHE: Chemical Reaction Engineering, Process Control, Unit Operations, Thermodynamics, Mass Transfer
- PI: Operations Research, Production Planning, Quality Control, Industrial Engineering, Manufacturing Systems

PRACTICE MODE GUIDELINES:

${practice_mode === 'academic' ? `
ACADEMIC MODE - University Exam Preparation:
- Focus on core syllabus concepts and fundamental understanding
- Clear academic language suitable for semester exams
- Conceptual questions that test theoretical knowledge
- Cover basic to intermediate difficulty concepts
- Examples: "What is the primary function of...", "Which of the following best describes..."
- Ensure questions align with university curriculum standards
` : ''}

${practice_mode === 'competitive' ? `
COMPETITIVE MODE - Engineering Competitive Exams:

Generate competitive engineering exam questions suitable for various exams:

QUESTION DISTRIBUTION RULES:

FOR GATE-RELEVANT TOPICS (CS, EE, ECE, ME, CE, CHE, PI core subjects):
- Generate 70% GATE questions with year references: "(GATE 2023)", "(GATE 2022)", "(GATE 2021)"
- Generate 30% other competitive exam questions: "(ESE 2023)", "(ISRO 2022)", "(DRDO 2021)", "(BARC 2023)"
- Include numerical problems and analytical thinking
- Focus on problem-solving and application
- Branch-specific technical depth for engineering topics
- Examples: "In a compiler, if the buffer size is 512 bytes, what is the maximum lookahead? (GATE 2023)"

FOR NON-GATE OR GENERAL TOPICS (Introduction, Basic concepts, Non-core subjects):
- Generate 20% GATE questions (if any relevance exists)
- Generate 80% other competitive exam questions for ESE, ISRO, DRDO, PSU exams
- Include year references from other exams: "(ESE 2023)", "(ISRO 2022)", "(DRDO 2021)", "(BARC 2023)"
- Maintain competitive exam rigor with numerical problems and analytical thinking
- Use engineering competitive exam question patterns
- Examples: "Calculate the efficiency of a heat engine operating between 800K and 300K reservoirs. (ESE 2023)"

SMART TOPIC DETECTION:
- Automatically detect if the topic is GATE-relevant based on content and engineering branch
- Apply appropriate question distribution ratios
- Ensure comprehensive preparation for all competitive exams
` : ''}

${practice_mode === 'career' ? `
CAREER MODE - Interview & Practical Preparation:

QUESTION DISTRIBUTION FOR CAREER MODE - STRICT ENFORCEMENT:
- MANDATORY: Generate EXACTLY 60% questions (12 out of 20) with specific COMPANY INTERVIEW references
- MANDATORY: Generate EXACTLY 40% questions (8 out of 20) with other career/role references
- DO NOT use generic terms like "Engineering Interview" or "Technical Interview" for the 60% company questions
- ALWAYS use specific company names with "Interview" or role designation (like "SDE", "Engineer")
- Focus on real-world scenarios and practical applications

CAREER OPPORTUNITY REFERENCES:

FOR CS/CODING TOPICS:
MANDATORY: Use exactly 60% questions (12 out of 20) with specific company interview references:
- MUST USE: "(Google Interview)", "(Amazon SDE)", "(Microsoft Interview)", "(Apple Interview)", "(Meta Interview)", "(Netflix Interview)", "(Uber Interview)", "(Airbnb Interview)", "(Adobe Interview)", "(Oracle Interview)", "(Salesforce Interview)", "(IBM Interview)", "(Intel Interview)", "(Nvidia Interview)", "(Tesla Interview)", "(SpaceX Interview)", "(Twitter Interview)", "(LinkedIn Interview)", "(PayPal Interview)", "(Stripe Interview)", "(Shopify Interview)", "(Atlassian Interview)", "(Zoom Interview)", "(Slack Interview)", "(Dropbox Interview)", "(GitHub Interview)", "(GitLab Interview)", "(Redis Interview)", "(MongoDB Interview)", "(Elastic Interview)", "(Palantir Interview)"

MANDATORY: Use exactly 40% questions (8 out of 20) with other tech career references:
- "(Technical Architect Role)", "(DevOps Engineer)", "(Cloud Solutions Architect)", "(Data Scientist Interview)", "(ML Engineer Role)", "(Full Stack Developer)", "(Backend Engineer)", "(Frontend Engineer)", "(Mobile App Developer)", "(AI/ML Researcher)", "(Site Reliability Engineer)", "(Security Engineer)", "(Platform Engineer)", "(Infrastructure Engineer)", "(Database Administrator)", "(Systems Analyst)", "(Software Architect)", "(Lead Developer)", "(Engineering Manager)", "(CTO Interview)"

FOR OTHER ENGINEERING BRANCHES:
MANDATORY: Use exactly 60% questions (12 out of 20) with specific COMPANY INTERVIEW references by branch:

MECHANICAL/PRODUCTION COMPANIES - MUST USE:
"(Tata Motors Interview)", "(Mahindra Interview)", "(Bajaj Auto Interview)", "(L&T Interview)", "(BHEL Interview)", "(Siemens Interview)", "(GE Interview)", "(Caterpillar Interview)", "(John Deere Interview)", "(Bosch Interview)", "(Maruti Suzuki Interview)", "(Hero MotoCorp Interview)", "(TVS Motors Interview)", "(Ashok Leyland Interview)", "(Cummins Interview)", "(Thermax Interview)", "(Godrej Interview)", "(Kirloskar Interview)", "(Crompton Greaves Interview)", "(Voltas Interview)"

ELECTRICAL COMPANIES - MUST USE:
"(ABB Interview)", "(Schneider Electric Interview)", "(Siemens Interview)", "(GE Interview)", "(BHEL Interview)", "(Crompton Greaves Interview)", "(Havells Interview)", "(Legrand Interview)", "(Eaton Interview)", "(Emerson Interview)", "(Tata Power Interview)", "(Adani Power Interview)", "(JSW Energy Interview)", "(Torrent Power Interview)", "(CG Power Interview)", "(KEI Industries Interview)", "(Polycab Interview)", "(V-Guard Interview)", "(Orient Electric Interview)", "(Bajaj Electricals Interview)"

CIVIL COMPANIES - MUST USE:
"(L&T Interview)", "(Shapoorji Pallonji Interview)", "(DLF Interview)", "(Godrej Properties Interview)", "(Tata Projects Interview)", "(HCC Interview)", "(Gammon India Interview)", "(NCC Interview)", "(Simplex Infrastructures Interview)", "(Punj Lloyd Interview)", "(Nagarjuna Construction Interview)", "(ITD Cementation Interview)", "(Afcons Infrastructure Interview)", "(Dilip Buildcon Interview)", "(PNC Infratech Interview)", "(Kajaria Ceramics Interview)", "(Asian Granito Interview)", "(Cera Sanitaryware Interview)", "(Hindware Interview)", "(RAK Ceramics Interview)"

CHEMICAL COMPANIES - MUST USE:
"(Reliance Interview)", "(ONGC Interview)", "(IOCL Interview)", "(BPCL Interview)", "(UPL Interview)", "(Pidilite Interview)", "(Asian Paints Interview)", "(Tata Chemicals Interview)", "(Aarti Industries Interview)", "(Deepak Nitrite Interview)", "(SRF Limited Interview)", "(Jubilant Life Sciences Interview)", "(Dr. Reddy's Interview)", "(Sun Pharma Interview)", "(Cipla Interview)", "(Lupin Interview)", "(Aurobindo Pharma Interview)", "(Glenmark Interview)", "(Torrent Pharma Interview)", "(Biocon Interview)"

ELECTRONICS/ECE COMPANIES - MUST USE:
"(Intel Interview)", "(Qualcomm Interview)", "(Broadcom Interview)", "(Texas Instruments Interview)", "(Analog Devices Interview)", "(Samsung Interview)", "(TSMC Interview)", "(MediaTek Interview)", "(Nvidia Interview)", "(AMD Interview)", "(ARM Interview)", "(Marvell Interview)", "(STMicroelectronics Interview)", "(NXP Interview)", "(Sony Interview)", "(LG Electronics Interview)", "(Panasonic Interview)", "(Hitachi Interview)", "(Ericsson Interview)", "(Nokia Interview)"

MANDATORY: Use exactly 40% questions (8 out of 20) with other career references:
"(Technical Consultant)", "(Project Manager Role)", "(R&D Engineer)", "(Design Engineer)", "(Quality Engineer)", "(Process Engineer)", "(Field Engineer)", "(Sales Engineer)", "(Product Manager)", "(Engineering Manager)", "(Application Engineer)", "(Test Engineer)", "(Validation Engineer)", "(Commissioning Engineer)", "(Maintenance Engineer)", "(Operations Engineer)", "(Planning Engineer)", "(Safety Engineer)", "(Environmental Engineer)", "(Energy Auditor)"

HANDLING TOPICS WITHOUT DIRECT INDUSTRY RELEVANCE:
- For foundational/theoretical topics (like basic mathematics, physics principles, introductory concepts):
  * Use generic career references: "(Engineering Interview)", "(Technical Interview)", "(Graduate Engineer)", "(Junior Engineer)"
  * Focus on how the concept applies to engineering practice
  * Ask about practical applications and real-world scenarios
  * Example: "How would you explain this concept to a non-technical stakeholder? (Engineering Interview)"

- For highly academic/research topics:
  * Use research-oriented references: "(Research Engineer)", "(Development Engineer)", "(Innovation Team)", "(Technical Specialist)"
  * Focus on problem-solving and analytical thinking
  * Example: "How would you approach this problem in a research setting? (Research Engineer)"

- For topics with limited direct application:
  * Use educational/training references: "(Technical Training)", "(Engineering Fundamentals)", "(Graduate Program)", "(Internship Interview)"
  * Focus on understanding and explanation skills
  * Example: "Explain this concept and its significance in engineering. (Graduate Program)"

${engineeringBranch === 'CS' || topicType === 'coding' ? `
FOR CS/CODING TOPICS:
- Interview-style questions with company references
- Focus on practical programming scenarios and problem-solving
- Algorithm and data structure applications in real systems
- System design and scalability questions
- Real-world implementation challenges
- Examples: "How would you implement a distributed cache system? What are the key considerations? (Google Interview)"
- Examples: "Explain the time complexity of merge sort and when you would use it in production. (Amazon SDE)"
` : `
FOR ENGINEERING TOPICS:
- Practical application questions and design scenarios with company references
- Real-world engineering problems and viva-style questions
- Industry-relevant applications and case studies
- Professional engineering challenges and troubleshooting



- Examples: "In a flywheel design for automotive applications, how would you optimize the moment of inertia? (Tata Motors Interview)"
- Examples: "Design a heat exchanger for a chemical plant. What parameters would you optimize? (Reliance Interview)"
- Examples: "How would you approach failure analysis of a mechanical component? (Technical Consultant)"
- Examples: "Describe your experience with vibration analysis in rotating machinery. (R&D Engineer Role)"
- Examples: "What factors would you consider in selecting materials for high-temperature applications? (Design Engineer)"
`}

INTERVIEW QUESTION STYLES:
- "Explain how..." and "Describe the process..." with industry context
- "What would you do if..." scenario-based questions with real company situations
- "Compare and contrast..." analytical questions with practical applications
- "Design a system that..." practical implementation questions with industry constraints
- "In your experience with [specific application]..." experience-based questions
- "How would you troubleshoot..." problem-solving questions with real scenarios

INDUSTRY CONTEXT EXAMPLES:
- Manufacturing: "In an automotive assembly line..." 
- Power Systems: "In a thermal power plant..."
- Process Industries: "In a petrochemical refinery..."
- Construction: "In a high-rise building project..."
- Electronics: "In semiconductor fabrication..."
- Software: "In a distributed system..."

REFERENCE CONTEXTS WHERE THESE CONCEPTS ARE APPLIED:
- Add context like "commonly asked in [Company] technical interviews"
- Include industry applications: "used in automotive/aerospace/power/chemical industries"
- Mention real-world scenarios: "critical for plant operations/safety/efficiency"

VALIDATION CHECK FOR CAREER MODE:
Before finalizing questions, ensure:

FOR CS/CODING TOPICS:
- Count exactly 12 questions with tech company names (Google Interview, Amazon SDE, Microsoft Interview, etc.)
- Count exactly 8 questions with tech role references (DevOps Engineer, Technical Architect, etc.)
- No generic "Engineering Interview" or "Technical Interview" in the 60% company category
- Each company reference should be realistic for the topic (e.g., Google for algorithms, Amazon for distributed systems)

FOR OTHER ENGINEERING BRANCHES:
- Count exactly 12 questions with branch-specific company interviews (Tata Motors Interview, L&T Interview, Reliance Interview, etc.)
- Count exactly 8 questions with engineering role references (Design Engineer, R&D Engineer, Technical Consultant, etc.)
- No generic "Engineering Interview" or "Technical Interview" in the 60% company category
- Each company reference should match the engineering branch (e.g., Tata Motors for Mechanical, ABB for Electrical, Reliance for Chemical)
` : ''}

CURRENT MODE: ${practice_mode.toUpperCase()}

QUESTION STYLE GUIDELINES:
- Create questions appropriate for intermediate difficulty level
- Focus on conceptual understanding and practical application
- Ensure questions are directly related to the provided topic content
- Make questions clear and unambiguous

MATHEMATICAL AND VISUAL CONTENT GUIDELINES:
When the topic involves mathematical concepts, circuits, algorithms, or data structures:

1. USE LATEX MATH NOTATION for mathematical expressions:
   - Inline math: $x^2 + y^2 = z^2$
   - Display math: $$\begin{matrix} a & b \\\\ c & d \end{matrix}$$
   - Matrices: $$\begin{pmatrix} 1 & 2 \\\\ 3 & 4 \end{pmatrix}$$
   - Equations: $$f(x) = \sum_{i=1}^{n} x_i$$

2. USE ASCII DIAGRAMS for simple visual content:
   - Circuit diagrams:
     ```
        R1
     +--[===]--+
     |         |
    V+         R2
     |       [===]
     +----+----+
          |
         GND
     ```
   - Tree structures:
     ```
         A
        / \\
       B   C
      /   / \\
     D   E   F
     ```
   - Flowcharts:
     ```
     [Start]
        |
        v
     [Process]
        |
        v
      [End]
     ```

3. USE MARKDOWN TABLES for data representation:
   ```
   | Input | Output | Result |
   |-------|--------|--------|
   | 0     | 0      | 0      |
   | 0     | 1      | 1      |
   | 1     | 0      | 1      |
   | 1     | 1      | 0      |
   ```

4. APPLY THESE BASED ON TOPIC TYPE:
   - Mathematics: LaTeX for equations, matrices, formulas
   - Computer Science: ASCII diagrams for algorithms, data structures
   - Electronics: ASCII circuit diagrams
   - Engineering: Diagrams for processes, systems
   - Data/Statistics: Tables for datasets, truth tables

QUESTION REQUIREMENTS:
1. Each question must have exactly 4 options (A, B, C, D)
2. Only one option should be correct
3. All options should be plausible and well-written
4. Questions should test understanding, not just memorization
5. Use clear, concise language with appropriate mathematical/visual content
6. Ensure questions are directly related to the provided content
7. Each question should test a different aspect of the topic
8. Include mathematical expressions, diagrams, or tables when relevant to the topic

STUDENT NEEDS ANALYSIS:
Based on the practice mode, tailor questions to what students actually need:

${practice_mode === 'academic' ? `
ACADEMIC STUDENTS NEED:
- Clear concept explanations through questions
- Step-by-step problem-solving approaches
- Fundamental principle applications
- Exam-pattern familiarity
- Confidence building through achievable questions
` : ''}

${practice_mode === 'competitive' ? `
COMPETITIVE EXAM STUDENTS NEED:
- Time-efficient problem-solving techniques
- Pattern recognition skills
- Numerical accuracy under pressure
- Multi-concept integration
- Elimination strategy practice
- Exposure to various competitive exam patterns (GATE, ESE, ISRO, DRDO, PSU)
- Engineering application-focused problems
` : ''}

${practice_mode === 'career' ? `
CAREER-FOCUSED STUDENTS NEED:
- Real-world application understanding
- Problem-solving methodology
- Industry-standard approaches
- Communication of technical concepts
- Practical implementation knowledge
` : ''}

FORMATTING REQUIREMENTS:
${practice_mode === 'competitive' ? `
- For GATE topics: Include year references "(GATE 2023)", "(GATE 2022)", "(GATE 2021)"
- For non-GATE topics: Include other competitive exam references "(ESE 2023)", "(ISRO 2022)", "(DRDO 2021)", "(BARC 2023)"
- Include numerical problems and analytical thinking for ALL competitive questions
- Maintain competitive exam rigor regardless of GATE status
- Focus on engineering problem-solving approach
` : ''}

${practice_mode === 'career' && (engineeringBranch === 'CS' || topicType === 'coding') ? `
- For interview questions, include company references: "(Google Interview)", "(Amazon SDE)", "(Microsoft)"
- Focus on practical problem-solving scenarios
- Include follow-up thinking prompts
` : ''}

RESPONSE FORMAT:
${practice_mode === 'competitive' ? `
For competitive mode, return a JSON object with this structure:
{
  "note": "Optional note about GATE relevance (only if topic is not in GATE syllabus)",
  "questions": [
    {
      "question": "What is the primary function of a lexical analyzer in a compiler? (GATE 2023)",
      "options": ["Option A text", "Option B text", "Option C text", "Option D text"],
      "correctAnswer": 0
    }
  ]
}

If topic IS in GATE syllabus: omit the "note" field
If topic is NOT in GATE syllabus: include "note": "This topic is not typically covered in GATE syllabus. Questions are designed for other engineering competitive exams like ESE, ISRO, DRDO, PSU exams."
` : `
Return ONLY a valid JSON array with this exact structure:
[
  {
    "question": "What is the primary function of...",
    "options": ["Option A text", "Option B text", "Option C text", "Option D text"],
    "correctAnswer": 0
  }
]
`}

IMPORTANT:
- correctAnswer should be 0, 1, 2, or 3 (corresponding to A, B, C, D)
- The correctAnswer index MUST point to the actually correct option
- Ensure the JSON is valid and properly formatted
- Focus on the specific content provided in the topic
- Generate exactly ${question_count} questions
- Make each question unique and test different aspects of the topic
- VERIFY: Before returning, ensure each correctAnswer index (0-3) points to the correct option

Generate ${question_count} questions for ${practice_mode.toUpperCase()} mode now:`;

  let questions;
  let gateNote;
  try {

    const geminiResponse = await callGemini(geminiPrompt, geminiApiKey);

    let text = geminiResponse.candidates?.[0]?.content?.parts?.[0]?.text || "";
    if (!text) {
      throw new Error("Empty response from Gemini API");
    }

    const result = validateAndParseQuestions(text, question_count, practice_mode);
    questions = result.questions;
    gateNote = result.note;
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
        ...corsHeaders,
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
      engineering_branch: engineeringBranch,
      practice_mode: practice_mode,
      questions,
      difficulty_level,
      question_count: questions.length,
      processing_time_ms: processingTime,
      existing_questions_count: existingQuestions.count,
      gate_note: gateNote, // Include the GATE note if present
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
        ...corsHeaders,
      }
    }
  );
}); 