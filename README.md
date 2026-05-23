# mockzilla/actions

GitHub Actions for [Mockzilla](https://mockzilla.org/) - instant API simulation from your OpenAPI specs on every push and pull request. Per-PR preview URLs, zero infrastructure required beyond `GITHUB_TOKEN`.

---

## mockzilla/actions/portable@v1

Publishes per-service OpenAPI/static mocks to Mockzilla. Each
`services/<name>/` folder becomes one service.

```yaml
- uses: mockzilla/actions/portable@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    region: us-east-1        # optional
    memory-size: 256         # optional, in MB (default: 128)
    timeout: 60              # optional, in seconds
    environment: '{"ENV":"production","DEBUG":"true"}'  # optional
    host: api.mockzilla.net  # optional, defaults to org setting
    services-dir: services   # optional, defaults to 'services'
```

Expected repo layout:

```
services/
  petstore/
    openapi.yml          # any *.{yml,yaml,json} works; `openapi.*` is canonical
    config.yml           # optional: latency, errors, mount, upstream
    context.yml          # optional: flat replacement values
    static/              # optional: pre-canned responses
      get/users/index.json
app.yml                  # optional: global app settings (port, history, etc.)
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
| `token` | yes | `GITHUB_TOKEN`, used to verify repo identity. |
| `region` | no | Preferred AWS region (e.g. `us-east-1`, `ap-southeast-1`). Used as a hint on first deploy only. If the region is at capacity, the nearest available one is used instead. Has no effect after the simulation is already deployed. |
| `memory-size` | no | Memory allocated to the simulation in megabytes (e.g. `128`, `256`, `512`). Defaults to `128`. |
| `timeout` | no | Request timeout for the simulation in seconds (e.g. `30`, `60`). |
| `environment` | no | JSON object of environment variables to set in the simulation (e.g. `'{"ENV":"production"}'`). |
| `host` | no | API host for the simulation URL. One of `api.mockzilla.org`, `api.mockzilla.de`, or `api.mockzilla.net`. Defaults to the org setting (or `api.mockzilla.org` if not set). |
| `timeout-minutes` | no | Maximum minutes the action will poll for the simulation to become active before failing the workflow step. Defaults to `5`. |
| `delete` | no | Remove this repository from Mockzilla. When set to `true`, the action skips publishing and deletes all mock APIs for this repo. Useful on the free plan to free up your slot before connecting a different repository. Defaults to `false`. |

**Portable-only inputs:**

| Input | Required | Description |
|---|---|---|
| `services-dir` | no | Directory containing per-service folders. Defaults to `services`. |

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
- `https://api.mockzilla.org/gh/{org}/{repo}/`: main branch
- `https://api.mockzilla.org/gh/{org}/{repo}/pr-{n}/`: per PR (where supported)

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

## Removing a repository from Mockzilla

On the free plan you can only have one repository connected to Mockzilla at
a time. If you want to try a different repository, run the action with
`delete: true` on the old one first. This removes all its mock APIs from
Mockzilla and frees the spot so you can publish from another repo.

```yaml
name: mockzilla-remove

on:
  workflow_dispatch:

jobs:
  remove:
    runs-on: ubuntu-latest
    steps:
      - uses: mockzilla/actions/portable@v1   # or codegen@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          delete: true
```

---

## Check from the CLI

Get your simulation URL without leaving the terminal:

```bash
gh run view --exit-status && echo "https://api.mockzilla.org/gh/$(gh repo view --json nameWithOwner -q .nameWithOwner)/$(git branch --show-current)/"
```
