# Charcoal AZ Search

The existing Android search Activity uses the fixed #212121 root, #2F2F2F
cards, #383838 controls, #454545 borders and F4/B4 text. The existing search
button remains a button with a dark interactive surface. Canonical resources
come from android-NDK e8b67dfc67776c2b8da919785d15f38d68c91db0, including fixed
system bars and default TextView/dialog colors, independent of system night mode.
The shared byte-copy guard verifies those resources.

This stacks on active Amazon-search PR29 at5e3b55c8. Backend requests, TSV,
Termux permission/command boundaries, caching, affiliate links, parallel price
limits and loaded-result filtering are unchanged. Existing Java/direct DEX
packaging is retained; no new framework or source language is introduced.

Host parser/boundary checks and the exact unsigned Android build must pass.
The canonical private AZ signer is unavailable to this job, so unsigned build
evidence is not a signed C67 upgrade. No key is generated or substituted.
API29/API34 palette/lifecycle and physical C67 acceptance remain NOT_RUN.
No merge, release, account sign-in, purchase or installed-app change is performed.
