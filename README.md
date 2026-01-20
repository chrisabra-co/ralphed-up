# Ralphed Up

A hybrid autonomous development system combining the [Ralph Wiggum Method](https://ghuntley.com/ralph)'s autonomous bash loop with [CC-Sessions](https://github.com/GWUDCAP/cc-sessions)' specialized agents for structured, self-correcting development workflows.

## Credits

This project builds on ideas from:

- **[Ralph Wiggum Method](https://ghuntley.com/ralph)** by Geoffrey Huntley - The autonomous bash loop pattern with fresh context per iteration
- **[How to Ralph Wiggum](https://github.com/ghuntley/how-to-ralph-wiggum)** - Official methodology and implementation guide
- **[CC-Sessions](https://github.com/GWUDCAP/cc-sessions)** - Specialized agents for context gathering, code review, and logging

## Features

- **Fresh context each iteration** - No state carried between iterations, reducing context pollution
- **Specialized agents** - Context gathering, code review, and logging agents handle specific phases
- **Self-correcting loops** - Critical issues from code review loop back to implementation (max 3 attempts)
- **Automatic backlog management** - Suggestions from reviews get queued for future iterations
- **Markdown throughout** - Token-efficient, human-readable task files

## Installation

### Quick Start

```bash
# Clone the repository
git clone https://github.com/chrisabra-co/ralphed-up.git
cd ralphed-up

# Initialize in your project
./ralphed-up.sh init
```

### Via npx (coming soon)

```bash
npx ralphed-up
```

## Usage

```bash
# Show current status and next task
./ralphed-up.sh status

# Run a single iteration
./ralphed-up.sh single

# Run multiple iterations
./ralphed-up.sh run 5

# Show help
./ralphed-up.sh help
```

## Workflow

Each iteration follows this 9-phase workflow:

| Phase | Description |
|-------|-------------|
| **1. Load Task** | Get next unchecked task from `IMPLEMENTATION_PLAN.md` |
| **2. Context Gathering** | Agent explores codebase, writes Context Manifest to task file |
| **3. Acceptance Criteria** | Auto-generated from task description |
| **4. Implementation** | Uses CGA context + project conventions from `AGENTS.md` |
| **5. Run Tests** | Execute tests, retry implementation once if they fail |
| **6. Code Review** | Agent categorizes issues: 🔴 Critical → loop back, 🟡 Warning → document, 🟢 Suggestion → backlog |
| **7. Logging** | Agent updates Work Log, cleans outdated info |
| **8. Git Commit** | Semantic commit message, process backlog queue |
| **9. Archive** | Mark task complete, archive session to `logs/` |

**⟳ Context cleared. Fresh Claude invocation. New iteration begins.**

## Directory Structure

```
your-project/
├── ralphed-up.sh               # Main orchestrator
├── IMPLEMENTATION_PLAN.md      # Task list + Backlog section
├── AGENTS.md                   # Project conventions
│
├── .claude/
│   └── agents/                 # Agent definitions
│       ├── context-gathering.md
│       ├── code-review.md
│       └── logging.md
│
├── plans/
│   └── current-task.md         # Active task file
│
├── logs/
│   ├── sessions/               # Per-iteration archives
│   └── transcripts/
│       └── logging/            # Temp files for logging agent
│
├── state/
│   ├── iteration.json          # Progress tracking
│   ├── backlog-queue.json      # Pending backlog items
│   └── last-commit.txt         # Rollback reference
│
└── templates/
    ├── task.md
    ├── IMPLEMENTATION_PLAN.md
    └── AGENTS.md
```

## Configuration

### AGENTS.md

Configure project-specific conventions:

```markdown
# Project Conventions

## Testing
test_command: npm test  # Override auto-detection

## Code Style
[Your project's style rules]

## Architecture
[Your project's patterns]
```

### IMPLEMENTATION_PLAN.md

Add tasks as a checklist:

```markdown
## Tasks

- [ ] Implement user authentication
- [ ] Add password reset flow
- [ ] Create admin dashboard

## Backlog

> Items from code reviews appear here
```

## Agents

### Context Gathering Agent
Explores the codebase at the start of each iteration. Writes a comprehensive Context Manifest to the task file including:
- How the current system works (narrative form)
- What needs to connect for new features
- Technical reference (signatures, schemas, paths)

### Code Review Agent
Reviews implementation changes and categorizes issues:
- **🔴 Critical** - Blocks deployment, loops back to implementation
- **🟡 Warning** - Should address, documents decision
- **🟢 Suggestion** - Consider for backlog

### Logging Agent
Updates the Work Log at the end of each iteration:
- Consolidates entries
- Cleans outdated information
- Updates Success Criteria checkboxes

## Error Handling

| Failure | Action |
|---------|--------|
| CGA fails | Retry once, skip task if still fails |
| Tests fail | Retry implementation (max 2 attempts) |
| Critical issues unresolved | Mark incomplete, queue to backlog |
| Git fails | Log warning, continue (manual commit later) |

## Requirements

- Bash 4.0+
- [Claude CLI](https://claude.ai/cli) installed and authenticated
- Git (for commits)
- jq (for JSON parsing)

## License

MIT
