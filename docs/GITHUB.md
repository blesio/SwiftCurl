# GitHub Publishing

This repository can be published with the GitHub CLI once authentication is available.

## First-Time Login

```bash
gh auth login
```

## Create And Push A New Repository

From the project root:

```bash
gh repo create SwiftCurl --source=. --private --push
```

Use `--public` instead of `--private` if the repository should be public.

## Push To An Existing Repository

```bash
git remote add origin git@github.com:OWNER/SwiftCurl.git
git push -u origin main
```

Replace `OWNER` with the GitHub account or organization.
