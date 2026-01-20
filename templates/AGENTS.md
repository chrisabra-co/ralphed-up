# Project Conventions

> This file defines project-specific conventions that all agents should follow.
> It is loaded alongside agent definitions to provide context.

## Testing

```yaml
test_command: npm test  # Override auto-detection if needed
test_patterns:
  - "**/*.test.ts"
  - "**/*.spec.ts"
```

## Code Style

- Language: TypeScript / JavaScript / Python / etc.
- Formatting: Prettier / ESLint / Black / etc.
- Naming conventions:
  - Files: kebab-case
  - Functions: camelCase
  - Classes: PascalCase
  - Constants: SCREAMING_SNAKE_CASE

## Architecture

### Directory Structure
```
src/
├── components/    # UI components
├── lib/           # Shared utilities
├── services/      # Business logic
└── types/         # Type definitions
```

### Key Patterns
- Pattern 1: Description
- Pattern 2: Description

## Error Handling

- Use custom error classes for domain errors
- Log errors with context (correlation IDs, user context)
- Return user-friendly messages, log technical details

## Authentication & Authorization

- Auth method: JWT / Session / OAuth
- Protected routes: Description
- Role-based access: Description

## Database

- ORM/Query Builder: Prisma / TypeORM / Raw SQL
- Migration strategy: Description
- Naming conventions: snake_case for tables/columns

## Caching

- Cache provider: Redis / Memory / None
- Cache key patterns: Description
- TTL defaults: Description

## Patterns to Follow

> Reference existing implementations as examples

- Auth flow: `src/lib/auth.ts`
- API handler: `src/app/api/example/route.ts`
- Component pattern: `src/components/Button.tsx`

## Anti-Patterns to Avoid

- Don't: X
- Instead: Y

## External Services

| Service | Purpose | Config Location |
|---------|---------|-----------------|
| Stripe | Payments | `.env.local` |
| SendGrid | Email | `.env.local` |
