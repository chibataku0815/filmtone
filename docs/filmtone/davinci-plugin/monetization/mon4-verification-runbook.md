# MON-4 Release-Gate Verification Runbook

Date: 2026-07-19 JST
Owner-gated: **yes — every gate below is a per-action owner decision.**

This runbook is **preparation only**. It is the ready-to-execute procedure for the
four MON-4 release gates that are still open in
`monetization/progress.md` (MON-4 section, 改訂 26). Do **not** run any step here
without the owner's explicit confirmation *at the time it is run*. Each gate is a
real production request, a real email, a real (or test) purchase, or a system-clock
change — this project treats that class of action as per-action consent, never
batched in advance. An agent executing this later must pause for a fresh yes/no
before each gate, not carry one blanket approval across all four.

Nothing in this document has been executed. Authoring it involved read-only
research only; the live Worker was **not** called beyond the two cases already
confirmed in progress.md (see §0).

## 0. Prerequisites, contract, and what is already confirmed

- **Worker endpoint:** `POST https://filmtone-license-worker.chiba-4f9.workers.dev/trial`
  Body: `{ "email": "...", "turnstileToken": "..." }` (both must be JSON strings).
  `Content-Type: application/json` required. Live version of record: per
  progress.md 改訂 26, Worker Version ID `31e8956b-0ee6-4b67-8a79-5b4cf13618b0`
  (source `6104168`). The README still names the prior `627b6337…` deploy — that
  is stale; progress.md 改訂 26 is the source of truth.
- **Turnstile binding (`infra/license-worker/src/index.ts`):** Siteverify must
  return `success === true` **and** `action === "filmtone_trial"` **and**
  `hostname ∈ { chibatakumi.studio, www.chibatakumi.studio }` (derived from
  `ALLOWED_ORIGIN`). Any failure → `403 verification_failed`. Fail-closed: missing
  `TURNSTILE_SECRET` → `500`.
- **Worker rejection order** (read this before interpreting any response):

  | Order | Condition | Response |
  |---|---|---|
  | 1 | `TURNSTILE_SECRET` unset | `500 server_misconfigured` |
  | 2 | bad `Content-Type` / >4 KB body / non-string `email`\|`turnstileToken` / non-JSON | `400 invalid_request` |
  | 3 | email fails regex or >254 chars | `400 invalid_email` |
  | 4 | Turnstile `success`\|`action`\|`hostname` check fails | `403 verification_failed` |
  | 5 | per-IP soft throttle (>5/hour) | `429 rate_limited` |
  | 6 | email already claimed a trial (KV hit) | `200 {"ok":true}` (generic, **no second email**) |
  | 7 | signed + Resend accepted | `200 {"ok":true}` + email |
  | — | Resend concurrent-idempotent / other failure | `503` (Retry-After: 2) / `502` |

- **Already confirmed against the live Worker** (progress.md 改訂 12 / 15, from an
  allowed origin): missing token → `400 invalid_request`; garbage/invalid token →
  `403 verification_failed`. Both stop at step 2/4 above — **no email sent, no KV
  write.** Re-running these adds nothing; they are not re-listed as open work.

- **The four open gates:** (1) Turnstile hostname-mismatch + action-mismatch
  rejection; (2) real trial → Resend delivery → attachment validation; (3) test
  purchase → receipt → manual full-license issuance; (4) trial-expiry
  clock-forward → watermark return.

---

## Gate 1 — Turnstile hostname-mismatch & action-mismatch → `403 verification_failed`

**Goal:** prove that a token that is *genuinely solved* but bound to the wrong
`action` or the wrong `hostname` is rejected with `403 verification_failed` — the
same status as the already-confirmed invalid-token case, but reaching a **different
branch** of `turnstilePasses()`.

### The honesty distinction (read first)

`result.hostname` and `result.action` are cryptographically bound **into the
Turnstile token by Cloudflare at solve time** and echoed back by Siteverify. They
are **not** derived from the curl request's `Origin`/`Host` headers or from
`remoteip`. Consequences:

