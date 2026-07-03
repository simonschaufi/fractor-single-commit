#!/bin/bash

# Create single commits for all fractor rules
# Needs:
# - git
# - jq
# - fractor (in vendor/bin or FRACTOR_PATH)

set -e

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PURPLE='\033[35m'
CYAN='\033[36m'
NC='\033[0m' # No Color

dryRun=false
commitMessagePrefix="[TASK] "

# Parse parameters
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "fractor-single-commit.sh [options] [commit message prefix]"
            echo "Options:"
            echo "  -h, --help     Show help"
            echo "  -n, --dry-run  Show changes without committing"
            exit 0
            ;;
        -n|--dry-run)
            dryRun=true
            shift
            ;;
        *)
            commitMessagePrefix="$1"
            shift
            ;;
    esac
done

commitMessagePrefix="${1:-[TASK] }"

messagesDirName="fractor-messages"
messagesDir="$(pwd)/$messagesDirName"
fractorPath=${FRACTOR_PATH:-./vendor/bin/fractor}
fractorConfigPath=${FRACTOR_CONFIG_PATH:-./fractor.php}
stashedChanges=false
stashedRef=""

# Validation helper
validate_exec() {
    if [ ! -x "$1" ]; then
        echo -e "${RED}Executable not found: $1${NC}" >&2
        exit 1
    fi
}

validate_exec "$fractorPath"

if ! command -v jq > /dev/null 2>&1; then
    echo -e "${RED}jq executable not found${NC}" >&2
    exit 1
fi

if [ ! -f "$fractorConfigPath" ]; then
    echo -e "${RED}Fractor configuration file missing: $fractorConfigPath${NC}" >&2
    exit 1
fi

prompt_to_stash_changes() {
    local answer

    while true; do
        echo ""
        printf " ${YELLOW}Git repository is dirty. Stash changes before continuing (yes/no)${NC} [${YELLOW}NO${NC}]:\n > "
        read -r answer

        case "${answer,,}" in
            y|yes)
                return 0
                ;;
            ""|n|no)
                return 1
                ;;
            *)
                echo -e "${YELLOW}Please enter y or n${NC}"
                ;;
        esac
    done
}

restore_stash() {
    if [ "$stashedChanges" != true ]; then
        return 0
    fi

    echo ""
    echo -e "${CYAN}Restoring stashed changes...${NC}"
    if git stash pop --index "$stashedRef" > /dev/null; then
        echo -e "${GREEN}Restored stashed changes${NC}"
        stashedChanges=false
        return 0
    fi

    echo -e "${RED}Failed to restore stashed changes from $stashedRef${NC}" >&2
    echo -e "${YELLOW}Restore them manually with: git stash pop --index $stashedRef${NC}" >&2
    return 1
}

restore_stash_on_exit() {
    local exitCode=$?
    trap - EXIT

    if [ "$exitCode" -ne 0 ] && [ "$stashedChanges" = true ]; then
        if ! restore_stash; then
            exitCode=1
        fi
    fi

    exit "$exitCode"
}

ensure_messages_dir() {
    local gitExcludeFile

    if [ -d "$messagesDir" ]; then
        return 0
    fi

    if [ -e "$messagesDir" ]; then
        echo -e "${RED}$messagesDir exists but is not a directory${NC}" >&2
        exit 1
    fi

    echo -e "${CYAN}Cloning fractor commit messages repository...${NC}"
    git clone git@github.com:simonschaufi/fractor-messages.git "$messagesDir" --quiet

    gitExcludeFile=$(git rev-parse --git-path info/exclude)
    touch "$gitExcludeFile"
    if ! grep -Fxq "/$messagesDirName/" "$gitExcludeFile"; then
        echo "/$messagesDirName/" >> "$gitExcludeFile"
    fi
}

trap restore_stash_on_exit EXIT

#if [ -n "$(git status --porcelain)" ]; then
if ! git diff-index --quiet HEAD --; then
    if ! prompt_to_stash_changes; then
        echo -e "${RED}Git repository is dirty. Commit or stash changes first.${NC}" >&2
        exit 2
    fi

    stashMessage="fractor-single-commit-$(date +%s)-$$"
    git stash push --include-untracked --message "$stashMessage" > /dev/null
    stashedRef="stash@{0}"

    if ! git rev-parse --verify "${stashedRef}^{commit}" > /dev/null 2>&1; then
        echo -e "${RED}Failed to determine stash reference for existing changes${NC}" >&2
        exit 1
    fi

    stashedChanges=true
    echo -e "${GREEN}Stashed existing changes in $stashedRef${NC}"
