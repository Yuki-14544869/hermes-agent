"""Gateway runtime-metadata footer.

Renders a compact footer showing runtime state (model, context %, cwd) and
appends it to the FINAL message of an agent turn when enabled.  Off by default
to keep replies minimal.

Config (``~/.hermes/config.yaml``)::

    display:
      runtime_footer:
        enabled: true                       # off by default
        fields: [model, context_pct, cwd]   # order shown; drop any to hide

Per-platform overrides live under ``display.platforms.<platform>.runtime_footer``.
Users can toggle the global setting with ``/footer on|off`` from both the CLI
and any gateway platform.

The footer is appended to the final response text in ``gateway/run.py`` right
before returning the response to the adapter send path — so it only lands on
the final message a user sees, not on tool-progress updates or streaming
partials.  When streaming is on and the final text has already been delivered
piecemeal, the footer is sent as a separate trailing message via
``send_trailing_footer()``.
"""

from __future__ import annotations

import json
import logging
import os
import sqlite3
from typing import Any, Iterable, Optional

logger = logging.getLogger(__name__)

_DEFAULT_FIELDS: tuple[str, ...] = ("model", "context_pct", "cwd")
_SEP = " · "

_DB_PATH = os.path.expanduser("~/.hermes/state.db")
_SNAPSHOT_PATH = os.path.expanduser("~/.hermes/.token_ticker_snapshot.json")


def _fmt_compact(value: int) -> str:
    """Compact thousands formatting: 1234 -> 1.2k, 1234567 -> 1.2M."""
    if abs(value) >= 1_000_000:
        return f"{value / 1_000_000:.1f}M"
    if abs(value) >= 1_000:
        return f"{value / 1_000:.1f}k"
    return str(value)


def _get_turn_delta(session_id: str) -> Optional[tuple[int, int, int]]:
    """Compute per-turn token delta via snapshot comparison.

    Reads session_model_usage, compares with last snapshot, updates snapshot.
    Returns (delta_in, delta_out, delta_cache_read) or None on failure.
    """
    if not os.path.exists(_DB_PATH):
        return None
    try:
        conn = sqlite3.connect(f"file:{_DB_PATH}?mode=ro", uri=True)
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT model, api_call_count, input_tokens, output_tokens, "
                "cache_read_tokens FROM session_model_usage "
                "WHERE session_id = ? ORDER BY last_seen",
                (session_id,),
            )
            current = [
                {"model": r[0], "calls": r[1] or 0, "in": r[2] or 0,
                 "out": r[3] or 0, "cache_r": r[4] or 0}
                for r in cur.fetchall()
            ]
        finally:
            conn.close()
    except sqlite3.Error as exc:
        logger.debug("token footer: db read failed: %s", exc)
        return None

    if not current:
        return None

    previous: list[dict] = []
    if os.path.exists(_SNAPSHOT_PATH):
        try:
            snap = json.loads(open(_SNAPSHOT_PATH).read())
            if snap.get("session_id") == session_id:
                previous = snap.get("usage", [])
        except (json.JSONDecodeError, KeyError):
            pass

    prev_map: dict[str, dict] = {r["model"]: r for r in previous}
    d_in = d_out = d_cr = 0
    for row in current:
        prev = prev_map.get(
            row["model"],
            {"calls": 0, "in": 0, "out": 0, "cache_r": 0},
        )
        di = row["in"] - prev["in"]
        do = row["out"] - prev["out"]
        dcr = row["cache_r"] - prev["cache_r"]
        if di > 0 or do > 0:
            d_in += di
            d_out += do
            d_cr += max(0, dcr)

    try:
        with open(_SNAPSHOT_PATH, "w") as f:
            json.dump({"session_id": session_id, "usage": current}, f)
    except OSError:
        pass

    if d_in == 0 and d_out == 0:
        return None
    return d_in, d_out, d_cr


def _home_relative_cwd(cwd: str) -> str:
    """Return *cwd* with ``$HOME`` collapsed to ``~``.  Empty string if unset."""
    if not cwd:
        return ""
    try:
        home = os.path.expanduser("~")
        p = os.path.abspath(cwd)
        if home and (p == home or p.startswith(home + os.sep)):
            return "~" + p[len(home):]
        return p
    except Exception:
        return cwd


