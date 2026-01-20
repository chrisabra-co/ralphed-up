#!/usr/bin/env bash
#
# Ralphed Up: Hybrid Autonomous Development System
# Combines RALPHED's autonomous bash loop with CC-Sessions' specialized agents
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${SCRIPT_DIR}/state"
LOGS_DIR="${SCRIPT_DIR}/logs"
PLANS_DIR="${SCRIPT_DIR}/plans"
AGENTS_DIR="${SCRIPT_DIR}/.claude/agents"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

IMPLEMENTATION_PLAN="${SCRIPT_DIR}/IMPLEMENTATION_PLAN.md"
AGENTS_MD="${SCRIPT_DIR}/AGENTS.md"
CURRENT_TASK="${PLANS_DIR}/current-task.md"

ITERATION_FILE="${STATE_DIR}/iteration.json"
BACKLOG_FILE="${STATE_DIR}/backlog-queue.json"
LAST_COMMIT_FILE="${STATE_DIR}/last-commit.txt"

MAX_CRITICAL_RETRIES=3
MAX_TEST_RETRIES=2

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# Utility Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_phase() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

ensure_directories() {
    mkdir -p "${STATE_DIR}"
    mkdir -p "${LOGS_DIR}/sessions"
    mkdir -p "${LOGS_DIR}/transcripts/logging"
    mkdir -p "${PLANS_DIR}"
}

get_timestamp() {
    date +"%Y-%m-%d-%H-%M-%S"
}

get_date() {
    date +"%Y-%m-%d"
}

# ============================================================================
# State Management
# ============================================================================

init_state() {
    if [[ ! -f "${ITERATION_FILE}" ]]; then
        echo '{"iteration": 0, "task_index": 0}' > "${ITERATION_FILE}"
    fi
    if [[ ! -f "${BACKLOG_FILE}" ]]; then
        echo '[]' > "${BACKLOG_FILE}"
    fi
}

get_iteration() {
    if [[ -f "${ITERATION_FILE}" ]]; then
        jq -r '.iteration' "${ITERATION_FILE}"
    else
        echo "0"
    fi
}

get_task_index() {
    if [[ -f "${ITERATION_FILE}" ]]; then
        jq -r '.task_index' "${ITERATION_FILE}"
    else
        echo "0"
    fi
}

increment_iteration() {
    local current
    current=$(get_iteration)
    local task_index
    task_index=$(get_task_index)
    echo "{\"iteration\": $((current + 1)), \"task_index\": $((task_index + 1))}" > "${ITERATION_FILE}"
}

add_to_backlog() {
    local item="$1"
    local current
    current=$(cat "${BACKLOG_FILE}")
    echo "${current}" | jq --arg item "${item}" '. + [$item]' > "${BACKLOG_FILE}"
}

process_backlog() {
    if [[ ! -f "${BACKLOG_FILE}" ]]; then
        return 0
    fi

    local items
    items=$(jq -r '.[]' "${BACKLOG_FILE}" 2>/dev/null || echo "")

    if [[ -z "${items}" ]]; then
        return 0
    fi

    log_info "Processing backlog items..."

    # Append to IMPLEMENTATION_PLAN.md Backlog section
    while IFS= read -r item; do
        if [[ -n "${item}" ]]; then
            sed -i '' "/^## Backlog$/a\\
- [ ] ${item}
" "${IMPLEMENTATION_PLAN}" 2>/dev/null || true
            log_info "  Added to backlog: ${item}"
        fi
    done <<< "${items}"

    # Clear the queue
    echo '[]' > "${BACKLOG_FILE}"
}

# ============================================================================
# Task Management
# ============================================================================

get_next_task() {
    # Find first unchecked task in IMPLEMENTATION_PLAN.md
    # Look for lines matching "- [ ] Task: description" or "- [ ] description"
    grep -n "^- \[ \]" "${IMPLEMENTATION_PLAN}" | head -1 | sed 's/^[0-9]*://; s/^- \[ \] //'
}

