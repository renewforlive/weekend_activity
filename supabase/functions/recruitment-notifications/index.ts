import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

type FirebaseServiceAccount = {
  client_email: string
  private_key: string
  project_id: string
  token_uri?: string
}

const base64Url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '')

const utf8 = (value: string) => new TextEncoder().encode(value)

const pemToBytes = (pem: string) => {
  const content = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '').replaceAll(/\s/g, '')
  const binary = atob(content)
  return Uint8Array.from(binary, (character) => character.charCodeAt(0))
}

let cachedAccessToken: { value: string; expiresAt: number } | null = null

async function getFirebaseAccessToken(serviceAccount: FirebaseServiceAccount) {
  if (cachedAccessToken != null && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.value
  }
  const now = Math.floor(Date.now() / 1000)
  const encodedHeader = base64Url(utf8(JSON.stringify({ alg: 'RS256', typ: 'JWT' })))
  const encodedClaim = base64Url(utf8(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })))
  const signingInput = `${encodedHeader}.${encodedClaim}`
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, utf8(signingInput))
  const assertion = `${signingInput}.${base64Url(new Uint8Array(signature))}`
  const tokenResponse = await fetch(serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })
  if (!tokenResponse.ok) throw new Error(`Firebase OAuth failed: ${await tokenResponse.text()}`)
  const token = await tokenResponse.json() as { access_token: string; expires_in: number }
  cachedAccessToken = { value: token.access_token, expiresAt: Date.now() + token.expires_in * 1000 }
  return token.access_token
}

async function sendToTokens(
  serviceAccount: FirebaseServiceAccount,
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
) {
  const accessToken = await getFirebaseAccessToken(serviceAccount)
  await Promise.all(tokens.map(async (token) => {
    const result = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data,
            android: { priority: 'high', notification: { channel_id: 'recruitment_updates' } },
            apns: { payload: { aps: { sound: 'default' } } },
          },
        }),
      },
    )
    if (!result.ok) console.error(`FCM send failed: ${await result.text()}`)
  }))
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders })
  const authorization = request.headers.get('Authorization')
  if (authorization == null) return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders })

  const userClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authorization } },
  })
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const { data: { user } } = await userClient.auth.getUser()
  if (user == null) return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders })

  const { type, recruitmentId, memberId, status } = await request.json()
  const { data: recruitment } = await admin
    .from('recruitments')
    .select('author_id, title')
    .eq('id', recruitmentId)
    .maybeSingle()
  if (recruitment == null) return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders })

  let recipientId: string
  let title: string
  let body: string
  if (type === 'join_request') {
    if (recruitment.author_id === user.id) return Response.json({ delivered: 0 }, { headers: corsHeaders })
    const { data: membership } = await admin.from('recruitment_members')
      .select('status').eq('recruitment_id', recruitmentId).eq('user_id', user.id).maybeSingle()
    if (membership == null || membership.status !== 'pending') return Response.json({ error: 'Forbidden' }, { status: 403, headers: corsHeaders })
    recipientId = recruitment.author_id
    title = '\u65b0\u7684\u52a0\u5165\u7533\u8acb'
    body = '\u6709\u4eba\u7533\u8acb\u52a0\u5165\uff1a' + recruitment.title
  } else if (type === 'member_status' && (status === 'approved' || status === 'rejected')) {
    if (recruitment.author_id !== user.id || typeof memberId !== 'string') return Response.json({ error: 'Forbidden' }, { status: 403, headers: corsHeaders })
    recipientId = memberId
    title = status === 'approved'
      ? '\u52a0\u5165\u7533\u8acb\u5df2\u901a\u904e'
      : '\u52a0\u5165\u7533\u8acb\u672a\u901a\u904e'
    body = status === 'approved'
      ? '\u4f60\u5df2\u6210\u529f\u52a0\u5165\uff1a' + recruitment.title
      : recruitment.title + '\u7684\u52a0\u5165\u7533\u8acb\u672a\u901a\u904e'
  } else {
    return Response.json({ error: 'Invalid notification request' }, { status: 400, headers: corsHeaders })
  }

  const { data: devices } = await admin.from('device_tokens').select('token').eq('user_id', recipientId)
  const tokens = (devices ?? []).map((device) => device.token).filter((token): token is string => typeof token === 'string')
  if (tokens.length === 0) return Response.json({ delivered: 0 }, { headers: corsHeaders })

  const rawServiceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
  if (rawServiceAccount == null) return Response.json({ error: 'Push service not configured' }, { status: 503, headers: corsHeaders })
  await sendToTokens(JSON.parse(rawServiceAccount), tokens, title, body, {
    recruitment_id: recruitmentId,
    type,
    status: status ?? '',
  })
  return Response.json({ delivered: tokens.length }, { headers: corsHeaders })
})
