# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-19

### Added

- **Main orchestrator** (`ralph-sessions.sh`)
  - Commands: `init`, `status`, `single`, `run [n]`, `help`
  - 9-phase workflow per iteration
  - Auto-detection of test commands (npm, pytest, cargo, go, make)
  - Colored terminal output with phase headers
  - Session archiving to `logs/sessions/`

- **Context Gathering Agent** (`.claude/agents/context-gathering.md`)
  - Explores codebase for task-relevant context
  - Writes narrative Context Manifest to task file
  - Self-verification checklist for completeness

- **Code Review Agent** (`.claude/agents/code-review.md`)
  - Generic review (no stack-specific rules)
  - Categorizes issues: Critical / Warning / Suggestion
  - Critical issues trigger implementation loop (max 3 attempts)
  - Warnings get documented, suggestions go to backlog

- **Logging Agent** (`.claude/agents/logging.md`)
  - Updates Work Log from session transcripts
  - Cleans outdated information
  - Consolidates entries across sessions

- **Project configuration**
  - `AGENTS.md` - Project conventions template with `test_command` override
  - `IMPLEMENTATION_PLAN.md` - Task list with Backlog section

- **State management**
  - `state/iteration.json` - Tracks iteration and task index
  - `state/backlog-queue.json` - Pending items from reviews
  - `state/last-commit.txt` - SHA for rollback reference

- **Templates**
  - `templates/task.md` - Per-iteration task file
  - `templates/IMPLEMENTATION_PLAN.md` - Plan template
  - `templates/AGENTS.md` - Conventions template

- **Node.js CLI** (`cli/`)
  - Interactive setup wizard
  - Auto-detects test commands
  - Creates directory structure and files

### Design Decisions

- Fresh context each iteration (Ralph-style) - no state carried between iterations
- CGA focuses on task scope, not entire codebase
- Critical issues loop back in-iteration (preserves context)
- Warnings require documented decisions, suggestions go to backlog
- Single model (no escalation) - escalation was unreliable
- Markdown throughout for token efficiency
- Agents live in `.claude/agents/` for Claude Code integration
