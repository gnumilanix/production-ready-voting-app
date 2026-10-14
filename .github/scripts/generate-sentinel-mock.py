#!/usr/bin/env python3
"""Generate a tfplan/v2 mock module for the Sentinel simulator from a
`terraform show -json` plan file.

Usage: generate-sentinel-mock.py <plan-json> <output-file>
"""
import json
import sys


def main() -> None:
    plan_path, out_path = sys.argv[1], sys.argv[2]
    with open(plan_path) as f:
        plan = json.load(f)

    keys = ("resource_changes", "variables", "configuration")
    with open(out_path, "w") as f:
        for key in keys:
            f.write(f"{key} = {json.dumps(plan.get(key, {} if key != 'resource_changes' else []))}\n")


if __name__ == "__main__":
    main()
