---
name: github-proxy-fix
description: Elysia's custom protocol. Handles complex proxy routing for GitHub APIs without polluting the global environment. Prevents Slack Socket Mode from dropping due to hijacked requests. Use when Git drops packets (HTTP/2 framing error) or GraphQL throws unexpected EOF.
---

# 🌐 GitHub Network Proxy Failover Protocol (Elysia Edition)

**Context**: Hermes acts as a background agent and runs Slack Socket Mode. Setting a global `HTTP_PROXY` inside user configurations (`~/.zshrc`) poisons the Python `requests/aiohttp` environment, breaking long-polling bots.

**Trigger**: If Hermes encounters `unexpected EOF` from GraphQL (`gh pr view/merge`), or Git throws `Error in the HTTP2 framing layer`.

## Autonomous Action Protocol
If you are Hermes and you are writing automation bash scripts or invoking `git` / `gh` in a Subprocess:

1. **Auto-Detect Local Proxy**:
   Always check if the proxy port is open (e.g., Clash Verge Rev on `7897`).
   ```bash
   lsof -nP -iTCP:7897 -sTCP:LISTEN >/dev/null 2>&1
   ```

2. **Scoped Injection**:
   Only inject `HTTPS_PROXY` right before the command, or set it via `git config --local`. Never run `export` in a shared runtime.
   
   **For Git**:
   ```bash
   git config --local http.proxy http://127.0.0.1:7897
   git config --local https.proxy http://127.0.0.1:7897
   git config --local http.version HTTP/1.1
   ```

   **For GitHub CLI (`gh`)**:
   ```bash
   HTTPS_PROXY="http://127.0.0.1:7897" gh pr merge ...
   ```

3. **Fallbacks**:
   If HTTP/2 still fails despite proxy, switch to REST API (curl) and explicitly pass `--http1.1`. 
