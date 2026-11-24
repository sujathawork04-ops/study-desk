// Supabase Edge Function: "daily-check"
// Runs EVERY HOUR from pg_cron. Each child is notified at 21:00 in their OWN
// timezone, so a family in Chennai, Nairobi or Toronto all get their evening
// summary in the evening. Pass ?hour=NN to test another local hour.
//
//   supabase secrets set VAPID_PUBLIC=... VAPID_PRIVATE=... VAPID_SUBJECT=mailto:you@example.org \
//                        CRON_SECRET=...
//   supabase functions deploy daily-check --no-verify-jwt
//
// Generate VAPID keys once:  npx web-push generate-vapid-keys

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

/** Local date, weekday and hour in any IANA timezone, with a safe fallback. */
function localNow(tz: string, now = new Date()) {
  let zone = tz || "UTC";
  let parts: Intl.DateTimeFormatPart[];
  const read = (z: string) =>
    new Intl.DateTimeFormat("en-CA", {
      timeZone: z, year: "numeric", month: "2-digit", day: "2-digit",
      hour: "2-digit", hour12: false, weekday: "short",
    }).formatToParts(now);
  try { parts = read(zone); } catch { zone = "UTC"; parts = read(zone); }
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  return {
    date: `${get("year")}-${get("month")}-${get("day")}`,
    weekday: get("weekday").slice(0, 3),
    hour: Number(get("hour")) % 24,
  };
}

Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }
  const wantHour = Number(new URL(req.url).searchParams.get("hour") ?? 21);

  webpush.setVapidDetails(
    Deno.env.get("VAPID_SUBJECT") ?? "mailto:admin@example.org",
    Deno.env.get("VAPID_PUBLIC")!,
    Deno.env.get("VAPID_PRIVATE")!,
  );

  const { data: students } = await admin.from("students").select("id, owner_id, name, timezone");
  let sent = 0, checked = 0;

  for (const st of students ?? []) {
    // Only the children for whom it is now evening where they go to school.
    const { date, weekday, hour } = localNow(st.timezone ?? "UTC");
    if (hour !== wantHour) continue;
    checked++;

    const [{ data: day }, { data: plan }, { data: tasks }, { data: practice }] = await Promise.all([
      admin.from("days").select("*").eq("student_id", st.id).eq("date", date).maybeSingle(),
      admin.from("plans").select("*").eq("student_id", st.id).maybeSingle(),
      admin.from("tasks").select("*").eq("student_id", st.id).eq("date", date),
      admin.from("practice").select("*").eq("student_id", st.id).eq("date", date),
    ]);

    // --- which kind of day is it? ---------------------------------------
    let type = day?.day_type as string | null;
    if (!type && plan) {
      const off = (plan.off_days ?? []).find((o: { from: string; to: string }) =>
        o.from && date >= o.from && date <= (o.to || o.from));
      type = off?.type ?? ((plan.week_off ?? []).includes(weekday) ? "holiday" : "school");
    }
    type ??= "school";

    const pending = (tasks ?? []).filter((t: { done: boolean }) => !t.done);
    const items = (practice ?? []);
    const practicePending = items.filter((p: { done: boolean }) => !p.done);
    const first = (st.name ?? "Your child").split(" ")[0];

    let title = "", body = "";
    if (type === "holiday" || type === "leave") {
      title = `${type === "holiday" ? "🏖️ Holiday" : "🤒 Leave"} — ${first}`;
      body = `Practice ${items.length - practicePending.length}/${items.length} done. No diary needed today.`;
    } else if (!day?.diary_posted_at && type === "school") {
      title = `⚠️ ${first} hasn't posted today's diary`;
      body = "No homework list was made today.";
    } else if (pending.length) {
      title = `⚠️ ${first}: ${pending.length} homework pending`;
      body = pending.slice(0, 3).map((t: { subject: string; task: string }) => `${t.subject} – ${t.task}`).join("; ");
    } else if (practicePending.length) {
      title = `⚠️ ${first}: homework done ✓, practice pending`;
      body = practicePending.map((p: { item: string }) => p.item).join(", ");
    } else {
      title = `✅ ${first}: all done today`;
      body = `${(day?.badges ?? []).length} badges earned. Nice work!`;
    }

    const { data: subs } = await admin.from("push_subscriptions").select("*").eq("account_id", st.owner_id);
    for (const s of subs ?? []) {
      try {
        await webpush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          JSON.stringify({ title, body, tag: `daily-${st.id}`, url: "/" }),
        );
        sent++;
      } catch (e) {
        // 404/410 = the browser dropped this subscription; clean it up
        const code = (e as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) await admin.from("push_subscriptions").delete().eq("id", s.id);
      }
    }
  }

  return new Response(JSON.stringify({ ok: true, hour: wantHour, checked, sent }), {
    headers: { "content-type": "application/json" },
  });
});
