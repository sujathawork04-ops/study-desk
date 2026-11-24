// Supabase Edge Function: "billing"
// Razorpay subscriptions (INR-friendly for Indian families).
//
//   supabase secrets set RAZORPAY_KEY_ID=rzp_live_... RAZORPAY_KEY_SECRET=... \
//                        RAZORPAY_WEBHOOK_SECRET=... RAZORPAY_PLAN_FAMILY=plan_...
//   supabase functions deploy billing --no-verify-jwt
//
// POST /billing            (signed in)  -> { subscriptionId, keyId }  : start checkout
// POST /billing?hook=1     (Razorpay)   -> verifies signature, updates the subscription
//
// In the Razorpay dashboard create a Plan (e.g. ₹299/month), copy its id into
// RAZORPAY_PLAN_FAMILY, and add this URL as a webhook for the events:
// subscription.activated, subscription.charged, subscription.halted, subscription.cancelled.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createHmac } from "node:crypto";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-razorpay-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "content-type": "application/json" } });

const admin = () => createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const url = new URL(req.url);

  // ------------------------------------------------------------- webhook
  if (url.searchParams.get("hook") === "1") {
    const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET")!;
    const raw = await req.text();
    const expected = createHmac("sha256", secret).update(raw).digest("hex");
    if (expected !== req.headers.get("x-razorpay-signature")) return json({ error: "bad_signature" }, 401);

    const ev = JSON.parse(raw);
    const sub = ev?.payload?.subscription?.entity;
    const accountId = sub?.notes?.account_id;
    if (!accountId) return json({ ok: true, ignored: ev.event });

    const status = switchStatus(ev.event);
    const periodEnd = sub?.current_end ? new Date(sub.current_end * 1000).toISOString() : null;

    await admin().from("subscriptions").upsert({
      account_id: accountId,
      plan: "family",
      status,
      max_students: 4,
      daily_msg_limit: 80,
      provider: "razorpay",
      provider_sub_id: sub.id,
      current_period_end: periodEnd,
      updated_at: new Date().toISOString(),
    });
    return json({ ok: true, status });
  }

  // ------------------------------------------------- start a subscription
  const auth = req.headers.get("Authorization") ?? "";
  const asUser = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: u } = await asUser.auth.getUser();
  if (!u?.user) return json({ error: "not_signed_in" }, 401);

  const keyId = Deno.env.get("RAZORPAY_KEY_ID")!;
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET")!;
  const planId = Deno.env.get("RAZORPAY_PLAN_FAMILY")!;
  if (!keyId || !keySecret || !planId) return json({ error: "billing_not_configured" }, 500);

  const r = await fetch("https://api.razorpay.com/v1/subscriptions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Basic " + btoa(`${keyId}:${keySecret}`),
    },
    body: JSON.stringify({
      plan_id: planId,
      total_count: 12,                 // 12 monthly charges, then renew again
      customer_notify: 1,
      notes: { account_id: u.user.id, email: u.user.email },
    }),
  });
  const out = await r.json();
  if (!r.ok) return json({ error: "razorpay_error", detail: out }, 502);
  return json({ subscriptionId: out.id, keyId });
});

function switchStatus(event: string): string {
  switch (event) {
    case "subscription.activated":
    case "subscription.charged":
    case "subscription.resumed":
      return "active";
    case "subscription.pending":
    case "subscription.halted":
      return "past_due";
    case "subscription.cancelled":
    case "subscription.completed":
    case "subscription.expired":
      return "cancelled";
    default:
      return "past_due";
  }
}
