# Educational Use Guide

This guide is for educators who want to provide GitHub Gist creation functionality to their students with improved rate limits.

## Overview

TStorie can use a GitHub Personal Access Token to create gists on behalf of students, providing higher rate limits for classroom use. However, this must be implemented carefully to minimize security risks.

## ⚠️ Important Security Warnings

**Before proceeding, understand these risks:**

1. **The token will be compiled into the WebAssembly binary** - Tech-savvy students can extract it using browser developer tools or WASM decompilers
2. **Students could potentially abuse the token** - They could create gists outside your controlled environment
3. **The token represents YOUR GitHub account** - Any gists created will be associated with your credentials
4. **This approach is NOT suitable for public hosting** - Never use this method on public GitHub Pages or publicly accessible servers

## When to Use This Approach

✅ **Appropriate scenarios:**
- Local classroom server (not internet-accessible)
- Private LAN deployment in computer lab
- Short-duration workshops or courses
- Controlled educational environments

❌ **Do NOT use for:**
- Public GitHub Pages deployments
- Internet-facing servers
- Long-term production use
- Environments where students are untrusted

## Setup Instructions

### Step 1: Create a Fine-Grained Personal Access Token

1. Go to [GitHub Settings > Developer settings > Personal access tokens > Fine-grained tokens](https://github.com/settings/tokens?type=beta)
2. Click **"Generate new token"**
3. Configure the token:
   - **Token name**: Use a descriptive name like `TStorie-Fall2025` or `Programming-Workshop-Jan2026`
   - **Expiration**: Set to match your course duration (30, 60, or 90 days) - NEVER "No expiration"
   - **Repository access**: Select "Public repositories (read-only)" or "All repositories" (read-only)
   - **Permissions**: Under "Account permissions", set:
     - **Gists**: Read and write access
     - All other permissions: No access (leave unchecked)
4. Click **"Generate token"**
5. **Copy the token immediately** - you won't be able to see it again

### Step 2: Add Token as GitHub Repository Secret

1. In your **private** TStorie repository, go to **Settings > Secrets and variables > Actions**
2. Click **"New repository secret"**
3. Configure the secret:
   - **Name**: `GITHUB_TOKEN` (or your preferred name)
   - **Value**: Paste the token you copied
4. Click **"Add secret"**

### Step 3: Update GitHub Actions Workflow

Modify your `.github/workflows/build.yml` (or relevant workflow file) to inject the token during compilation:

```yaml
- name: Build WebAssembly
  env:
    GITHUB_API_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    nim c -d:js -d:githubToken="$GITHUB_API_TOKEN" index.nim
```

### Step 4: Update Your Code

In your Nim code, add support for the compile-time token:

```nim
import std/os

# Compile-time token (from GitHub Actions)
const githubTokenCompiled {.strdefine.} = ""

# Runtime token (from environment variable for native builds)
proc getGithubToken(): string =
  # Check for runtime environment variable first (native builds)
  let envToken = getEnv("GITHUB_TOKEN")
  if envToken != "":
    return envToken
  
  # Fall back to compile-time token (WASM builds)
  if githubTokenCompiled != "":
    return githubTokenCompiled
  
  return ""

# Use the token
let token = getGithubToken()
if token != "":
  # Token available - use for GitHub API calls
  echo "Using authenticated GitHub API access"
else:
  # No token - use anonymous access (lower rate limits)
  echo "Using anonymous GitHub API access"
```

### Step 5: Deploy Privately

**Deploy your built TStorie instance to a private, local server only:**

- Use a local web server on your classroom network
- Use password protection or network-level access controls
- Do NOT deploy to GitHub Pages
- Do NOT expose to the public internet

## Monitoring and Maintenance

### During Your Course

1. **Monitor token usage**: Check GitHub Settings > Developer settings > Personal access tokens for activity
2. **Watch for abuse**: Review gists created under your account periodically
3. **Be prepared to revoke**: If you suspect misuse, revoke the token immediately

### After Your Course

1. **Revoke the token**: Go to GitHub Settings > Developer settings > Personal access tokens
2. Find your token and click **"Revoke"**
3. Confirm revocation

## Alternative Approaches (More Secure)

If the above security trade-offs are unacceptable, consider these alternatives:

### 1. Student Personal Tokens
- Have each student create their own GitHub account (free)
- Students generate their own personal access tokens with gist scope
- Students set their tokens as environment variables locally
- Pros: No shared credentials, no abuse risk
- Cons: Requires GitHub accounts, more setup per student

### 2. Server-Side Proxy (Recommended for Production)
- Set up a simple backend service (Cloudflare Worker, Netlify Function, etc.)
- Backend holds the token securely
- Frontend makes requests to your backend, which proxies to GitHub
- Pros: Token never exposed to clients
- Cons: Requires additional infrastructure

### 3. Anonymous Access Only
- Don't use a token at all
- Accept GitHub's anonymous rate limits (60 requests/hour per IP)
- Pros: Zero security risk
- Cons: Rate limits may be insufficient for larger classes

## Example: Native Build with Environment Variable

For native (non-WASM) builds, educators can use environment variables instead:

```bash
# Linux/macOS
export GITHUB_TOKEN="ghp_your_token_here"
./tstorie

# Windows (PowerShell)
$env:GITHUB_TOKEN="ghp_your_token_here"
.\tstorie.exe

# Windows (Command Prompt)
set GITHUB_TOKEN=ghp_your_token_here
tstorie.exe
```

This approach is safer for native builds since the token isn't compiled into the binary.

## FAQ

**Q: Can students see the token in the GitHub Actions logs?**  
A: No. GitHub automatically masks secrets in action logs.

**Q: What if a student extracts the token from WASM?**  
A: They would only have gist creation access with the limited scope you set. Monitor your gists and revoke the token if you see abuse. This is why expiration dates are critical.

**Q: Can I use this on a public website?**  
A: **No.** The token would be publicly accessible to anyone who visits the site.

**Q: How many students can share one token?**  
A: GitHub's rate limit for authenticated requests is 5,000 requests per hour. For gist creation specifically, there are no documented hard limits, but reasonable use (a few gists per student per session) should be fine for classrooms of 20-50 students.

**Q: What happens when the token expires?**  
A: Gist creation will stop working. You'll need to generate a new token and rebuild/redeploy.

## Summary Checklist

- [ ] Created fine-grained token with ONLY gist access
- [ ] Set expiration date matching course duration
- [ ] Added token as GitHub Repository Secret (NOT in code)
- [ ] Updated build workflow to inject token at compile-time
- [ ] Deploying ONLY to private/local environment
- [ ] Plan to revoke token after course ends
- [ ] Communicated risks to institution/department if required

---

**Remember**: This approach trades security for convenience. It's suitable for controlled educational environments but NOT for production use. Always use the minimum permissions necessary and set appropriate expiration dates.
