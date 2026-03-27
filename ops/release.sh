#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# release.sh — Push a clean release to the upstream (public) remote
#
# Usage:
#   ops/release.sh [--dry-run] <version>
#
# Arguments:
#   <version>    Tag to create (e.g. v0.4.0)
#   --dry-run    Show what would be done without pushing
#
# The script:
#   1. Creates a temporary branch from HEAD
#   2. Removes private/maintainer artifacts
#   3. Commits the clean state
#   4. Pushes to upstream/main
#   5. Tags the release
#   6. Cleans up the branch
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DRY_RUN=0
VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -*)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      VERSION="$1"
      shift
      ;;
  esac
done

if [[ -z "${VERSION}" ]]; then
  echo "Usage: ops/release.sh [--dry-run] <version>" >&2
  echo "Example: ops/release.sh v0.4.0" >&2
  exit 1
fi

# Validate version format
if [[ ! "${VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Version must match vX.Y.Z format (got: ${VERSION})" >&2
  exit 1
fi

# Verify upstream remote exists
if ! git remote get-url upstream &>/dev/null; then
  echo "ERROR: 'upstream' remote not configured" >&2
  echo "Add it with: git remote add upstream <url>" >&2
  exit 1
fi

# Verify working tree is clean (tracked files only — untracked/ignored are fine)
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "ERROR: Working tree has uncommitted changes. Commit or stash first." >&2
  exit 1
fi

echo "=== Release ${VERSION} ==="
echo "Source: HEAD ($(git rev-parse --short HEAD))"
echo "Target: upstream/main"
echo ""

# --- Private paths to strip (some may already be absent after purity audit) ---
STRIP_PATHS=(
  "docs/superpowers"
  "memory"
  "docs/compliance-coverage.md"
  "ops/release.sh"
)

# Create a temporary branch for the release
RELEASE_BRANCH="release-${VERSION}-$(date +%s)"
git checkout -b "${RELEASE_BRANCH}" HEAD

# Remove private paths
for path in "${STRIP_PATHS[@]}"; do
  if [[ -e "${path}" ]]; then
    git rm -rf "${path}" 2>/dev/null || true
    echo "  Stripped: ${path}"
  fi
done

# Commit the stripped state
git commit -m "chore: strip maintainer artifacts for ${VERSION} release" --allow-empty

echo ""
echo "Files to push:"
git diff --stat upstream/main..HEAD 2>/dev/null || echo "(upstream/main not fetched — run git fetch upstream first)"
echo ""

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[DRY RUN] Would push to upstream/main and tag ${VERSION}"
  echo "[DRY RUN] Cleaning up release branch"
  git checkout -
  git branch -D "${RELEASE_BRANCH}"
  exit 0
fi

echo "Push to upstream/main and tag ${VERSION}? [y/N]"
read -r confirm
if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
  echo "Aborted. Cleaning up release branch."
  git checkout -
  git branch -D "${RELEASE_BRANCH}"
  exit 0
fi

# Push to upstream (force: release branch replaces upstream main)
git push --force-with-lease upstream "${RELEASE_BRANCH}:main"

# Cleanup release branch (return to previous branch first)
git checkout -
git branch -D "${RELEASE_BRANCH}"

echo ""
echo "=== Pushed ${VERSION} to upstream/main ==="
echo ""
echo "Next step: create the GitHub release with release notes."
echo "  gh release create ${VERSION} --repo rdunie/venutian-antfarm --title '${VERSION}' --notes-file <notes.md>"
echo ""
echo "The GitHub release creates the tag automatically — do NOT git tag separately."
