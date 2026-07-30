---
name: project-release
description: Verify, commit, and push changes for the volunteer-record-system repository. Use when the user asks to commit, push, release, or publish changes to a Git branch. Inspect scope and branch, run proportional checks, stage only intended files, create an accurate Conventional Commit, and push without deploying unless deployment is explicitly requested.
---

# Project release

Read and follow the repository root `AGENTS.md` before acting.

## 1. Establish scope

1. Inspect the current branch, `git status --short`, relevant diffs, and the latest commit.
2. Identify files belonging to the user's requested task.
3. Preserve unrelated changes. If intended and unrelated changes overlap, stop and explain the conflict.
4. Do not switch, merge, rebase, or create branches unless requested.

## 2. Verify proportionally

- Documentation or instruction-only changes: run `git diff --check`; do not build application code.
- Frontend changes: run `npm.cmd run build` from `frontend/`.
- Backend behavior changes: run `.\mvnw.cmd test` from `backend/`.
- Low-risk backend compile-only changes: `.\mvnw.cmd -DskipTests compile` is acceptable when tests add no useful coverage.
- Mixed frontend/backend changes: verify both affected sides.
- SQL migration changes: review transaction boundaries, constraints, dependencies, and repeat-execution risk. Do not execute the migration without explicit permission. Remind the user that local PostgreSQL and Neon must be migrated separately.

If a required check fails, do not bypass it or push a knowingly broken commit. Report the failure or fix it only when the user's request includes fixing it.

## 3. Commit safely

1. Review `git diff --check` and the final diff summary.
2. Stage explicit task files rather than unrelated working-tree changes.
3. Use a concise English Conventional Commit message that describes the actual outcome.
4. Confirm the resulting commit and remaining working-tree status.

## 4. Push

1. Push the explicitly requested branch; otherwise push the current branch.
2. Treat push and deployment as separate actions.
3. Do not manually deploy to Render unless the user explicitly requests deployment.
4. If the target branch may have Render auto-deploy enabled, mention that the external service may deploy after the push.

## 5. Report

Report:

- verification commands and results;
- commit hash and message;
- pushed branch;
- any uncommitted files left behind;
- whether deployment was performed.
