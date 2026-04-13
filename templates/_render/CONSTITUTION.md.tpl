# {{PROJECT_NAME}} Constitution

Updated: {{DATE}}
Project Root: {{PROJECT_ROOT}}

## Authority
This constitution has the highest priority for project engineering practices.
Runtime instructions in agent files must follow these principles.

## Core Principles

### 1. Context First (Non-Negotiable)
- Read existing code before implementation.
- Search for reusable patterns and shared modules.
- Review project docs and recent changes.

### 2. Single Source of Truth
- Shared types/constants/schemas must live in one location.
- Consumers import instead of duplicating logic.
- Recommended shared path: `{{SHARED_TYPES_PATH}}`.

### 3. Library First
- Before writing custom logic larger than 20 lines, evaluate existing libraries.
- Use maintained packages when they satisfy most requirements.
- Document chosen library and rejected alternatives.

### 4. Code Reuse and DRY
- Extend existing components/utilities before creating new ones.
- If reuse is impossible, write a short rationale in the task notes.

### 5. Type Safety
- Avoid weak typing and unchecked payloads.
- Exported API boundaries require explicit schema/contract validation.

### 6. Atomic Task Execution
- One agent invocation should cover one concrete task.
- Validate and close a task before moving to the next one.

### 7. Quality Gates (Non-Negotiable)
Before merge:
- Type-check passes
- Build passes
- Lint passes
- Tests or smoke checks pass
- No hardcoded secrets

### 8. Progressive Delivery
Feature lifecycle:
1. Specification
2. Plan
3. Atomic tasks
4. Implementation and verification

No phase should be skipped for non-trivial work.

## Security and Compliance
- Authentication provider: `{{AUTH_PROVIDER}}`
- Compliance requirements: `{{COMPLIANCE_REQUIREMENTS}}`
- Never commit secrets to repository.
- Validate external input.

## Accessibility
- Accessibility level target: `{{A11Y_LEVEL}}`
- UI changes must support keyboard navigation and readable contrast.

## Technology Baseline
- Language: `{{LANGUAGE}}`
- Framework: `{{FRAMEWORK}}`
- Database: `{{DATABASE}}`
- Hosting: `{{HOSTING}}`

## Git Governance
- Main branch: `{{MAIN_BRANCH}}`
- Task prefix: `{{TASK_PREFIX}}`
- Every task starts in a new branch.
- Never push directly to `{{MAIN_BRANCH}}`.
- Merge only via Pull Request flow.

