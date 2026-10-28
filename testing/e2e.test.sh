#!/usr/bin/env bash
# TIER 2 — the site a bootstrap produces builds, deploys (dry) and serves.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the finished site, the landing's own checks — install with the
#      lockfile the site ships, render fixtures, typecheck, lint, test,
#      build. The bootstrap's own landings are checked in the box with
#      `orun validate` and `orun plan` alone (`checks: local`; their PR's CI
#      on an `orun/BASE-…` branch is `plan` alone, and the convergence on
#      main builds, deploys and smoke-tests the site), so THIS is where a
#      site those steps refuse is caught: before the tag, not after a build
#      has merged it. Every later pull request of the site runs ci.yml's
#      verify lanes;
#   2. the stage lane's own steps, rendered by `orun plan` in the site: on a
#      pull request (the verify profile) `build-app` — the component's
#      buildCommand, origin and all, the same step the deploy profile runs —
#      `verify-build-output` and `deploy-dry-run` (`wrangler deploy --dry-run
#      --name <reponame>-web-stage`). They run IN THE TREE THE RUNNER STAGES
#      for the job (testing/lib/stage-job.py), with the dependency layout the
#      pinned composition produces: if its install step is `scope: lane`, the
#      top-level node_modules is a symlink to the source checkout's; if not,
#      the job's own install step runs inside the staged tree. Run in a plain
#      checkout, this tier was green while the first live bootstrap's lanes
#      died in the lane layout (Turbopack: "Symlink … points out of the
#      filesystem root");
#   3. serve the built Worker with `wrangler dev` and run the component's OWN
#      `smokeCommand` against it, verbatim — the check the real deploy ends
#      with — and then read every route the site promises. A fresh site has
#      no Clerk application, so this is the site as it is born: every page
#      renders, with the "connect Clerk" notice where sign-in would be, the
#      title carries the site's name, the header links the site's repository,
#      /api/protected says Clerk is not connected (503), /api/health is ok;
#   4. the same stage lane's build-app again, now with a Clerk application's
#      two keys in its environment as the optional secret refs put them there
#      (made-up keys: nothing here reaches Clerk), and the result checked:
#      the secret key in no file of the build, the publishable key in the
#      pages, the secret handed to the Worker only from a lane that can
#      deploy. Served with the secret as the deploy hands it over (wrangler's
#      .dev.vars), it is the template itself — Clerk's middleware answering
#      every request, signed out: the sign-in button, /dashboard sending the
#      visitor to /sign-in, /api/protected refusing them, /api/health
#      connected. Served WITHOUT the secret, the deploy's smoke must fail: a
#      Worker that lost its secret is caught by the deploy, not by a visitor.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare token, deploy for real and probe workers.dev. That is a
# bootstrap against a workspace (BOOTSTRAP.md); everything short of it is here.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, and the network for
# `pnpm install` (or a warm store). A few minutes: two installs and three
# builds (the landing's checks over the site, and the stage lane's own in its
# staged tree, without Clerk and with it).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
cleanup() {
  if [ -n "$dev_pid" ]; then
    kill -TERM -- "-$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$dev_pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
sub="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['subdomain'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NEXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1

# The landing's own checks, step for step, run here at once on the whole
# tree. A pull request in the site builds and dry-deploys it through ci.yml's
# lanes; the lint and the tests run here, and by hand before a push.
LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm run wire:fixture"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "pnpm build"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   2 phases placed and landed"

# ── 1. the finished site ───────────────────────────────────────────────────
echo "── the finished site: install, the fixture render, typecheck, lint, test, build"
checks "$tree" "$scratch/checks-site.log"

# ── 2. the deploy lane's steps, for stage ──────────────────────────────────
echo "── the stage lane: build-app, verify-build-output, deploy-dry-run"
# The 01-product landing over the repository's empty first commit: every file
# of the site changed, as on its pull request.
s00="$(git -C "$tree" rev-parse HEAD~2)"; s01="$(git -C "$tree" rev-parse HEAD~1)"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { echo "FAIL: orun plan" >&2; tail -15 "$scratch/plan.log" >&2; exit 1; }
python3 - "$scratch/plan.json" "$scratch/steps" <<'PY'
import json, pathlib, sys
plan = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2]); out.mkdir()
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
for s in job["steps"]:
    if s["id"] in ("build-app", "verify-build-output", "deploy-dry-run"):
        (out / f"{s['id']}.sh").write_text(s.get("run") or "")
    if s["id"] == "install-workspace-dependencies":
        (out / "install.sh").write_text(s.get("run") or "")
        (out / "install.wd").write_text(s.get("working-directory") or ".")
        (out / "install.scope").write_text(s.get("scope") or "job")
