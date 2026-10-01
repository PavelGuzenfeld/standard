#!/usr/bin/env python3
import argparse
import html
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
HEADER = "| Input | Type | Default | Description |"
SEPARATOR = "|-------|------|---------|-------------|"
ROW = re.compile(r"^\| `([^`]+)` \| (.*?) \| (.*?) \| (.*) \|$")
HEADING = re.compile(r"^(#+) (.*)$")


class Input:
    def __init__(self, name, spec):
        self.name = name
        self.type = spec.get("type", "")
        self.required = bool(spec.get("required", False))
        self.has_default = "default" in spec
        self.default = spec.get("default")
        self.description = " ".join(str(spec.get("description", "")).split())

    def default_cell(self):
        if not self.has_default:
            return "required" if self.required else "none"
        if isinstance(self.default, bool):
            return f"`{str(self.default).lower()}`"
        if isinstance(self.default, str):
            return "`'" + self.default.replace("'", "''") + "'`"
        return f"`{self.default}`"

    def description_cell(self):
        return html.escape(self.description, quote=False).replace("|", "\\|")

    def row(self):
        description = self.description_cell()
        return (
            f"| `{self.name}` | {self.type} | {self.default_cell()} | {description} |"
        )


class Table:
    def __init__(self, header, rows):
        self.header = header
        self.rows = rows


def usage_text():
    return (
        "Usage: check-workflow-docs.py [--map FILE] [--workflows-dir DIR] [--docs-dir DIR] [--regenerate]\n"
        "\n"
        "Fail when a workflow_call input table in docs/workflows differs from its workflow YAML\n"
        "in names, order, types, defaults or descriptions. A page may split a workflow into\n"
        "several tables: each keeps workflow order and together they list every input once.\n"
        "Each map line is\n"
        "'<workflow.yml> <page.md> [section heading]'.\n"
        "\n"
        "Options:\n"
        "  --map FILE           Workflow to page map (default: scripts/workflow-docs.map)\n"
        "  --workflows-dir DIR  Workflow files (default: .github/workflows)\n"
        "  --docs-dir DIR       Docs pages (default: docs/workflows)\n"
        "  --regenerate         Print the tables from the YAML, one per existing table, and exit\n"
        "  -h, --help           Show this help message"
    )


def load_inputs(path):
    document = yaml.safe_load(path.read_text())
    trigger = document.get("on", document.get(True)) or {}
    call = trigger.get("workflow_call") if isinstance(trigger, dict) else None
    specs = (call or {}).get("inputs") or {}
    return [Input(name, spec or {}) for name, spec in specs.items()]


def load_map(path):
    entries = []
    for line in path.read_text().splitlines():
        if line.strip():
            fields = line.split(None, 2)
            entries.append(
                (fields[0], fields[1], fields[2] if len(fields) > 2 else None)
            )
    return entries


def section_lines(text, heading):
    lines = text.splitlines()
    if heading is None:
        return lines
    start = None
    for index, line in enumerate(lines):
        match = HEADING.match(line)
        if start is None:
            if match and match.group(2) == heading:
                start, level = index + 1, len(match.group(1))
        elif match and len(match.group(1)) <= level:
            return lines[start:index]
    return [] if start is None else lines[start:]


def parse_tables(lines):
    tables, current = [], None
    for line in lines:
        if not line.startswith("|"):
            current = None
        elif current is None:
            current = Table(line, [])
            tables.append(current)
        elif not line.startswith("|--"):
            current.rows.append(line)
    return tables


def render_table(inputs):
    return "\n".join([HEADER, SEPARATOR] + [item.row() for item in inputs])


def cells(row):
    match = ROW.match(row)
    return match.groups() if match else None


def row_name(row):
    parsed = cells(row)
    return parsed[0] if parsed else None


def partition(inputs, tables):
    if not tables:
        return [inputs]
    names = [{row_name(row) for row in table.rows} for table in tables]
    chunks = [
        [item for item in inputs if item.name in table_names] for table_names in names
    ]
    chunks[-1] += [
        item
        for item in inputs
        if not any(item.name in table_names for table_names in names)
    ]
    return chunks


def compare_row(label, item, row):
    name, type_, default, description = cells(row)
    problems = []
    for field, expected, actual in (
        ("type", item.type, type_),
        ("default", item.default_cell(), default),
        ("description", item.description_cell(), description),
    ):
        if expected != actual:
            problems.append(
                f"{label}: {field} is {actual!r}, workflow has {expected!r}"
            )
    return problems


def compare(label, inputs, tables):
    problems = []
    by_name = {item.name: item for item in inputs}
    position = {item.name: index for index, item in enumerate(inputs)}
    seen = set()
    for table in tables:
        if table.header != HEADER:
            problems.append(f"{label}: header is {table.header!r}, expected {HEADER!r}")
        previous = -1
        for row in table.rows:
            name = row_name(row)
            if name is None:
                problems.append(
                    f"{label}: row is not in `name | type | default | description` form: {row}"
                )
                continue
            if name not in by_name:
                problems.append(f"{label}: row has no input in the workflow: {row}")
                continue
            if name in seen:
                problems.append(f"{label}: input {name} is listed twice")
            seen.add(name)
            if position[name] < previous:
                problems.append(f"{label}: input {name} is out of workflow order")
            previous = position[name]
            problems += compare_row(f"{label} input {name}", by_name[name], row)
    for item in inputs:
        if item.name not in seen:
            problems.append(f"{label}: input {item.name} is missing from the tables")
    return problems


def check(entries, workflows_dir, docs_dir):
    problems, mapped = [], {entry[0] for entry in entries}
    for path in sorted(workflows_dir.glob("*.yml")):
        if path.name not in mapped and load_inputs(path):
            problems.append(
                f"{path.name}: has workflow_call inputs but no line in the map"
            )
    for workflow, page, heading in entries:
        label = f"{workflow} -> {page}" + (f" [{heading}]" if heading else "")
        path = workflows_dir / workflow
        if not path.exists() or not (docs_dir / page).exists():
            problems.append(f"{label}: workflow or page does not exist")
            continue
        tables = parse_tables(section_lines((docs_dir / page).read_text(), heading))
        problems += compare(label, load_inputs(path), tables)
    return problems


def regenerate(entries, workflows_dir, docs_dir):
    for workflow, page, heading in entries:
        inputs = load_inputs(workflows_dir / workflow)
        tables = parse_tables(section_lines((docs_dir / page).read_text(), heading))
        print(f"=== {page} {heading or ''}".rstrip())
        for chunk in partition(inputs, tables):
            print(render_table(chunk))
            print()


def main(argv):
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument(
        "--map", type=Path, default=ROOT / "scripts" / "workflow-docs.map"
    )
    parser.add_argument(
        "--workflows-dir", type=Path, default=ROOT / ".github" / "workflows"
    )
    parser.add_argument("--docs-dir", type=Path, default=ROOT / "docs" / "workflows")
    parser.add_argument("--regenerate", action="store_true")
    parser.add_argument("-h", "--help", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit:
        print(usage_text(), file=sys.stderr)
        return 1
    if args.help:
        print(usage_text())
        return 0
    entries = load_map(args.map)
    if args.regenerate:
        regenerate(entries, args.workflows_dir, args.docs_dir)
        return 0
    problems = check(entries, args.workflows_dir, args.docs_dir)
    for problem in problems:
        print(f"FAIL: {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
