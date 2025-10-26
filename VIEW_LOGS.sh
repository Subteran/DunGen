#!/bin/bash
#
# Find and view gameplay logs from DunGen simulator
#
# The logs are stored in the iOS simulator's sandbox Documents directory,
# not in ~/Documents/. This script helps locate and view them.
#

set -e

echo "🔍 Finding DunGen gameplay logs..."
echo ""

# Find the DunGen app container in simulator
SIMULATOR_ROOT="$HOME/Library/Developer/CoreSimulator/Devices"

# Look for GameplayLogs directory in all simulator containers
LOG_DIRS=$(find "$SIMULATOR_ROOT" -type d -name "GameplayLogs" 2>/dev/null | grep -v "Trash")

if [ -z "$LOG_DIRS" ]; then
    echo "❌ No gameplay logs found!"
    echo ""
    echo "This could mean:"
    echo "  1. No tests have been run yet"
    echo "  2. The simulator was reset/cleaned"
    echo "  3. The app hasn't created any sessions"
    echo ""
    echo "Try running a test first:"
    echo "  xcodebuild test -scheme DunGen \\"
    echo "    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \\"
    echo "    -only-testing:DunGenTests/PlayDataGenerationExample/testSingleAdventure"
    exit 1
fi

# Count total sessions
TOTAL_SESSIONS=0
echo "📂 Found GameplayLogs directories:"
echo ""

while IFS= read -r LOG_DIR; do
    SESSION_COUNT=$(ls -1 "$LOG_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
    if [ "$SESSION_COUNT" -gt 0 ]; then
        echo "  Location: $LOG_DIR"
        echo "  Sessions: $SESSION_COUNT"
        echo ""
        TOTAL_SESSIONS=$((TOTAL_SESSIONS + SESSION_COUNT))
        LATEST_LOG_DIR="$LOG_DIR"
    fi
done <<< "$LOG_DIRS"

if [ "$TOTAL_SESSIONS" -eq 0 ]; then
    echo "❌ Found GameplayLogs directories but no session files!"
    echo ""
    echo "Run a test to generate session data."
    exit 1
fi

echo "📊 Total sessions found: $TOTAL_SESSIONS"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Options:"
echo ""
echo "1. Open in Finder:"
echo "   open '$LATEST_LOG_DIR'"
echo ""
echo "2. List all sessions:"
echo "   ls -lh '$LATEST_LOG_DIR'"
echo ""
echo "3. View a session (pretty-printed JSON):"
echo "   cat '$LATEST_LOG_DIR'/session_*.json | python3 -m json.tool | less"
echo ""
echo "4. Copy to Desktop for easy access:"
echo "   cp '$LATEST_LOG_DIR'/*.json ~/Desktop/"
echo ""
echo "5. Count sessions by quest type:"
echo "   grep -h '\"questType\"' '$LATEST_LOG_DIR'/*.json | sort | uniq -c"
echo ""
echo "6. Check completion rate:"
echo "   echo \"Completed: \$(grep -c '\"questCompleted\": true' '$LATEST_LOG_DIR'/*.json) / $TOTAL_SESSIONS\""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Offer to open automatically
read -p "Open logs directory in Finder? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$LATEST_LOG_DIR"
    echo "✅ Opened in Finder"
fi

echo ""
echo "💡 Tip: To copy all logs to your Desktop for easier access:"
echo "   cp '$LATEST_LOG_DIR'/*.json ~/Desktop/"
echo ""
