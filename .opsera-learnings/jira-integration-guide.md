# Opsera Session Learnings & Implementation Guide

> **Generated:** 2026-02-03
> **Last Updated:** 2026-02-03
> **Application:** voting01
> **Environment:** dev

---

## Table of Contents

1. [Complete Session History](#complete-session-history)
2. [Overview](#overview)
3. [Issues Encountered & Fixes](#issues-encountered--fixes)
4. [Secrets Configuration](#secrets-configuration)
5. [Jira Authentication Methods](#jira-authentication-methods)
6. [Workflow Templates](#workflow-templates)
7. [YAML Best Practices](#yaml-best-practices)
8. [Testing & Verification](#testing--verification)
9. [Changelog](#changelog)
10. [How to Update This Guide](#how-to-update-this-guide)

---

## Complete Session History

This section captures all work done during the session, organized chronologically.

### Phase 1: Initial Deployment State & UI Changes

| Commit | Description |
|--------|-------------|
| `b617d43` | Added rounded corners to voting buttons |
| `f6487b9` | Added 2mm golden border to vote buttons |

**Files Modified:**
- `vote/templates/index.html`
- `vote/static/stylesheets/style.css`

### Phase 2: Deployment Landscape Enhancements

| Commit | Description |
|--------|-------------|
| `772b13f` | Added Application Architecture & CI/CD Pipeline Flow diagrams (Mermaid) |
| `66dc530` | Fixed GITHUB_STEP_SUMMARY heredoc escaping issues |
| `db5b8fd` | Added last 5 deployments history for each environment |
| `885ac64` | Fixed delimiter parsing in deployment history |
| `c1d5721` | Added author name and relative time to deployment history |
| `dfd2afd` | Added Last Deploy Status visualization with Jira integration |

**Key Features Added:**
- Mermaid diagrams for architecture visualization
- Deployment history with author correlation
- Relative timestamps ("2 hours ago")
- Fixed `github-actions[bot]` showing as author → now shows actual code author

**Author Correlation Fix:**
```bash
# Extract source commit SHA from image tag (format: sha-timestamp)
SOURCE_SHA=$(echo "$MSG" | cut -d'-' -f1)
# Look up original commit author
AUTHOR=$(git log -1 --format="%an" "$SOURCE_SHA" 2>/dev/null || echo "Unknown")
```

### Phase 3: Jira Integration

| Commit | Description |
|--------|-------------|
| `8b59d3d` | Created test Jira integration workflow with API v2 support |
| `cdb86a0` | Added API key authentication for mock Jira |
| `9d3579c` | Fixed AUTH_HEADER passing, use discovered project key |
| `c66eba4` | Updated Jira integration for mock Jira compatibility |
| `35173c0` | Fixed YAML syntax with heredoc for multi-line strings |
| `8c9989f` | Added Jira ticket creation for SonarQube quality gate failures |
| `adc6e65` | Fixed capturing SonarQube scan failures |

**Key Learnings:**
- Mock Jira uses API key auth (`X-API-Key` header), not Basic auth
- API v2 uses plain text descriptions, v3 uses ADF format
- Use `steps.scan.outcome` not `job.result` when `continue-on-error: true`
- Rebuild AUTH_HEADER in each step (don't pass via GITHUB_ENV)

### Phase 4: Testing & Verification

| Commit | Description |
|--------|-------------|
| `809c1c2` | Version bump to v5 - test Jira integration |
| `7df6b85` | Version bump to v8 - test with secrets |
| `5f41090` | Version bump to v9 - test with JIRA_AUTH_TYPE=api-key |

**Infrastructure Fixes:**
| Commit | Description |
|--------|-------------|
| `a587f64` | Separate hosts for vote/result apps in Ingress |
| `8dfcd38` | Added Redis/Postgres endpoints to ConfigMap |

### Phase 5: Documentation

| Commit | Description |
|--------|-------------|
| `08923f6` | Created `.opsera-learnings/jira-integration-guide.md` (this file) |

### Summary of All Issues Resolved

| # | Issue | Root Cause | Fix |
|---|-------|------------|-----|
| 1 | YAML multi-line parsing error | Improper multi-line string syntax | Use heredoc syntax |
| 2 | Jira 401 "Not authenticated" | Mock Jira requires API key, not Basic auth | Add auth type detection |
| 3 | API v2 vs v3 format differences | v3 uses ADF, mock uses v2 plain text | Use API v2 |
| 4 | AUTH_HEADER not passing via GITHUB_ENV | Special characters (colons) cause issues | Rebuild in each step |
| 5 | SonarQube failure not triggering Jira | `continue-on-error` makes job result 'success' | Use `steps.scan.outcome` |
| 6 | Wrong project key (DEPLOY vs TEST) | Hardcoded key doesn't exist | Use configurable secret |
| 7 | Author showing as "github-actions[bot]" | Deploy commits are by bot | Extract source SHA from image tag |

### Files Modified in Session

| Category | Files |
|----------|-------|
| **Voting App UI** | `vote/templates/index.html`, `vote/static/stylesheets/style.css` |
| **CI/CD Pipeline** | `.github/workflows/ci-build-push-voting01-dev.yaml` |
| **Landscape Dashboard** | `.github/workflows/deployment-landscape-voting01.yaml` |
| **Jira Testing** | `.github/workflows/test-jira-integration.yaml` |
| **Documentation** | `.opsera-learnings/jira-integration-guide.md` |

---

---

## Overview

This document captures all learnings from implementing Jira integration in the CI/CD pipeline for automatic ticket creation on:
- SonarQube quality gate failures
- Security vulnerability findings
- Deployment failures

### Key Components

| Component | Purpose |
|-----------|---------|
| `test-jira-integration.yaml` | Standalone workflow to test Jira connectivity |
| `ci-build-push-voting01-dev.yaml` | Main pipeline with Jira ticket creation jobs |
| Mock Jira | `https://opsera-opserajira-dev.agent.opsera.dev` |

---

## Issues Encountered & Fixes

### Issue 1: YAML Multi-line String Parsing Error

**Problem:** Multi-line strings in `run:` blocks caused YAML parsing errors.

```yaml
# BAD - Causes YAML parsing error
run: |
  DESCRIPTION="Line 1

  Line 2
  Line 3"
```

**Error:**
```
yaml.parser.ParserError: while parsing a block mapping
expected <block end>, but found '<scalar>'
```

**Fix:** Use heredoc syntax with proper indentation:

```yaml
# GOOD - Proper heredoc syntax
run: |
  DESCRIPTION=$(cat << 'DESCEOF'
  Line 1

  Line 2
  Line 3
  DESCEOF
  )
```

---

### Issue 2: Mock Jira Authentication (401 Unauthorized)

**Problem:** Mock Jira uses API key authentication, not Basic auth.

**Error:**
```json
{"detail":"Not authenticated"}
```

**Root Cause:** The pipeline was using Basic auth (`Authorization: Basic base64(email:token)`) but mock Jira requires API key auth (`X-API-Key: <token>`).

**Fix:** Add auth type detection:

```yaml
env:
  JIRA_AUTH_TYPE: ${{ secrets.JIRA_AUTH_TYPE }}
  JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
run: |
  if [ "$JIRA_AUTH_TYPE" = "api-key" ]; then
    AUTH_HEADER="X-API-Key: ${JIRA_API_TOKEN}"
  else
    AUTH_HEADER="Authorization: Basic $(echo -n "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64)"
  fi
```

---

### Issue 3: Jira API v2 vs v3 Format Differences

**Problem:** Jira Cloud API v3 uses ADF (Atlassian Document Format) for descriptions, while mock Jira uses API v2 with plain text.

**API v3 (Jira Cloud):**
```json
{
  "fields": {
    "description": {
      "type": "doc",
      "version": 1,
      "content": [{"type": "paragraph", "content": [{"type": "text", "text": "..."}]}]
    }
  }
}
```

**API v2 (Mock Jira / Compatible):**
```json
{
  "fields": {
    "description": "Plain text description"
  }
}
```

**Fix:** Use API v2 with plain text for broader compatibility.

---

### Issue 4: AUTH_HEADER Not Passing via GITHUB_ENV

**Problem:** Storing `AUTH_HEADER` in `GITHUB_ENV` caused issues due to special characters (colons).

**Fix:** Rebuild the auth header in each step instead of passing via environment:

```yaml
# Each step that needs auth should rebuild the header
- name: Step 1
  env:
    JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
    JIRA_AUTH_TYPE: ${{ secrets.JIRA_AUTH_TYPE }}
  run: |
    if [ "$JIRA_AUTH_TYPE" = "api-key" ]; then
      AUTH_HEADER="X-API-Key: ${JIRA_API_TOKEN}"
    else
      AUTH_HEADER="Authorization: Basic $(echo -n "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64)"
    fi
    # Use AUTH_HEADER...
```

---

### Issue 5: SonarQube Failure Not Triggering Jira Job

**Problem:** SonarQube job has `continue-on-error: true`, so `needs.quality-sonarqube.result` returns `'success'` even when the scan fails.

**Fix:** Capture the step outcome as an output and check that instead:

```yaml
quality-sonarqube:
  outputs:
    scan_failed: ${{ steps.scan.outcome == 'failure' }}
  steps:
    - name: SonarQube Scan
      id: scan
      continue-on-error: true  # Allows workflow to continue
      uses: sonarsource/sonarqube-scan-action@master

# Then in the Jira job:
notify-jira-quality:
  needs: [quality-sonarqube]
  if: always() && (needs.quality-sonarqube.outputs.scan_failed == 'true' || needs.quality-sonarqube.outputs.quality_gate_status == 'ERROR')
```

---

### Issue 6: Wrong Project Key (DEPLOY vs TEST)

**Problem:** Hardcoded project key `DEPLOY` doesn't exist in mock Jira.

**Fix:** Make project key configurable via secret with fallback:

```yaml
env:
  JIRA_PROJECT: ${{ secrets.JIRA_PROJECT }}
run: |
  PROJECT_KEY="${JIRA_PROJECT:-TEST}"
```

---

## Secrets Configuration

### Required GitHub Secrets

| Secret | Value | Description |
|--------|-------|-------------|
| `JIRA_API_TOKEN` | `<your-api-key>` | API key from mock Jira settings |
| `JIRA_BASE_URL` | `https://opsera-opserajira-dev.agent.opsera.dev` | Mock Jira base URL |
| `JIRA_AUTH_TYPE` | `api-key` | Authentication method |
| `JIRA_PROJECT` | `TEST` | Project key for tickets |
| `JIRA_EMAIL` | `<email>` | (Optional) For Basic auth with Jira Cloud |

### How to Get Mock Jira API Key

1. Navigate to: `https://opsera-opserajira-dev.agent.opsera.dev/ui`
2. Sign in with Google OAuth
3. Go to Settings
4. Generate an API key
5. Copy and save as `JIRA_API_TOKEN` secret

---

## Jira Authentication Methods

### Method 1: API Key (Mock Jira)

```bash
curl -X POST \
  -H "X-API-Key: ${JIRA_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "${JIRA_BASE_URL}/rest/api/2/issue" \
  -d '{"fields": {...}}'
```

### Method 2: Basic Auth (Jira Cloud)

```bash
curl -X POST \
  -H "Authorization: Basic $(echo -n "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64)" \
  -H "Content-Type: application/json" \
  "${JIRA_BASE_URL}/rest/api/2/issue" \
  -d '{"fields": {...}}'
```

---

## Workflow Templates

### Template 1: Test Jira Integration Workflow

```yaml
# .github/workflows/test-jira-integration.yaml
name: "Test Jira Integration"

on:
  workflow_dispatch:
    inputs:
      test_type:
        description: 'Type of Jira ticket to create'
        type: choice
        options: ['security-vulnerability', 'deployment-failure', 'test-ticket']
        default: 'test-ticket'
      jira_url_override:
        description: 'Override JIRA_BASE_URL (leave empty to use secret)'
        type: string
        default: ''
      api_version:
        description: 'Jira API version'
        type: choice
        options: ['2', '3']
        default: '2'
      auth_type:
        description: 'Authentication type'
        type: choice
        options: ['basic', 'api-key']
        default: 'basic'

jobs:
  test-jira:
    name: "Test Jira"
    runs-on: ubuntu-latest
    steps:
      - name: Check Jira Configuration
        id: check-jira
        run: |
          CONFIGURED="true"
          if [ -z "${{ secrets.JIRA_API_TOKEN }}" ]; then
            CONFIGURED="false"
          fi
          echo "configured=${CONFIGURED}" >> $GITHUB_OUTPUT

      - name: Test Jira API Connection
        if: steps.check-jira.outputs.configured == 'true'
        env:
          JIRA_EMAIL: ${{ secrets.JIRA_EMAIL }}
          JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
          JIRA_BASE_URL_SECRET: ${{ secrets.JIRA_BASE_URL }}
          JIRA_URL_OVERRIDE: ${{ github.event.inputs.jira_url_override }}
          API_VERSION: ${{ github.event.inputs.api_version }}
          AUTH_TYPE: ${{ github.event.inputs.auth_type }}
        run: |
          # Use override URL if provided
          if [ -n "$JIRA_URL_OVERRIDE" ]; then
            JIRA_BASE_URL="$JIRA_URL_OVERRIDE"
          else
            JIRA_BASE_URL="$JIRA_BASE_URL_SECRET"
          fi

          # Set auth header
          if [ "$AUTH_TYPE" = "api-key" ]; then
            AUTH_HEADER="X-API-Key: ${JIRA_API_TOKEN}"
          else
            AUTH_HEADER="Authorization: Basic $(echo -n "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64)"
          fi

          # Test connection
          RESPONSE=$(curl -s -w "\n%{http_code}" \
            -H "${AUTH_HEADER}" \
            -H "Content-Type: application/json" \
            "${JIRA_BASE_URL}/rest/api/${API_VERSION}/project")

          HTTP_CODE=$(echo "$RESPONSE" | tail -1)

          if [ "$HTTP_CODE" = "200" ]; then
            echo "API Connection: Success"
            echo "JIRA_BASE_URL=${JIRA_BASE_URL}" >> $GITHUB_ENV
          else
            echo "API Connection: Failed (HTTP $HTTP_CODE)"
            exit 1
          fi

      - name: Create Test Ticket
        if: steps.check-jira.outputs.configured == 'true'
        env:
          JIRA_EMAIL: ${{ secrets.JIRA_EMAIL }}
          JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
          API_VERSION: ${{ github.event.inputs.api_version }}
          AUTH_TYPE: ${{ github.event.inputs.auth_type }}
          JIRA_PROJECT: ${{ secrets.JIRA_PROJECT }}
        run: |
          # Rebuild auth header
          if [ "$AUTH_TYPE" = "api-key" ]; then
            AUTH_HEADER="X-API-Key: ${JIRA_API_TOKEN}"
          else
            AUTH_HEADER="Authorization: Basic $(echo -n "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64)"
          fi

          PROJECT_KEY="${JIRA_PROJECT:-TEST}"
          TIMESTAMP=$(date -u +'%Y-%m-%d %H:%M UTC')

          PAYLOAD=$(jq -n \
            --arg project "$PROJECT_KEY" \
            --arg summary "[TEST] Jira Integration Test - ${TIMESTAMP}" \
            --arg description "Test ticket from CI/CD pipeline" \
            '{
              "fields": {
                "project": {"key": $project},
                "summary": $summary,
                "description": $description,
                "issuetype": {"name": "Task"},
                "priority": {"name": "Medium"}
              }
            }')

          RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
            -H "${AUTH_HEADER}" \
            -H "Content-Type: application/json" \
            "${JIRA_BASE_URL}/rest/api/${API_VERSION}/issue" \
            -d "$PAYLOAD")

          HTTP_CODE=$(echo "$RESPONSE" | tail -1)
          BODY=$(echo "$RESPONSE" | sed '$d')
          ISSUE_KEY=$(echo "$BODY" | jq -r '.key // "FAILED"')

          if [ "$ISSUE_KEY" != "FAILED" ] && [ "$HTTP_CODE" = "201" ]; then
            echo "Ticket Created: $ISSUE_KEY"
          else
            echo "Failed to create ticket (HTTP $HTTP_CODE)"
            echo "Response: $BODY"
            exit 1
          fi
```

---

### Template 2: Jira Quality Gate Issue Job

```yaml
# Add to main CI/CD pipeline
notify-jira-quality:
  name: "Jira Quality Issue"
  needs: [quality-sonarqube]
  if: always() && (needs.quality-sonarqube.outputs.scan_failed == 'true' || needs.quality-sonarqube.outputs.quality_gate_status == 'ERROR')
  runs-on: ubuntu-latest
  continue-on-error: true
  steps:
    - name: Check Jira Configuration
      id: check-jira
      run: |
        CONFIGURED="true"
        if [ -z "${{ secrets.JIRA_API_TOKEN }}" ] || [ -z "${{ secrets.JIRA_BASE_URL }}" ]; then
          CONFIGURED="false"
        fi
        echo "configured=${CONFIGURED}" >> $GITHUB_OUTPUT

    - name: Create Jira Quality Gate Issue
      if: steps.check-jira.outputs.configured == 'true'
      env:
        JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
        JIRA_EMAIL: ${{ secrets.JIRA_EMAIL }}
        JIRA_BASE_URL: ${{ secrets.JIRA_BASE_URL }}
        JIRA_PROJECT: ${{ secrets.JIRA_PROJECT }}
        JIRA_AUTH_TYPE: ${{ secrets.JIRA_AUTH_TYPE }}
      run: |
        # Set auth header
        if [ "$JIRA_AUTH_TYPE" = "api-key" ]; then
          AUTH_HEADER="X-API-Key: ${JIRA_API_TOKEN}"
        else
          AUTH_HEADER="Authorization: Basic $(echo -n "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64)"
        fi

        PROJECT_KEY="${JIRA_PROJECT:-TEST}"

        DESCRIPTION="SonarQube quality gate check failed.

        Details:
        - Dashboard: ${{ needs.quality-sonarqube.outputs.sonar_url }}
        - Status: ${{ needs.quality-sonarqube.outputs.quality_gate_status }}
        - Commit: ${{ github.sha }}
        - Branch: ${{ github.ref_name }}
        - Triggered by: ${{ github.actor }}

        Workflow: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"

        PAYLOAD=$(jq -n \
          --arg project "$PROJECT_KEY" \
          --arg summary "[QUALITY] SonarQube Quality Gate Failed" \
          --arg description "$DESCRIPTION" \
          '{
            "fields": {
              "project": {"key": $project},
              "summary": $summary,
              "description": $description,
              "issuetype": {"name": "Task"},
              "priority": {"name": "High"}
            }
          }')

        RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
          -H "${AUTH_HEADER}" \
          -H "Content-Type: application/json" \
          "${JIRA_BASE_URL}/rest/api/2/issue" \
          -d "$PAYLOAD")

        HTTP_CODE=$(echo "$RESPONSE" | tail -1)
        BODY=$(echo "$RESPONSE" | sed '$d')
        ISSUE_KEY=$(echo "$BODY" | jq -r '.key // "FAILED"')

        if [ "$ISSUE_KEY" != "FAILED" ] && [ "$HTTP_CODE" = "201" ]; then
          echo "### Jira Quality Gate Issue Created" >> $GITHUB_STEP_SUMMARY
          echo "**Issue:** [$ISSUE_KEY](${JIRA_BASE_URL}/browse/${ISSUE_KEY})" >> $GITHUB_STEP_SUMMARY
        else
          echo "Failed to create Jira issue (HTTP $HTTP_CODE)" >> $GITHUB_STEP_SUMMARY
        fi
```

---

### Template 3: Jira Security Issue Job

```yaml
notify-jira-security:
  name: "Jira Security Issue"
  needs: [build]
  if: always() && needs.build.outputs.has_security_findings == 'true'
  runs-on: ubuntu-latest
  continue-on-error: true
  steps:
    - name: Check Jira Configuration
      id: check-jira
      run: |
        CONFIGURED="true"
        if [ -z "${{ secrets.JIRA_API_TOKEN }}" ] || [ -z "${{ secrets.JIRA_BASE_URL }}" ]; then
          CONFIGURED="false"
        fi
        echo "configured=${CONFIGURED}" >> $GITHUB_OUTPUT

    - name: Create Jira Security Issue
      if: steps.check-jira.outputs.configured == 'true'
      env:
        JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
        JIRA_EMAIL: ${{ secrets.JIRA_EMAIL }}
        JIRA_BASE_URL: ${{ secrets.JIRA_BASE_URL }}
        JIRA_PROJECT: ${{ secrets.JIRA_PROJECT }}
        JIRA_AUTH_TYPE: ${{ secrets.JIRA_AUTH_TYPE }}
      run: |
        TOTAL_CRIT="${{ needs.build.outputs.total_critical }}"
        TOTAL_HIGH="${{ needs.build.outputs.total_high }}"

        if [ "${TOTAL_CRIT:-0}" -gt 0 ]; then
          PRIORITY="High"
        else
          PRIORITY="Medium"
        fi

        if [ "$JIRA_AUTH_TYPE" = "api-key" ]; then
          AUTH_HEADER="X-API-Key: ${JIRA_API_TOKEN}"
        else
          AUTH_HEADER="Authorization: Basic $(echo -n "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64)"
        fi

        PROJECT_KEY="${JIRA_PROJECT:-TEST}"

        DESCRIPTION=$(cat << 'DESCEOF'
        Security scan detected vulnerabilities in container images.

        Vulnerability Summary:
        - Vote: ${{ needs.build.outputs.vote_critical }} Critical, ${{ needs.build.outputs.vote_high }} High
        - Result: ${{ needs.build.outputs.result_critical }} Critical, ${{ needs.build.outputs.result_high }} High
        - Worker: ${{ needs.build.outputs.worker_critical }} Critical, ${{ needs.build.outputs.worker_high }} High

        Build Details:
        - Image Tag: ${{ needs.build.outputs.image_tag }}
        - Commit: ${{ github.sha }}
        - Triggered by: ${{ github.actor }}

        Workflow: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
        DESCEOF
        )

        PAYLOAD=$(jq -n \
          --arg project "$PROJECT_KEY" \
          --arg summary "[SECURITY] ${TOTAL_CRIT} Critical, ${TOTAL_HIGH} High vulnerabilities" \
          --arg description "$DESCRIPTION" \
          --arg priority "$PRIORITY" \
          '{
            "fields": {
              "project": {"key": $project},
              "summary": $summary,
              "description": $description,
              "issuetype": {"name": "Task"},
              "priority": {"name": $priority}
            }
          }')

        RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
          -H "${AUTH_HEADER}" \
          -H "Content-Type: application/json" \
          "${JIRA_BASE_URL}/rest/api/2/issue" \
          -d "$PAYLOAD")

        HTTP_CODE=$(echo "$RESPONSE" | tail -1)
        BODY=$(echo "$RESPONSE" | sed '$d')
        ISSUE_KEY=$(echo "$BODY" | jq -r '.key // "FAILED"')

        if [ "$ISSUE_KEY" != "FAILED" ] && [ "$HTTP_CODE" = "201" ]; then
          echo "### Jira Security Issue Created" >> $GITHUB_STEP_SUMMARY
          echo "**Issue:** [$ISSUE_KEY](${JIRA_BASE_URL}/browse/${ISSUE_KEY})" >> $GITHUB_STEP_SUMMARY
        else
          echo "Failed to create Jira issue (HTTP $HTTP_CODE)" >> $GITHUB_STEP_SUMMARY
        fi
```

---

### Template 4: Jira Deployment Failure Job

```yaml
notify-jira:
  name: "Jira Issue"
  needs: [build, deploy]
  if: always() && needs.deploy.outputs.success == 'false'
  runs-on: ubuntu-latest
  continue-on-error: true
  steps:
    - name: Check Jira Configuration
      id: check-jira
      run: |
        CONFIGURED="true"
        if [ -z "${{ secrets.JIRA_API_TOKEN }}" ] || [ -z "${{ secrets.JIRA_BASE_URL }}" ]; then
          CONFIGURED="false"
        fi
        echo "configured=${CONFIGURED}" >> $GITHUB_OUTPUT

    - name: Create Jira Issue
      if: steps.check-jira.outputs.configured == 'true'
      env:
        JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
        JIRA_EMAIL: ${{ secrets.JIRA_EMAIL }}
        JIRA_BASE_URL: ${{ secrets.JIRA_BASE_URL }}
        JIRA_PROJECT: ${{ secrets.JIRA_PROJECT }}
        JIRA_AUTH_TYPE: ${{ secrets.JIRA_AUTH_TYPE }}
      run: |
        if [ "$JIRA_AUTH_TYPE" = "api-key" ]; then
          AUTH_HEADER="X-API-Key: ${JIRA_API_TOKEN}"
        else
          AUTH_HEADER="Authorization: Basic $(echo -n "${JIRA_EMAIL}:${JIRA_API_TOKEN}" | base64)"
        fi

        PROJECT_KEY="${JIRA_PROJECT:-TEST}"

        DESCRIPTION=$(cat << 'DESCEOF'
        Deployment failed.

        Details:
        - Image Tag: ${{ needs.build.outputs.image_tag }}
        - Commit: ${{ github.sha }}
        - Branch: ${{ github.ref_name }}
        - Triggered by: ${{ github.actor }}

        Workflow: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
        DESCEOF
        )

        PAYLOAD=$(jq -n \
          --arg project "$PROJECT_KEY" \
          --arg summary "[DEPLOY-FAIL] Deployment Failed" \
          --arg description "$DESCRIPTION" \
          '{
            "fields": {
              "project": {"key": $project},
              "summary": $summary,
              "description": $description,
              "issuetype": {"name": "Task"},
              "priority": {"name": "High"}
            }
          }')

        RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
          -H "${AUTH_HEADER}" \
          -H "Content-Type: application/json" \
          "${JIRA_BASE_URL}/rest/api/2/issue" \
          -d "$PAYLOAD")

        HTTP_CODE=$(echo "$RESPONSE" | tail -1)
        BODY=$(echo "$RESPONSE" | sed '$d')
        ISSUE_KEY=$(echo "$BODY" | jq -r '.key // "FAILED"')

        if [ "$ISSUE_KEY" != "FAILED" ] && [ "$HTTP_CODE" = "201" ]; then
          echo "### Jira Issue Created" >> $GITHUB_STEP_SUMMARY
          echo "**Issue:** [$ISSUE_KEY](${JIRA_BASE_URL}/browse/${ISSUE_KEY})" >> $GITHUB_STEP_SUMMARY
        else
          echo "Failed to create Jira issue (HTTP $HTTP_CODE)" >> $GITHUB_STEP_SUMMARY
        fi
```

---

## YAML Best Practices

### 1. Multi-line Strings

```yaml
# Use heredoc for complex multi-line content
run: |
  DESCRIPTION=$(cat << 'DESCEOF'
  Line 1
  Line 2
  DESCEOF
  )
```

### 2. JSON Payload Construction

```yaml
# Use jq for safe JSON construction
PAYLOAD=$(jq -n \
  --arg project "$PROJECT_KEY" \
  --arg summary "$SUMMARY" \
  --arg description "$DESCRIPTION" \
  '{
    "fields": {
      "project": {"key": $project},
      "summary": $summary,
      "description": $description
    }
  }')
```

### 3. HTTP Response Handling

```yaml
# Capture both body and status code
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST ... -d "$PAYLOAD")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')
```

### 4. Conditional Job Execution

```yaml
# Check multiple conditions
if: always() && (condition1 == 'true' || condition2 == 'ERROR')
```

### 5. Output Capture from Steps with continue-on-error

```yaml
steps:
  - name: Step that might fail
    id: my-step
    continue-on-error: true
    run: ...

outputs:
  step_failed: ${{ steps.my-step.outcome == 'failure' }}
```

---

## Testing & Verification

### Test Jira Connection

```bash
# Using gh CLI
gh workflow run "test-jira-integration.yaml" \
  -f test_type="test-ticket" \
  -f jira_url_override="https://opsera-opserajira-dev.agent.opsera.dev" \
  -f api_version="2" \
  -f auth_type="api-key"
```

### Verify Ticket Creation

```bash
# Check workflow result
gh run list --workflow="test-jira-integration.yaml" --limit 1

# View logs for ticket ID
gh run view <run-id> --log | grep "TEST-"
```

### Trigger Main Pipeline

```bash
# Make a change to trigger push event
# Files watched: vote/**, result/**, worker/**, .opsera-voting01/**
```

---

## Troubleshooting Checklist

- [ ] `JIRA_API_TOKEN` secret is set
- [ ] `JIRA_BASE_URL` points to correct Jira instance
- [ ] `JIRA_AUTH_TYPE` is `api-key` for mock Jira
- [ ] `JIRA_PROJECT` matches an existing project key
- [ ] API version matches Jira instance (v2 for mock)
- [ ] No trailing slash in `JIRA_BASE_URL`

---

## Quick Reference

| Scenario | Jira Job | Trigger Condition |
|----------|----------|-------------------|
| SonarQube Fails | `notify-jira-quality` | `scan_failed == 'true'` |
| Security Vulns | `notify-jira-security` | `has_security_findings == 'true'` |
| Deploy Fails | `notify-jira` | `deploy.success == 'false'` |

---

## Changelog

Track all updates to this learning guide.

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-03 | 1.0 | Initial creation with Jira integration learnings |
| 2026-02-03 | 1.1 | Added complete session history, UI changes, landscape enhancements |

---

## How to Update This Guide

### Option 1: Manual Update

Add new learnings directly to this file:

```bash
# Edit the file
vi .opsera-learnings/jira-integration-guide.md

# Commit changes
git add .opsera-learnings/jira-integration-guide.md
git commit -m "docs: Update learnings guide with [topic]"
git push
```

### Option 2: Automated Update via Workflow

A GitHub Actions workflow can be triggered to update this guide with recent session learnings.

```yaml
# .github/workflows/update-learnings.yaml
name: "📚 Update Learnings Guide"

on:
  workflow_dispatch:
    inputs:
      section:
        description: 'Section to update'
        type: choice
        options: ['session-history', 'issues', 'templates', 'all']
        default: 'session-history'
      learning_summary:
        description: 'Summary of new learning (one line)'
        type: string
        required: true

jobs:
  update-learnings:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Update Learnings Guide
        run: |
          DATE=$(date -u +'%Y-%m-%d')
          GUIDE=".opsera-learnings/jira-integration-guide.md"

          # Get current version
          CURRENT_VERSION=$(grep -E "^\| $DATE" "$GUIDE" | tail -1 | awk -F'|' '{print $3}' | tr -d ' ' || echo "1.0")
          MAJOR=$(echo "$CURRENT_VERSION" | cut -d'.' -f1)
          MINOR=$(echo "$CURRENT_VERSION" | cut -d'.' -f2)
          NEW_VERSION="${MAJOR}.$((MINOR + 1))"

          # Update Last Updated date
          sed -i "s/^> \*\*Last Updated:\*\*.*/> **Last Updated:** $DATE/" "$GUIDE"

          # Add changelog entry
          CHANGELOG_LINE="| $DATE | $NEW_VERSION | ${{ github.event.inputs.learning_summary }} |"
          sed -i "/^| Date | Version | Changes |/a\\$CHANGELOG_LINE" "$GUIDE"

          echo "Updated to version $NEW_VERSION"

      - name: Commit Changes
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .opsera-learnings/
          git commit -m "docs: Update learnings guide - ${{ github.event.inputs.learning_summary }}" || echo "No changes"
          git push
```

### Option 3: Claude Code Session Export

At the end of each Claude Code session, export learnings:

```
User: export session learnings to .opsera-learnings/
```

Claude will:
1. Review the session transcript
2. Extract key issues, fixes, and patterns
3. Update the guide with new content
4. Commit and push changes

### Recommended Update Cadence

| Trigger | Action |
|---------|--------|
| End of major feature work | Export session learnings |
| New issue discovered | Add to Issues section |
| New workflow template | Add to Templates section |
| Weekly | Review and consolidate learnings |

### Template for Adding New Issues

```markdown
### Issue N: [Title]

**Problem:** [What went wrong]

**Error:**
\`\`\`
[Error message]
\`\`\`

**Root Cause:** [Why it happened]

**Fix:** [How to resolve]

\`\`\`yaml
# Code example
\`\`\`
```

---

*This document is a living record of DevOps learnings. Update regularly to build institutional knowledge.*