- **A garbage/synthetic token can never exercise the action or hostname branch.**
  The check is `if (result.success !== true || result.action !== "filmtone_trial") return false`.
  A synthetic token makes Siteverify return `success: false`, so the `||`
  short-circuits at the *first* clause and returns `403` **before** `action` or
  `hostname` is ever compared. Faking headers does not change this.
- Therefore the curl-only path (below) only reproduces the **already-confirmed
  invalid-token → 403** case. It is a regression floor, **not** proof of the
  hostname/action branches.
- **Genuinely exercising the action/hostname branches requires a real Turnstile
  widget solve** (a `success: true` token can only be minted by solving the real
  widget on a domain the sitekey allows). This is owner + browser work, not curl.

### 1a. curl regression floor (does NOT close the gate)

```sh
WORKER="https://filmtone-license-worker.chiba-4f9.workers.dev"
curl -si -X POST "$WORKER/trial" \
  -H 'Content-Type: application/json' \
  -d '{"email":"you@example.com","turnstileToken":"garbage-not-a-real-token"}'
```

- **Expect:** `HTTP/… 403` + `{"error":"verification_failed"}`. Identical to the
  invalid-token case already confirmed (改訂 12/15). No email, no KV write.
- **This does not distinguish action- vs hostname- vs generic-invalid** — it only
  shows the endpoint still rejects a bad token. Do not record it as closing Gate 1.

### 1b. Genuine action-mismatch (real solve, wrong `action`)

Render the **production sitekey** on an allowed origin (`chibatakumi.studio` /
`www.chibatakumi.studio`) with a **non-matching action**, solve it, and POST the
resulting token.

1. On a page served from an allowed origin (a scratch page, or the browser console
   on the live product page), render the widget with an action other than
   `filmtone_trial` — e.g. `turnstile.render(el, { sitekey: <prod site key>, action: "wrong_action", callback: t => console.log(t) })`.
2. Copy the solved token `t` and POST it:
   ```sh
   curl -si -X POST "$WORKER/trial" \
     -H 'Content-Type: application/json' \
     -d '{"email":"you@example.com","turnstileToken":"<TOKEN-with-action=wrong_action>"}'
   ```
- **Expect:** `403 verification_failed` (Siteverify returns `success:true,
  action:"wrong_action"` → fails the `action` clause). No email, no KV write.
- **Cleanup:** none — no persistent config changed (action is set per render).

### 1c. Genuine hostname-mismatch (real solve, non-allowlisted `hostname`)

The production sitekey is domain-locked to the two allowed hosts, so a token whose
`hostname` is outside the allowlist can only be minted by temporarily widening the
**sitekey's** allowed hostnames (Turnstile dashboard) — the **Worker's**
`ALLOWED_ORIGIN` stays unchanged, which is the point.

1. In the Turnstile dashboard for the `Filmtone Trial` widget, **temporarily add** a
   throwaway allowed hostname (e.g. a Vercel preview host, or `localhost` if
   permitted). Keep `data-action="filmtone_trial"` so only the hostname differs.
2. Solve the widget on that throwaway host, capture the token, POST it as in 1b.
- **Expect:** `403 verification_failed` (Siteverify returns `success:true,
  action:"filmtone_trial", hostname:"<throwaway>"` → fails the hostname set-membership
  check). No email, no KV write.
- **Cleanup (mandatory):** **remove the throwaway hostname** from the sitekey's
  allowed-hostnames list immediately after, so the production widget is domain-locked
  again.

### Failure interpretation (Gate 1)

- Any `2xx`/`200 {"ok":true}` from 1b or 1c = **fail** (a mis-bound token was
  accepted → an email/KV write may have happened; investigate the Siteverify branch).
- A `400`/`429` instead of `403` means you did not reach the Turnstile branch
  (bad body, or you tripped the IP throttle at step 5 — wait out the hour and retry).
- `500 server_misconfigured` = `TURNSTILE_SECRET` missing on the Worker; that is a
  deploy problem, not a Gate 1 result.

---

## Gate 2 — Real trial → Resend delivery → `Filmtone.license` attachment validation

