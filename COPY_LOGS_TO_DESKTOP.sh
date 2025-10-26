#!/bin/bash
#
# Copy gameplay logs from iOS simulator to Desktop for easy access
#

set -e

echo "🔍 Searching for DunGen gameplay logs in simulator..."
echo ""

# Find the most recent GameplayLogs directory
# The path is: ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Documents/GameplayLogs
SIMULATOR_ROOT="$HOME/Library/Developer/CoreSimulator/Devices"

echo "Searching simulator containers (this may take a moment)..."

# More efficient search: look for GameplayLogs in Documents directories only
LOG_DIR=$(find "$SIMULATOR_ROOT" -type d -path "*/Containers/Data/Application/*/Documents/GameplayLogs" 2>/dev/null | \
    while read dir; do
        # Check if directory has JSON files
        if ls "$dir"/*.json >/dev/null 2>&1; then
            # Get the most recently modified file in this directory
            LATEST=$(ls -t "$dir"/*.json 2>/dev/null | head -1)
            if [ -n "$LATEST" ]; then
                # Output directory path with timestamp for sorting
                echo "$(stat -f %m "$LATEST") $dir"
            fi
        fi
    done | sort -rn | head -1 | cut -d' ' -f2-)

if [ -z "$LOG_DIR" ]; then
    echo "❌ No gameplay logs found!"
    echo ""
    echo "Possible reasons:"
    echo "  1. Tests haven't been run yet"
    echo "  2. Simulator was reset"
    echo "  3. Tests failed before logging"
    echo ""
    echo "Try running a test first:"
    echo "  xcodebuild test -scheme DunGen \\"
    echo "    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \\"
    echo "    -only-testing:DunGenTests/PlayDataGenerationExample/testSingleAdventure"
    exit 1
fi

# Count sessions
SESSION_COUNT=$(ls -1 "$LOG_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')

if [ "$SESSION_COUNT" -eq 0 ]; then
    echo "❌ Found GameplayLogs directory but no session files!"
    echo "Directory: $LOG_DIR"
    exit 1
fi

echo "✅ Found $SESSION_COUNT gameplay session(s)"
echo "📂 Location: $LOG_DIR"
echo ""

# Create destination directory on Desktop
DESKTOP="$HOME/Desktop/DunGen_Logs_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DESKTOP"

# Copy all JSON files
echo "📋 Copying logs to Desktop..."
cp "$LOG_DIR"/*.json "$DESKTOP/"

echo "✅ Copied $SESSION_COUNT session file(s) to:"
echo "   $DESKTOP"
echo ""

# Show some basic stats
echo "📊 Quick Stats:"
COMPLETED=$(grep -c '"questCompleted": true' "$DESKTOP"/*.json 2>/dev/null || echo "0")
TOTAL=$SESSION_COUNT
echo "   Quests Completed: $COMPLETED / $TOTAL"

DEATHS=$(grep -c '"deathOccurred": true' "$DESKTOP"/*.json 2>/dev/null || echo "0")
echo "   Character Deaths: $DEATHS"

echo ""
echo "🎉 Done! Open in Finder:"
echo "   open '$DESKTOP'"
echo ""