(out / "path").write_text(job.get("path") or "apps/web")
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
PY
# The job's private tree, staged as orun stages it. The source checkout
# carries no build output (a CI checkout has none, so the plain-tree build's is
# removed rather than copied in), and its dependencies are what the pinned
# composition says: a lane-scoped install ran once in the source tree (step 1
# ran the same command) and is linked in, or the job installs its own.
rm -rf "$tree/apps/web/.open-next" "$tree/apps/web/.wrangler"
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
[ -f "$scratch/steps/install.sh" ] || { echo "FAIL: the stage lane has no install step" >&2; exit 1; }
if [ "$(cat "$scratch/steps/install.scope")" = lane ]; then
  python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
  [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; exit 1; }
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: lane — node_modules → the source tree's"
else
  python3 "$here/lib/stage-job.py" "$tree" "$work"
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: job — installing inside it"
  echo "   ▸ install-workspace-dependencies"
  (cd "$work/$(cat "$scratch/steps/path")/$(cat "$scratch/steps/install.wd")" && bash -e "$scratch/steps/install.sh") \
    > "$scratch/install.log" 2>&1 || { echo "FAIL: the lane's install step" >&2; tail -30 "$scratch/install.log" >&2; exit 1; }
  [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ] \
    || { echo "FAIL: the job's install did not land inside its own tree" >&2; exit 1; }