get_next_task_line() {
    grep -n "^- \[ \]" "${IMPLEMENTATION_PLAN}" | head -1 | cut -d: -f1
}

mark_task_complete() {
    local line_num="$1"
    if [[ -n "${line_num}" ]]; then
        sed -i '' "${line_num}s/- \[ \]/- [x]/" "${IMPLEMENTATION_PLAN}" 2>/dev/null || \
        sed -i "${line_num}s/- \[ \]/- [x]/" "${IMPLEMENTATION_PLAN}"
    fi
}

create_task_file() {
    local task_name="$1"
    local iteration
    iteration=$(get_iteration)
    local timestamp
    timestamp=$(get_timestamp)
    local date
    date=$(get_date)

    cat > "${CURRENT_TASK}" << EOF
# Task: ${task_name}

**Iteration**: ${iteration}
**Started**: ${timestamp}
**Status**: In Progress

## Description

${task_name}

## Success Criteria

- [ ] Task completed successfully
- [ ] Tests pass
- [ ] Code review passed

## Context Manifest

> This section will be populated by the Context Gathering Agent

## Implementation Notes

> Implementation decisions and notes will be added here during development

## Code Review Results

> Code review findings will be documented here

### Warnings Acknowledged
> Warnings from code review that were reviewed and accepted

### Deferred Suggestions
> Suggestions queued to backlog for future consideration

## Work Log

### ${date}

#### Completed
-

#### Decisions
-

#### Discovered
-

#### Next Steps
-
EOF
}

# ============================================================================
# Test Detection & Execution
# ============================================================================

detect_test_command() {
    # Check AGENTS.md for override
    if [[ -f "${AGENTS_MD}" ]]; then
        local override
        override=$(grep -E "^test_command:" "${AGENTS_MD}" | head -1 | sed 's/test_command://' | xargs)
        if [[ -n "${override}" && "${override}" != "echo" ]]; then
            echo "${override}"
            return
        fi
    fi

    # Auto-detect based on project files
    if [[ -f "${SCRIPT_DIR}/package.json" ]]; then
        echo "npm test"
    elif [[ -f "${SCRIPT_DIR}/pytest.ini" ]] || [[ -f "${SCRIPT_DIR}/pyproject.toml" ]]; then
        echo "pytest"
    elif [[ -f "${SCRIPT_DIR}/Cargo.toml" ]]; then
        echo "cargo test"
    elif [[ -f "${SCRIPT_DIR}/go.mod" ]]; then
        echo "go test ./..."
    elif [[ -f "${SCRIPT_DIR}/Makefile" ]]; then
        if grep -q "^test:" "${SCRIPT_DIR}/Makefile"; then
            echo "make test"
        fi
    fi

    # Default: no tests
    echo ""
}

run_tests() {
    local test_cmd
    test_cmd=$(detect_test_command)

    if [[ -z "${test_cmd}" ]]; then
        log_warning "No test command detected. Skipping tests."
        return 0
    fi

    log_info "Running tests: ${test_cmd}"
    if eval "${test_cmd}"; then
        log_success "Tests passed"
        return 0
    else
        log_error "Tests failed"
        return 1
    fi
}

# ============================================================================
# Agent Invocation
# ============================================================================

run_context_gathering() {
    log_phase "Phase 2: Context Gathering Agent"

    local task_name="$1"

    log_info "Exploring codebase for task-relevant context..."

    if claude --print \
        "@${CURRENT_TASK}" \
        "@${AGENTS_DIR}/context-gathering.md" \
        "@${AGENTS_MD}" \
        -p "Explore codebase for: ${task_name}. Write Context Manifest to task file." \
        > "${LOGS_DIR}/transcripts/logging/cga_output.txt" 2>&1; then
        log_success "Context Gathering completed"
        return 0
    else
        log_error "Context Gathering failed"
        return 1
    fi
}

