#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
SMOKE_ROOT=${GLEAMCMS_SMOKE_DIR:-"$ROOT_DIR/.smoke/run-$$"}
OUTPUT_DIR="$SMOKE_ROOT/output"
DATA_DIR="$SMOKE_ROOT/data"
COOKIE_JAR="$SMOKE_ROOT/cookies.txt"
PORT=${GLEAMCMS_SMOKE_PORT:-4317}
BASE_URL="http://127.0.0.1:$PORT"
SECRET=$(openssl rand -hex 32)
ADMIN_TOKEN=$(openssl rand -hex 16)
SERVER_PID=""
SERVER_LOG="$SMOKE_ROOT/server.log"
RESTART_LOG="$SMOKE_ROOT/server-restart.log"

mkdir -p "$OUTPUT_DIR"

fail() {
  printf '%s\n' "SMOKE TEST FAILED: $*" >&2
  if [ -f "$SERVER_LOG" ]; then
    printf '%s\n' '--- server log ---' >&2
    tail -80 "$SERVER_LOG" >&2 || true
  fi
  exit 1
}

assert_status() {
  expected=$1
  actual=$2
  label=$3
  [ "$actual" = "$expected" ] || fail "$label returned HTTP $actual (expected $expected)"
}

assert_contains() {
  file=$1
  text=$2
  label=$3
  grep -F -- "$text" "$file" >/dev/null || fail "$label did not contain: $text"
}

assert_absent() {
  file=$1
  text=$2
  label=$3
  if grep -F -- "$text" "$file" >/dev/null; then
    fail "$label unexpectedly contained: $text"
  fi
}

stop_server() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
  fi
}

cleanup() {
  stop_server
}
trap cleanup EXIT INT TERM

start_server() {
  log_file=$1
  (
    cd "$ROOT_DIR"
    GLEAMCMS_SECRET="$SECRET" \
    GLEAMCMS_ADMIN_TOKEN="$ADMIN_TOKEN" \
    GLEAMCMS_OUTPUT_DIR="$OUTPUT_DIR" \
    GLEAMCMS_DATA_DIR="$DATA_DIR" \
    GLEAMCMS_PORT="$PORT" \
    GLEAMCMS_COOKIE_MAX_AGE=3600 \
    GLEAMCMS_IMPORT_LEGACY=false \
    gleam run >"$log_file" 2>&1
  ) &
  SERVER_PID=$!

  attempt=0
  while [ "$attempt" -lt 30 ]; do
    if curl -sS --max-time 1 "$BASE_URL/health" >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  fail "server did not become healthy on port $PORT"
}

request() {
  body_file=$1
  header_file=$2
  url=$3
  shift 3
  curl -sS -D "$header_file" -o "$body_file" -w '%{http_code}' "$url" "$@"
}

printf '%s\n' "Starting live smoke test on $BASE_URL"
printf '%s\n' "Evidence directory: $SMOKE_ROOT"
start_server "$SERVER_LOG"

status=$(request "$SMOKE_ROOT/health.body" "$SMOKE_ROOT/health.headers" "$BASE_URL/health")
assert_status 200 "$status" '/health'
assert_contains "$SMOKE_ROOT/health.body" '"status": "healthy"' '/health body'

status=$(request "$SMOKE_ROOT/home.body" "$SMOKE_ROOT/home.headers" "$BASE_URL/")
assert_status 200 "$status" 'public home'
assert_contains "$SMOKE_ROOT/home.body" 'GleamCMS' 'public home body'

status=$(request "$SMOKE_ROOT/editor.body" "$SMOKE_ROOT/editor.headers" "$BASE_URL/static/editor.js")
assert_status 200 "$status" '/static/editor.js'
assert_contains "$SMOKE_ROOT/editor.body" 'dataset.themes' 'editor asset'

status=$(request "$SMOKE_ROOT/login.body" "$SMOKE_ROOT/login.headers" "$BASE_URL/admin/login")
assert_status 200 "$status" '/admin/login'
assert_contains "$SMOKE_ROOT/login.body" 'GleamCMS Login' 'login page'

status=$(request "$SMOKE_ROOT/unauth-api.body" "$SMOKE_ROOT/unauth-api.headers" "$BASE_URL/api/posts")
assert_status 303 "$status" 'unauthenticated /api/posts'
assert_contains "$SMOKE_ROOT/unauth-api.headers" 'location: /admin/login' 'unauthenticated redirect'

status=$(request "$SMOKE_ROOT/login-wrong.body" "$SMOKE_ROOT/login-wrong.headers" "$BASE_URL/admin/login" \
  -X POST -H 'content-type: application/x-www-form-urlencoded' --data-urlencode 'token=wrong-token')
assert_status 200 "$status" 'invalid login'
assert_contains "$SMOKE_ROOT/login-wrong.body" 'Invalid token' 'invalid login body'

