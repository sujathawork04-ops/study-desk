// Supabase Edge Function: "tutor"
// The only place the Anthropic API key exists. Also enforces subscription +
// per-child daily limits, and streams the reply so words appear as they are written.
//
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase functions deploy tutor
//
// Request: { studentId, messages:[{role,content}], images?:[dataUrl], wantJson?, tier?, stream?, maxTokens? }
// Response: { text } | { data } | text/event-stream of {type:"delta"|"done"|"error"}

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const API = "https://api.anthropic.com/v1/messages";
const MODELS = { quick: "claude-haiku-4-5", default: "claude-sonnet-4-5" };
// A chat reply to a nine-year-old is a few sentences. Transcribing a whole
// textbook page is not — it is the title, the headings, every definition, the
// worked examples and all the exercise questions, and it does not fit in the
// same budget. One ceiling for everything meant a lesson came back chopped
// off mid-sentence, the JSON would not parse, and the app told a parent their
// photograph was blurry. It was never the photograph.
const MAX_TOKENS = 1400;          // the default: a conversation turn
const MAX_TOKENS_CEILING = 8000;  // the most any one job may ask for

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) return json({ error: "server_not_configured" }, 500);

  const auth = req.headers.get("Authorization") ?? "";
  const asUser = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: userData } = await asUser.auth.getUser();
  const user = userData?.user;
  if (!user) return json({ error: "not_signed_in" }, 401);

  const body = await req.json().catch(() => null);
  if (!body?.messages?.length) return json({ error: "bad_request" }, 400);

  // ---- the student must belong to this account -------------------------
  const { data: student } = await asUser.from("students").select("id").eq("id", body.studentId).maybeSingle();
  if (!student) return json({ error: "not_your_student" }, 403);

  // ---- subscription + daily limit --------------------------------------
  await admin.rpc("ensure_subscription", { uid: user.id });
  const { data: entitled } = await admin.rpc("entitled", { uid: user.id });
  if (!entitled) return json({ error: "subscription_required" }, 402);

  const { data: sub } = await admin.from("subscriptions").select("daily_msg_limit").eq("account_id", user.id).maybeSingle();
  const limit = sub?.daily_msg_limit ?? 200;
  const today = new Date(Date.now() + 5.5 * 3600_000).toISOString().slice(0, 10); // IST date

  // Reading her diary, transcribing a chapter, reading an exam timetable — the
  // app does these on her behalf; she did not "use up" a conversation by
  // photographing a page. They used to count, so uploading a 23-page chapter
  // (twelve batches) spent a quarter of the day's allowance before she had
  // asked a single question — and the cap fell on the evening before an exam.
  // Tokens are still recorded below either way, so the real cost stays visible.
  const isBackgroundRead = body.wantJson === true;

  const { data: used } = await admin.rpc("bump_usage", {
    sid: body.studentId, d: today, msgs: isBackgroundRead ? 0 : 1, tin: 0, tout: 0,
  });
  if (!isBackgroundRead && typeof used === "number" && used > limit) {
    return json({ error: "daily_limit", limit }, 429);
  }

  // ---- build the Anthropic request -------------------------------------
  const msgs = body.messages.map((m: { role: string; content: string }) => ({
    role: m.role === "assistant" ? "assistant" : "user",
    content: [{ type: "text", text: String(m.content).slice(0, 60000) }] as unknown[],
  }));
  for (const dataUrl of (body.images ?? []).slice(0, 5)) {
    const m = /^data:(image\/(?:jpeg|png|webp|gif));base64,(.+)$/.exec(dataUrl);
    if (!m) continue;
    (msgs[msgs.length - 1].content as unknown[]).unshift({
      type: "image", source: { type: "base64", media_type: m[1], data: m[2] },
    });
  }

  const wantStream = body.stream === true && !body.wantJson;
  const payload = {
    model: MODELS[(body.tier as keyof typeof MODELS) ?? "default"] ?? MODELS.default,
    max_tokens: Math.min(
      Math.max(Number(body.maxTokens) || MAX_TOKENS, 256),
      MAX_TOKENS_CEILING,
    ),
    messages: msgs,
    ...(body.wantJson ? { system: "Reply with ONLY the JSON value asked for. No prose, no code fence." } : {}),
    ...(wantStream ? { stream: true } : {}),
  };

  const r = await fetch(API, {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01" },
    body: JSON.stringify(payload),
  });

  if (!r.ok) {
    const detail = await r.text();
    const code = r.status === 429 ? "rate_limited" : r.status === 401 ? "bad_api_key" : "upstream_error";
    return json({ error: code, detail: detail.slice(0, 500) }, r.status === 429 ? 429 : 502);
  }

  // ---- streaming: pass Anthropic's SSE through as simple events ---------
  if (wantStream) {
    const out = new ReadableStream({
      async start(controller) {
        const enc = new TextEncoder();
        const send = (o: unknown) => controller.enqueue(enc.encode(`data: ${JSON.stringify(o)}\n\n`));
        const reader = r.body!.getReader();
        const dec = new TextDecoder();
        let buf = "", full = "", usage: Record<string, number> = {};
        try {
          for (;;) {
            const { value, done } = await reader.read();
            if (done) break;
            buf += dec.decode(value, { stream: true });
            const parts = buf.split("\n\n");
            buf = parts.pop() ?? "";
            for (const p of parts) {
              const line = p.split("\n").find((l) => l.startsWith("data: "));
              if (!line) continue;
              const ev = JSON.parse(line.slice(6));
              if (ev.type === "content_block_delta" && ev.delta?.text) {
                full += ev.delta.text;
                send({ type: "delta", text: ev.delta.text });
              } else if (ev.type === "message_delta" && ev.usage) {
                usage = { ...usage, ...ev.usage };
              } else if (ev.type === "message_start" && ev.message?.usage) {
                usage = { ...usage, ...ev.message.usage };
              }
            }
          }
          send({ type: "done", text: full });
          await admin.rpc("bump_usage", {
            sid: body.studentId, d: today, msgs: 0,
            tin: usage.input_tokens ?? 0, tout: usage.output_tokens ?? 0,
          });
        } catch (e) {
          send({ type: "error", error: "upstream_error", text: full, message: String(e) });
        } finally {
          controller.close();
        }
      },
    });
    return new Response(out, {
      headers: { ...cors, "content-type": "text/event-stream", "cache-control": "no-cache", connection: "keep-alive" },
    });
  }

  // ---- non-streaming ---------------------------------------------------
  const outJson = await r.json();
  const text: string = (outJson.content ?? []).filter((c: { type: string }) => c.type === "text")
    .map((c: { text: string }) => c.text).join("\n").trim();

  await admin.rpc("bump_usage", {
    sid: body.studentId, d: today, msgs: 0,
    tin: outJson.usage?.input_tokens ?? 0, tout: outJson.usage?.output_tokens ?? 0,
  });

  if (!body.wantJson) return json({ text, usage: outJson.usage });

  const tryParse = (s: string) => { try { return JSON.parse(s); } catch { return undefined; } };
  const fence = /```(?:json)?\s*([\s\S]*?)```/.exec(text);
  const slice = (() => {
    const starts = [text.indexOf("{"), text.indexOf("[")].filter((n) => n >= 0);
    const i = starts.length ? Math.min(...starts) : -1;
    const j = Math.max(text.lastIndexOf("}"), text.lastIndexOf("]"));
    return i >= 0 && j > i ? text.slice(i, j + 1) : "";
  })();
  const data = tryParse(text) ?? (fence ? tryParse(fence[1]) : undefined) ?? tryParse(slice);
  if (data === undefined) {
    // Cut off at the ceiling, rather than genuinely unreadable. Saying so
    // stops a parent retaking a perfectly good photograph.
    if (outJson.stop_reason === "max_tokens") {
      return json({ error: "too_long", text }, 422);
    }
    return json({ error: "invalid_json", text }, 422);
  }
  return json({ data, usage: outJson.usage });
});
