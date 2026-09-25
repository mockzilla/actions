# mockzilla/actions

GitHub Actions for [Mockzilla](https://mockzilla.org/) - instant API simulation from your OpenAPI specs on every push and pull request. Per-PR preview URLs, zero infrastructure required beyond `GITHUB_TOKEN`.

---

## mockzilla/actions@v1

Publishes per-service OpenAPI/static mocks to Mockzilla. Each
`services/<name>/` folder becomes one service.

```yaml
- uses: mockzilla/actions@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    region: us-east-1        # optional
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
| `environment` | no | JSON object of environment variables to set in the simulation (e.g. `'{"ENV":"production"}'`). |
| `host` | no | Where the simulation answers: an API host (`api.mockz.io`, `api.mockz.net`, `api.mockz.org`, `api.mockzilla.org`, `api.mockzilla.de` or `api.mockzilla.net`), or a host for the simulation on one of them (`petstore.api.mockz.io`), which asks for that label. Fixed at the first deploy. Defaults to the org setting (or `api.mockz.io` if not set), with the repo name as the label. |
| `basic-auth-user` | no | Username for HTTP Basic Auth on the API Explorer UI. Set together with `basic-auth-password`. Empty leaves the UI open. |
| `basic-auth-password` | no | Password for the API Explorer Basic Auth. Pass a GitHub secret. Stored hashed, never logged. |
| `allowed-ips` | no | JSON array of CIDRs allowed to reach this simulation, e.g. `'["203.0.113.0/24"]'`. Ignored with a warning when the org's plan allows no IP allowlist. |
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
    types: [opened, synchronize, reopened, closed]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: mockzilla/actions@v1   # or mockzilla/actions/codegen@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

`closed` has to be listed. GitHub's default activity types for `pull_request` are
`opened`, `synchronize` and `reopened`, so a workflow that says only `pull_request:`
never runs when a PR closes and its deployment is never torn down.

Your API simulation answers at a host of its own, on `api.mockz.io` or the API host you picked:
- `https://{label}.api.mockz.io`: default branch
- `https://{label}-pr{number}.api.mockz.io`: a pull request, for as long as it is open
- `https://{label}-{branch}.api.mockz.io`: a push to any other branch your workflow lists

The label is the repo name as a host name: lowercase, with anything else turned
into `-` (`My_Repo` becomes `my-repo`), up to 55 characters, and `-2`, `-3` if it
is taken. A label never ends in `-pr` and digits, which is kept for pull requests.
To ask for another, set the `host` input before the first deploy.

A pull request deploys under its number, so its branch can be called anything,
`feature/checkout` included. A branch deployed on push has its name in its host,
lowercased, with everything but letters and digits removed: a push to
`feature/checkout` on `petstore` answers at `https://petstore-featurecheckout.api.mockz.io`.
Branches deploy on plans with PR environments and count toward the same limit.

A push to a branch fails, and says why, when:
- its name has no letters or digits,
- its name reads as a pull request, `pr` and digits (`pr-12`),
- `{label}-{branch}` is longer than 63 characters,
- another live branch gets the same host (`feature/x` and `feature-x`),
- another simulation already answers at that host. Rename the branch.

---

## Outputs

| Output | Description |
|---|---|
| `url` | The live simulation URL |

Use in a subsequent step:

```yaml
- uses: mockzilla/actions@v1
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
      - uses: mockzilla/actions@v1   # or mockzilla/actions/codegen@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          delete: true
```

---

## Check from the CLI

Get the simulation URL of the current branch's pull request without leaving the terminal. It reads
the URL from the action's comment on the pull request:

```bash
gh run view --exit-status && gh pr view --json comments -q '.comments[].body' | grep -o 'simulation live at [^ ]*' | tail -1 | cut -d' ' -f4
```