status=$(request "$SMOKE_ROOT/login-auth.body" "$SMOKE_ROOT/login.headers" "$BASE_URL/admin/login" \
  -X POST -H 'content-type: application/x-www-form-urlencoded' --data-urlencode "token=$ADMIN_TOKEN" -c "$COOKIE_JAR")
assert_status 303 "$status" 'valid login'
assert_contains "$SMOKE_ROOT/login.headers" 'set-cookie: gleamcms_session=' 'session cookie'
assert_contains "$SMOKE_ROOT/login.headers" 'HttpOnly' 'session cookie flags'
assert_contains "$SMOKE_ROOT/login.headers" 'SameSite=Strict' 'session cookie flags'
assert_contains "$SMOKE_ROOT/login.headers" 'Max-Age=3600' 'session cookie flags'

status=$(request "$SMOKE_ROOT/admin-auth.body" "$SMOKE_ROOT/admin-auth.headers" "$BASE_URL/admin" -b "$COOKIE_JAR")
assert_status 200 "$status" 'authenticated /admin'

status=$(request "$SMOKE_ROOT/posts-before.body" "$SMOKE_ROOT/posts-before.headers" "$BASE_URL/api/posts" -b "$COOKIE_JAR")
assert_status 200 "$status" 'authenticated post listing'

printf '%s' '{"title":"Smoke Live","slug":"smoke-live","content":"<p>Hello <script>alert(1)</script><img src=\"x\" onerror=\"alert(2)\"></p>","status":"published"}' > "$SMOKE_ROOT/publish.json"
status=$(request "$SMOKE_ROOT/publish.body" "$SMOKE_ROOT/publish.headers" "$BASE_URL/api/publish" \
  -X POST -H 'content-type: application/json' -H "Origin: $BASE_URL" --data-binary "@$SMOKE_ROOT/publish.json" -b "$COOKIE_JAR")
assert_status 200 "$status" 'publish'
assert_contains "$SMOKE_ROOT/publish.body" '"status": "ok"' 'publish body'

printf '%s' '{"title":"Invalid","slug":"Bad Slug!","content":"should not persist","status":"draft"}' > "$SMOKE_ROOT/invalid-save.json"
status=$(request "$SMOKE_ROOT/invalid-save.body" "$SMOKE_ROOT/invalid-save.headers" "$BASE_URL/api/save" \
  -X POST -H 'content-type: application/json' -H "Origin: $BASE_URL" --data-binary "@$SMOKE_ROOT/invalid-save.json" -b "$COOKIE_JAR")
assert_status 400 "$status" 'invalid slug save'
assert_contains "$SMOKE_ROOT/invalid-save.body" 'Invalid slug format' 'invalid slug response'

status=$(request "$SMOKE_ROOT/posts.body" "$SMOKE_ROOT/posts.headers" "$BASE_URL/api/posts" -b "$COOKIE_JAR")
assert_status 200 "$status" 'published post listing'
assert_contains "$SMOKE_ROOT/posts.body" 'smoke-live' 'published post listing'
assert_absent "$SMOKE_ROOT/posts.body" 'Bad Slug!' 'published post listing'

status=$(request "$SMOKE_ROOT/generate.body" "$SMOKE_ROOT/generate.headers" "$BASE_URL/api/generate?theme=Default%20Dark" \
  -X POST -H "Origin: $BASE_URL" -b "$COOKIE_JAR")
assert_status 200 "$status" 'generate'
assert_contains "$SMOKE_ROOT/generate.body" '"pages": 2' 'generate body'

status=$(request "$SMOKE_ROOT/output.body" "$SMOKE_ROOT/output.headers" "$BASE_URL/gleamcms_output/default-dark/smoke-live.html")
assert_status 200 "$status" 'generated output'
assert_contains "$SMOKE_ROOT/output.body" 'Hello' 'generated output'
assert_absent "$SMOKE_ROOT/output.body" 'onerror' 'generated output sanitization'
assert_absent "$SMOKE_ROOT/output.body" 'alert(1)' 'generated output sanitization'

stop_server
SERVER_LOG="$RESTART_LOG"
start_server "$RESTART_LOG"

status=$(request "$SMOKE_ROOT/restart-health.body" "$SMOKE_ROOT/restart-health.headers" "$BASE_URL/health")
assert_status 200 "$status" 'health after restart'

status=$(request "$SMOKE_ROOT/restart-output.body" "$SMOKE_ROOT/restart-output.headers" "$BASE_URL/gleamcms_output/default-dark/smoke-live.html")
assert_status 200 "$status" 'generated output after restart'
assert_contains "$SMOKE_ROOT/restart-output.body" 'Hello' 'generated output after restart'

status=$(request "$SMOKE_ROOT/restart-admin.body" "$SMOKE_ROOT/restart-admin.headers" "$BASE_URL/admin" -b "$COOKIE_JAR")
assert_status 200 "$status" 'stateless session after restart'

printf '%s\n' "SMOKE TEST PASSED"
printf '%s\n' "Evidence: $SMOKE_ROOT"