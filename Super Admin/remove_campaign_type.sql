-- Remove campaign_type field from existing feedback campaign data
-- This will clean up any existing campaigns that might have the campaign_type field

UPDATE public.feedback_data 
SET campaign_info = campaign_info - 'campaign_type'
WHERE type = 'campaign' 
AND campaign_info ? 'campaign_type';

-- Verify the update worked
SELECT 
    id,
    campaign_info->>'title' as title,
    campaign_info ? 'campaign_type' as has_campaign_type,
    campaign_info
FROM public.feedback_data 
WHERE type = 'campaign'
ORDER BY created_at DESC;
