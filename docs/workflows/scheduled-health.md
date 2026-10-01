# Scheduled health

[`scheduled-health.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/scheduled-health.yml): Open an issue when a scheduled upstream workflow fails. Pin to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `issue_title` | string | `'[SCHEDULED-BUILD] CI failure detected'` | Title for auto-created issue on failure |
| `issue_labels` | string | `'bug,ci'` | Comma-separated labels for the auto-created issue |
| `upstream_workflow` | string | required | Name of the upstream workflow to monitor (e.g., "CI Tests") |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON |
