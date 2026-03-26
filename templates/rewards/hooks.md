# Rewards Ledger — Prescribed Hooks

Add these to your `.claude/settings.json` during onboarding.

## PreToolUse (Edit|Write) — Ledger file protection

```json
{
  "type": "command",
  "command": "echo \"$CLAUDE_FILE_PATH\" | grep -qE 'rewards/ledger\\.md$|rewards/ledger-checksum' && { [ -f .claude/rewards/.issuing ] && find .claude/rewards/.issuing -mmin -1 -print -quit 2>/dev/null | grep -q . && exit 0 || echo 'BLOCKED: Rewards ledger is protected. Use ops/rewards-log.sh to issue feedback.' && exit 2; } || exit 0"
}
```

## PreToolUse (Bash) — Block direct ledger writes

```json
{
  "type": "command",
  "command": "echo \"$CLAUDE_TOOL_INPUT\" | grep -q 'rewards/ledger' && echo 'BLOCKED: Use ops/rewards-log.sh instead of writing the rewards ledger directly' && exit 2 || exit 0"
}
```

## SessionStart — Checksum verification

```json
{
  "type": "command",
  "command": "[ -f .claude/rewards/ledger-checksum.sha256 ] && [ -f .claude/rewards/ledger.md ] && { EXPECTED=$(sha256sum .claude/rewards/ledger.md | cut -d' ' -f1); ACTUAL=$(cut -d' ' -f1 .claude/rewards/ledger-checksum.sha256); [ \"$EXPECTED\" = \"$ACTUAL\" ] && echo '[CO] Rewards ledger integrity verified.' || echo '[CO] WARNING: Rewards ledger checksum mismatch. Possible tampering. Run git checkout to restore.'; } || true"
}
```

## .gitignore entry

```
# Rewards sentinel file (transient, never committed)
.claude/rewards/.issuing
```
