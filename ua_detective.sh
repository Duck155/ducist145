#!/bin/bash

# Chrome OS Kiosk User Agent Detective
# Tries multiple methods to discover the kiosk browser's user agent

echo "=============================================="
echo "   Chrome OS Kiosk User Agent Detective"
echo "=============================================="
echo ""

SUCCESS_COUNT=0
TOTAL_CHECKS=0

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}▶ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_fail() {
    echo -e "${RED}✗ $1${NC}"
}

# Method 1: Check Chrome Process Arguments
print_section "Method 1: Chrome Process Command Line"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
echo "Looking for Chrome processes and their arguments..."
CHROME_PROCS=$(ps aux | grep -E "chrome|chromium" | grep -v grep)
if [ -n "$CHROME_PROCS" ]; then
    echo "$CHROME_PROCS" | while read -r line; do
        PID=$(echo "$line" | awk '{print $2}')
        if [ -f "/proc/$PID/cmdline" ]; then
            CMDLINE=$(cat /proc/$PID/cmdline 2>/dev/null | tr '\0' ' ')
            if echo "$CMDLINE" | grep -q "user-agent"; then
                print_success "Found user-agent in process $PID"
                echo "$CMDLINE" | grep -oP 'user-agent[=\s]+\K[^-]*' | head -1
            fi
        fi
    done
    
    echo ""
    echo "Chrome process info:"
    echo "$CHROME_PROCS" | head -5
else
    print_fail "No Chrome processes found"
fi

# Method 2: Check Chrome Logs
print_section "Method 2: Chrome Logs"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
LOG_LOCATIONS=(
    "/var/log/chrome/chrome"
    "/var/log/messages"
    "/home/chronos/user/log"
    "/tmp/chrome_debug.log"
    "/var/log/ui/ui.LATEST"
)

echo "Checking Chrome log locations..."
for log in "${LOG_LOCATIONS[@]}"; do
    if [ -f "$log" ]; then
        print_info "Checking: $log"
        UA_INFO=$(grep -i "user-agent\|useragent\|User Agent" "$log" 2>/dev/null | tail -5)
        if [ -n "$UA_INFO" ]; then
            print_success "Found user agent info in $log"
            echo "$UA_INFO"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    fi
done

# Method 3: Check journalctl
print_section "Method 3: System Journal (journalctl)"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if command -v journalctl &> /dev/null; then
    echo "Searching journal for user agent mentions..."
    JOURNAL_UA=$(journalctl -b 2>/dev/null | grep -i "user-agent" | tail -10)
    if [ -n "$JOURNAL_UA" ]; then
        print_success "Found user agent info in journal"
        echo "$JOURNAL_UA"
    else
        print_fail "No user agent info in journal"
    fi
else
    print_info "journalctl not available"
fi

# Method 4: Check Device Policy
print_section "Method 4: Device Policy Files"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
POLICY_LOCATIONS=(
    "/var/lib/devicesettings/policy"
    "/var/lib/whitelist/policy"
    "/home/chronos/Local State"
    "/home/chronos/.config/google-chrome/Local State"
)

echo "Checking device policy and configuration files..."
for policy in "${POLICY_LOCATIONS[@]}"; do
    if [ -f "$policy" ]; then
        print_info "Checking: $policy"
        UA_POLICY=$(grep -i "user.*agent\|useragent" "$policy" 2>/dev/null)
        if [ -n "$UA_POLICY" ]; then
            print_success "Found user agent configuration in $policy"
            echo "$UA_POLICY"
        fi
    fi
done

# Method 5: Check Kiosk App Configuration
print_section "Method 5: Kiosk App Manifests & Config"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
echo "Searching for kiosk app configurations..."

# Find manifest.json files
MANIFESTS=$(find /home/chronos/ -name "manifest.json" 2>/dev/null)
if [ -n "$MANIFESTS" ]; then
    echo "$MANIFESTS" | while read -r manifest; do
        print_info "Checking: $manifest"
        cat "$manifest" 2>/dev/null | grep -i "user.*agent"
    done
fi

# Check for kiosk specific files
KIOSK_FILES=$(find /home/chronos/ -name "*kiosk*" 2>/dev/null | head -10)
if [ -n "$KIOSK_FILES" ]; then
    echo ""
    print_info "Found kiosk-related files:"
    echo "$KIOSK_FILES"
fi

# Method 6: Check Chrome Preferences
print_section "Method 6: Chrome Preferences"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
PREF_LOCATIONS=(
    "/home/chronos/user/Preferences"
    "/home/chronos/.config/google-chrome/Default/Preferences"
    "/home/chronos/.config/chromium/Default/Preferences"
)

echo "Checking Chrome preferences files..."
for pref in "${PREF_LOCATIONS[@]}"; do
    if [ -f "$pref" ]; then
        print_info "Checking: $pref"
        UA_PREF=$(grep -i "user.*agent" "$pref" 2>/dev/null)
        if [ -n "$UA_PREF" ]; then
            print_success "Found user agent in preferences"
            echo "$UA_PREF" | head -5
        fi
    fi