**Precondition (blocker):** a real trial request needs a **real Turnstile solve
from an allowed origin**. As of progress.md 改訂 26 the only trial form that posts
to this Worker is the **portfolio `/filmtone/resolve` scaffold, which is untracked
(uncommitted) and not yet deployed**, and it needs the owner's Vercel env var
`NEXT_PUBLIC_FILMTONE_RESOLVE_TURNSTILE_SITE_KEY` set **and a redeploy** (the page
is SSG). There is **no existing/alternative committed trial form** on the shared
`/filmtone` (Signature) page that hits this Worker — grepping the portfolio,
the only Worker-posting form is the new `/filmtone/resolve` route. So Gate 2 is
blocked until: owner commits the scaffold → sets the Vercel Turnstile site key →
redeploys → the form is live at `https://www.chibatakumi.studio/filmtone/resolve`.

### Procedure (once the form is live)

1. **Use a plus-alias, not the owner's primary address.** A successful trial writes
   a per-email KV record with a ~13-month TTL, and the Worker lowercases the email
   with **no plus-alias stripping** — so a real trial to `owner@fores-tone.co.jp`
   locks *that* address out of a real trial for 13 months (repeats return generic
   `200 {"ok":true}` with **no second email**). Use `owner+trial1@fores-tone.co.jp`,
   `owner+trial2@…`, etc. so each re-test is a distinct HMAC yet still deliverable.
2. Open the live form, solve the Turnstile widget, submit the plus-alias email.
   Expect the UI success state (Worker `200 {"ok":true}`).
3. Check the inbox for that alias. Expect a mail from
   `Filmtone <filmtone@fores-tone.co.jp>`, subject
   `Filmtone — 14日無料体験ライセンス / 14-day trial license`, with a
   **`Filmtone.license`** attachment. Save it locally, e.g. `~/Downloads/Filmtone.license`.
4. Validate the attachment with the trial public key
   (`Sources/License/PublicKeys.h:24`, also progress.md MON-3 record):
   ```sh
   bun run license:verify -- \
     --file ~/Downloads/Filmtone.license \
     --trial-pub 39af05f555ecdf06702470a09b2c0384e0ff34457b25f148fa98ee0e232fa4e0
   ```
   (Equivalent alternative if the trial key file is present:
   `--trial-key ~/.filmtone/secrets/filmtone-trial.key.json`.)

- **Expect:** exit code **0**, `status: trial`, `kind: trial`, `email:` the
  plus-alias, `expires:` ≈ 14 days out (issuedAt is hour-truncated by the Worker).
  Exit codes: `0` = valid (licensed or in-trial), `2` = valid signature but expired,
  `1` = invalid/usage error.
- **Failure interpretation:** no email → check Resend Usage/logs and the Worker
  response (a `502`/`503` means Resend rejected/retry; a generic `200` with no mail
  usually means that alias already has a KV record — switch aliases). Exit `1` from
  verify → the attachment is not a valid trial license (wrong key, truncated
  download, or tampering) — re-download before concluding a signing problem.
- **Cleanup:** none required. Note that each alias you burn is now trial-claimed for
  ~13 months; that is expected and harmless.

---

## Gate 3 — Test purchase → receipt → manual L1 (full) issuance

**Primary path: Polar Sandbox (no real money).** Verified live on 2026-07-19 from
Polar docs (`docs.polar.sh/integrate/sandbox`, updated 2026-07-15): Polar provides
a **sandbox environment**, isolated from production, at `https://sandbox.polar.sh/start`
(API base `https://sandbox-api.polar.sh`). It runs the **complete checkout funnel**
and takes **Stripe test cards** — e.g. `4242 4242 4242 4242`, any future expiry,
random CVC — with **no real money moved**. The sandbox is a **separate account/org**
from production, so it needs its own throwaway product + checkout URL.

### 3a. Sandbox test purchase (recommended)

1. **Owner prerequisite:** in the sandbox org (`sandbox.polar.sh`), create a
   throwaway "Filmtone" product and copy its **sandbox** checkout URL. (Owner-only,
   analogous to the real checkout URL tracked in the S2 owner-runbook stream.)
