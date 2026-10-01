# Trend dashboard

[`trend-dashboard.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/trend-dashboard.yml): Weekly pass-rate report, optional Slack and Discussions posting. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Default | Description |
|-------|---------|-------------|
| `lookback_days` | `28` | Number of days of history to analyze |
| `slack_webhook_url` | `''` | Slack webhook URL for posting trend report (empty = skip) |
| `post_to_discussions` | `false` | Post trend report as a GitHub Discussion (opt-in) |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |

