# Security Policy

## Reporting a vulnerability

Please do **not** open a public issue for a security vulnerability. Report it
privately to the maintainers.

- **Email:** salanazy@smu.edu
- **GitHub:** open a private vulnerability report, or reach out to
  [@drsultan2008](https://github.com/drsultan2008).

Please include:

1. A description of the vulnerability and its impact.
2. Steps to reproduce.
3. Affected version(s) / commit hash if known.
4. Any suggested remediation.

We'll acknowledge receipt within a few days and keep you updated on the fix.

## Security notes for this project

- **GitHub tokens** are stored in the iOS Keychain (`Services/TokenStore.swift`)
  and are never logged or written to disk outside the Keychain.
- The app talks to the GitHub REST API over **HTTPS** only.
- Secrets must never be committed to the repository. Keep them in the Keychain
  or in environment variables for CI, not in source files.