2. Open the sandbox checkout URL, pay with `4242 4242 4242 4242` (future expiry,
   random CVC). Confirm the sandbox order/receipt and note its **order reference**.
3. Issue the full license manually (see 3c) using the sandbox order ref.
- **Cleanup:** none — sandbox money is fake; nothing to refund.

### 3b. Real production purchase (fallback — only if the *production* funnel itself
must be validated end-to-end)

Use the real Polar checkout URL (owner-only, S2 stream). This charges real money at
the real price ($39 launch / $49). If you take this path, **refund is a mandatory
cleanup step**, not optional.
- **Cleanup (mandatory):** refund the order from the Polar dashboard within the
  14-day window (`monetization/refund-policy.md`). Note the transaction-unit
  downside documented in strategy.md §4 (card fees are not fully returned on refund)
  — this is why sandbox is the primary path.

### 3c. Manual full-license issuance (identical for both paths)

The order ref only ends up embedded in the license payload — `issue.ts` does **not**
validate it against Polar — so a sandbox order ref is fine. Full licenses are signed
**only** with the full key, which lives on the owner's Mac (never in the Worker):

```sh
bun run license:issue -- \
  --key ~/.filmtone/secrets/filmtone-full.key.json \
  --kind full \
  --name "<Buyer Full Name>" \
  --email "<buyer@example.com>" \
  --order "<polar-or-sandbox-order-ref>" \
  --out "Filmtone-<buyer-slug>.license"
```

- `issue.ts` refuses to overwrite an existing `--out` (opened with `wx`), so use a
  unique `--out` per issuance. Email is lowercased/trimmed and name is trimmed on write.
- **Verify before sending to the buyer** (full public key from `PublicKeys.h:20`):
  ```sh
  bun run license:verify -- \
    --file "Filmtone-<buyer-slug>.license" \
    --full-pub 4b887963416f325a290203b086caf40d811dd7724252f780f3c15fbfe7fdd376
  ```
  **Expect:** exit `0`, `status: licensed`, `kind: full`, `expires: never`.
- Deliver by replying to the purchase email with the `.license` attached; the buyer
  places it at `~/Library/Application Support/Filmtone/Filmtone.license`.
- **Failure interpretation:** `issue.ts` "key role mismatch" → you passed the trial
  key with `--kind full`; use `filmtone-full.key.json`. verify exit `1` → the issued
  file is malformed; do not send it.

---

## Gate 4 — Trial-expiry clock-forward → watermark return

> **STOP — owner confirmation required before changing the system clock.** This
> gate changes the Mac's wall clock, which is a system-settings operation and can
> trigger transient TLS/certificate errors and misbehavior in other time-licensed
> software (including Resolve activation). Get an explicit owner yes **immediately
> before** doing it, keep the window as short as possible, and treat the rollback in
> the final step as **mandatory**, not optional.

**What this proves and why it's not a new idea.** Offline verification compares the
signed `expiresAt` against the local system clock by design (strategy.md §5, lines
113/167 — no network). The implementation-plan states the **acceptance test for
expiry is performed by advancing the system clock**
(`implementation-plan.md:204-205`: 「`expiresAt` 超過(検証はシステム時計を進めて
実施)」), and documents clock manipulation as an **accepted known limitation** of
offline verification (`implementation-plan.md:174-177`: 「時計操作: オフライン検証の
既知の限界として許容する」). So the clock-forward here is the *documented* method,
not a workaround this runbook invents.

**Relationship to MON-2 (already done).** The MON-2 Resolve matrix already confirmed
that a *synthetic* `trial-expired.license` (from `gen_license_files.ts`) renders as
watermark (17/17 parity + Resolve live check, 改訂 22). Gate 4 adds the one thing
that file cannot: proof that an **actually-issued trial**, left in place, flips to
watermark **in situ** once real time passes its `expiresAt`. Verified against source:
`LicenseStore::evaluate()` re-derives Trial-vs-Expired from `::time(nullptr)` on
**every render call** (`LicenseStore.h:40-43,66-67`; `LicenseStore.mm:401-402`,
`343-344`), so advancing the clock and re-rendering flips the state with **no file
edit and no project reopen**.