run_implementation() {
    log_phase "Phase 4: Implementation"

    local task_name="$1"

    log_info "Implementing: ${task_name}"

    if claude --print \
        "@${CURRENT_TASK}" \
        "@${AGENTS_MD}" \
        -p "Implement the task described in the task file. Use the Context Manifest for guidance. Follow project conventions from AGENTS.md." \
        > "${LOGS_DIR}/transcripts/logging/impl_output.txt" 2>&1; then
        log_success "Implementation completed"
        return 0
    else
        log_error "Implementation failed"
        return 1
    fi
}

run_code_review() {
    log_phase "Phase 6: Code Review Agent"

    log_info "Reviewing changes..."

    # Get list of modified files
    local modified_files
    modified_files=$(git diff --name-only HEAD 2>/dev/null || echo "")

    local review_output="${LOGS_DIR}/transcripts/logging/review_output.txt"

    if claude --print \
        "@${CURRENT_TASK}" \
        "@${AGENTS_DIR}/code-review.md" \
        "@${AGENTS_MD}" \
        -p "Review the following changes. Files modified: ${modified_files}. Return structured review with Critical/Warning/Suggestion categories." \
        > "${review_output}" 2>&1; then

        # Check for critical issues
        if grep -q "🔴 Critical Issues (0)" "${review_output}" || \
           grep -q "## 🔴 Critical Issues (0)" "${review_output}"; then
            log_success "Code review passed (no critical issues)"
            echo "none"
            return 0
        elif grep -q "🔴 Critical" "${review_output}"; then
            log_warning "Critical issues found"
            echo "critical"
            return 1
        else
            log_success "Code review passed"
            echo "none"
            return 0
        fi
    else
        log_error "Code review failed to execute"
        echo "error"
        return 1
    fi
}

run_logging() {
    log_phase "Phase 7: Logging Agent"

    log_info "Updating work log..."

    if claude --print \
        "@${CURRENT_TASK}" \
        "@${AGENTS_DIR}/logging.md" \
        -p "Update Work Log from transcripts in logs/transcripts/logging/. Clean outdated info, consolidate entries." \
        > "${LOGS_DIR}/transcripts/logging/log_output.txt" 2>&1; then
        log_success "Work log updated"
        return 0
    else
        log_warning "Logging agent encountered issues"
        return 0  # Non-fatal
    fi
}

# ============================================================================
# Git Operations
# ============================================================================

git_commit() {
    log_phase "Phase 8: Git Commit"

    local task_name="$1"

    # Check if there are changes to commit
    if ! git diff --quiet HEAD 2>/dev/null; then
        log_info "Committing changes..."

        # Stage all changes
        git add -A

        # Create commit message
        local commit_msg="feat: ${task_name}

Iteration: $(get_iteration)

Co-Authored-By: Claude <noreply@anthropic.com>"

        if git commit -m "${commit_msg}"; then
            # Store commit SHA for rollback
            git rev-parse HEAD > "${LAST_COMMIT_FILE}"
            log_success "Changes committed"
            return 0
        else
            log_warning "Git commit failed"
            return 1
        fi
    else
        log_info "No changes to commit"
        return 0
    fi
}

# ============================================================================
# Session Archive
# ============================================================================

archive_session() {
    log_phase "Phase 9: Archive Session"

    local timestamp
    timestamp=$(get_timestamp)
    local archive_dir="${LOGS_DIR}/sessions/${timestamp}"

    mkdir -p "${archive_dir}"

    # Copy current task file
    if [[ -f "${CURRENT_TASK}" ]]; then
        cp "${CURRENT_TASK}" "${archive_dir}/task.md"
    fi

    # Copy transcripts
    if [[ -d "${LOGS_DIR}/transcripts/logging" ]]; then
        cp -r "${LOGS_DIR}/transcripts/logging/"* "${archive_dir}/" 2>/dev/null || true
    fi

    log_success "Session archived to ${archive_dir}"

    # Clear transcripts for next iteration
    rm -f "${LOGS_DIR}/transcripts/logging/"*
}

