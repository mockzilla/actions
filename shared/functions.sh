#!/usr/bin/env bash
# Shared helpers sourced by portable and codegen actions.
# Expects these env vars to be set by the caller:
#   GITHUB_TOKEN, REPO, EVENT, ACTION, REF, PR_NUMBER,
#   PREFERRED_REGION, TIMEOUT_MINUTES

post_error() {
  local msg="$1" upgrade="$2"
  local comment="**Mockzilla:** $msg"
  [ -n "$upgrade" ] && comment="$comment - [upgrade]($upgrade)"
  echo "::error::$msg"
  if [ -n "$PR_NUMBER" ]; then
    gh pr comment "$PR_NUMBER" --body "$comment" --edit-last 2>/dev/null || \
    gh pr comment "$PR_NUMBER" --body "$comment"
  fi
}

post_success() {
  local url="$1"
  echo "::notice::Mockzilla simulation live at $url"
  if [ -n "$PR_NUMBER" ]; then
    gh pr comment "$PR_NUMBER" --body "**Mockzilla:** simulation live at $url" --edit-last 2>/dev/null || \
    gh pr comment "$PR_NUMBER" --body "**Mockzilla:** simulation live at $url"
  fi
}

# handle_teardown <mode>
# Sends teardown request and exits 0.
handle_teardown() {
  local mode="$1"
  curl -sf -X POST "https://ingest.mockzilla.org/webhook?ref=${REF}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"repo\":\"$REPO\",\"event\":\"$EVENT\",\"action\":\"$ACTION\",\"mode\":\"${mode}\"}" \
    2>&1 || post_error "Mockzilla teardown failed"
  exit 0
}

# register_upload <mode>
# POSTs to ingest, validates response, sets UPLOAD_URL.
# Exits 1 on any error.
register_upload() {
  local mode="$1" region_field=""
  [ -n "$PREFERRED_REGION" ] && region_field=",\"preferred_region\":\"$PREFERRED_REGION\""

  local http_code response
  http_code=$(curl -s -w "%{http_code}" \
    -o /tmp/mz-response.json \
    -X POST "https://ingest.mockzilla.org/webhook?ref=${REF}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"repo\":\"$REPO\",\"event\":\"$EVENT\",\"action\":\"$ACTION\",\"mode\":\"${mode}\"${region_field}}")
  response=$(cat /tmp/mz-response.json 2>/dev/null)
  echo "::debug::Ingest HTTP ${http_code}: ${response}"

  if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ] 2>/dev/null; then
    post_error "Mockzilla publish failed (HTTP ${http_code}: ${response})"
    exit 1
  fi

  local error message upgrade_url
  error=$(echo "$response" | jq -r '.error // empty')
  message=$(echo "$response" | jq -r '.message // empty')
  upgrade_url=$(echo "$response" | jq -r '.upgrade_url // empty')

  if [ -n "$error" ]; then
    post_error "$message" "$upgrade_url"
    exit 1
  fi

  UPLOAD_URL=$(echo "$response" | jq -r '.upload_url // empty')
  if [ -z "$UPLOAD_URL" ]; then
    post_error "No upload URL returned from Mockzilla"
    exit 1
  fi
}

poll_status() {
  local org repo deadline resp status elapsed err live_url
  org=$(echo "$REPO" | cut -d/ -f1)
  repo=$(echo "$REPO" | cut -d/ -f2)
  deadline=$(( $(date +%s) + TIMEOUT_MINUTES * 60 ))
  sleep 15
  while true; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
      post_error "Mockzilla simulation did not become active within ${TIMEOUT_MINUTES} minutes"
      exit 1
    fi
    resp=$(curl -s \
      "https://ingest.mockzilla.org/webhook?org=${org}&repo=${repo}&ref=${REF}" \
      -H "Authorization: Bearer $GITHUB_TOKEN" 2>/dev/null)
    if [ -z "$resp" ]; then
      echo "Waiting for Mockzilla simulation... (no response yet)"
      sleep 15
      continue
    fi
    status=$(echo "$resp" | jq -r '.status // empty' 2>/dev/null)
    if [ -z "$status" ]; then
      echo "Waiting for Mockzilla simulation..."
    else
      elapsed=$(echo "$resp" | jq -r '.elapsed_ms // 0' 2>/dev/null)
      echo "Waiting for Mockzilla simulation... status=${status} elapsed=${elapsed}ms"
    fi
    case "$status" in
      active)
        live_url=$(echo "$resp" | jq -r '.url // empty')
        post_success "$live_url"
        exit 0
        ;;
      failed)
        err=$(echo "$resp" | jq -r '.error // "unknown error"')
        post_error "Mockzilla simulation failed: $err"
        exit 1
        ;;
    esac
    sleep 15
  done
}
