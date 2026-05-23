# Tests

This folder is for workbench verification helpers and tests.

Current validation is script-based:

- Parse all JSON files.
- Parse all PowerShell scripts.
- Validate global Skills with `quick_validate.py`.
- Run focused script checks such as snapshots, Unity log parsing, and project index validation.

Unity project tests are run through `scripts/run-unity-tests.ps1` against the linked external project source paths.
