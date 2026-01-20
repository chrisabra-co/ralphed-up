# Project Conventions

> This file defines project-specific conventions for the Ralphed Up system.
> Loaded alongside agent definitions to provide context.

## Testing

```yaml
test_command: echo "No tests configured"  # Override for your project
test_patterns: []
```

## Code Style

- Language: Bash (orchestrator), Markdown (agents/tasks)
- Shell: bash 4.0+
- Formatting: shellcheck compliant

## Architecture

### Directory Structure
```
your-project/
├── ralphed-up.sh           # Main orchestrator
├── IMPLEMENTATION_PLAN.md  # Task list + Backlog
├── AGENTS.md               # This file (project conventions)
├── .claude/
│   └── agents/             # Agent definitions
├── plans/                  # Active task file
├── logs/                   # Session archives & transcripts
├── state/                  # Iteration tracking
└── templates/              # File templates
```

### Workflow Phases
1. Load next task from IMPLEMENTATION_PLAN.md
2. Context Gathering Agent explores codebase
3. Generate acceptance criteria
4. Implementation phase
5. Run tests (retry once on failure)
6. Code Review Agent categorizes issues
7. Logging Agent updates Work Log
8. Git commit + process backlog
9. Archive session, clear context

## Error Handling

- CGA fails: Retry once, skip task if still fails
- Tests fail: Retry implementation (max 2 attempts)
- Critical issues unresolved: Mark incomplete, queue to backlog
- Git fails: Log warning, continue (manual commit later)

## Agent Invocation

### Context Gathering
```bash
claude --print \
    @plans/current-task.md \
    @.claude/agents/context-gathering.md \
    @AGENTS.md \
    -p "Explore codebase for: [task]. Write Context Manifest."
```

### Code Review
```bash
claude --print \
    @plans/current-task.md \
    @.claude/agents/code-review.md \
    @AGENTS.md \
    -p "Review changes. Files: [list]. Return structured review."
```

### Logging
```bash
claude --print \
    @plans/current-task.md \
    @.claude/agents/logging.md \
    -p "Update Work Log from transcripts."
```

## State Files

- `state/iteration.json`: `{"iteration": N, "task_index": M}`
- `state/backlog-queue.json`: `["item1", "item2"]`
- `state/last-commit.txt`: SHA for rollback

## Patterns to Follow

- Fresh context each iteration (no carried state)
- CGA focuses on task scope (not whole codebase)
- Critical issues loop back in-iteration (preserves context)
- Warnings get documented decisions
- Suggestions go to backlog
- Markdown throughout for token efficiency
