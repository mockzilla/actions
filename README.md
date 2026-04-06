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
    memory: 256              # optional, in 128 MB increments
    timeout: 10000           # optional, in milliseconds
```

---

## mockzilla/actions/codegen@v1

Builds and publishes a codegen server to Mockzilla.

```yaml
- uses: mockzilla/actions/codegen@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    region: us-east-1       # optional
    memory: 256              # optional, in 128 MB increments
    timeout: 10000           # optional, in milliseconds
```

---

## Inputs

Both actions accept the same inputs:

| Input | Required | Description |
|---|---|---|
| `token` | yes | `GITHUB_TOKEN` — used to verify repo identity |
| `region` | no | Preferred AWS region (e.g. `us-east-1`, `ap-southeast-1`). Used as a hint on first deploy only — if the region is at capacity, the nearest available one is used instead. Has no effect after the simulation is already deployed. |
| `memory` | no | Memory allocated to the simulation in megabytes, in 128 MB increments (e.g. `128`, `256`, `512`). |
| `timeout` | no | Request timeout for the running simulation in milliseconds (e.g. `5000`, `10000`). |
| `timeout-minutes` | no | Maximum minutes the action will poll for the simulation to become active before failing the workflow step. Defaults to `5`. |

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
- `https://api.mockzilla.org/{org}/{repo}/` — main branch
- `https://api.mockzilla.org/{org}/{repo}/pr-{n}/` — per PR (where supported)
