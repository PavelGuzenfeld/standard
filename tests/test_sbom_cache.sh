#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW="${SBOM_WORKFLOW:-$ROOT/.github/workflows/sbom.yml}"
PYTHON="${PYTHON:-python3}"

"$PYTHON" - "$WORKFLOW" <<'PY'
import sys

import yaml

jobs = yaml.safe_load(open(sys.argv[1]))["jobs"]
failed = False


def check(name, ok):
    global failed
    print(("PASS: " if ok else "FAIL: ") + name)
    failed = failed or not ok


def step(job, name):
    return next((s for s in jobs[job]["steps"] if s.get("name") == name), {})


def cache_step(job):
    return next(
        (s for s in jobs[job]["steps"] if s.get("uses", "").startswith("actions/cache@")),
        {},
    )


def gated_on_miss(job, name):
    cache_id = cache_step(job).get("id", "<no cache step>")
    return f"steps.{cache_id}.outputs.cache-hit != 'true'" in step(job, name).get("if", "")


resolve = step("container-sbom", "Resolve image digest")
resolve_run = resolve.get("run", "")
check(
    "container key resolves the digest without pulling",
    "docker buildx imagetools inspect" in resolve_run and "docker pull" not in resolve_run,
)
check(
    "container key names the digest and the reusable workflow sha",
    "sbom-$DIGEST-$WORKFLOW_SHA" in resolve_run
    and resolve.get("env", {}).get("WORKFLOW_SHA") == "${{ fromJSON(toJSON(job)).workflow_sha }}",
)
check(
    "empty digest or workflow sha writes no key",
    'if [ -n "$DIGEST" ] && [ -n "$WORKFLOW_SHA" ]' in resolve_run,
)

container_cache = cache_step("container-sbom")
check(
    "container cache is keyed on the resolved key and skipped without one",
    container_cache.get("with", {}).get("key") == "${{ steps.digest.outputs.key }}"
    and container_cache.get("if") == "steps.digest.outputs.key != ''",
)
check(
    "container cache holds both SBOM formats",
    container_cache.get("with", {}).get("path", "").split()
    == ["container-sbom-spdx.json", "container-sbom-cdx.json"],
)
check(
    "container key is a job output",
    jobs["container-sbom"].get("outputs", {}).get("sbom_key")
    == "${{ steps.digest.outputs.key }}",
)
for name in ("Pull Docker image", "Generate SPDX SBOM", "Generate CycloneDX SBOM"):
    check(f"cache hit skips {name}", gated_on_miss("container-sbom", name))
check(
    "SBOM upload runs on hit and miss",
    "if" not in step("container-sbom", "Upload SBOM artifacts"),
)

check("vuln-scan has no job condition", "if" not in jobs["vuln-scan"])
check("vuln-scan has no cache step", cache_step("vuln-scan") == {})
check(
    "grype runs on every SBOM",
    "if" not in step("vuln-scan", "Run Grype vulnerability scan"),
)

license_key = cache_step("license-check").get("with", {}).get("key", "")
check(
    "license key is the container key plus the policy, checker and source SBOM hash",
    license_key
    == "license-${{ needs.container-sbom.outputs.sbom_key }}-${{ hashFiles("
    "inputs.license_policy_file || inputs.license_check_script, "
    "inputs.license_check_script || inputs.license_policy_file, "
    "'source-sbom.cdx.json') }}",
)
check(
    "license cache is skipped without a container key",
    cache_step("license-check").get("if") == "needs.container-sbom.outputs.sbom_key != ''",
)
license_steps = jobs["license-check"]["steps"]
check(
    "license key is hashed after the source SBOM lands",
    cache_step("license-check") in license_steps
    and license_steps.index(cache_step("license-check"))
    > license_steps.index(step("license-check", "Download source SBOM")),
)
for name in ("Write built-in license checker", "Run license check"):
    check(f"license cache hit skips {name}", gated_on_miss("license-check", name))

sys.exit(1 if failed else 0)
PY
