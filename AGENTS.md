# Gunryak — repository instructions for Codex and development agents

## Objective
Build a compelling FM-inspired historical army-command game, not a troop movement simulator. The owner has rejected the existing demo for visual quality, lack of battle feeling and unclear commander decisions. A successful build is NOT a successful game.

## Required working method
- Start by running the current Godot project and inspecting actual screenshots of the order map, wide battlefield, zoomed real combat, and commander information. Record baseline commit and image files. Do not use generated mockups as evidence.
- Work in integrated batches: identify a root cause, implement changes, run the engine, inspect the new output, and revise if still unsatisfactory. Do not stop at a plan or commit count.
- Use Godot 4 matching .github/workflows/godot-tests.yml. Run the repository's engine tests and screenshot harness using the existing workflow commands; also run a graphical session when available. Report exact commands, failures and limits. If graphical execution is unavailable, mark the visual gate unverified; do not claim success.
- Keep main stable. Work from ai/demo-visual-overhaul in an isolated branch; do not merge or publish without owner approval. Keep existing 25-minute operation, 6 armies per faction, real troop counts, autonomous formations, separate parchment orders, early preplanned orders and courier restrictions unless an explicit design decision changes them.
- Do not ask the owner to upload code or repeat requirements already in DEVELOPMENT_PROGRESS.md.
- Maintain DEVELOPMENT_PROGRESS.md with tested commit, screenshots, concrete remaining defects and next actionable changes. Never inflate subjective scores or claim gameplay verified by headless tests alone.

## Priority for next integrated milestone
1. Battle presentation: use coherent art scale, directional animation, genuine contact/retreat/formation transitions, camera and audiovisual cues driven by real simulation events; no fake attacks or misleading damage.
2. Terrain: visually distinct geography that makes tactical sense. No standalone gates on open ground; roads meet bridges; actual walls enclose or block access. Forest and unit depth, occlusion, terrain clarity.
3. Commander UI: all six friendly commanders' action, mood, rationale, urgent requests and order status readable without hovering; select commander to inspect actual observed evidence, response and outcome. Distinguish enemy observed information from friendly command authority.
4. Visual coherence: replace weak/repetitive vector portraits and sprites with coherent actual licensed/original game assets; use consistent painterly palette and legible screen typography. Do not substitute concept images for integrated assets.
5. Verify the integrated result at 1280×800 and with actual player-like commands. Capture baseline and revised images at matched camera/scenario/tick; record FPS and loading where measurable. Preserve automatic regression checks and do not weaken tests to obtain a pass.

## Deliverable
A working revision, actual before/after gameplay screenshots, verified build/test results, known shortcomings and a concise Korean report. No unsupported numeric quality rating, no plan-only delivery. User remains final quality approver.
