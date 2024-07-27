#!/bin/bash
set -euo pipefail

# Determine database directory based on macOS version
DB_DIR=$([ "$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ] && 
         echo "$HOME/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings" || 
         echo "$HOME/Library/Application Support/com.apple.voicememos/Recordings")

EXPORT_DIR="$HOME/Desktop/AllVoiceMemos"
DB_PATH="$DB_DIR/CloudRecordings.db"

# Check requirements
[ -f "$DB_PATH" ] || { echo "Error: Database not found: $DB_PATH" >&2; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || { echo "Error: sqlite3 is required" >&2; exit 1; }

# Create and navigate to export directory
mkdir -p "$EXPORT_DIR" && cd "$EXPORT_DIR" || exit 1

# Export voice memos
sqlite3 -separator '|' "$DB_PATH" "SELECT ZPATH, ZCUSTOMLABEL, ZDATE FROM ZCLOUDRECORDING" |
while IFS='|' read -r location name date; do
    filename="${name:-Unnamed_Memo}.m4a"
    
    # Convert Apple's timestamp to Unix timestamp
    unix_timestamp=$(printf "%.0f" $(echo "$date + 978307200" | bc))
    
    # Format the date
    formatteddate=$(date -r "$unix_timestamp" "+%y%m%d%H%M.%S")
    
    echo "Exporting: $filename (Date: $formatteddate)"
    
    if [ -f "$DB_DIR/$location" ]; then
        cp "$DB_DIR/$location" "./$filename" && 
        touch -a -m -t "$formatteddate" "./$filename" || 
        echo "Warning: Failed to export $filename" >&2
    else
        echo "Warning: Source file not found: $DB_DIR/$location" >&2
    fi
done

echo "Export completed. Files saved in: $EXPORT_DIR"
open "$EXPORT_DIR"
