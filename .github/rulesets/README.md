# Repository rulesets

Codified branch/tag protection for `dsaad68/termdown`, applied via the GitHub
REST API with the `gh` CLI.

> **Requirement:** repository rulesets are only available on a **public** repo or
> with a paid plan (**GitHub Pro/Team/Enterprise**) for private repos. While this
> repo is private and on the free plan, `gh api … rulesets` returns
> `403 Upgrade to GitHub Pro or make this repository public`. Make the repo public
> (or upgrade), then run the commands below.

## Apply

```sh
gh api -X POST repos/dsaad68/termdown/rulesets --input .github/rulesets/main-protection.json
gh api -X POST repos/dsaad68/termdown/rulesets --input .github/rulesets/release-tags.json
```

To update an existing ruleset, list IDs and `PUT`:

```sh
gh api repos/dsaad68/termdown/rulesets --jq '.[] | "\(.id)\t\(.name)"'
gh api -X PUT repos/dsaad68/termdown/rulesets/<id> --input .github/rulesets/main-protection.json
```

## What they enforce

**`main-protection.json`** (default branch):
- Pull request required before merging (0 required approvals — solo-friendly), with
  conversation-resolution required.
- Required status checks (strict / up-to-date): `Build & Test · macOS`,
  `Build & Test · Linux`, `Lint & Format`.
- Linear history; no force-pushes; branch cannot be deleted.

**`release-tags.json`** (`refs/tags/v*`):
- Release tags cannot be deleted or moved (no non-fast-forward updates) — releases
  stay immutable.

Both grant the repository **Admin** role a bypass (`actor_id: 5`) so the owner is
never locked out. If a required status-check name ever changes (it must match the
CI job name exactly), update the `context` values here to match.
