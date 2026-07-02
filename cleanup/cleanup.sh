#!/usr/bin/env bash
# cleanup.sh — Developer disk cleanup for macOS
# Usage:
#   ./cleanup.sh              Interactive mode (confirms each category)
#   ./cleanup.sh --dry-run    Show what would be cleaned, don't delete anything
#   ./cleanup.sh --all        Clean everything without prompting
#   ./cleanup.sh --report     Only show disk usage report, no cleaning

set -uo pipefail

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

MODE="interactive"
[[ "${1:-}" == "--dry-run" ]] && MODE="dry-run"
[[ "${1:-}" == "--all" ]] && MODE="all"
[[ "${1:-}" == "--report" ]] && MODE="report"

PROJECTS_DIR="$HOME/Desktop/github"
TOTAL_FREED=0

# ── Helpers ─────────────────────────────────────────────────────────
human_size() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        printf "%.1fG" "$(echo "scale=1; $bytes / 1073741824" | bc)"
    elif (( bytes >= 1048576 )); then
        printf "%.0fM" "$(echo "scale=0; $bytes / 1048576" | bc)"
    elif (( bytes >= 1024 )); then
        printf "%.0fK" "$(echo "scale=0; $bytes / 1024" | bc)"
    else
        printf "%dB" "$bytes"
    fi
}

dir_size_bytes() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sk "$dir" 2>/dev/null | awk '{print $1 * 1024}' || echo 0
    else
        echo 0
    fi
}

dir_size_human() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sh "$dir" 2>/dev/null | awk '{print $1}' || echo "0B"
    else
        echo "0B"
    fi
}