# ============================================================================
# Main Workflow
# ============================================================================

run_iteration() {
    local iteration
    iteration=$(($(get_iteration) + 1))

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           RALPHED UP ITERATION ${iteration}                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Phase 1: Load next task
    log_phase "Phase 1: Load Next Task"

    local task_name
    task_name=$(get_next_task)
    local task_line
    task_line=$(get_next_task_line)

    if [[ -z "${task_name}" ]]; then
        log_success "All tasks completed!"
        return 0
    fi

    log_info "Task: ${task_name}"
    create_task_file "${task_name}"

    # Phase 2: Context Gathering
    local cga_retries=0
    while ! run_context_gathering "${task_name}"; do
        cga_retries=$((cga_retries + 1))
        if [[ ${cga_retries} -ge 2 ]]; then
            log_error "Context Gathering failed after retries. Skipping task."
            add_to_backlog "SKIPPED: ${task_name} (CGA failed)"
            increment_iteration
            return 1
        fi
        log_warning "Retrying Context Gathering..."
    done

    # Phase 3: Generate Acceptance Criteria (auto-approved in task file)
    log_phase "Phase 3: Acceptance Criteria"
    log_info "Using criteria from task file (auto-approved)"

    # Phase 4: Implementation with test retry loop
    local impl_attempts=0
    local tests_passed=false

    while [[ ${impl_attempts} -lt ${MAX_TEST_RETRIES} ]]; do
        impl_attempts=$((impl_attempts + 1))

        if run_implementation "${task_name}"; then
            # Phase 5: Run Tests
            log_phase "Phase 5: Run Tests"

            if run_tests; then
                tests_passed=true
                break
            else
                if [[ ${impl_attempts} -lt ${MAX_TEST_RETRIES} ]]; then
                    log_warning "Retrying implementation (attempt ${impl_attempts}/${MAX_TEST_RETRIES})..."
                fi
            fi
        else
            if [[ ${impl_attempts} -lt ${MAX_TEST_RETRIES} ]]; then
                log_warning "Retrying implementation (attempt ${impl_attempts}/${MAX_TEST_RETRIES})..."
            fi
        fi
    done

    if [[ "${tests_passed}" != "true" ]]; then
        log_error "Tests failed after ${MAX_TEST_RETRIES} attempts"
    fi

    # Phase 6: Code Review with critical loop
    local review_attempts=0
    local review_result="critical"

    while [[ "${review_result}" == "critical" && ${review_attempts} -lt ${MAX_CRITICAL_RETRIES} ]]; do
        review_attempts=$((review_attempts + 1))

        review_result=$(run_code_review) || true

        if [[ "${review_result}" == "critical" ]]; then
            if [[ ${review_attempts} -lt ${MAX_CRITICAL_RETRIES} ]]; then
                log_warning "Critical issues found. Looping back to implementation (attempt ${review_attempts}/${MAX_CRITICAL_RETRIES})..."
                run_implementation "${task_name}"
            else
                log_error "Critical issues unresolved after ${MAX_CRITICAL_RETRIES} attempts"
                add_to_backlog "UNRESOLVED CRITICAL: ${task_name}"
            fi
        fi
    done

    # Phase 7: Logging
    run_logging

    # Phase 8: Git Commit + Process Backlog
    git_commit "${task_name}"
    process_backlog

    # Phase 9: Archive and Complete
    archive_session
    mark_task_complete "${task_line}"
    increment_iteration

    # Summary
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ITERATION ${iteration} COMPLETE${NC}"
    echo -e "${GREEN}  Task: ${task_name}${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}═══════════ CONTEXT CLEARED ═══════════${NC}"
    echo ""

    return 0
}

