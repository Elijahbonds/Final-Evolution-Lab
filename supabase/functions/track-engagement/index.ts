import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight for iOS client requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Establish Supabase connection and verify caller identity
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized user token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 2. Parse request payload
    const { session_id, mode_id, action, duration_seconds, xp_earned, telemetry } = await req.json()

    if (!session_id || !mode_id || !action) {
      return new Response(JSON.stringify({ error: 'Missing required parameters: session_id, mode_id, action' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const ended_at = (action === 'completed' || action === 'abandoned') ? new Date().toISOString() : null

    // 3. Upsert engagement record
    const { data, error } = await supabaseClient
      .from('user_mode_engagement')
      .upsert({
        user_id: user.id,
        session_id: session_id,
        mode_id: mode_id,
        status: action,
        duration_seconds: duration_seconds || 0,
        xp_earned: xp_earned || 0,
        telemetry_summary: telemetry || {},
        ended_at: ended_at
      }, { onConflict: 'session_id,status' }) // Upsert matching on session state changes
      .select()

    if (error) throw error

    return new Response(JSON.stringify({ ok: true, data }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
