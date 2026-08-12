import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const response = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

const requireSuccess = (error: { message: string } | null) => {
  if (error != null) throw new Error(error.message)
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (request.method !== 'POST') return response({ error: 'Method not allowed' }, 405)

  const authorization = request.headers.get('Authorization')
  if (authorization == null) return response({ error: 'Unauthorized' }, 401)

  const url = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  })
  const admin = createClient(url, serviceRoleKey)

  // Use the JWT to identify the caller. The client cannot choose another user ID.
  const { data: { user }, error: userError } = await userClient.auth.getUser()
  if (userError != null || user == null) return response({ error: 'Unauthorized' }, 401)

  try {
    const { data: profile, error: profileError } = await admin
      .from('profiles')
      .select('avatar_path')
      .eq('id', user.id)
      .maybeSingle()
    requireSuccess(profileError)

    const { data: photos, error: photosError } = await admin
      .from('profile_photos')
      .select('storage_path')
      .eq('user_id', user.id)
    requireSuccess(photosError)

    const paths = [
      profile?.avatar_path,
      ...(photos ?? []).map((photo) => photo.storage_path),
    ].filter((path): path is string => typeof path === 'string' && path.length > 0)
    if (paths.length > 0) {
      requireSuccess((await admin.storage.from('profile-photos').remove(paths)).error)
    }

    // Delete groups hosted by this account and their members, then remove this
    // account from groups hosted by other users.
    const { data: hosted, error: hostedError } = await admin
      .from('recruitments')
      .select('id')
      .eq('author_id', user.id)
    requireSuccess(hostedError)
    const hostedIds = (hosted ?? []).map((item) => item.id)
    if (hostedIds.length > 0) {
      requireSuccess(
        (await admin.from('recruitment_members').delete().in('recruitment_id', hostedIds)).error,
      )
      requireSuccess((await admin.from('recruitments').delete().in('id', hostedIds)).error)
    }

    requireSuccess((await admin.from('recruitment_members').delete().eq('user_id', user.id)).error)
    requireSuccess((await admin.from('schedules').delete().eq('user_id', user.id)).error)
    requireSuccess((await admin.from('profile_photos').delete().eq('user_id', user.id)).error)
    requireSuccess((await admin.from('profiles').delete().eq('id', user.id)).error)
    // Hard-delete the Auth record so the email address can be used to sign up again.
    requireSuccess((await admin.auth.admin.deleteUser(user.id, false)).error)

    return response({ deleted: true })
  } catch (error) {
    console.error('Account deletion failed:', error)
    return response({ error: 'Unable to delete account' }, 500)
  }
})
