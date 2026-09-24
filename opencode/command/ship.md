---
description: Run the full build pipeline (plan, code, test, review, open PR) on a feature request.
agent: ship
---

Run the build pipeline for the following feature request. Artifacts will be organized in `.pipeline/<YYYY-MM-DD>-<slug>/` where the slug is derived from the feature name. Multiple runs in a day remain separate; same-day reruns overwrite only their own subfolder.

$ARGUMENTS

Execute the pipeline exactly as defined in your orchestrator instructions: reset `.pipeline/`, then run planner, coder, tester, reviewer, and pr-writer in order, chaining artifacts through the `.pipeline/` folder. Apply the one-retry auto-loop if the reviewer returns FAIL. Open a draft PR only if the final verdict is PASS. Then give me the final report.