# ============================================================================
# Commands
# ============================================================================

cmd_init() {
    log_info "Initializing Ralphed Up..."

    ensure_directories
    init_state

    # Create IMPLEMENTATION_PLAN.md if missing
    if [[ ! -f "${IMPLEMENTATION_PLAN}" ]]; then
        cp "${TEMPLATES_DIR}/IMPLEMENTATION_PLAN.md" "${IMPLEMENTATION_PLAN}"
        log_info "Created IMPLEMENTATION_PLAN.md"
    fi

    # Create AGENTS.md if missing
    if [[ ! -f "${AGENTS_MD}" ]]; then
        cp "${TEMPLATES_DIR}/AGENTS.md" "${AGENTS_MD}"
        log_info "Created AGENTS.md"
    fi

    log_success "Ralphed Up initialized!"
    echo ""
    echo "Next steps:"
    echo "  1. Edit IMPLEMENTATION_PLAN.md to add your tasks"
    echo "  2. Edit AGENTS.md to configure project conventions"
    echo "  3. Run: ./ralph-sessions.sh single"
}

cmd_status() {
    ensure_directories
    init_state

    local iteration
    iteration=$(get_iteration)
    local next_task
    next_task=$(get_next_task)

    echo ""
    echo -e "${CYAN}Ralphed Up Status${NC}"
    echo "═══════════════════════════════════════"
    echo ""
    echo "Iteration: ${iteration}"
    echo ""

    if [[ -n "${next_task}" ]]; then
        echo "Next Task: ${next_task}"
    else
        echo "Next Task: None (all tasks complete)"
    fi

    echo ""

    # Count tasks
    local total
    total=$(grep -c "^- \[" "${IMPLEMENTATION_PLAN}" 2>/dev/null) || total=0
    local completed
    completed=$(grep -c "^- \[x\]" "${IMPLEMENTATION_PLAN}" 2>/dev/null) || completed=0
    local remaining=$((total - completed))

    echo "Progress: ${completed}/${total} tasks complete"
    echo "Remaining: ${remaining}"
    echo ""
}

cmd_single() {
    ensure_directories
    init_state
    run_iteration
}

cmd_run() {
    local count="${1:-1}"

    ensure_directories
    init_state

    for ((i=1; i<=count; i++)); do
        log_info "Starting iteration ${i} of ${count}..."

        if ! run_iteration; then
            log_warning "Iteration ${i} had issues"
        fi

        # Check if all tasks complete
        local next_task
        next_task=$(get_next_task)
        if [[ -z "${next_task}" ]]; then
            log_success "All tasks completed!"
            break
        fi
    done
}

cmd_help() {
    echo ""
    echo "Ralphed Up: Hybrid Autonomous Development System"
    echo ""
    echo "Usage: ./ralphed-up.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  init          Initialize directory structure and state"
    echo "  status        Show current state and next task"
    echo "  single        Run a single iteration"
    echo "  run [n]       Run n iterations (default: 1)"
    echo "  help          Show this help message"
    echo ""
    echo "Workflow per iteration:"
    echo "  1. Load next unchecked task from IMPLEMENTATION_PLAN.md"
    echo "  2. Context Gathering Agent explores codebase"
    echo "  3. Generate acceptance criteria"
    echo "  4. Implementation phase"
    echo "  5. Run tests (retry once on failure)"
    echo "  6. Code Review Agent (loop for critical issues)"
    echo "  7. Logging Agent updates Work Log"
    echo "  8. Git commit + process backlog"
    echo "  9. Archive session, clear context"
    echo ""
}

# ============================================================================
# Entry Point
# ============================================================================

main() {
    local cmd="${1:-help}"
    shift || true

    case "${cmd}" in
        init)
            cmd_init
            ;;
        status)
            cmd_status
            ;;
        single)
            cmd_single
            ;;
        run)
            cmd_run "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            log_error "Unknown command: ${cmd}"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
