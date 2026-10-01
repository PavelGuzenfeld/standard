# CLI

`standard-ci` has no dependencies and supports Python 3.8 and newer. Install it with `pip install git+https://github.com/PavelGuzenfeld/standard.git`. The [Quickstart](CONSUMER-QUICKSTART.md) walks through `init` and `update`.

`standard-ci --version` prints the version. With no command it prints the help and exits 1.

| Command | What it does |
|---|---|
| `init` | Scaffold workflow files and `.standard.yml` |
| `update` | Update SHA pins to the latest release |
| `check` | Validate setup matches `.standard.yml` |
| `install-starters` | Install starter workflow templates into an org's `.github` repo |
| `scan` | Scan org repos for compliance |
| `dashboard` | Generate a compliance dashboard |
| `auto-update` | Open update PRs in drifted consumer repos |

## Options

| Command | Option | Default | Description |
|---|---|---|---|
| `init` | `--preset {minimal,recommended,full}` | `recommended` | Preset configuration |
| `init` | `--non-interactive` | off | Accept all defaults without prompting |
| `init` | `--pin TAG` | latest tag | Pin to a specific tag |
| `init` | `--output-dir DIR` | `.` | Project directory |
| `update` | `--dry-run` | off | Show what would change |
| `update` | `--pin TAG` | latest tag | Pin to a specific tag |
| `update` | `--output-dir DIR` | `.` | Project directory |
| `check` | `--output-dir DIR` | `.` | Project directory |
| `install-starters` | `--org ORG` | required | GitHub org or user |
| `install-starters` | `--pin TAG` | latest tag | Pin to a specific tag |
| `install-starters` | `--dry-run` | off | Show what would change |
| `install-starters` | `--create-repo` | off | Create the `.github` repo if it doesn't exist |
| `scan` | `--org ORG` | required | GitHub org or user to scan |
| `scan` | `--token TOKEN` | `GITHUB_TOKEN` env | GitHub token |
| `scan` | `--json` | off | Output as JSON |
| `scan` | `--exit-code` | off | Exit non-zero if any repo is non-compliant |
| `dashboard` | `--org ORG` | required | GitHub org or user |
| `dashboard` | `--token TOKEN` | `GITHUB_TOKEN` env | GitHub token |
| `dashboard` | `--format {markdown,json}` | `markdown` | Output format |
| `dashboard` | `--scan-results FILE` | none | Use pre-computed scan results JSON instead of scanning |
| `auto-update` | `--org ORG` | required | GitHub org or user |
| `auto-update` | `--token TOKEN` | `GITHUB_TOKEN` env | GitHub token |
| `auto-update` | `--dry-run` | off | Show what would change |
| `auto-update` | `--scan-results FILE` | none | Use pre-computed scan results JSON instead of scanning |
| `auto-update` | `--pr-title-prefix PREFIX` | `chore(deps): ` | Prefix for auto-update PR titles |
| `auto-update` | `--pr-labels LABELS` | `dependencies,standard-ci` | Comma-separated labels for auto-update PRs |

`check` also reports every `.yml` or `.yaml` file under `.github/workflows` that still has a `REQUIRED_` placeholder as a workflow input value, for example `docker_image: REQUIRED_DOCKER_IMAGE` left behind by `init`. Each finding is an `ERROR` naming the file, line and key, and makes `check` exit 1. Placeholders in comments, in keys, or in the middle of a value are not reported.

[Compliance](COMPLIANCE.md) covers `scan`, `dashboard` and `auto-update` in an org.
