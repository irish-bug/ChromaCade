# Contributing to ChromaCade

## Branching workflow
Main is protected — nobody (including Shane) pushes to it directly. For every task:

1. Create a new branch off `main`, named like `yourname/short-task-description` (e.g. `dave/pitch-bend-math`).
2. Commit your work there.
3. Open a pull request into `main` when it's ready for review.

Keep pull requests scoped to one task where possible — smaller PRs are easier to review and test.

## Connecting your Claude to this repo

**If you're using Claude.ai / Cowork:**
1. Claude menu → Settings → Customize → Connectors → find GitHub → Connect → authorize with your GitHub account.
2. When authorizing, grant access to the [`irish-bug/ChromaCade`](https://github.com/irish-bug/ChromaCade) repo (Shane will add you as a collaborator first).
3. Tell your Claude, as a standing instruction: *"We're working in the ChromaCade repo. Always create a new branch for each task, never commit directly to main, and open a pull request when the work is ready."*

**If you're using Claude Code (the CLI):**
1. Clone the repo locally: `git clone https://github.com/irish-bug/ChromaCade.git`
2. Run `claude` from inside the repo folder.
3. Give it the same standing instruction — branch per task, PR instead of pushing to main.

Either way works fine; use whichever you're more comfortable with.

## Testing
Shane (and his Claude) maintain a `pytest` suite covering the logic that doesn't need real hardware to test — note tables, pitch-bend math, semitone/octave shifting, color-blend calculations, menu state machine, etc.

Every pull request automatically runs this suite via GitHub Actions before it can be merged (see `.github/workflows/tests.yml`). You don't need to write full test coverage yourself — just try to keep the logic you're contributing in plain, testable functions (not tangled up with GPIO/hardware calls), and we'll fill in coverage together during review.

## Review
Shane reviews and merges pull requests into `main` once tests pass and the change looks good.
