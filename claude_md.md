# Agent Collaboration & GitHub Workflow (`CLAUDE.md`)

This document defines the mandatory workflow and operational rules for AI agents collaborating in this repository via GitHub. Every agent must strictly follow these guidelines to prevent conflicts, duplicate work, and broken builds.

---

## 1. Core Rules (Non-Negotiable)

1. **Never work directly on `main`:** Direct commits, pushes, or merges to `main` (or `master`) are strictly forbidden.
2. **Strict 1:1:1 Principle:** **One Issue = One Branch = One Pull Request.** Never bundle multiple unrelated issues into a single branch or PR.
3. **Stay in your own branch:** Only commit and push to the specific branch you created for your assigned issue. Never modify or push to another agent's branch unless explicitly requested for a code review fix.
4. **Claim your issue first:** Before writing any code or creating a branch, assign the GitHub issue to yourself (or add an `in-progress` label/comment) so other agents know the task is taken.
5. **Create dedicated branches:** Always branch off an up-to-date `main` branch for every new issue.

---

## 2. Naming Conventions

### Branches
Use lowercase, hyphens (`-`), and always prefix with the issue number and type:
- **Features:** `feat/issue-<number>-<short-description>` (e.g., `feat/issue-42-user-login`)
- **Bug Fixes:** `fix/issue-<number>-<short-description>` (e.g., `fix/issue-19-null-pointer`)
- **Chores / Docs:** `chore/issue-<number>-<short-description>` (e.g., `chore/issue-7-update-readme`)

### Commit Messages
Follow [Conventional Commits](https://www.conventionalcommits.org/) and reference the issue number:
- `feat(#42): add OAuth2 authentication endpoint`
- `fix(#19): handle empty payload in webhook parser`
- `docs(#7): update agent workflow instructions`

---

## 3. Step-by-Step Agent Workflow

### Step 1: Discover or Create an Issue
- Check existing open issues (`gh issue list`) before creating a new one to avoid duplicates.
- If a task, bug, or sub-task is not tracked yet, create a clear, atomic issue (`gh issue create`) describing the goal and acceptance criteria.

### Step 2: Claim the Issue
- Assign the issue to yourself and mark it as active before starting implementation:
  ```bash
  gh issue edit <issue-number> --add-assignee "@me"
  gh issue comment <issue-number> --body "Claiming this issue and starting work."
  ```

### Step 3: Create a New Branch from `main`
- Ensure your local `main` branch is completely up to date, then create and switch to your dedicated branch:
  ```bash
  git checkout main
  git pull origin main
  git checkout -b feat/issue-<issue-number>-<short-description>
  ```

### Step 4: Implement, Test, and Commit
- Make changes strictly scoped to the claimed issue.
- Run all relevant tests, linters, and build checks locally before committing.
- Commit your changes cleanly and push only to your own remote branch:
  ```bash
  git add .
  git commit -m "feat(#<issue-number>): <concise description>"
  git push -u origin feat/issue-<issue-number>-<short-description>
  ```

### Step 5: Open a Pull Request (Merge Request)
- Open a Pull Request targeting `main` and link the issue using closing keywords (`Closes #<issue-number>`):
  ```bash
  gh pr create \
    --base main \
    --title "feat(#<issue-number>): <concise title>" \
    --body "Closes #<issue-number>

  ### Summary of Changes
  - <Bullet point 1>
  - <Bullet point 2>

  ### Verification
  - [ ] Unit/integration tests pass
  - [ ] Linting and type checks pass"
  ```

### Step 6: Handoff & Cleanup
- Do **not** merge your own PR unless explicitly authorized by repository policy and all CI checks pass.
- Once the PR is reviewed and merged, switch back to `main` and delete your local feature branch before claiming the next issue:
  ```bash
  git checkout main
  git pull origin main
  git branch -d feat/issue-<issue-number>-<short-description>
  ```