def _model_short(model: Optional[str]) -> str:
    """Drop ``vendor/`` prefix for readability (``openai/gpt-5.4`` → ``gpt-5.4``)."""
    if not model:
        return ""
    return model.rsplit("/", 1)[-1]


def resolve_footer_config(
    user_config: dict[str, Any] | None,
    platform_key: str | None = None,
) -> dict[str, Any]:
    """Resolve effective runtime-footer config for *platform_key*.

    Merge order (later wins):
        1. Built-in defaults (enabled=False)
        2. ``display.runtime_footer``
        3. ``display.platforms.<platform_key>.runtime_footer``
    """
    resolved = {"enabled": False, "fields": list(_DEFAULT_FIELDS)}
    cfg = (user_config or {}).get("display") or {}

    global_cfg = cfg.get("runtime_footer")
    if isinstance(global_cfg, dict):
        if "enabled" in global_cfg:
            resolved["enabled"] = bool(global_cfg.get("enabled"))
        if isinstance(global_cfg.get("fields"), list) and global_cfg["fields"]:
            resolved["fields"] = [str(f) for f in global_cfg["fields"]]

    if platform_key:
        platforms = cfg.get("platforms") or {}
        plat_cfg = platforms.get(platform_key)
        if isinstance(plat_cfg, dict):
            plat_footer = plat_cfg.get("runtime_footer")
            if isinstance(plat_footer, dict):
                if "enabled" in plat_footer:
                    resolved["enabled"] = bool(plat_footer.get("enabled"))
                if isinstance(plat_footer.get("fields"), list) and plat_footer["fields"]:
                    resolved["fields"] = [str(f) for f in plat_footer["fields"]]

    return resolved


def format_runtime_footer(
    *,
    model: Optional[str],
    context_tokens: int,
    context_length: Optional[int],
    cwd: Optional[str] = None,
    fields: Iterable[str] = _DEFAULT_FIELDS,
    **kwargs: Any,
) -> str:
    """Render the footer line, or return "" if no fields have data.

    Fields are skipped silently when their underlying data is missing — a
    partially-populated footer is better than a line with ``?%`` or empty slots.
    """
    parts: list[str] = []
    for field in fields:
        if field == "model":
            m = _model_short(model)
            if m:
                parts.append(m)
        elif field == "context_pct":
            if context_length and context_length > 0 and context_tokens >= 0:
                pct = max(0, min(100, round((context_tokens / context_length) * 100)))
                parts.append(f"{pct}%")
        elif field == "cwd":
            rel = _home_relative_cwd(cwd or os.environ.get("TERMINAL_CWD", ""))
            if rel:
                parts.append(rel)
        elif field == "token":
            # Per-turn token delta via snapshot comparison.
            # session_id passed via closure from build_footer_line.
            _sid = kwargs.get("session_id") if kwargs else None
            if _sid:
                delta = _get_turn_delta(_sid)
                if delta:
                    di, do, dcr = delta
                    _total_in = di + dcr
                    _pct = (dcr / _total_in * 100) if _total_in > 0 else 0
                    _cache_str = f" cache {_pct:.0f}%" if dcr > 0 else ""
                    parts.append(f"↑{_fmt_compact(di)}/↓{_fmt_compact(do)}{_cache_str}")
        # Unknown field names are silently ignored.

    if not parts:
        return ""
    return _SEP.join(parts)


def build_footer_line(
    *,
    user_config: dict[str, Any] | None,
    platform_key: str | None,
    model: Optional[str],
    context_tokens: int,
    context_length: Optional[int],
    cwd: Optional[str] = None,
    session_id: Optional[str] = None,
) -> str:
    """Top-level entry point used by gateway/run.py.

    Returns the footer text (empty string when disabled or no data).  Callers
    append this to the final response themselves, preserving a single blank
    line of separation.
    """
    cfg = resolve_footer_config(user_config, platform_key)
    if not cfg.get("enabled"):
        return ""
    return format_runtime_footer(
        model=model,
        context_tokens=context_tokens,
        context_length=context_length,
        cwd=cwd,
        fields=cfg.get("fields") or _DEFAULT_FIELDS,
        session_id=session_id,
    )
