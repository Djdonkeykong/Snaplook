// Supabase Edge Function: Send welcome drip notifications to new users
// Triggered daily by pg_cron at 10:00 AM UTC
//
// Day 1 (~24h after signup): Nudge to try first scan
// Day 3 (~72h after signup): Follow-up if still no scan

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const WELCOME_STEPS = [
  {
    type: 'welcome_day1',
    minDaysAgo: 1,
    maxDaysAgo: 2,
    title: 'Your style journey starts here',
    body: "Snap a photo of any outfit and we'll find similar items for you!",
  },
  {
    type: 'welcome_day3',
    minDaysAgo: 3,
    maxDaysAgo: 4,
    title: 'See something you like?',
    body: "Try scanning an outfit -- we'll match you with similar fashion finds instantly.",
  },
]

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const now = new Date()
    // Safety: only consider users created in the last 7 days
    const sevenDaysAgo = new Date(now)
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)

    console.log(`[WelcomeDrip] Running at ${now.toISOString()}`)

    // Fetch recent users who have never scanned and have notifications enabled
    const { data: candidates, error: candidatesError } = await supabase
      .from('users')
      .select('id, created_at, total_analyses_performed, notification_enabled')
      .eq('total_analyses_performed', 0)
      .eq('notification_enabled', true)
      .gte('created_at', sevenDaysAgo.toISOString())

    if (candidatesError) {
      throw candidatesError
    }

    if (!candidates || candidates.length === 0) {
      console.log('[WelcomeDrip] No candidates found')
      return new Response(
        JSON.stringify({ success: true, sent_count: 0, message: 'No candidates found' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[WelcomeDrip] Found ${candidates.length} users with 0 scans in the last 7 days`)

    // Filter out users who don't have FCM tokens registered
    const candidateIds = candidates.map(u => u.id)
    const { data: fcmTokens, error: fcmError } = await supabase
      .from('fcm_tokens')
      .select('user_id')
      .in('user_id', candidateIds)

    if (fcmError) {
      console.error('[WelcomeDrip] Error fetching FCM tokens:', fcmError)
      throw fcmError
    }

    const usersWithTokens = new Set((fcmTokens || []).map(t => t.user_id))

    // Fetch existing notification_log entries to prevent duplicates
    const { data: existingLogs, error: logsError } = await supabase
      .from('notification_log')
      .select('user_id, notification_type')
      .in('user_id', candidateIds)
      .in('notification_type', WELCOME_STEPS.map(s => s.type))

    if (logsError) {
      console.error('[WelcomeDrip] Error fetching notification logs:', logsError)
      throw logsError
    }

    // Build a set of "user_id:notification_type" for quick lookup
    const alreadySent = new Set(
      (existingLogs || []).map(log => `${log.user_id}:${log.notification_type}`)
    )

    const sendNotificationUrl = `${supabaseUrl}/functions/v1/send-push-notification`
    let totalSent = 0
    const results: Array<{ step: string; sent: number; skipped: number }> = []

    for (const step of WELCOME_STEPS) {
      const minDate = new Date(now)
      minDate.setDate(minDate.getDate() - step.maxDaysAgo)
      const maxDate = new Date(now)
      maxDate.setDate(maxDate.getDate() - step.minDaysAgo)

      // Filter candidates for this step's time window
      const eligible = candidates.filter(user => {
        const createdAt = new Date(user.created_at)
        return (
          createdAt >= minDate &&
          createdAt < maxDate &&
          usersWithTokens.has(user.id) &&
          !alreadySent.has(`${user.id}:${step.type}`)
        )
      })

      const skipped = candidates.filter(user => {
        const createdAt = new Date(user.created_at)
        return createdAt >= minDate && createdAt < maxDate
      }).length - eligible.length

      console.log(`[WelcomeDrip] ${step.type}: ${eligible.length} eligible, ${skipped} skipped`)

      if (eligible.length === 0) {
        results.push({ step: step.type, sent: 0, skipped })
        continue
      }

      const eligibleIds = eligible.map(u => u.id)

      const notificationResponse = await fetch(sendNotificationUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${supabaseServiceKey}`,
        },
        body: JSON.stringify({
          user_ids: eligibleIds,
          title: step.title,
          body: step.body,
          data: { type: step.type },
        }),
      })

      const notificationResult = await notificationResponse.json()
      console.log(`[WelcomeDrip] ${step.type} push result:`, notificationResult)

      // Log each sent notification to notification_log
      const { error: insertError } = await supabase
        .from('notification_log')
        .insert(eligibleIds.map(userId => ({
          user_id: userId,
          notification_type: step.type,
          title: step.title,
          body: step.body,
          data: { type: step.type },
          status: 'sent',
        })))

      if (insertError) {
        console.error(`[WelcomeDrip] Error logging ${step.type}:`, insertError)
        // Don't throw -- notification was already sent
      }

      totalSent += eligible.length
      results.push({ step: step.type, sent: eligible.length, skipped })
    }

    console.log(`[WelcomeDrip] Done. Total sent: ${totalSent}`)

    return new Response(
      JSON.stringify({ success: true, total_sent: totalSent, steps: results }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[WelcomeDrip] Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