fi
for step in build-app verify-build-output deploy-dry-run; do
  [ -f "$scratch/steps/$step.sh" ] || { echo "FAIL: the stage verify lane has no $step step" >&2; exit 1; }
  echo "   ▸ $step"
  # The runner's per-job environment: the job's env (intent environment
  # `env:`) and ORUN_ENVIRONMENT; the step runs in the component's directory.
  if ! (cd "$work/$(cat "$scratch/steps/path")" && \
        { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
        export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/$step.sh") > "$scratch/$step.log" 2>&1; then
    echo "FAIL: the deploy lane's $step step" >&2; tail -40 "$scratch/$step.log" >&2; exit 1
  fi
done

# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
# serve DIR LOG [DEV_VARS] — wrangler dev over the built Worker in DIR, on a
# free port; sets $url. DEV_VARS, when given, is the Worker's secrets file.
serve() {
  local dir="$1" log="$2" vars="${3:-}"
  stop_dev
  port=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
  rm -f "$dir/.dev.vars"
  [ -n "$vars" ] && cp "$vars" "$dir/.dev.vars"
  (cd "$dir" && exec setsid pnpm exec wrangler dev --config wrangler.jsonc --ip 127.0.0.1 --port "$port" \
     --name "$repo-web-stage" --show-interactive-dev-session=false) > "$log" 2>&1 < /dev/null &
  dev_pid=$!
  # By name, not by address: wrangler dev hands the Worker `localhost` as the
  # request's host whichever address it was reached on, and Clerk's
  # middleware forwards a request to that host. Reached as 127.0.0.1, OpenNext
  # takes the forward for an external rewrite and fetches it — following a
  # redirect the browser should have seen. On workers.dev the two agree.
  url="http://localhost:$port"
  for _ in $(seq 1 90); do
    curl -s -o /dev/null "$url/" && return 0
    kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$log" >&2; exit 1; }
    sleep 1
  done
  curl -s -o /dev/null "$url/" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$log" >&2; exit 1; }
}
stop_dev() {
  if [ -n "$dev_pid" ]; then
    kill -TERM -- "-$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$dev_pid" 2>/dev/null || true
    dev_pid=""
  fi
}
smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"
app="$work/$(cat "$scratch/steps/path")"

echo "── wrangler dev over the built Worker: the site as it is born, Clerk not connected"
serve "$app" "$scratch/dev.log"
echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the site" >&2; exit 1; }

echo "   ▸ every route the site promises"
routes() { # MODE (not-connected|connected)
python3 - "$url" "$values" "https://$repo-web-stage.$sub.workers.dev" "$1" <<'PY'
import html, json, re, sys, urllib.error, urllib.request
base, values, origin, mode = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3], sys.argv[4]
name, repo, org = values["productname"], values["reponame"], values["githuborg"]
problems = []
def bad(m): problems.append(m)
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k): return None
opener = urllib.request.build_opener(NoRedirect)
def get(path):
    try:
        with opener.open(base + path, timeout=30) as r:
            return r.status, {k.lower(): v for k, v in r.headers.items()}, r.read().decode(errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, {k.lower(): v for k, v in e.headers.items()}, e.read().decode(errors="replace")

status, headers, page = get("/")
if status != 200 or "</html>" not in page:
    bad(f"/ answered {status}, or did not render to its end")
title = re.search(r"<title>(.*?)</title>", page, re.S)
if not title or html.unescape(title.group(1)) != name:
    bad(f"the home page's <title> is {title and title.group(1)!r}, not {name!r}")
if f'href="https://github.com/{org}/{repo}"' not in page:
    bad(f"the header does not link the site's repository github.com/{org}/{repo}")
og = re.search(r'<meta property="og:image" content="([^"]+)"', page)
if not og or not og.group(1).startswith(origin + "/"):
    bad(f"the Open Graph image is not absolute on {origin}: {og and og.group(1)}")
if "Next.js Clerk Template" in page or "clerk-auth-starter" in page:
    bad("the home page still carries the baseline's name")
if "Deploy to Vercel" in page or "vercel.com/new" in page:
    bad("the home page still offers to deploy the template to Vercel")

status, _, body = get("/api/health")
try:
    health = json.loads(body)
except ValueError:
    health = None
if status != 200 or health != {"ok": True, "clerk": mode}:
    bad(f"/api/health answered {status} {body[:120]!r}, want 200 ok and clerk {mode!r}")

s, _, _ = get("/no-such-page")
if s != 404:
    bad(f"/no-such-page answered {s}, want 404")

if mode == "not-connected":
    if 'data-clerk="not-connected"' not in page or "Connect Clerk to sign in" not in page:
        bad("the home page does not say Clerk is not connected where sign-in would be")
    for path in ("/dashboard", "/sign-in"):
        s, _, body = get(path)
        if s != 200 or "Clerk is not connected yet" not in body or "CLERK_SECRET_KEY" not in body:
            bad(f"{path} answered {s} without the connect-Clerk notice")
    s, _, body = get("/api/protected")
    if s != 503 or json.loads(body or "null") != {"error": "Clerk is not connected"}:
        bad(f"/api/protected answered {s} {body[:80]!r}, want 503 and why")
else:
    if 'data-clerk="not-connected"' in page or "Sign in</button>" not in page:
        bad("the connected home page does not offer the template's sign-in button")
    if headers.get("x-clerk-auth-status") != "signed-out":
        bad(f"Clerk's middleware did not answer the request (x-clerk-auth-status {headers.get('x-clerk-auth-status')!r})")
    # A redirect, or — the page streams behind its loading.tsx — a 200 whose
    # body redirects (Next's streamed NEXT_REDIRECT and a meta refresh).
    s, h, body = get("/dashboard")
    if "Clerk is not connected yet" in body or not re.search(r"/sign-in\?redirect_url=", body + h.get("location", "")):
        bad(f"/dashboard answered {s} without sending a signed-out visitor to /sign-in")
    s, _, body = get("/sign-in")
    if s != 200 or "Clerk is not connected yet" in body:
        bad(f"/sign-in answered {s}, or still says Clerk is not connected")
    # Clerk's auth.protect() in a route handler sends a signed-out caller to
    # sign-in, as upstream does: a 307, never the route's own answer.
    s, h, body = get("/api/protected")
    if s != 307 or "/sign-in?redirect_url=" not in h.get("location", "") or "protected route" in body:
        bad(f"/api/protected answered {s} {h.get('location')!r} to a signed-out request — want a 307 to /sign-in")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   /, /dashboard, /sign-in, /api/protected, /api/health and a 404 — the site's own, Clerk {mode}, on {origin}")
PY
}
routes not-connected

# ── 4. the same lane, with a Clerk application's keys ──────────────────────
# Made-up keys in the shape Clerk issues them (the publishable key is base64
# of a Frontend API host and `$`); the host is never contacted — a signed-out
# request needs nothing from Clerk.
echo "── the stage lane's build-app again, with Clerk's keys as the optional refs supply them"
pk="pk_test_$(printf 'e2e-fixture-00.clerk.accounts.dev$' | base64 | tr -d '\n')"
sk="sk_test_e2e_fixture_$(python3 -c "import secrets;print(secrets.token_hex(16))")"
rm -rf "$app/.open-next" "$app/.next" "$app/.wrangler"
if ! (cd "$app" && { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
      export ORUN_ENVIRONMENT=stage NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$pk" CLERK_SECRET_KEY="$sk" && \
      unset CLOUDFLARE_API_TOKEN && bash -e "$scratch/steps/build-app.sh") > "$scratch/build-app-clerk.log" 2>&1; then
  echo "FAIL: the deploy lane's build-app step, with Clerk's keys" >&2; tail -40 "$scratch/build-app-clerk.log" >&2; exit 1
fi
grep -q "worker-secrets: no Cloudflare credential in this job (a verify lane) — CLERK_SECRET_KEY reach $repo-web-stage from the deploy lane" \
  "$scratch/build-app-clerk.log" || { echo "FAIL: the build did not hand CLERK_SECRET_KEY to $repo-web-stage (or claimed to from a verify lane)" >&2; tail -10 "$scratch/build-app-clerk.log" >&2; exit 1; }
if grep -rlF -- "$sk" "$app/.open-next" "$app/.next" "$scratch/build-app-clerk.log" > "$scratch/leaks.txt" 2>/dev/null; then
  echo "FAIL: Clerk's secret key is in the build:" >&2; head -5 "$scratch/leaks.txt" >&2; exit 1
fi
grep -rqF -- "$pk" "$app/.open-next/assets" || { echo "FAIL: the publishable key was not inlined into the pages" >&2; exit 1; }
echo "   the secret key in no file of the build; the publishable key in the pages; the secret pushed only by a deploy lane"
(cd "$app" && { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
   export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/verify-build-output.sh") > "$scratch/verify-clerk.log" 2>&1 \
  || { echo "FAIL: verify-build-output, with Clerk" >&2; tail -20 "$scratch/verify-clerk.log" >&2; exit 1; }

echo "── wrangler dev over it, with the secret the deploy hands the Worker"
CLERK_SECRET_KEY="$sk" node "$tree/tooling/wire/worker-secrets.mjs" --secret CLERK_SECRET_KEY --dev-vars "$scratch/clerk.dev.vars" > /dev/null
serve "$app" "$scratch/dev-clerk.log" "$scratch/clerk.dev.vars"
echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the site with Clerk connected" >&2; exit 1; }
echo "   ▸ every route the site promises"
routes connected

echo "── and without it: the deploy's smoke must refuse a Worker that lost its secret"
serve "$app" "$scratch/dev-nosecret.log"
if DEPLOYED_URL="$url" bash -c "$smoke" 2>/dev/null; then
  echo "FAIL: the smoke passed a connected site whose Worker has no CLERK_SECRET_KEY" >&2; exit 1
fi
echo "   refused"
stop_dev

echo "e2e.test.sh: ok"
