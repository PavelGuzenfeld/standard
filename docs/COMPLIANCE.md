# Compliance

Two org-level workflows keep consumer repos current: `compliance.yml` (SHA-pin drift) and `cis-org-compliance.yml` (CIS supply-chain scan). Each org runs a small trigger workflow from its `.github` repo that calls the reusable workflow in `PavelGuzenfeld/standard`.

## SHA-pin drift

Every run scans the org for repos with `.standard.yml`, checks their SHA pins against the latest release, and writes a dashboard. With `auto_update: true` it also clones drifted repos, updates the pins and opens PRs with the `gh` CLI. Repos without `.standard.yml` are listed but never updated.

### Setup, once per org

The bot needs a token with `repo` and `workflow` scopes to push branches and open PRs:

```bash
gh auth token | gh secret set COMPLIANCE_BOT_TOKEN --repo my-org/.github
```

Or use a fine-grained PAT for all repos in the org with Contents, Pull Requests and Workflows set to read and write.

Add `.github/workflows/compliance.yml` to the org's `.github` repo:

```yaml
name: Compliance

on:
  schedule:
    - cron: '0 9 * * 1'
  workflow_dispatch:
    inputs:
      auto_update:
        description: 'Open PRs to update drifted repos'
        type: boolean
        default: false
      dry_run:
        description: 'Dry run (no PRs opened)'
        type: boolean
        default: false

permissions:
  contents: read

jobs:
  compliance:
    uses: PavelGuzenfeld/standard/.github/workflows/compliance.yml@main
    with:
      org: my-org
      auto_update: ${{ inputs.auto_update || false }}
      dry_run: ${{ inputs.dry_run || false }}
    secrets:
      bot_token: ${{ secrets.COMPLIANCE_BOT_TOKEN }}
```

The schedule runs Mondays 09:00 UTC and produces the dashboard only. Set `auto_update: true` in the `with:` block to open PRs on schedule.

### Onboarding a consumer repo

A repo needs workflow files that call `standard`, and a `.standard.yml` in the root. The CLI writes both:

```bash
pip install git+https://github.com/PavelGuzenfeld/standard.git
standard-ci init --preset recommended
```

If the repo already calls standard workflows, add only `.standard.yml`:

```yaml
tag: vX.Y.Z
sha: <full-40-char-sha>
workflows:
  - cpp-quality
  - infra-lint
```

`standard-ci init` also records `version` and `preset`. Workflow refs pin the SHA: `cpp-quality.yml@<SHA>  # vX.Y.Z`.

### Dashboard

- Step summary of the latest run under `https://github.com/my-org/.github/actions/workflows/compliance.yml`
- `compliance-dashboard` artifact (markdown)
- A pinned gist, with `post_to_gist: true` and `gist_id`
- Locally: `standard-ci dashboard --org my-org [--format json]`

### Trigger manually

```bash
gh workflow run compliance.yml --repo my-org/.github
gh workflow run compliance.yml --repo my-org/.github -f auto_update=true
gh workflow run compliance.yml --repo my-org/.github -f auto_update=true -f dry_run=true
```

Dashboard only, dashboard and PRs, and PR preview. The same options are in the Actions UI under "Run workflow".

### CLI only

```bash
export GITHUB_TOKEN=ghp_...
standard-ci scan --org my-org
standard-ci scan --org my-org --json
standard-ci scan --org my-org --exit-code
standard-ci auto-update --org my-org --dry-run
standard-ci auto-update --org my-org
```

`--exit-code` exits non-zero when any repo is drifted.

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Bot can't push to a consumer repo | Check that `COMPLIANCE_BOT_TOKEN` has `repo` and `workflow` scopes |
| Bot doesn't detect a repo | Add `.standard.yml` to the repo root |
| Dashboard shows "0 repos scanned" | The token may lack `read:org` for a private org |
| PR has merge conflicts | The bot makes a simple branch. Resolve and merge by hand |
| Workflow fails at "Install standard-ci" | The checkout step needs `repository: PavelGuzenfeld/standard` |

## CIS supply-chain compliance

[CIS Software Supply Chain Security v1.0](https://www.cisecurity.org/benchmark/software-supply-chain-security) scores repository and org security: branch protection, signed commits, CI pipeline security, dependency management. The scan uses [chain-bench](https://github.com/aquasecurity/chain-bench) and checks 35 controls in 5 categories.

It runs per org because a per-repo scan scores 0/35: `GITHUB_TOKEN` in a `workflow_call` cannot read org settings (2FA enforcement, team reviews, RBAC). An App token in the org's `.github` repo can.

### Setup, once per org

Create a GitHub App with these permissions, install it on the org, and note the App ID and private key:

- Organization Members: read (2FA checks)
- Repository Administration: read (branch protection)
- Repository Contents: read
- Repository Actions: read
- Repository Issues: read and write (optional, tracking issue)

```bash
gh secret set CIS_APP_ID --repo my-org/.github --body "12345"
gh secret set CIS_APP_PRIVATE_KEY --repo my-org/.github < app-private-key.pem
```

Add `.github/workflows/cis-compliance.yml` to the org's `.github` repo:

```yaml
name: CIS Compliance

on:
  schedule:
    - cron: '0 10 * * 6'
  workflow_dispatch:
    inputs:
      repos:
        description: 'Specific repos to scan (comma-separated, empty=all)'
        type: string
        default: ''

permissions:
  contents: read

jobs:
  cis:
    uses: PavelGuzenfeld/standard/.github/workflows/cis-org-compliance.yml@main
    with:
      org: my-org
      repos: ${{ inputs.repos || '' }}
      create_tracking_issue: true
    secrets:
      app_id: ${{ secrets.CIS_APP_ID }}
      app_private_key: ${{ secrets.CIS_APP_PRIVATE_KEY }}
```

It runs Saturdays 10:00 UTC. Trigger by hand with `gh workflow run cis-compliance.yml --repo my-org/.github`, adding `-f repos="repo-a,repo-b"` to limit it.

Each run lists non-archived repos with `.standard.yml` (or the `repos` input), scans each with chain-bench, and posts a per-repo score table to the workflow summary, the `cis-org-compliance` artifact, and optionally a tracking issue in `.github`. With `min_score > 0` it fails when any repo scores below it.

The per-repo `cis-compliance.yml` still exists for a single-repo report on PRs. Keep `min_score: 0` there unless the repo has an App token with org-level read access.

### Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `org` | (required) | GitHub org or user to scan |
| `repos` | `""` | Comma-separated repo names (empty = auto-discover) |
| `max_repos` | `100` | Max repos to scan per run |
| `active_months` | `6` | Only scan repos pushed within this many months (0 = all repos) |
| `min_score` | `0` | Minimum CIS score (0 = report only) |
| `chain_bench_version` | `0.1.10` | chain-bench release version |
| `create_tracking_issue` | `false` | Post results to a tracking issue |

### Secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `app_id` | No | GitHub App ID with org-level read permissions |
| `app_private_key` | No | GitHub App private key (PEM) |
| `scan_token` | No | PAT with `repo` and `read:org` scope (fallback) |

## CLI reference

```
standard-ci scan --org ORG [--token TOKEN] [--json] [--exit-code]
standard-ci dashboard --org ORG [--token TOKEN] [--format markdown|json] [--scan-results FILE]
standard-ci auto-update --org ORG [--token TOKEN] [--dry-run] [--scan-results FILE]
                        [--pr-title-prefix PREFIX] [--pr-labels LABELS]
```
