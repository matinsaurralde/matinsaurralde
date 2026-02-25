#!/bin/bash
# Reads Claude Code local stats and updates stats.json in the profile repo
# Run: ./update-stats.sh (from the repo root)
# Or set up a cron: */30 * * * * cd ~/matinsaurralde && ./update-stats.sh

set -e

STATS_FILE="$HOME/.claude/stats-cache.json"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$STATS_FILE" ]; then
  echo "Claude Code stats not found at $STATS_FILE"
  exit 1
fi

# Extract token totals from all models
total_tokens=$(python3 -c "
import json
with open('$STATS_FILE') as f:
    data = json.load(f)
total = 0
for model, usage in data.get('modelUsage', {}).items():
    total += usage.get('inputTokens', 0)
    total += usage.get('outputTokens', 0)
    total += usage.get('cacheReadInputTokens', 0)
    total += usage.get('cacheCreationInputTokens', 0)
print(total)
")

total_sessions=$(python3 -c "
import json
with open('$STATS_FILE') as f:
    data = json.load(f)
print(data.get('totalSessions', 0))
")

total_messages=$(python3 -c "
import json
with open('$STATS_FILE') as f:
    data = json.load(f)
print(data.get('totalMessages', 0))
")

total_tool_calls=$(python3 -c "
import json
with open('$STATS_FILE') as f:
    data = json.load(f)
total = sum(d.get('toolCallCount', 0) for d in data.get('dailyActivity', []))
print(total)
")

since_date=$(python3 -c "
import json
with open('$STATS_FILE') as f:
    data = json.load(f)
print(data.get('firstSessionDate', '')[:10])
")

models=$(python3 -c "
import json
with open('$STATS_FILE') as f:
    data = json.load(f)
print(json.dumps(list(data.get('modelUsage', {}).keys())))
")

# Format tokens for display
formatted=$(python3 -c "
t = $total_tokens
if t >= 1_000_000_000:
    print(f'{t/1_000_000_000:.2f}B')
elif t >= 1_000_000:
    print(f'{t/1_000_000:.1f}M')
else:
    print(f'{t:,}')
")

today=$(date +%Y-%m-%d)

# Write stats.json
cat > "$REPO_DIR/stats.json" <<EOF
{
  "totalTokens": $total_tokens,
  "totalTokensFormatted": "$formatted",
  "totalSessions": $total_sessions,
  "totalMessages": $total_messages,
  "totalToolCalls": $total_tool_calls,
  "models": $models,
  "since": "$since_date",
  "lastUpdated": "$today"
}
EOF

echo "Stats updated: $formatted tokens | $total_sessions sessions | $total_messages messages | $total_tool_calls tool calls"

# Auto-commit and push if there are changes
cd "$REPO_DIR"
if ! git diff --quiet stats.json 2>/dev/null; then
  git add stats.json
  git commit -m "update claude code stats: $formatted tokens"
  git push
  echo "Pushed to GitHub."
else
  echo "No changes to push."
fi