fi

# Convert rule name to file path (backslashes become directory separators)
# e.g., Fractor\CodeQuality\Fractor\BooleanAnd\SomeFractor -> Fractor/CodeQuality/Fractor/BooleanAnd/SomeFractor.txt
rule_to_filepath() {
    local rule="$1"
    echo "$messagesDir/$(echo "$rule" | tr '\\' '/').txt"
}

# Get info URL for a rule
get_rule_info_url() {
    local rule="$1"
    if [[ "$rule" == Fractor* ]]; then
        echo "https://getrector.com/find-rule?query=$(echo "$rule" | sed 's/^.*\\//')"
    fi
}

# Prompt user for commit message
prompt_for_commit_message() {
    local rule="$1"
    local messageFilePath="$2"
    local infoUrl

    echo ""
    print_separator
    echo -e "${YELLOW}Missing commit message for rule: ${NC}"
    echo "  $rule"

    infoUrl=$(get_rule_info_url "$rule")
    if [ -n "$infoUrl" ]; then
        echo -e "  ${BLUE}Info:  $infoUrl${NC}"
    fi
    echo -e "  ${BLUE}File: $messageFilePath${NC}"
    print_separator
    echo ""
    echo -e "Enter commit message (single line, or empty to abort):"
    read -r commitMessage

    if [ -z "$commitMessage" ]; then
        echo -e "${RED}Aborted:  No commit message provided${NC}" >&2
        exit 3
    fi

    # Create directory structure if needed
    mkdir -p "$(dirname "$messageFilePath")"

    # Write the commit message to file
    echo "$commitMessage" > "$messageFilePath"
    echo -e "${GREEN}Saved commit message to: $messageFilePath${NC}"
}

# Ask whether a rule should be applied after showing its dry-run output
prompt_to_apply_rule() {
    local rule="$1"
    local answer

    while true; do
        echo ""
        printf " ${GREEN}Apply this change for %s (y/n)${NC} [${YELLOW}Y${NC}]:\n > " "$rule"
        read -r answer

        case "${answer,,}" in
            ""|y)
                return 0
                ;;
            n)
                return 1
                ;;
            *)
                echo -e "${YELLOW}Please press Enter or enter y or n${NC}"
                ;;
        esac
    done
}

# Print a styled block (Symfony console style)
# Usage: print_block <type> <message>
# Types: success, error, warning, note, info, caution
print_block() {
    local type="$1"
    local message="$2"
    local prefix=" "

    local style
    local label

    case "$type" in
        success)
            style='\033[30;42m'  # Black text on green background
            label="OK"
            ;;
        error)
            style='\033[97;41m'  # White text on red background
            label="ERROR"
            ;;
        warning)
            style='\033[30;43m'  # Black text on yellow background
            label="WARNING"
            ;;
        note)
            style='\033[33m'     # Yellow text
            label="NOTE"
            prefix=" !  "
            ;;
        info)
            style='\033[30;42m'  # Black text on green background
            label="INFO"
            ;;
        caution)
            style='\033[97;41m'  # White text on red background
            label="CAUTION"
            prefix=" !  "
            ;;
        separator)
            style='\033[36m'     # Cyan text
            label=""
            prefix=""
            ;;
        *)
            echo "Unknown block type: $type" >&2
            return 1
            ;;
    esac

    local reset='\033[0m'

    # Get terminal width, default to 120, cap at 120 (like Symfony's MAX_LINE_LENGTH)
    local termWidth
    termWidth=$(tput cols 2>/dev/null || echo 120)
    local lineLength=$((termWidth < 120 ? termWidth : 120))

    # Handle separator differently (single line of characters)
    if [ "$type" = "separator" ]; then
        local separatorLine
        printf -v separatorLine "%-${lineLength}s" ""
        separatorLine="${separatorLine// /━}"
        echo -e "${style}${separatorLine}${reset}"
        return
    fi

    # Calculate components
    local typePrefix="[${label}] "
    local indentLength=${#typePrefix}
    local lineIndentation
    printf -v lineIndentation "%${indentLength}s" ""

    # Build the three lines (padding line, message line, padding line)
    local emptyLine="${prefix}${lineIndentation}"
    local messageLine="${prefix}${typePrefix}${message}"

    # Pad all lines to full width
    local emptyLinePadded
    local messageLinePadded
    printf -v emptyLinePadded "%-${lineLength}s" "$emptyLine"
    printf -v messageLinePadded "%-${lineLength}s" "$messageLine"

    echo ""
    echo -e "${style}${emptyLinePadded}${reset}"
    echo -e "${style}${messageLinePadded}${reset}"
    echo -e "${style}${emptyLinePadded}${reset}"
    echo ""
}

