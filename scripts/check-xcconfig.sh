#!/usr/bin/env bash
# Blocks committing .xcconfig files that contain real secret values.
# Only .xcconfig.template files are allowed in git.
set -e
STAGED=$(git diff --cached --name-only)
FAIL=0
while IFS= read -r f; do
  if echo "$f" | grep -qE '\.xcconfig$' && ! echo "$f" | grep -q '\.template'; then
    if grep -qE 'FEEDBACK_INSTANCE_URL\s*=\s*https?://' "$f" 2>/dev/null; then
      echo "ERROR: $f contains a real FEEDBACK_INSTANCE_URL."
      echo "       Keep secrets out of git — use FeedbackApp.xcconfig.template instead."
      FAIL=1
    fi
  fi
done <<< "$STAGED"
exit $FAIL
