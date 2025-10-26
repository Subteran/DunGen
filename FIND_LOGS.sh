#!/bin/bash
#
# Simple script to find and show DunGen gameplay logs
#

echo "🔍 Searching for DunGen logs..."
echo ""

# Direct search for any session JSON files
echo "Looking for session files..."
SESSIONS=$(find ~/Library/Developer/CoreSimulator/Devices \
    -name "session_*.json" \
    -path "*/GameplayLogs/*" \
    2>/dev/null)

if [ -z "$SESSIONS" ]; then
    echo "❌ No session files found."
    echo ""
    echo "This means either:"
    echo "  1. No tests have been run yet"
    echo "  2. Tests ran but failed before creating logs"
    echo "  3. Simulator data was cleared"
    echo ""
    echo "Try running a test first to generate data."
    exit 1
fi

# Count sessions
COUNT=$(echo "$SESSIONS" | wc -l | tr -d ' ')
echo "✅ Found $COUNT session file(s)"
echo ""

# Get the directory of the first session
FIRST_SESSION=$(echo "$SESSIONS" | head -1)
LOG_DIR=$(dirname "$FIRST_SESSION")

echo "📂 Log directory:"
echo "   $LOG_DIR"
echo ""

# List all sessions with timestamps
echo "📋 Sessions:"
ls -lh "$LOG_DIR"/*.json | awk '{print "   " $9 " (" $5 ")"}'
echo ""

# Offer to copy to Desktop
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Copy all logs to Desktop? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    DESKTOP="$HOME/Desktop/DunGen_Logs_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DESKTOP"
    cp "$LOG_DIR"/*.json "$DESKTOP/"
    echo "✅ Copied to: $DESKTOP"
    open "$DESKTOP"
else
    echo "💡 You can copy them manually:"
    echo "   cp '$LOG_DIR'/*.json ~/Desktop/"
fi

echo ""
