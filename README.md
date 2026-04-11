# Mockzilla/actions

GitHub Actions for [Mockzilla](https://mockzilla.org) — instant API simulation from your OpenAPI specs.

---

## mockzilla/actions/portable@v1

Publishes `openapi/` and `static/` specs to Mockzilla.

```yaml
- uses: mockzilla/actions/portable@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    region: us-east-1       # optional
    memory-size: 256         # optional, in MB (default: 128)
    timeout: 60              # optional, in seconds
    environment: '{"ENV":"production","DEBUG":"true"}'  # optional
    host: api.mockzilla.net   # optional, defaults to org setting
    spec-dir: openapi        # optional, defaults to 'openapi'
    static-dir: static       # optional, defaults to 'static'
```

---

## mockzilla/actions/codegen@v1

Builds and publishes a codegen server to Mockzilla.

```yaml
- uses: mockzilla/actions/codegen@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    region: us-east-1       # optional
    memory-size: 256         # optional, in MB (default: 128)
    timeout: 60              # optional, in seconds
    environment: '{"ENV":"production","DEBUG":"true"}'  # optional
    host: api.mockzilla.net   # optional, defaults to org setting
```

---

## Inputs

Both actions accept the same inputs:

| Input | Required | Description |
|---|---|---|
| `token` | yes | `GITHUB_TOKEN` — used to verify repo identity |
| `region` | no | Preferred AWS region (e.g. `us-east-1`, `ap-southeast-1`). Used as a hint on first deploy only — if the region is at capacity, the nearest available one is used instead. Has no effect after the simulation is already deployed. |
| `memory-size` | no | Memory allocated to the simulation in megabytes (e.g. `128`, `256`, `512`). Defaults to `128`. |
| `timeout` | no | Request timeout for the simulation in seconds (e.g. `30`, `60`). |
| `environment` | no | JSON object of environment variables to set in the simulation (e.g. `'{"ENV":"production"}'`). |
| `host` | no | API host for the simulation URL. One of `api.mockzilla.org`, `api.mockzilla.de`, or `api.mockzilla.net`. Defaults to the org setting (or `api.mockzilla.org` if not set). |
| `timeout-minutes` | no | Maximum minutes the action will poll for the simulation to become active before failing the workflow step. Defaults to `5`. |

**Portable-only inputs:**

| Input | Required | Description |
|---|---|---|
| `spec-dir` | no | Directory containing OpenAPI specs. Defaults to `openapi`. |
| `static-dir` | no | Directory containing static API responses. Defaults to `static`. |

---

## Full workflow example

```yaml
name: mockzilla

on:
  push:
    branches: [main]
  pull_request:

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: mockzilla/actions/portable@v1   # or codegen@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

Your API simulation will be live at:
- `https://api.mockzilla.org/gh/{org}/{repo}/` — main branch
- `https://api.mockzilla.org/gh/{org}/{repo}/pr-{n}/` — per PR (where supported)

---

## Outputs

| Output | Description |
|---|---|
| `url` | The live simulation URL |

Use in a subsequent step:

```yaml
- uses: mockzilla/actions/portable@v1
  id: mockzilla
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
- run: echo "${{ steps.mockzilla.outputs.url }}"
```

---

## Check from the CLI

Get your simulation URL without leaving the terminal:

```bash
gh run view --exit-status && echo "https://api.mockzilla.org/gh/$(gh repo view --json nameWithOwner -q .nameWithOwner)/$(git branch --show-current)/"
```
