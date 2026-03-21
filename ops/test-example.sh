#!/usr/bin/env bash
# test-example.sh — Scaffold a Venutian Antfarm example into an isolated git worktree.
#
# Usage:
#   ops/test-example.sh <example-name>            # Set up test environment
#   ops/test-example.sh --cleanup <example-name>   # Remove test environment
#
# Examples:
#   ops/test-example.sh 01-getting-started
#   ops/test-example.sh --cleanup 01-getting-started
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKTREE_DIR="$REPO_ROOT/.worktrees"

usage() {
  echo "Usage: $0 [--cleanup] <example-name>" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 01-getting-started" >&2
  echo "  $0 --cleanup 01-getting-started" >&2
  exit 1
}

cleanup_example() {
  local name="$1"
  local found=0

  for wt in "$WORKTREE_DIR"/test-"$name"-*; do
    if [[ -d "$wt" ]]; then
      found=1
      local branch
      branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

      echo "Removing worktree: $wt"
      git -C "$REPO_ROOT" worktree remove --force "$wt" 2>/dev/null || rm -rf "$wt"

      if [[ -n "$branch" && "$branch" != "main" && "$branch" != "HEAD" ]]; then
        git -C "$REPO_ROOT" branch -D "$branch" 2>/dev/null || true
      fi
    fi
  done

  if [[ $found -eq 0 ]]; then
    echo "No worktrees found for example: $name" >&2
    exit 1
  fi

  echo "Cleanup complete."
}

setup_example() {
  local name="$1"
  local example_dir="$REPO_ROOT/examples/$name"

  # Validate example exists
  if [[ ! -d "$example_dir" ]]; then
    echo "Error: Example not found: examples/$name" >&2
    echo "" >&2
    echo "Available examples:" >&2
    ls -1 "$REPO_ROOT/examples/" 2>/dev/null | grep -v README | sed 's/^/  /' >&2
    exit 1
  fi

  # Check for existing worktree
  for existing in "$WORKTREE_DIR"/test-"$name"-*; do
    if [[ -d "$existing" ]]; then
      echo "Warning: Existing worktree found: $existing" >&2
      echo "Run '$0 --cleanup $name' first, or use the existing worktree." >&2
      exit 1
    fi
  done

  local timestamp
  timestamp=$(date +%s)
  local branch="test-${name}-${timestamp}"
  local wt_path="$WORKTREE_DIR/test-${name}-${timestamp}"

  mkdir -p "$WORKTREE_DIR"

  # Create worktree on a new branch
  echo "Creating worktree at: $wt_path"
  git -C "$REPO_ROOT" worktree add -b "$branch" "$wt_path" HEAD --quiet

  # Copy harness infrastructure
  echo "Copying harness infrastructure..."

  # Core agents
  mkdir -p "$wt_path/.claude/agents"
  cp "$REPO_ROOT"/.claude/agents/*.md "$wt_path/.claude/agents/" 2>/dev/null || true

  # Collaboration docs
  cp "$REPO_ROOT/.claude/COLLABORATION.md" "$wt_path/.claude/" 2>/dev/null || true
  cp "$REPO_ROOT/.claude/DOCUMENTATION-STYLE.md" "$wt_path/.claude/" 2>/dev/null || true

  # Settings (hooks for compliance enforcement)
  cp "$REPO_ROOT/.claude/settings.json" "$wt_path/.claude/" 2>/dev/null || true

  # Skills, governance, compliance, findings
  for dir in skills governance compliance findings; do
    if [[ -d "$REPO_ROOT/.claude/$dir" ]]; then
      cp -r "$REPO_ROOT/.claude/$dir" "$wt_path/.claude/"
    fi
  done

  # MCP config
  cp "$REPO_ROOT/.mcp.json" "$wt_path/" 2>/dev/null || true

  # Ops scripts
  cp -r "$REPO_ROOT/ops" "$wt_path/"

  # Templates
  cp -r "$REPO_ROOT/templates" "$wt_path/"

  # Copy example files (overwriting harness defaults where applicable)
  echo "Copying example files from: examples/$name"
  cp -r "$example_dir"/* "$wt_path/" 2>/dev/null || true
  # Handle dotfiles/directories (.claude)
  if [[ -d "$example_dir/.claude" ]]; then
    cp -r "$example_dir/.claude"/* "$wt_path/.claude/" 2>/dev/null || true
  fi

  # Apply overrides: copy override files into agents directory
  if [[ -d "$wt_path/.claude/overrides" ]]; then
    echo "Applying agent overrides..."
    cp "$wt_path/.claude/overrides"/*.md "$wt_path/.claude/agents/" 2>/dev/null || true
  fi

  # Run setup.sh if present
  if [[ -x "$wt_path/setup.sh" ]]; then
    echo "Running setup.sh..."
    if (cd "$wt_path" && bash setup.sh); then
      echo "Setup complete."
    else
      echo "Warning: setup.sh exited with errors. The example is still usable." >&2
    fi
  fi

  # Create initial commit in worktree so git state is clean
  (cd "$wt_path" && git add -A && git commit -m "test: scaffold example $name" --quiet 2>/dev/null) || true

  echo ""
  echo "================================================"
  echo "  Example $name ready!"
  echo "================================================"
  echo ""
  echo "  cd $wt_path"
  echo "  claude"
  echo ""
  echo "  Try first: /po"
  echo ""
  echo "  Cleanup:   $0 --cleanup $name"
  echo "================================================"
}

# Parse arguments
if [[ $# -lt 1 ]]; then
  usage
fi

if [[ "$1" == "--cleanup" ]]; then
  if [[ $# -lt 2 ]]; then
    usage
  fi
  cleanup_example "$2"
elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
  usage
else
  setup_example "$1"
fi
