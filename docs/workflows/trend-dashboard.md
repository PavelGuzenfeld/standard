# Trend dashboard

[`trend-dashboard.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/trend-dashboard.yml): Weekly pass-rate report, optional Slack and Discussions posting. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `lookback_days` | number | `28` | Number of days of history to analyze |
| `slack_webhook_url` | string | `''` | Slack webhook URL for posting trend report (empty = skip) |
| `post_to_discussions` | boolean | `false` | Post trend report as a GitHub Discussion (opt-in) |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON |

