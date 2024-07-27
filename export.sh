#!/bin/bash
# inspired by Bulk Export Voice Memos https://discussions.apple.com/thread/253230259 
# Set strict mode
set -euo pipefail

# Function to print error messages
error() {
    echo "Error: $1" >&2
    exit 1
}

# Function to get macOS version
get_macos_version() {
    sw_vers -productVersion | cut -d. -f1,2
}

# Check macOS version and set DB_DIR accordingly
MACOS_VERSION=$(get_macos_version)
if [[ $(echo "$MACOS_VERSION > 13.0" | bc -l) -eq 1 ]]; then
    DB_DIR="$HOME/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings"
else
    DB_DIR="$HOME/Library/Application Support/com.apple.voicememos/Recordings"
fi

# Define constants
DB_NAME="CloudRecordings.db"
DB_PATH="$DB_DIR/$DB_NAME"
EXPORT_DIR="$HOME/Desktop/AllVoiceMemos"
TIMESTAMP_OFFSET=978307200

# Check if required commands are available
command -v sqlite3 >/dev/null 2>&1 || error "sqlite3 is required but not installed."
command -v bc >/dev/null 2>&1 || error "bc is required but not installed."

# Check if database file exists
[ -f "$DB_PATH" ] || error "Database file not found: $DB_PATH"

# Create export directory
mkdir -p "$EXPORT_DIR" || error "Failed to create export directory: $EXPORT_DIR"

# Change to export directory
cd "$EXPORT_DIR" || error "Failed to change to export directory: $EXPORT_DIR"

# Export voice memos
sqlite3 -separator '|' "$DB_PATH" \
    "SELECT ZPATH, ZCUSTOMLABEL, ZDATE FROM ZCLOUDRECORDING" |
while IFS='|' read -r location name date; do
    # Calculate and format date
    newdate=$(bc <<< "$date + $TIMESTAMP_OFFSET")
    trimdate=${newdate%.*}
    formatteddate=$(date -r "$trimdate" +%y%m%d%H%M.%S)
    
    # Generate file name
    filename="${name:-Unnamed_Memo}.m4a"
    
    echo "Exporting: $filename (Date: $formatteddate)"
    
    # Copy file
    if [ -f "$DB_DIR/$location" ]; then
        cp "$DB_DIR/$location" "./$filename" || error "Failed to copy file: $location"
        touch -a -m -t "$formatteddate" "./$filename" || error "Failed to set file timestamp: $filename"
    else
        echo "Warning: Source file not found: $DB_DIR/$location" >&2
    fi
done

echo "Export completed. Files saved in: $EXPORT_DIR"

# Open the export directory
open "$EXPORT_DIR"