confirm() {
    local prompt="$1"
    if [[ "$MODE" == "all" ]]; then return 0; fi
    if [[ "$MODE" == "dry-run" || "$MODE" == "report" ]]; then return 1; fi
    printf "${YELLOW}  → %s [y/N] ${RESET}" "$prompt"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

track_freed() {
    local before=$1 after=$2
    local freed=$(( before - after ))
    if (( freed > 0 )); then
        TOTAL_FREED=$(( TOTAL_FREED + freed ))
        printf "${GREEN}    Freed: %s${RESET}\n" "$(human_size $freed)"
    fi
}

section() {
    printf "\n${BOLD}${CYAN}━━━ %s ━━━${RESET}\n" "$1"
}

# ── Disk Overview ───────────────────────────────────────────────────
print_disk_overview() {
    section "DISK OVERVIEW"
    local disk_info
    disk_info=$(df -h / | tail -1)
    local total used avail pct
    total=$(echo "$disk_info" | awk '{print $2}')
    used=$(echo "$disk_info" | awk '{print $3}')
    avail=$(echo "$disk_info" | awk '{print $4}')
    pct=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')

    printf "  Total: ${BOLD}%s${RESET}  Used: ${BOLD}%s${RESET}  Free: " "$total" "$used"
    if (( pct > 90 )); then
        printf "${RED}${BOLD}%s (%s%% used)${RESET}\n" "$avail" "$pct"
    elif (( pct > 75 )); then
        printf "${YELLOW}${BOLD}%s (%s%% used)${RESET}\n" "$avail" "$pct"
    else
        printf "${GREEN}${BOLD}%s (%s%% used)${RESET}\n" "$avail" "$pct"
    fi

    # Visual bar
    local bar_width=50
    local filled=$(( pct * bar_width / 100 ))
    local empty=$(( bar_width - filled ))
    printf "  ["
    local color="$GREEN"
    (( pct > 75 )) && color="$YELLOW"
    (( pct > 90 )) && color="$RED"
    printf "%s" "$color"
    printf '%0.s█' $(seq 1 $filled)
    printf "${DIM}"
    (( empty > 0 )) && printf '%0.s░' $(seq 1 $empty)
    printf "${RESET}]\n"
}

# ── Space Hogs Report ──────────────────────────────────────────────
print_space_report() {
    section "BIGGEST SPACE CONSUMERS"

    declare -a entries=()

    # Developer caches
    for dir in \
        "$HOME/Library/Caches" \
        "$HOME/Library/Application Support" \
        "$HOME/Library/Developer" \
        "$HOME/Library/Logs" \
        "$HOME/.npm" \
        "$HOME/.yarn" \
        "$HOME/.cache" \
        "$HOME/.cargo" \
        "$HOME/.rustup" \
        "$HOME/.docker" \
        "$HOME/.claude" \
        "$HOME/go" \
        "$HOME/Library/pnpm" \
        "/opt/homebrew" \
    ; do
        if [ -d "$dir" ]; then
            local size
            size=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
            [[ -z "$size" ]] && continue
            (( size > 1024 )) && entries+=("${size}|${dir}")
        fi
    done

    # Sort and display
    printf '%s\n' "${entries[@]}" | sort -t'|' -k1 -nr | while IFS='|' read -r kb path; do
        local bytes=$(( kb * 1024 ))
        local h
        h=$(human_size $bytes)
        local short="${path/#$HOME/~}"
        if (( kb > 1048576 )); then
            printf "  ${RED}%8s${RESET}  %s\n" "$h" "$short"
        elif (( kb > 102400 )); then
            printf "  ${YELLOW}%8s${RESET}  %s\n" "$h" "$short"
        else
            printf "  ${DIM}%8s${RESET}  %s\n" "$h" "$short"
        fi
    done

    # node_modules
    section "NODE_MODULES IN PROJECTS"
    local total_nm=0
    while IFS= read -r dir; do
        local size
        size=$(du -sk "$dir" 2>/dev/null | awk '{print $1}') || continue
        (( size < 1024 )) && continue
        total_nm=$(( total_nm + size ))
        local h
        h=$(human_size $(( size * 1024 )))
        local short="${dir/#$PROJECTS_DIR\//}"
        printf "  %8s  %s\n" "$h" "$short"
    done < <(find "$PROJECTS_DIR" -maxdepth 4 -name "node_modules" -type d 2>/dev/null)
    printf "  ${BOLD}%8s  TOTAL${RESET}\n" "$(human_size $(( total_nm * 1024 )))"

    # Rust target dirs
    section "RUST BUILD ARTIFACTS (target/)"
    local total_target=0
    while IFS= read -r dir; do
        local size
        size=$(du -sk "$dir" 2>/dev/null | awk '{print $1}') || continue
        (( size < 1024 )) && continue
        total_target=$(( total_target + size ))
        local h
        h=$(human_size $(( size * 1024 )))
        local short="${dir/#$PROJECTS_DIR\//}"
        printf "  %8s  %s\n" "$h" "$short"
    done < <(find "$PROJECTS_DIR" -maxdepth 4 -name "target" -type d 2>/dev/null)
    printf "  ${BOLD}%8s  TOTAL${RESET}\n" "$(human_size $(( total_target * 1024 )))"

    # Library/Caches breakdown
    section "LIBRARY/CACHES BREAKDOWN (top 10)"
    du -sk "$HOME/Library/Caches"/*/ 2>/dev/null | sort -nr | head -10 | while read -r kb path; do
        (( kb < 1024 )) && continue
        local h
        h=$(human_size $(( kb * 1024 )))
        local name
        name=$(basename "$path")
        printf "  %8s  %s\n" "$h" "$name"
    done
}

# ── Cleaning Functions ─────────────────────────────────────────────

clean_homebrew() {
    section "HOMEBREW"
    if ! command -v brew &>/dev/null; then
        printf "  ${DIM}Not installed, skipping${RESET}\n"
        return
    fi
    local cache_dir
    cache_dir=$(brew --cache 2>/dev/null)
    printf "  Cache: %s\n" "$(dir_size_human "$cache_dir")"
    if confirm "Clean Homebrew cache?"; then
        local before
        before=$(dir_size_bytes "$cache_dir")
        brew cleanup --prune=all -s 2>/dev/null
        rm -rf "$cache_dir"/*.incomplete 2>/dev/null
        local after
        after=$(dir_size_bytes "$cache_dir")
        track_freed $before $after
    fi
}

clean_npm() {
    section "NPM CACHE"
    if ! command -v npm &>/dev/null; then
        printf "  ${DIM}Not installed, skipping${RESET}\n"
        return
    fi
    printf "  Cache: %s\n" "$(dir_size_human "$HOME/.npm")"
    if confirm "Clean npm cache?"; then
        local before
        before=$(dir_size_bytes "$HOME/.npm")
        npm cache clean --force 2>/dev/null
        local after
        after=$(dir_size_bytes "$HOME/.npm")
        track_freed $before $after
    fi
}

clean_yarn() {
    section "YARN CACHE"
    if ! command -v yarn &>/dev/null; then
        printf "  ${DIM}Not installed, skipping${RESET}\n"
        return
    fi
    local yarn_cache
    yarn_cache=$(yarn cache dir 2>/dev/null) || yarn_cache="$HOME/.yarn/cache"
    printf "  Cache: %s\n" "$(dir_size_human "$yarn_cache")"
    if confirm "Clean Yarn cache?"; then
        local before
        before=$(dir_size_bytes "$yarn_cache")
        yarn cache clean 2>/dev/null
        local after
        after=$(dir_size_bytes "$yarn_cache")
        track_freed $before $after
    fi
}

clean_pnpm() {
    section "PNPM STORE"
    if ! command -v pnpm &>/dev/null; then
        printf "  ${DIM}Not installed, skipping${RESET}\n"
        return
    fi
    local pnpm_dir="$HOME/Library/pnpm"
    local pnpm_cache="$HOME/Library/Caches/pnpm"
    printf "  Store: %s\n" "$(dir_size_human "$pnpm_dir")"
    printf "  Cache: %s\n" "$(dir_size_human "$pnpm_cache")"
    if confirm "Clean pnpm store and cache?"; then
        local before
        before=$(( $(dir_size_bytes "$pnpm_dir") + $(dir_size_bytes "$pnpm_cache") ))
        pnpm store prune 2>/dev/null
        rm -rf "$pnpm_cache" 2>/dev/null
        local after
        after=$(( $(dir_size_bytes "$pnpm_dir") + $(dir_size_bytes "$pnpm_cache") ))
        track_freed $before $after
    fi
}

clean_pip() {
    section "PIP CACHE"
    if ! command -v pip3 &>/dev/null; then
        printf "  ${DIM}Not installed, skipping${RESET}\n"
        return
    fi
    local pip_cache="$HOME/Library/Caches/pip"
    printf "  Cache: %s\n" "$(dir_size_human "$pip_cache")"
    if confirm "Clean pip cache?"; then
        local before
        before=$(dir_size_bytes "$pip_cache")
        pip3 cache purge 2>/dev/null
        local after
        after=$(dir_size_bytes "$pip_cache")
        track_freed $before $after
    fi
}

clean_go() {
    section "GO CACHE"
    if ! command -v go &>/dev/null; then
        printf "  ${DIM}Not installed, skipping${RESET}\n"
        return
    fi
    local go_cache="$HOME/Library/Caches/go-build"
    local go_mod="$HOME/go/pkg/mod"
    printf "  Build cache: %s\n" "$(dir_size_human "$go_cache")"
    printf "  Module cache: %s\n" "$(dir_size_human "$go_mod")"
    if confirm "Clean Go build cache?"; then
        local before
        before=$(dir_size_bytes "$go_cache")
        go clean -cache 2>/dev/null
        local after
        after=$(dir_size_bytes "$go_cache")
        track_freed $before $after
    fi
    if confirm "Clean Go module cache? (will need to re-download on next build)"; then
        local before
        before=$(dir_size_bytes "$go_mod")
        go clean -modcache 2>/dev/null
        local after
        after=$(dir_size_bytes "$go_mod")
        track_freed $before $after
    fi
}

clean_cargo() {
    section "CARGO / RUST"
    if ! command -v cargo &>/dev/null; then
        printf "  ${DIM}Not installed, skipping${RESET}\n"
        return
    fi
    printf "  Registry: %s\n" "$(dir_size_human "$HOME/.cargo/registry")"
    if confirm "Clean Cargo registry cache?"; then
        local before
        before=$(dir_size_bytes "$HOME/.cargo/registry")
        rm -rf "$HOME/.cargo/registry/cache" 2>/dev/null
        rm -rf "$HOME/.cargo/registry/src" 2>/dev/null
        local after
        after=$(dir_size_bytes "$HOME/.cargo/registry")
        track_freed $before $after
    fi
}

clean_rust_targets() {
    section "RUST BUILD ARTIFACTS (target/ in projects)"
    local total=0
    local targets=()
    while IFS= read -r dir; do
        local size
        size=$(du -sk "$dir" 2>/dev/null | awk '{print $1}') || continue
        (( size < 1024 )) && continue
        total=$(( total + size ))
        targets+=("$dir")
    done < <(find "$PROJECTS_DIR" -maxdepth 4 -name "target" -type d 2>/dev/null)

    if (( ${#targets[@]} == 0 )); then
        printf "  ${DIM}No target/ directories found${RESET}\n"
        return
    fi

    printf "  Found %d target/ dirs totaling %s\n" "${#targets[@]}" "$(human_size $(( total * 1024 )))"
    if confirm "Delete all Rust target/ directories?"; then
        local before=$(( total * 1024 ))
        for dir in "${targets[@]}"; do
            rm -rf "$dir"
        done
        TOTAL_FREED=$(( TOTAL_FREED + before ))
        printf "${GREEN}    Freed: %s${RESET}\n" "$(human_size $before)"
    fi
}

clean_node_modules() {
    section "NODE_MODULES IN PROJECTS"
    local total=0
    local dirs=()
    while IFS= read -r dir; do
        local size
        size=$(du -sk "$dir" 2>/dev/null | awk '{print $1}') || continue
        (( size < 1024 )) && continue
        total=$(( total + size ))
        dirs+=("$dir")
    done < <(find "$PROJECTS_DIR" -maxdepth 4 -name "node_modules" -type d 2>/dev/null)

    if (( ${#dirs[@]} == 0 )); then
        printf "  ${DIM}No node_modules found${RESET}\n"
        return
    fi

    printf "  Found %d node_modules dirs totaling %s\n" "${#dirs[@]}" "$(human_size $(( total * 1024 )))"
    printf "  ${DIM}(You can re-install with npm/yarn/pnpm install in each project)${RESET}\n"
    if confirm "Delete all node_modules directories?"; then
        local before=$(( total * 1024 ))
        for dir in "${dirs[@]}"; do
            rm -rf "$dir"
        done
        TOTAL_FREED=$(( TOTAL_FREED + before ))
        printf "${GREEN}    Freed: %s${RESET}\n" "$(human_size $before)"
    fi
}

clean_docker() {
    section "DOCKER"
    if ! command -v docker &>/dev/null; then
        printf "  ${DIM}Not installed, skipping${RESET}\n"
        return
    fi
    if ! docker info &>/dev/null; then
        printf "  ${DIM}Docker not running, skipping${RESET}\n"
        return
    fi
    docker system df 2>/dev/null
    if confirm "Run docker system prune (dangling images, stopped containers, unused networks)?"; then
        docker system prune -f 2>/dev/null
    fi
    if confirm "Also remove unused Docker volumes? (DATA LOSS if volumes have state)"; then
        docker volume prune -f 2>/dev/null
    fi
}

clean_system_caches() {
    section "SYSTEM CACHES"
    local logs_dir="$HOME/Library/Logs"
    printf "  Logs: %s\n" "$(dir_size_human "$logs_dir")"
    if confirm "Clean user log files?"; then
        local before
        before=$(dir_size_bytes "$logs_dir")
        find "$logs_dir" -type f -mtime +7 -delete 2>/dev/null
        local after
        after=$(dir_size_bytes "$logs_dir")
        track_freed $before $after
    fi

    local dns_cache_note=""
    if confirm "Flush DNS cache?"; then
        sudo dscacheutil -flushcache 2>/dev/null && sudo killall -HUP mDNSResponder 2>/dev/null
        printf "${GREEN}    DNS cache flushed${RESET}\n"
    fi
}

clean_app_caches() {
    section "APPLICATION CACHES (Library/Caches)"
    printf "  Total: %s\n" "$(dir_size_human "$HOME/Library/Caches")"
    printf "  ${DIM}Top consumers:${RESET}\n"
    du -sk "$HOME/Library/Caches"/*/ 2>/dev/null | sort -nr | head -5 | while read -r kb path; do
        printf "    %8s  %s\n" "$(human_size $(( kb * 1024 )))" "$(basename "$path")"
    done

    if confirm "Clear safe application caches (Spotify, browser caches, build caches)?"; then
        local before
        before=$(dir_size_bytes "$HOME/Library/Caches")
        # Only clear known-safe caches, not all of Library/Caches
        for dir in \
            "$HOME/Library/Caches/com.spotify.client" \
            "$HOME/Library/Caches/Google" \
            "$HOME/Library/Caches/com.duckduckgo.macos.browser" \
            "$HOME/Library/Caches/com.apple.python" \
            "$HOME/Library/Caches/JetBrains" \
            "$HOME/Library/Caches/ms-playwright" \
            "$HOME/Library/Caches/com.operasoftware.OperaGX" \
        ; do
            rm -rf "$dir" 2>/dev/null
        done
        local after
        after=$(dir_size_bytes "$HOME/Library/Caches")
        track_freed $before $after
    fi
}

clean_misc() {
    section "MISCELLANEOUS"

    # Python __pycache__
    local pycache_count
    pycache_count=$(find "$PROJECTS_DIR" -maxdepth 5 -name "__pycache__" -type d 2>/dev/null | wc -l | tr -d ' ')
    if (( pycache_count > 0 )); then
        printf "  Found %s __pycache__ directories\n" "$pycache_count"
        if confirm "Delete all __pycache__ directories?"; then
            find "$PROJECTS_DIR" -maxdepth 5 -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null
            printf "${GREEN}    Cleaned${RESET}\n"
        fi
    fi

    # .pyc files
    local pyc_count
    pyc_count=$(find "$PROJECTS_DIR" -maxdepth 5 -name "*.pyc" -type f 2>/dev/null | wc -l | tr -d ' ')
    if (( pyc_count > 0 )); then
        printf "  Found %s .pyc files\n" "$pyc_count"
        if confirm "Delete all .pyc files?"; then
            find "$PROJECTS_DIR" -maxdepth 5 -name "*.pyc" -type f -delete 2>/dev/null
            printf "${GREEN}    Cleaned${RESET}\n"
        fi
    fi

    # .DS_Store
    local ds_count
    ds_count=$(find "$PROJECTS_DIR" -maxdepth 5 -name ".DS_Store" -type f 2>/dev/null | wc -l | tr -d ' ')
    if (( ds_count > 0 )); then
        printf "  Found %s .DS_Store files\n" "$ds_count"
        if confirm "Delete all .DS_Store files?"; then
            find "$PROJECTS_DIR" -maxdepth 5 -name ".DS_Store" -type f -delete 2>/dev/null
            printf "${GREEN}    Cleaned${RESET}\n"
        fi
    fi

    # Trash
    local trash_size
    trash_size=$(dir_size_human "$HOME/.Trash")
    if [ -d "$HOME/.Trash" ] && [ "$(ls -A "$HOME/.Trash" 2>/dev/null)" ]; then
        printf "  Trash: %s\n" "$trash_size"
        if confirm "Empty Trash?"; then
            local before
            before=$(dir_size_bytes "$HOME/.Trash")
            rm -rf "$HOME/.Trash"/* 2>/dev/null
            local after
            after=$(dir_size_bytes "$HOME/.Trash")
            track_freed $before $after
        fi
    fi
}

# ── Main ────────────────────────────────────────────────────────────
printf "${BOLD}${BLUE}"
printf '╔══════════════════════════════════════╗\n'
printf '║     macOS Developer Disk Cleanup     ║\n'
printf '╚══════════════════════════════════════╝\n'
printf "${RESET}"
printf "  Mode: ${BOLD}%s${RESET}\n" "$MODE"

print_disk_overview

if [[ "$MODE" == "report" ]]; then
    print_space_report
    printf "\n${DIM}  Run without --report to clean up.${RESET}\n\n"
    exit 0
fi

print_space_report

printf "\n${BOLD}Starting cleanup...${RESET}\n"

if [[ "$MODE" == "dry-run" ]]; then
    printf "${YELLOW}  DRY RUN: showing what would be cleaned, not deleting anything${RESET}\n"
fi

clean_homebrew
clean_npm
clean_yarn
clean_pnpm
clean_pip
clean_go
clean_cargo
clean_rust_targets
clean_node_modules
clean_docker
clean_app_caches
clean_system_caches
clean_misc

# ── Summary ─────────────────────────────────────────────────────────
section "SUMMARY"
print_disk_overview

if (( TOTAL_FREED > 0 )); then
    printf "\n  ${GREEN}${BOLD}Total freed: %s${RESET}\n" "$(human_size $TOTAL_FREED)"
else
    printf "\n  ${DIM}No space freed this run.${RESET}\n"
fi
printf "\n"
