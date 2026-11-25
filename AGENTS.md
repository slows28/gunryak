# Gunryak: branch guard

IMPORTANT: `main` is the intentionally preserved early stable prototype, NOT the current development baseline. Do not start or continue game development from this branch. The owner's latest game work is on `ai/demo-visual-overhaul`, including six armies per side, 25-minute operations, commander psychology, front dashboards, separate order maps, courier orders and forest depth rendering.

Before editing gameplay files, switch the task's base to `ai/demo-visual-overhaul` (fetch the existing remote branch if necessary). Read that branch's AGENTS.md and DEVELOPMENT_PROGRESS.md and verify the baseline includes scripts/general_mind.gd and scripts/front_view.gd. If the environment cannot access that branch, stop and report the specific blocker; do not rebuild the early prototype or overwrite main. Preserve any existing task changes separately; do not use a destructive reset. No game code changes or merge into main without owner approval.