### Prerequisite: a valid trial license placed

Pick one variant:

- **Variant A (full end-to-end):** the real trial `.license` from Gate 2, placed at
  `~/Library/Application Support/Filmtone/Filmtone.license`. Requires a ~15-day
  forward jump — most disruptive.
- **Variant B (low-disruption, recommended for the mechanism check):** issue a
  short trial locally and jump only ~26 hours. `LicenseStore` accepts any trial with
  `0 < (expires − issued) ≤ kTrialMaxDays` (`LicenseStore.mm:286-287`), so a 1-day
  trial exercises the identical Trial→Expired transition:
  ```sh
  bun run license:issue -- \
    --key ~/.filmtone/secrets/filmtone-trial.key.json \
    --kind trial --days 1 \
    --name "expiry-test" --email "expiry-test@example.com" \
    --order "clock-fwd-check-0001" \
    --out /tmp/trial-1day.license
  cp /tmp/trial-1day.license ~/Library/Application\ Support/Filmtone/Filmtone.license
  ```

Confirm the baseline first: re-render the frame in Resolve → **clean**, License >
Status shows `Trial — expires <date>`.

### Procedure (clock forward)

```sh
# 1. Record current state (to restore exactly).
date
sudo systemsetup -getusingnetworktime

# 2. Disable automatic time sync so the OS won't immediately re-correct.
sudo systemsetup -setusingnetworktime off

# 3. Jump the clock PAST the trial's expiresAt.
#    The macOS/BSD `date` set-operand is CCYYMMDDHHMM.ss (year FIRST), so format
#    with %Y%m%d%H%M.%S — NOT the GNU/System-V year-last form, which BSD misparses.
#    Variant B (1-day trial): +2 days is comfortably past.
sudo date "$(date -v+2d '+%Y%m%d%H%M.%S')"
#    Variant A (14-day trial): use +15d instead:  sudo date "$(date -v+15d '+%Y%m%d%H%M.%S')"
```

(If `systemsetup`/`date` is blocked by MDM/SIP, use System Settings → General →
Date & Time: turn **off** "Set time and date automatically", then set the date
manually.)

4. In Resolve, **re-render the same frame** (scrub off and back, or flush the render
   cache if it serves a cached frame). Observe:
   - **Image → watermark returns.**
   - **License > Status → `Trial mode (watermarked)`** (the text label may need a
     panel re-display to refresh, per the MON-2 status-label constraint; the image
     flips immediately on re-render).

### Rollback (MANDATORY — do this immediately, last step, not optional)

```sh
# Re-enable automatic network time; macOS re-syncs from Apple within seconds.
sudo systemsetup -setusingnetworktime on
# Belt-and-suspenders: force an immediate resync.
sudo sntp -sS time.apple.com
# Confirm the clock is correct again.
date
```

Then re-render in Resolve once more and confirm the image returns to **clean** (the
trial is valid again under the correct clock) — this both proves reversibility and
leaves the machine in its original state. If you used Variant B, delete the throwaway
trial file: `rm ~/Library/Application\ Support/Filmtone/Filmtone.license` (or restore
whatever license was there before).

### Failure interpretation (Gate 4)

- Watermark does **not** return after the jump → before calling it a product bug,
  confirm (a) the clock actually moved (`date`), and (b) the frame was actually
  re-rendered and not served from Resolve's cache (flush cache / scrub). Only a
  genuine "clock past expiry + fresh render still clean" is a real failure.
- The clock will not restore → re-run the rollback block; if `sntp` fails, toggling
  "Set time and date automatically" on in System Settings forces a resync. **Do not
  leave this gate without a correct clock.**

---

## Recording results

Record pass/fail per gate. Coordinator-owned files (progress.md / workstreams) are
updated by the coordinator after owner-confirmed execution, not pre-filled here.
On a full pass of Gates 1–4, the remaining MON-4 launch-gate items in progress.md
(改訂 26, MON-4 section) — real delivery, production-token success/mismatch, test
purchase → issuance, and trial-expiry — are closed, leaving only owner legal review
and the MON-6 publish steps.
