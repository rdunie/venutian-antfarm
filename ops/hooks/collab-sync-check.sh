#!/usr/bin/env bash
# PostToolUse hook: warns when collaboration docs are edited without their pair.
# Advisory only (always exits 0). Checks git diff for paired modifications.

FILE="$CLAUDE_FILE_PATH"
COLLAB=".claude/COLLABORATION.md"
MODEL="docs/COLLABORATION-MODEL.md"

# Only fire for collaboration-related files
case "$FILE" in
  *COLLABORATION.md|*COLLABORATION-MODEL.md|*memory/feedback_*)
    ;;
  *)
    exit 0
    ;;
esac

# Gather all files touched in this session (staged + unstaged)
TOUCHED=$(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null)

if echo "$FILE" | grep -q "$COLLAB" && ! echo "$TOUCHED" | grep -q "COLLABORATION-MODEL.md"; then
  echo "[COLLAB-SYNC] You edited COLLABORATION.md -- check if docs/COLLABORATION-MODEL.md needs a matching update."
elif echo "$FILE" | grep -q "COLLABORATION-MODEL.md" && ! echo "$TOUCHED" | grep -q "COLLABORATION.md"; then
  echo "[COLLAB-SYNC] You edited COLLABORATION-MODEL.md -- check if .claude/COLLABORATION.md needs a matching update."
elif echo "$FILE" | grep -q "memory/feedback_" && ! echo "$TOUCHED" | grep -qE "(COLLABORATION.md|COLLABORATION-MODEL.md)"; then
  echo "[COLLAB-SYNC] You wrote a collaboration behavior memory -- check if COLLABORATION.md or COLLABORATION-MODEL.md need a matching update."
fi

exit 0
