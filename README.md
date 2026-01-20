# Create Git Tag for Branch GitHub Action

This GitHub Action creates a git tag on a specific branch using the GitHub REST API and PowerShell.  
It is designed to be simple, composable, and independent of the local git state.

## Features

- Creates an annotated git tag in your repository using the REST API (no dependencies on local git or CLI).
- Lets you specify the target branch, tag name, and tag message.
- Allows you to specify a commit SHA to tag if needed.
- Fully supports GitHub Organizations and user-owned repositories.
- Outputs the tag creation result and error message (if any) for use in subsequent workflow steps.
- Designed for secure automation with the minimal required token permissions.

## Inputs

| Name           | Description                                                     | Required | Default |
|----------------|-----------------------------------------------------------------|----------|---------|
| `branch-name`  | Branch name on which to create the tag (e.g., `main`)           | Yes      |         |
| `tag-name`     | Name of the tag to create                                       | Yes      |         |
| `tag-message`  | Tag message (optional)                                          | No       | `''`    |
| `commit-sha`   | A commit SHA to tag (optional). If empty, default is branch head. | No       | `''`    |
| `org-name`     | The name of the GitHub organization                             | Yes      |         |
| `repo-name`    | The name of the repository                                      | Yes      |         |
| `token`        | GitHub token with access to Git tags                            | Yes      |         |

## Outputs

| Name            | Description                                                    |
|-----------------|---------------------------------------------------------------|
| `result`        | Result of the tag creation attempt (`success` or `failure`)    |
| `error-message` | Error message if tag creation failed                          |

## Usage

Create a workflow file in your repository (e.g., `.github/workflows/create-tag.yml`).  
**Ensure you pass all required inputs and use a valid token with tag write access.**

### Example Workflow

```yaml
name: Create Git Tag
on:
  workflow_dispatch:

jobs:
  create-tag:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v5

      - name: Create Git Tag via API
        id: create-tag
        uses: lee-lott-actions/create-git-tag@v1
        with:
          branch-name: 'main'
          tag-name: 'v1.0.0'
          tag-message: 'Release v1.0.0'
          commit-sha: 'abcdef12345'
          repo-name: ${{ github.event.repository.name }}
          org-name: ${{ github.repository_owner }}
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Output Tag Result
        run: |
          echo "Tag Result: ${{ steps.create-tag.outputs.result }}"
          echo "Error Message: ${{ steps.create-tag.outputs.error-message }}"
```
