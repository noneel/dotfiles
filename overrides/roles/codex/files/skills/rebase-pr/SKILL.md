---
name: rebase-pr
description: Rebase the current PR branch onto its base branch, use GitHub PR context and recently merged changes to resolve conflicts, and ask feature-level questions when intent is unclear.
---

# Rebase PR

Use this skill when the user wants to update, rebase, sync, fix conflicts, resolve merge conflicts, or bring a PR branch up to date with its base branch.

## Core rules

- Rebase the current branch onto the PR base branch.
- Use GitHub PR context before resolving conflicts.
- Use recently merged base-branch context before resolving conflicts.
- Resolve conflicts by preserving feature intent, not by choosing hunks mechanically.
- Never ask the user to choose between raw code snippets, conflict markers, "ours", or "theirs".
- If intent is unclear, ask a feature-level question explaining what application behavior is affected.
- Never force push automatically.
- Never run destructive commands like git reset --hard or git clean without explicit approval.

## Inputs

The user may provide:

- BASE=origin/main
- PR=123

If not provided:

- Infer the current branch with git branch --show-current.
- Infer the PR with gh pr view if available.
- Infer the base branch from the PR.
- Otherwise default to origin/main.

## Phase 1: Preflight

Run:

    git status --short
    git branch --show-current
    git remote -v
    git fetch --all --prune

If there are unrelated unstaged or uncommitted changes, stop and explain what you found.

Set safer conflict defaults:

    git config --local merge.conflictstyle zdiff3
    git config --local rerere.enabled true

If .codex/rebase-pr-rules.md exists, read it before resolving conflicts and treat it as repo-specific guidance.

## Phase 2: Understand the PR

If GitHub CLI is available, run:

    gh auth status
    gh pr view --json number,title,body,baseRefName,headRefName,url,commits,files,reviews,comments

Summarize:

- What this PR is trying to do.
- What feature or application behavior it affects.
- Important files changed.
- Important review comments or PR discussion.
- Tests added or changed.

Also inspect local changes:

    git diff --stat BASE...HEAD
    git diff --name-only BASE...HEAD
    git log --oneline --decorate BASE..HEAD

Do not start resolving conflicts until the PR intent is clear enough to describe in plain English.

## Phase 3: Understand base branch changes

Find what changed since this branch diverged:

    MERGE_BASE=$(git merge-base HEAD BASE)
    git log --oneline --decorate "$MERGE_BASE"..BASE
    git diff --stat "$MERGE_BASE"..BASE
    git diff --name-only "$MERGE_BASE"..BASE

Compare PR files with base-branch files.

Classify possible conflicts as:

- same file, same feature
- same file, unrelated feature
- API/interface changed underneath this PR
- renamed or moved file
- deleted vs modified file
- generated file or lockfile
- test behavior changed
- config/build/deployment change
- database/schema/migration conflict

## Phase 4: Rebase

Run:

    git rebase BASE

If conflicts happen, inspect before editing:

    git status
    git diff --name-only --diff-filter=U
    git diff --cc

For conflicted files, inspect context:

    git log --oneline --follow -- <file>
    git blame -L <range> -- <file>
    git show :1:<file>
    git show :2:<file>
    git show :3:<file>

Remember during rebase:

- "ours" usually means the base branch being rebased onto.
- "theirs" usually means the commit being replayed.
- Explain decisions in terms of base-branch behavior and PR behavior, not ours/theirs.

## Phase 5: Resolve by intent

For each conflict, determine:

- What this PR was trying to do.
- What the base branch changed.
- Whether both intents can coexist.
- Whether one side supersedes the other.
- What application behavior is affected.
- What test or check proves the resolution.

You may resolve automatically when the issue is clearly:

- formatting
- imports
- simple type/signature updates
- lockfiles where package manifests are clear
- generated snapshots after regeneration
- obvious file rename/move conflicts
- duplicate implementation where the base branch already added the same behavior

Do not automatically resolve conflicts involving:

- user-facing behavior
- authorization
- security
- tenancy
- access control
- audit behavior
- data contracts
- API response shapes
- database migrations
- feature flags
- competing implementations of the same feature
- deleting meaningful behavior from either side

## Phase 6: Ask feature-level questions when unsure

When unsure, do not ask the user to pick code.

Use this exact format:

    I hit a conflict that affects: <feature/capability>

    What changed:
    - This PR appears to be adding/changing: <plain-English behavior>
    - The base branch now does: <plain-English behavior>

    Why I cannot safely choose:
    - <explain ambiguity without raw hunk noise>

    Decision needed:
    Should the application now:
    A) <behavior option A>
    B) <behavior option B>
    C) <combined behavior if plausible>

    Files affected:
    - <file>: <why it matters>
    - <file>: <why it matters>

    My recommendation:
    <recommended option and why>

    Validation I will run after:
    - <test/check command>

Only include code excerpts if they help, and only after the feature-level explanation.

## Phase 7: Continue

After resolving files:

    git add <resolved-files>
    git rebase --continue

Repeat until the rebase completes.

If the rebase becomes risky or confusing, stop and ask the user a feature-level question.

Do not abort the rebase unless the user asks.

## Phase 8: Validate

After successful rebase, run:

    git diff --check

Then discover and run relevant checks from:

- package.json
- Makefile
- justfile
- Taskfile.yml
- pyproject.toml
- go.mod
- CI workflows
- README/contributing docs

Common examples:

    npm run typecheck
    npm run lint
    npm test
    npm run build
    pytest
    go test ./...
    make test

Fix failures caused by the rebase. If failures appear unrelated, report that clearly.

## Final report

End with:

    Rebase result: completed / blocked / aborted / needs user decision

    Branch:
    Base:
    PR:

    Conflict summary:
    - <file>: <feature-level explanation of conflict and resolution>

    User decisions requested:
    - None / list decisions

    Validation:
    - <command>: passed/failed/not run and why

    Remaining risks:
    - <risk>

    Next command if you want to update the remote branch:
    git push --force-with-lease

Never run git push --force-with-lease unless the user explicitly asks.
