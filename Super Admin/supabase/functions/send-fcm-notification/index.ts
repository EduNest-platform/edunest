import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationRequest {
  studentIds: string[]
  title: string
  body: string
  data?: Record<string, any>
  type?: 'assignment_marks' | 'midsem_marks' | 'attendance_alert' | 'test_assigned'
}

// Function to get OAuth2 access token for FCM v1 API
async function getAccessToken(): Promise<string> {
  // Get Firebase service account from environment variables
  const serviceAccount = {
    type: Deno.env.get('FIREBASE_TYPE') || 'service_account',
    project_id: Deno.env.get('FIREBASE_PROJECT_ID'),
    private_key_id: Deno.env.get('FIREBASE_PRIVATE_KEY_ID'),
    private_key: Deno.env.get('FIREBASE_PRIVATE_KEY'),
    client_email: Deno.env.get('FIREBASE_CLIENT_EMAIL'),
    client_id: Deno.env.get('FIREBASE_CLIENT_ID'),
    auth_uri: Deno.env.get('FIREBASE_AUTH_URI') || 'https://accounts.google.com/o/oauth2/auth',
    token_uri: Deno.env.get('FIREBASE_TOKEN_URI') || 'https://oauth2.googleapis.com/token',
    auth_provider_x509_cert_url: Deno.env.get('FIREBASE_AUTH_PROVIDER_CERT_URL') || 'https://www.googleapis.com/oauth2/v1/certs',
    client_x509_cert_url: Deno.env.get('FIREBASE_CLIENT_CERT_URL')
  }

  // Validate required fields
  if (!serviceAccount.project_id || !serviceAccount.private_key || !serviceAccount.client_email) {
    throw new Error('Missing required Firebase service account environment variables: FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, FIREBASE_CLIENT_EMAIL')
  }

  // Create JWT for Google OAuth2
  const header = {
    alg: 'RS256',
    typ: 'JWT'
  }

  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600
  }

  // Import crypto key for signing
  // Fix private key formatting - extract base64 content from PEM
  let privateKey = serviceAccount.private_key
  
  // Handle various newline escape scenarios
  if (privateKey.includes('\\n')) {
    privateKey = privateKey.replace(/\\n/g, '\n')
  }
  
  // Ensure proper PEM format
  if (!privateKey.includes('-----BEGIN PRIVATE KEY-----')) {
    throw new Error('Invalid private key format - missing PEM headers')
  }
  
  // Extract base64 content from PEM (remove headers and newlines)
  const base64Key = privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '') // Remove all whitespace including newlines
  
  console.log('📱 FCM: Base64 key length:', base64Key.length)
  
  // Convert base64 to binary
  const binaryKey = Uint8Array.from(atob(base64Key), c => c.charCodeAt(0))
  
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256'
    },
    false,
    ['sign']
  )

  // Create JWT
  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const encodedPayload = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const unsignedToken = `${encodedHeader}.${encodedPayload}`
  
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  )
  
  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  
  const jwt = `${unsignedToken}.${encodedSignature}`

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  })

  const tokenData = await tokenResponse.json()
  
  if (!tokenData.access_token) {
    throw new Error('Failed to get access token: ' + JSON.stringify(tokenData))
  }

  return tokenData.access_token
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const requestData: NotificationRequest = await req.json()
    const { studentIds, title, body, data, type } = requestData

    // Validate required fields
    if (!studentIds || !Array.isArray(studentIds) || studentIds.length === 0) {
      throw new Error('studentIds array is required and cannot be empty')
    }
    if (!title || !body) {
      throw new Error('title and body are required')
    }

    console.log(`📱 FCM: Processing notification for ${studentIds.length} students`)
    console.log(`📱 FCM: Type: ${type}, Title: ${title}`)

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get active FCM tokens for the students
    const { data: tokens, error: tokenError } = await supabaseClient
      .from('user_fcm_tokens')
      .select('fcm_token, user_id, device_type')
      .in('user_id', studentIds)
      .eq('is_active', true)

    if (tokenError) {
      console.error('📱 FCM: Error fetching tokens:', tokenError)
      throw tokenError
    }

    if (!tokens || tokens.length === 0) {
      console.log('📱 FCM: No active tokens found for students')
      return new Response(JSON.stringify({ 
        success: true, 
        message: 'No active FCM tokens found for the specified students',
        studentsRequested: studentIds.length,
        tokensFound: 0
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    console.log(`📱 FCM: Found ${tokens.length} active tokens`)

    // Get Firebase project ID and access token
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID')
    if (!projectId) {
      throw new Error('FIREBASE_PROJECT_ID environment variable is not set')
    }

    const accessToken = await getAccessToken()

    // Prepare notification payload for FCM v1 API
    const createNotificationPayload = (token: string) => ({
      message: {
        token,
        notification: {
          title,
          body,
        },
        data: {
          type: type || 'general',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          ...Object.fromEntries(
            Object.entries(data || {}).map(([key, value]) => [key, String(value)])
          )
        },
        android: {
          notification: {
            icon: 'ic_notification',
            color: '#2563eb',
            sound: 'default',
            channel_id: type === 'assignment_marks' || type === 'midsem_marks' 
              ? 'edunest_marks' 
              : 'edunest_notifications'
          },
          priority: 'high'
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      }
    })

    // Send notifications to all tokens using FCM v1 API
    const notificationPromises = tokens.map(async (tokenData) => {
      try {
        const payload = createNotificationPayload(tokenData.fcm_token)
        console.log(`📱 FCM: Sending payload:`, JSON.stringify(payload, null, 2))
        
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(payload),
          }
        )

        const result = await response.json()
        
        // Handle invalid tokens in v1 API
        if (!response.ok) {
          console.error(`📱 FCM: Failed to send notification. Status: ${response.status}`)
          console.error(`📱 FCM: Error details:`, JSON.stringify(result, null, 2))
          console.error(`📱 FCM: Token: ${tokenData.fcm_token.substring(0, 20)}...`)
          
          if (result.error?.details?.[0]?.errorCode === 'UNREGISTERED' || 
              result.error?.details?.[0]?.errorCode === 'INVALID_ARGUMENT') {
            console.log(`📱 FCM: Deactivating invalid token for user ${tokenData.user_id}`)
            // Deactivate invalid token
            await supabaseClient
              .from('user_fcm_tokens')
              .update({ is_active: false })
              .eq('fcm_token', tokenData.fcm_token)
          }
          
          return {
            user_id: tokenData.user_id,
            device_type: tokenData.device_type,
            success: false,
            error: result.error?.message || `HTTP ${response.status}: ${response.statusText}`,
            message_id: null
          }
        }

        return {
          user_id: tokenData.user_id,
          device_type: tokenData.device_type,
          success: true,
          error: null,
          message_id: result.name || null
        }
      } catch (error) {
        console.error(`📱 FCM: Error sending to token:`, error)
        return {
          user_id: tokenData.user_id,
          device_type: tokenData.device_type,
          success: false,
          error: error.message
        }
      }
    })

    const results = await Promise.all(notificationPromises)
    const successCount = results.filter(r => r.success).length
    const failureCount = results.filter(r => !r.success).length

    console.log(`📱 FCM: Notification sent - Success: ${successCount}, Failed: ${failureCount}`)

    return new Response(JSON.stringify({ 
      success: true, 
      studentsRequested: studentIds.length,
      tokensFound: tokens.length,
      successCount,
      failureCount,
      results,
      type,
      title
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('📱 FCM: Function error:', error)
    return new Response(JSON.stringify({ 
      error: error.message,
      success: false 
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
