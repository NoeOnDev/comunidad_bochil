import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.56.0'
import { SignJWT, importPKCS8 } from 'npm:jose@5.9.6'

type DbWebhookPayload = {
  type?: string
  table?: string
  schema?: string
  record?: Record<string, unknown>
  old_record?: Record<string, unknown>
}

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const firebaseServiceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ?? ''

const supabase = createClient(supabaseUrl, serviceRoleKey)

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 })
    }

    if (!supabaseUrl || !serviceRoleKey || !firebaseServiceAccountJson) {
      return new Response(
        JSON.stringify({
          ok: false,
          error:
            'Missing env vars: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FIREBASE_SERVICE_ACCOUNT_JSON',
        }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      )
    }

    const payload = (await req.json()) as DbWebhookPayload
    const table = payload.table
    const record = payload.record ?? {}

    if (table === 'historial_estados') {
      return await handleHistorialEstados(record)
    }

    if (table === 'alertas_oficiales') {
      return await handleAlertas(record)
    }

    return json({ ok: true, ignored: true, reason: `Unsupported table: ${table}` })
  } catch (error) {
    return json({ ok: false, error: String(error) }, 500)
  }
})

async function handleHistorialEstados(record: Record<string, unknown>) {
  const reporteId = String(record.reporte_id ?? '')
  const estadoNuevo = String(record.estado_nuevo ?? '')

  if (!reporteId || !estadoNuevo) {
    return json({ ok: false, error: 'Missing reporte_id or estado_nuevo' }, 400)
  }

  const { data: reporte, error: reporteError } = await supabase
    .from('reportes')
    .select('id, titulo, usuario_id')
    .eq('id', reporteId)
    .maybeSingle()

  if (reporteError || !reporte) {
    return json({ ok: false, error: `Reporte not found: ${reporteError?.message ?? 'unknown'}` }, 404)
  }

  const { data: tokens, error: tokenError } = await supabase
    .from('device_tokens')
    .select('token')
    .eq('usuario_id', reporte.usuario_id)

  if (tokenError) {
    return json({ ok: false, error: tokenError.message }, 500)
  }

  if (!tokens || tokens.length === 0) {
    return json({ ok: true, sent: 0, reason: 'No device tokens for user' })
  }

  const title = 'Actualizacion de tu reporte'
  const body = `Tu reporte "${reporte.titulo}" cambio a estado: ${estadoNuevo}`

  const results = await Promise.all(
    tokens.map((t) => sendFcmV1(String(t.token), title, body, {
      tipo: 'reporte_estado',
      reporte_id: reporteId,
      estado_nuevo: estadoNuevo,
    })),
  )

  const sent = results.filter((r) => r.ok).length
  return json({ ok: true, sent, total: tokens.length, table: 'historial_estados' })
}

async function handleAlertas(record: Record<string, unknown>) {
  const activa = Boolean(record.activa ?? false)
  if (!activa) {
    return json({ ok: true, sent: 0, reason: 'Alert is not active' })
  }

  const titulo = String(record.titulo ?? 'Alerta oficial')
  const mensaje = String(record.mensaje ?? '')

  const aplicaTodasCalles = Boolean(record.aplica_todas_calles ?? false)
  const callesObjetivo = extractTargetStreets(record.calles_objetivo)
  const requiereFiltroPorCalle = callesObjetivo.length > 0 && !aplicaTodasCalles

  const { data: tokenRows, error: tokenError } = await supabase
    .from('device_tokens')
    .select('token, perfiles_usuarios!inner(calle)')

  if (tokenError) {
    return json({ ok: false, error: tokenError.message }, 500)
  }

  if (!tokenRows || tokenRows.length === 0) {
    return json({ ok: true, sent: 0, reason: 'No device tokens' })
  }

  const normalizedTargetStreets = new Set(callesObjetivo.map(normalizeStreet))

  const filteredRows = requiereFiltroPorCalle
    ? tokenRows.filter((row) => {
        const calle = getStreetFromJoin(row)
        if (!calle) return false
        return normalizedTargetStreets.has(normalizeStreet(calle))
      })
    : tokenRows

  const uniqueTokens = [...new Set(filteredRows.map((t) => String(t.token)))]

  if (uniqueTokens.length === 0) {
    return json({
      ok: true,
      sent: 0,
      reason: requiereFiltroPorCalle
        ? 'No tokens matched target streets'
        : 'No device tokens',
      target_streets: requiereFiltroPorCalle ? callesObjetivo : undefined,
    })
  }

  const results = await Promise.all(
    uniqueTokens.map((token) => sendFcmV1(token, titulo, mensaje, {
      tipo: 'alerta_oficial',
      alerta_id: String(record.id ?? ''),
    })),
  )

  const sent = results.filter((r) => r.ok).length
  return json({
    ok: true,
    sent,
    total: uniqueTokens.length,
    table: 'alertas_oficiales',
    target_streets: requiereFiltroPorCalle ? callesObjetivo : undefined,
  })
}

function extractTargetStreets(value: unknown): string[] {
  if (!Array.isArray(value)) return []
  return value
    .map((street) => String(street ?? '').trim())
    .filter((street) => street.length > 0)
}

function getStreetFromJoin(row: Record<string, unknown>): string {
  const perfil = row.perfiles_usuarios
  if (Array.isArray(perfil)) {
    const first = perfil[0] as Record<string, unknown> | undefined
    return String(first?.calle ?? '')
  }

  if (perfil && typeof perfil === 'object') {
    return String((perfil as Record<string, unknown>).calle ?? '')
  }

  return ''
}

function normalizeStreet(value: string): string {
  return value.trim().toLowerCase()
}

async function sendFcmV1(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  const serviceAccount = getServiceAccount()
  const accessToken = await getGoogleAccessToken(serviceAccount)

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data,
        android: {
          priority: 'high',
          notification: { sound: 'default' },
        },
      },
    }),
    },
  )

  if (!response.ok) {
    const txt = await response.text()
    return { ok: false, status: response.status, error: txt }
  }

  return { ok: true }
}

type FirebaseServiceAccount = {
  project_id: string
  client_email: string
  private_key: string
  token_uri?: string
}

function getServiceAccount(): FirebaseServiceAccount {
  try {
    const parsed = JSON.parse(firebaseServiceAccountJson) as FirebaseServiceAccount
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      throw new Error('Invalid service account JSON: missing required fields')
    }
    return parsed
  } catch (e) {
    throw new Error(`Invalid FIREBASE_SERVICE_ACCOUNT_JSON: ${String(e)}`)
  }
}

async function getGoogleAccessToken(serviceAccount: FirebaseServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const jwt = await createJwtAssertion(serviceAccount, now)

  const tokenUri = serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token'
  const response = await fetch(tokenUri, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!response.ok) {
    const text = await response.text()
    throw new Error(`Failed to get Google access token (${response.status}): ${text}`)
  }

  const jsonRes = (await response.json()) as { access_token?: string }
  if (!jsonRes.access_token) {
    throw new Error('Google token response missing access_token')
  }

  return jsonRes.access_token
}

async function createJwtAssertion(
  serviceAccount: FirebaseServiceAccount,
  now: number,
): Promise<string> {
  const privateKey = await importPKCS8(serviceAccount.private_key, 'RS256')

  return await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience(serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey)
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
