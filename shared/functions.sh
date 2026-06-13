#!/usr/bin/env bash
# Shared helpers sourced by portable and codegen actions.
# Expects these env vars to be set by the caller:
#   GITHUB_TOKEN, REPO, EVENT, ACTION, REF, DEFAULT_BRANCH, PR_NUMBER,
#   PREFERRED_REGION, ENVIRONMENT, HOST, TIMEOUT_MINUTES

# Blank ref only for a push to the default branch; a non-default push keeps its name so it can't clobber the default slot.
if [ "$REF" = "$DEFAULT_BRANCH" ]; then
  REF=""
fi

install_mockzilla() {
  GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}" gh release download \
    --repo mockzilla/mockzilla \
    --pattern '*-linux-amd64' \
    --output /tmp/mockzilla
  chmod +x /tmp/mockzilla
  export PATH="/tmp:$PATH"
}

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
  local terms_notice=""
  if [ "$FIRST_USE" = "true" ]; then
    terms_notice=$'\n\nBy using Mockzilla you agree to our [Terms of Service](https://mockzilla.org/terms/) and [Privacy Policy](https://mockzilla.org/privacy/).'
  fi
  echo "::notice::Mockzilla simulation live at $url"
  echo "url=$url" >> "$GITHUB_OUTPUT"
  {
    echo "### Mockzilla"
    echo "Simulation live at $url"
    [ -n "$terms_notice" ] && echo "$terms_notice"
  } >> "$GITHUB_STEP_SUMMARY"
  if [ -n "$PR_NUMBER" ]; then
    gh pr comment "$PR_NUMBER" --body "**Mockzilla:** simulation live at $url${terms_notice}" --edit-last 2>/dev/null || \
    gh pr comment "$PR_NUMBER" --body "**Mockzilla:** simulation live at $url${terms_notice}"
  fi
}

# surface_warnings <response-json>
# Emits non-fatal notices from an ingest response as GitHub warnings (and a PR
# comment) without failing the build.
surface_warnings() {
  local resp="$1" warning
  while IFS= read -r warning; do
    [ -z "$warning" ] && continue
    echo "::warning::Mockzilla: $warning"
    if [ -n "$PR_NUMBER" ]; then
      gh pr comment "$PR_NUMBER" --body "**Mockzilla:** $warning" 2>/dev/null || true
    fi
  done < <(echo "$resp" | jq -r '.warnings[]? // empty' 2>/dev/null)
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

# handle_delete <mode>
# Sends a sim-level delete request and exits 0.
# Releases the org's sim slot by removing the entire simulation for this repo.
handle_delete() {
  local mode="$1"
  local http_code
  http_code=$(curl -s -o /tmp/mz-response.json -w "%{http_code}" \
    -X DELETE "https://ingest.mockzilla.org/webhook" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"repo\":\"$REPO\",\"mode\":\"${mode}\"}")
  if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ] 2>/dev/null; then
    local err_message
    err_message=$(jq -r '.message // empty' /tmp/mz-response.json 2>/dev/null)
    [ -z "$err_message" ] && err_message="Mockzilla delete failed (HTTP ${http_code})"
    post_error "$err_message"
    exit 1
  fi
  echo "::notice::Mockzilla: repository removed"
  exit 0
}

# register_upload <mode>
# POSTs to ingest, validates response, sets UPLOAD_URL.
# Exits 1 on any error.
register_upload() {
  local mode="$1" region_field="" env_field="" host_field=""
  local ba_user_field="" ba_pass_field="" ips_field="" services_field=""
  [ -n "$PREFERRED_REGION" ] && region_field=",\"preferred_region\":\"$PREFERRED_REGION\""
  [ -n "$ENVIRONMENT" ] && env_field=",\"environment\":$ENVIRONMENT"
  [ -n "$HOST" ] && host_field=",\"host\":\"$HOST\""
  [ -n "$BASIC_AUTH_USER" ] && ba_user_field=",\"basic_auth_user\":\"$BASIC_AUTH_USER\""
  [ -n "$BASIC_AUTH_PASSWORD" ] && ba_pass_field=",\"basic_auth_password\":\"$BASIC_AUTH_PASSWORD\""
  [ -n "$ALLOWED_IPS" ] && ips_field=",\"allowed_ips\":$ALLOWED_IPS"
  [ -n "$SERVICES_JSON" ] && [ "$SERVICES_JSON" != "[]" ] && services_field=",\"services\":$SERVICES_JSON"

  local http_code response
  http_code=$(curl -s -w "%{http_code}" \
    -o /tmp/mz-response.json \
    -X POST "https://ingest.mockzilla.org/webhook?ref=${REF}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"repo\":\"$REPO\",\"event\":\"$EVENT\",\"action\":\"$ACTION\",\"mode\":\"${mode}\"${region_field}${env_field}${host_field}${ba_user_field}${ba_pass_field}${ips_field}${services_field}}")
  response=$(cat /tmp/mz-response.json 2>/dev/null)
  echo "::debug::Ingest HTTP ${http_code}: ${response}"

  if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ] 2>/dev/null; then
    local err_message
    err_message=$(echo "$response" | jq -r '.message // empty' 2>/dev/null)
    if [ -n "$err_message" ]; then
      post_error "$err_message"
    else
      post_error "Mockzilla publish failed (HTTP ${http_code})"
    fi
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

  FIRST_USE=$(echo "$response" | jq -r '.first_use // empty')

  surface_warnings "$response"
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