# Convenience functions
print_success() {
    print_block "success" "$1"
}

print_error() {
    print_block "error" "$1"
}

print_warning() {
    print_block "warning" "$1"
}

print_note() {
    print_block "note" "$1"
}

print_info() {
    print_block "info" "$1"
}

print_caution() {
    print_block "caution" "$1"
}

print_separator() {
    print_block "separator"
}

# Usage
#print_success "Fractor is done"
#print_error "Something went wrong"
#print_warning "This might cause issues"
#print_note "Remember to commit your changes"
#print_info "Processing 42 files"
#print_caution "This will delete all files!"

# Or use the generic function directly
#print_block "success" "Custom message here"

print_warning "Running Fractor analysis... This may take a while."

# Get rules into an array
mapfile -t rulesArray < <("$fractorPath" process --config="$fractorConfigPath" --dry-run --clear-cache --output-format=json \
    | jq -r '.file_diffs[]?.applied_rules[]' \
    | sort \
    | uniq)

numRules=${#rulesArray[@]}

if [ "$numRules" -eq 0 ]; then
    print_success "Nothing to do"
    exit
fi

ruleWord=$([ "$numRules" -eq 1 ] && echo "rule" || echo "rules")
echo -e "${PURPLE}Fractor wants to apply $numRules $ruleWord to the code${NC}"

ensure_messages_dir

# Phase 1: Check all commit message files and prompt for missing ones
echo ""
echo -e "${CYAN}Phase 1: Checking commit message files...${NC}"

missingMessages=()
for rule in "${rulesArray[@]}"; do
    messageFilePath=$(rule_to_filepath "$rule")

    if [ ! -f "$messageFilePath" ]; then
        missingMessages+=("$rule")
    fi
done

if [ ${#missingMessages[@]} -gt 0 ]; then
    echo -e "${YELLOW}Found ${#missingMessages[@]} missing commit message file(s)${NC}"

    for rule in "${missingMessages[@]}"; do
        messageFilePath=$(rule_to_filepath "$rule")
        prompt_for_commit_message "$rule" "$messageFilePath"
    done

    print_success "All commit messages collected"
else
    print_success "All commit message files exist"
fi

# Phase 2: Apply rules and create commits
echo ""
echo -e "${CYAN}Phase 2: Applying rules and creating commits...${NC}"

for rule in "${rulesArray[@]}"; do
    if [ "$dryRun" = true ]; then
        printf "${YELLOW}Would apply rule: %s${NC}\n" "$rule"
        continue
    fi

    printf "${YELLOW}Previewing rule: %s${NC}\n" "$rule"

    set +e
    "$fractorPath" process --config="$fractorConfigPath" --dry-run --clear-cache --ansi --only="$rule"
    dryRunStatus=$?
    set -e

    if [ "$dryRunStatus" -eq 0 ]; then
        printf "${YELLOW}WARN: No code changes for %s${NC}\n" "$rule"
        continue
    fi

    if ! prompt_to_apply_rule "$rule"; then
        printf "${YELLOW}Skipping rule: %s${NC}\n" "$rule"
        continue
    fi

    printf "${YELLOW}Applying rule: %s${NC}\n" "$rule"

    # Process individual rule
    "$fractorPath" process --config="$fractorConfigPath" --clear-cache --no-progress-bar --no-diffs --only="$rule"

    # Check if changes happened
    if git diff --quiet; then
        printf "${YELLOW}WARN: No code changes for %s${NC}\n" "$rule"
        continue
    fi

	# Normalize composer.json files after modifications
    git status --porcelain=v1 | \
        grep 'composer\.json$' | \
        awk '{print $2}' | \
        while IFS= read -r file_path; do
            composer normalize --no-check-lock --no-update-lock --no-scripts "$file_path"
            if [ $? -ne 0 ]; then
            	echo -e "\033[31mError after running composer normalize for file $file_path\033[0m" >&2
                exit 1
            fi
        done

    # Build commit message
    messageFilePath=$(rule_to_filepath "$rule")
    messageFileContents=$(<"$messageFilePath")

    commitMessage=$(cat <<EOF
${commitMessagePrefix}${messageFileContents}

Applied rule:
${rule}
EOF
)

    git add .
    git commit \
        --all \
        --message="$commitMessage" \
        --quiet

    echo ""
done

if ! restore_stash; then
    trap - EXIT
    exit 1
fi

trap - EXIT
print_success "Fractor is done"
