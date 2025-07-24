import "jsr:@supabase/functions-js/edge-runtime.d.ts"

function withCORS(response: Response) {
  const newHeaders = new Headers(response.headers);
  newHeaders.set("Access-Control-Allow-Origin", "*");
  newHeaders.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  newHeaders.set("Access-Control-Allow-Headers", "authorization, content-type");
  return new Response(response.body, {
    status: response.status,
    headers: newHeaders,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return withCORS(new Response(null, { status: 204 }));
  }

  // Require Authorization header
  const authHeader = req.headers.get("authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return withCORS(new Response(
      JSON.stringify({ code: 401, message: "Missing or invalid authorization header" }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    ));
  }

  const apiKey = Deno.env.get("GOOGLE_API_KEY");
  const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
  const serviceAccountJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
  if (!apiKey || !clientId || !serviceAccountJson) {
    return withCORS(new Response(
      JSON.stringify({ error: "Missing Google API credentials" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    ));
  }

  let fileId = null;
  let checkOnly = false;
  try {
    const body = await req.json();
    fileId = body.fileId;
    checkOnly = !!body.checkOnly;
  } catch (e) {
    return withCORS(new Response(JSON.stringify({ error: "Invalid JSON body" }), { status: 400, headers: { "Content-Type": "application/json" } }));
  }
  if (!fileId) {
    return withCORS(new Response(JSON.stringify({ error: "Missing fileId" }), { status: 400, headers: { "Content-Type": "application/json" } }));
  }

  // Authenticate with Google using service account (same as upload)
  const credentials = JSON.parse(serviceAccountJson);
  const jwtHeader = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const jwtClaimSet = {
    iss: credentials.client_email,
    scope: "https://www.googleapis.com/auth/drive",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };
  function base64url(input: string | Uint8Array) {
    return btoa(typeof input === "string" ? input : String.fromCharCode(...input))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  }
  const encoder = new TextEncoder();
  const encodedHeader = base64url(JSON.stringify(jwtHeader));
  const encodedClaimSet = base64url(JSON.stringify(jwtClaimSet));
  const toSign = `${encodedHeader}.${encodedClaimSet}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(credentials.private_key.replace(/-----\w+ PRIVATE KEY-----|\n/g, "")), c => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(toSign)
  ));
  const jwt = `${toSign}.${base64url(signature)}`;

  // Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const tokenJson = await tokenRes.json();
  if (!tokenJson.access_token) {
    return withCORS(new Response(JSON.stringify({ error: "Failed to get Google access token", details: tokenJson }), { status: 500, headers: { "Content-Type": "application/json" } }));
  }
  const accessToken = tokenJson.access_token;

  if (checkOnly) {
    // Check if file exists in Google Drive
    try {
      const checkRes = await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}?fields=id`, {
        method: "GET",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
        },
      });
      if (checkRes.status === 200) {
        return withCORS(new Response(JSON.stringify({ exists: true }), { headers: { "Content-Type": "application/json" } }));
      } else if (checkRes.status === 404) {
        return withCORS(new Response(JSON.stringify({ notFound: true }), { headers: { "Content-Type": "application/json" } }));
      } else {
        const errJson = await checkRes.json();
        return withCORS(new Response(JSON.stringify({ error: errJson.error?.message || "Failed to check file", details: errJson }), { status: 500, headers: { "Content-Type": "application/json" } }));
      }
    } catch (error) {
      return withCORS(new Response(JSON.stringify({ error: error.message || "Google Drive check failed" }), { status: 500, headers: { "Content-Type": "application/json" } }));
    }
  }

  // Delete file from Google Drive
  try {
    const deleteRes = await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}`, {
      method: "DELETE",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
      },
    });
    if (deleteRes.status === 204) {
      return withCORS(new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } }));
    } else {
      const errJson = await deleteRes.json();
      return withCORS(new Response(JSON.stringify({ error: errJson.error?.message || "Failed to delete file", details: errJson }), { status: 500, headers: { "Content-Type": "application/json" } }));
    }
  } catch (error) {
    return withCORS(new Response(JSON.stringify({ error: error.message || "Google Drive delete failed" }), { status: 500, headers: { "Content-Type": "application/json" } }));
  }
}); 