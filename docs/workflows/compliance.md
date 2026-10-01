# Compliance and CIS

[`compliance.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/compliance.yml): Scan an org for standard-ci drift, optionally open update PRs; [`cis-compliance.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/cis-compliance.yml): CIS supply-chain scan of one repo; [`cis-org-compliance.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/cis-org-compliance.yml): CIS supply-chain scan across an org. Pin to a release SHA, as [Versioning](../VERSIONING.md) says.

## compliance.yml

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `org` | string | required | GitHub org or user to scan |
| `auto_update` | boolean | `false` | Open PRs to update drifted repos |
| `dry_run` | boolean | `false` | Show what would change without opening PRs (requires auto_update) |
| `pr_title_prefix` | string | `'chore(deps): '` | Prefix for auto-update PR titles |
| `pr_labels` | string | `'dependencies,standard-ci'` | Comma-separated labels for auto-update PRs |
| `post_to_gist` | boolean | `false` | Update a pinned gist with dashboard content |
| `gist_id` | string | `''` | Gist ID to update (required if post_to_gist is true) |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON |

## cis-compliance.yml

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `branch` | string | `''` | Branch to scan (default: current branch or main/master) |
| `min_score` | number | `0` | Minimum passing score (0-35). Workflow fails if score is below this. 0 = report only. |
| `chain_bench_version` | string | `'0.1.10'` | chain-bench version to install |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON |

## cis-org-compliance.yml

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `org` | string | required | GitHub org or user to scan |
| `repos` | string | `''` | Comma-separated repo names to scan (empty = all non-archived repos) |
| `max_repos` | number | `100` | Maximum number of repos to scan (controls runtime) |
| `active_months` | number | `6` | Only scan repos pushed within this many months (0 = all repos) |
| `min_score` | number | `0` | Minimum passing score per repo (0-35). 0 = report only. |
| `chain_bench_version` | string | `'0.1.10'` | chain-bench version to install |
| `create_tracking_issue` | boolean | `false` | Create/update a tracking issue in the .github repo with results |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON |
