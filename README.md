# LiteLLM Log Upload Plugin

Auto-upload your Claude Code session logs to the JHU IDIES LiteLLM gateway when each session ends.

## Prerequisites

- Claude Code CLI installed
- Gateway access configured (see [CLAUDE_CODE_SETUP.md](https://github.com/JH-DSAI/litellm/blob/main/CLAUDE_CODE_SETUP.md))
- The following environment variables set in your shell profile:
  ```bash
  export ANTHROPIC_BASE_URL="https://dev.sites.idies.jhu.edu/litellm"
  export ANTHROPIC_CUSTOM_HEADERS="x-litellm-api-key: Bearer sk-litellm-<your-key>"
  ```

## Install

```bash
claude plugin add https://github.com/cliu238/litellm-log-upload.git
```

That's it. The plugin takes effect on your **next** Claude Code session (not the one currently running).

## Uninstall

```bash
claude plugin remove litellm-log-upload
```

No terminal restart needed.

## How It Works

1. When a Claude Code session ends, the plugin's Stop hook fires
2. It scans `~/.claude/projects/` for all session `.jsonl` log files
3. It uploads any files not yet uploaded to the gateway via `POST /log/upload`
4. Successfully uploaded files are recorded in `~/.claude/.last-log-upload`
5. The upload runs in the background so it doesn't delay your terminal

**Self-healing:** If an upload fails (network down, gateway unreachable), the file stays in the "not yet uploaded" list. The next time any Claude Code session ends, it catches up and uploads all missed files.

## What Gets Uploaded

Your full Claude Code session logs (`.jsonl` files), which include:
- Conversation messages (user + assistant)
- Tool usage (commands run, files read/edited)
- Token usage and model info

Logs are stored on the gateway at:
```
/data/logs/LocalLog/{your-username}@{your-ip}/
```

## Troubleshooting

**Logs not appearing on the server?**

1. Verify the gateway is reachable:
   ```bash
   curl https://dev.sites.idies.jhu.edu/litellm/health/liveliness
   # Expected: "I'm alive!"
   ```

2. Verify your env vars are set:
   ```bash
   echo $ANTHROPIC_BASE_URL
   echo $ANTHROPIC_CUSTOM_HEADERS
   ```

3. Check the marker file for upload history:
   ```bash
   cat ~/.claude/.last-log-upload
   ```

4. Test the upload endpoint manually:
   ```bash
   curl -X POST "https://dev.sites.idies.jhu.edu/litellm/log/upload?filename=manual-test.jsonl" \
       -H "x-litellm-api-key: Bearer sk-litellm-<your-key>" \
       -H "X-User-ID: $(whoami)" \
       -d '{"test": true}'
   ```

**Want to re-upload everything?**

Delete the marker file and start a new Claude Code session:
```bash
rm ~/.claude/.last-log-upload
```
