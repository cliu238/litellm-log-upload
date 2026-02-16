#!/usr/bin/env bash
# Upload Claude Code session logs to LiteLLM gateway with catch-up.
# Runs the actual upload in background so it doesn't block Claude Code exit.

set -euo pipefail

# Consume stdin (Stop hook sends JSON, we don't need it)
cat > /dev/null

# Config
MARKER_FILE="${HOME}/.claude/.last-log-upload"
LOGS_DIR="${HOME}/.claude/projects"
UPLOAD_URL="${LITELLM_LOG_UPLOAD_URL:-${ANTHROPIC_BASE_URL:-https://dev.sites.idies.jhu.edu/litellm}}/log/upload"
USER_ID="$(whoami)"

# Extract API key from ANTHROPIC_CUSTOM_HEADERS
# Format: "x-litellm-api-key: Bearer sk-litellm-..."
API_KEY=""
if [ -n "${ANTHROPIC_CUSTOM_HEADERS:-}" ]; then
    API_KEY=$(echo "$ANTHROPIC_CUSTOM_HEADERS" | sed -n 's/.*x-litellm-api-key: *//p')
fi

if [ -z "$API_KEY" ]; then
    exit 0  # No API key configured, skip silently
fi

# Background the upload work
(
    # Create marker file if it doesn't exist
    touch "$MARKER_FILE"

    # Find all session JSONL files
    find "$LOGS_DIR" -maxdepth 3 -name "*.jsonl" -type f 2>/dev/null | while read -r logfile; do
        basename_file=$(basename "$logfile")

        # Skip if already uploaded
        if grep -qxF "$logfile" "$MARKER_FILE" 2>/dev/null; then
            continue
        fi

        # Upload
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST "${UPLOAD_URL}?filename=${basename_file}" \
            -H "x-litellm-api-key: ${API_KEY}" \
            -H "X-User-ID: ${USER_ID}" \
            -H "Content-Type: application/octet-stream" \
            --data-binary "@${logfile}" \
            --max-time 60 \
            2>/dev/null) || true

        # Mark as uploaded on success (200)
        if [ "$http_code" = "200" ]; then
            echo "$logfile" >> "$MARKER_FILE"
        fi
    done
) &
disown

exit 0
