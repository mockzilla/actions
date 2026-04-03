# Mockzilla/actions

GitHub Actions for [Mockzilla](https://mockzilla.org) — instant API simulation from your OpenAPI specs.

---

## mockzilla/actions/portable@v1

Publishes `openapi/` and `static/` specs to Mockzilla.

```yaml
- uses: mockzilla/actions/portable@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
```

---

## mockzilla/actions/codegen@v1

Builds and publishes a codegen server to Mockzilla.

```yaml
- uses: mockzilla/actions/codegen@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
```

---

## Inputs

Both actions accept the same inputs:

| Input | Required | Default | Description |
|---|---|---|---|
| `token` | yes | — | `GITHUB_TOKEN` — used to verify repo identity |
| `url` | no | `https://ingest.mockzilla.org/webhook` | Override for self-hosted or staging |

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