done

# Method 7: Check Environment Variables
print_section "Method 7: Chrome Environment Variables"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
echo "Checking environment variables of Chrome processes..."
CHROME_PIDS=$(pgrep -f "chrome\|chromium" | head -5)
if [ -n "$CHROME_PIDS" ]; then
    for pid in $CHROME_PIDS; do
        if [ -f "/proc/$pid/environ" ]; then
            UA_ENV=$(cat /proc/$pid/environ 2>/dev/null | tr '\0' '\n' | grep -i "user.*agent\|chrome")
            if [ -n "$UA_ENV" ]; then
                print_success "Found Chrome environment for PID $pid"
                echo "$UA_ENV" | head -5
            fi
        fi
    done
else
    print_fail "No Chrome PIDs found"
fi

# Method 8: Network Traffic Capture (passive)
print_section "Method 8: Network Traffic Analysis"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if command -v tcpdump &> /dev/null; then
    echo "Attempting to capture User-Agent from network traffic..."
    echo "This will run for 10 seconds - try refreshing the kiosk page if possible"
    print_info "Capturing traffic... (10 seconds)"
    
    timeout 10 tcpdump -i any -A 'tcp port 80' 2>/dev/null | grep -i "user-agent" --line-buffered | head -5 &
    TCPDUMP_PID=$!
    
    sleep 10
    
    if kill -0 $TCPDUMP_PID 2>/dev/null; then
        kill $TCPDUMP_PID 2>/dev/null
    fi
    
    print_info "Network capture complete (HTTPS traffic is encrypted and won't show)"
else
    print_fail "tcpdump not available"
fi

# Method 9: Check Chrome Version Info
print_section "Method 9: Chrome/ChromeOS Version Info"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
echo "Getting Chrome and ChromeOS version information..."

if [ -f "/etc/lsb-release" ]; then
    print_success "Found /etc/lsb-release"
    grep -E "CHROMEOS|CHROME" /etc/lsb-release
fi

CHROME_VERSION=$(google-chrome --version 2>/dev/null || chromium --version 2>/dev/null || chromium-browser --version 2>/dev/null)
if [ -n "$CHROME_VERSION" ]; then
    print_success "Chrome version: $CHROME_VERSION"
fi

# Method 10: Standard User Agent Pattern
print_section "Method 10: Expected Chrome OS User Agent Pattern"
echo "Based on Chrome OS standards, your kiosk user agent likely follows this pattern:"
echo ""
echo "Mozilla/5.0 (X11; CrOS x86_64 [VERSION]) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/[CHROME_VERSION] Safari/537.36"
echo ""

if [ -f "/etc/lsb-release" ]; then
    CROS_VERSION=$(grep CHROMEOS_RELEASE_VERSION /etc/lsb-release 2>/dev/null | cut -d= -f2)
    CHROME_VER=$(grep CHROMEOS_RELEASE_CHROME_MILESTONE /etc/lsb-release 2>/dev/null | cut -d= -f2)
    
    if [ -n "$CROS_VERSION" ] && [ -n "$CHROME_VER" ]; then
        print_success "Reconstructed likely User Agent:"
        echo ""
        echo "Mozilla/5.0 (X11; CrOS x86_64 $CROS_VERSION) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$CHROME_VER.0.0.0 Safari/537.36"
        echo ""
    fi
fi

# Summary
echo ""
echo "=============================================="
echo "                 SUMMARY"
echo "=============================================="
echo "Methods attempted: $TOTAL_CHECKS"
echo ""

# Final recommendation
print_section "Recommendations"
echo "If no user agent was found above, try these manual checks:"
echo ""
echo "1. Check if kiosk is making network requests:"
echo "   sudo tcpdump -i any -A | grep -i 'user-agent' --line-buffered"
echo ""
echo "2. Look at Chrome's verbose logs:"
echo "   sudo restart ui"
echo "   tail -f /var/log/ui/ui.LATEST | grep -i user"
echo ""
echo "3. Check the actual kiosk URL configuration:"
echo "   cat /etc/chrome_dev.conf"
echo ""
echo "4. For enterprise kiosks, check device management:"
echo "   chrome://policy (if you had access)"
echo "   /var/lib/whitelist/owner.key"
echo ""

print_section "Alternative: Deploy Detection Server"
echo "If you control the website the kiosk loads, add this JavaScript:"
echo ""
echo "<script>"
echo "  console.log('User Agent:', navigator.userAgent);"
echo "  // Or send to your server:"
echo "  fetch('/log-ua?ua=' + encodeURIComponent(navigator.userAgent));"
echo "</script>"

echo ""
echo "=============================================="
echo "Script completed!"
echo "=============================================="
