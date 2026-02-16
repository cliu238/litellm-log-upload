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
        file_size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0)

        # Skip if already uploaded at same size (path<TAB>size format)
        prev_size=$(grep -F "$logfile" "$MARKER_FILE" 2>/dev/null | tail -1 | cut -f2)
        if [ "$prev_size" = "$file_size" ]; then
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

        # Record path<TAB>size on success — replaces old entry if present
        if [ "$http_code" = "200" ]; then
            sed -i'' -e "\|^${logfile}	|d" "$MARKER_FILE" 2>/dev/null || true
            printf '%s\t%s\n' "$logfile" "$file_size" >> "$MARKER_FILE"
        fi
    done
) &
disown

exit 0
