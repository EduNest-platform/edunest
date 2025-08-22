-- Create feedback_data table for storing feedback campaigns and responses
-- This table uses JSONB for flexible storage of campaign data and responses

CREATE TABLE IF NOT EXISTS public.feedback_data (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    type VARCHAR(50) NOT NULL, -- 'campaign' or 'response'
    semester VARCHAR(100), -- For easier querying by semester
    campaign_info JSONB, -- Stores complete campaign data for type='campaign'
    response_info JSONB, -- Stores response data for type='response'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_feedback_data_type ON public.feedback_data(type);
CREATE INDEX IF NOT EXISTS idx_feedback_data_semester ON public.feedback_data(semester);
CREATE INDEX IF NOT EXISTS idx_feedback_data_created_at ON public.feedback_data(created_at DESC);

-- Create index on campaign_info for campaign-specific queries
CREATE INDEX IF NOT EXISTS idx_feedback_data_campaign_status ON public.feedback_data USING GIN ((campaign_info->'status')) WHERE type = 'campaign';
CREATE INDEX IF NOT EXISTS idx_feedback_data_campaign_hierarchy ON public.feedback_data USING GIN ((campaign_info->'hierarchy')) WHERE type = 'campaign';

-- Create index on response_info for response-specific queries
CREATE INDEX IF NOT EXISTS idx_feedback_data_response_campaign ON public.feedback_data USING GIN ((response_info->'campaign_id')) WHERE type = 'response';

-- Add RLS (Row Level Security) policies if needed
ALTER TABLE public.feedback_data ENABLE ROW LEVEL SECURITY;

-- Policy for authenticated users to read all data
CREATE POLICY "Allow authenticated users to read feedback data" ON public.feedback_data
    FOR SELECT USING (auth.role() = 'authenticated');

-- Policy for authenticated users to insert data
CREATE POLICY "Allow authenticated users to insert feedback data" ON public.feedback_data
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Policy for authenticated users to update data
CREATE POLICY "Allow authenticated users to update feedback data" ON public.feedback_data
    FOR UPDATE USING (auth.role() = 'authenticated');

-- Policy for authenticated users to delete data
CREATE POLICY "Allow authenticated users to delete feedback data" ON public.feedback_data
    FOR DELETE USING (auth.role() = 'authenticated');

-- Add trigger for updating updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_feedback_data_updated_at BEFORE UPDATE ON public.feedback_data
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data structure documentation as comments

/*
Campaign Data Structure (when type = 'campaign'):
{
  "type": "campaign",
  "title": "Mid-Semester Feedback 2025",
  "description": "Feedback for all subjects",
  "hierarchy": {
    "collegeId": "uuid",
    "collegeName": "Engineering College",
    "branchId": "uuid", 
    "branchName": "Computer Science",
    "semesterId": "uuid",
    "semesterName": "Semester 5"
  },
  "semester": "Semester 5", // For easier querying
  "dates": {
    "start": "2025-08-21",
    "end": "2025-08-31"
  },
  "status": "active", // "draft", "active", "closed"
  "questions": [
    {
      "id": "q1",
      "text": "Teaching Quality and Clarity",
      "type": "rating",
      "scale": 5
    }
  ],
  "created_by": "admin@example.com",
  "created_at": "2025-08-21T10:30:00Z"
}

Response Data Structure (when type = 'response'):
{
  "type": "response",
  "campaign_id": "uuid",
  "student_info": {
    "semester": "Semester 5",
    "branch": "Computer Science",
    "college": "Engineering College"
  },
  "responses": [
    {
      "question_id": "q1",
      "rating": 4,
      "comment": "Optional comment"
    }
  ],
  "submitted_at": "2025-08-21T14:30:00Z",
  "is_anonymous": true
}
*/
