# CI/CD Pipeline

## End-to-End Flow

```mermaid
sequenceDiagram
    autonumber
    participant Dev as 👨‍💻 Developer
    participant GH as GitHub
    participant GHA as GitHub Actions
    participant AWS as AWS STS
    participant S3 as S3 (Artifacts)
    participant CD as CodeDeploy
    participant EC2 as EC2 Fleet (×3)

    Dev->>GH: git push origin main
    GH->>GHA: Trigger workflow

    Note over GHA: composer install --no-dev<br/>npm ci && npm run build<br/>zip -r deploy.zip

    GHA->>AWS: Request OIDC token
    AWS-->>GHA: Temp credentials (1h, scoped role)
    Note over GHA,AWS: No long-lived secrets

    GHA->>S3: Upload releases/{sha}.zip
    GHA->>CD: create-deployment (S3 location)

    loop OneAtATime (3 instances)
        CD->>EC2: BeforeInstall → clean /var/www/html
        CD->>EC2: AfterInstall → fetch SSM, generate .env,<br/>composer install, migrate
        CD->>EC2: ApplicationStart → restart nginx + php-fpm
        CD->>EC2: ValidateService → curl /health
    end

    EC2-->>CD: Health OK
    CD-->>GHA: Deployment succeeded
    GHA-->>Dev: ✅ Live in ~2 minutes
```

## Authentication: OIDC Instead of Access Keys

```mermaid
flowchart LR
    GHA[GitHub Actions Run] -->|1. Request token| GitHub[GitHub OIDC Provider]
    GitHub -->|2. Signed JWT with sub claim| GHA
    GHA -->|3. AssumeRoleWithWebIdentity| STS[AWS STS]
    STS -->|4. Validate trust policy| IAM[IAM Role<br/>GitHubActions-Deploy-Role]
    IAM -->|5. Temporary credentials<br/>valid 1 hour| GHA
    GHA -->|6. API calls with temp creds| AWS[AWS Services<br/>S3 · CodeDeploy]

    style GHA fill:#e2d4f8,stroke:#6f42c1
    style IAM fill:#ffe4b5,stroke:#ff8c00
    style AWS fill:#d4edda,stroke:#28a745
```

### Trust Policy Scoping

The IAM role's trust policy uses GitHub's **immutable subject format** (new since July 2026 for all repos), scoped to the exact repository and branch:

```
repo:DeveloperMaher@191956391/task-manager-aws@1410820575:ref:refs/heads/main
```

| Component | Value | Purpose |
|---|---|---|
| `repo:` | Prefix | OIDC claim type |
| `DeveloperMaher@191956391` | Owner + numeric ID | Immutable user identity |
| `task-manager-aws@1410820575` | Repo + numeric ID | Immutable repo identity |
| `ref:refs/heads/main` | Branch ref | Only `main` pushes can assume the role |

**Why immutable IDs?** If the repo is renamed or transferred, the old name could be re-registered by an attacker. The numeric ID is permanent — it can never be reused.

## Deployment Lifecycle (CodeDeploy Hooks)

```mermaid
stateDiagram-v2
    [*] --> BeforeInstall
    BeforeInstall: Clean /var/www/html
    BeforeInstall --> Install

    Install: Extract zip from S3
    Install --> AfterInstall

    AfterInstall: Fetch SSM params<br/>Generate .env<br/>composer install<br/>config:cache, route:cache<br/>migrate --force
    AfterInstall --> ApplicationStart

    ApplicationStart: Restart nginx + php8.3-fpm
    ApplicationStart --> ValidateService

    ValidateService: curl /health
    ValidateService --> Succeeded: HTTP 200
    ValidateService --> Rollback: Non-200

    Rollback: Reinstall previous revision
    Rollback --> [*]

    Succeeded --> [*]
```

| Phase | Script | Failure action |
|---|---|---|
| **BeforeInstall** | `scripts/before_install.sh` | Deploy fails |
| **AfterInstall** | `scripts/after_install.sh` | Deploy fails (rollback if enabled) |
| **ApplicationStart** | `scripts/application_start.sh` | Deploy fails (rollback if enabled) |
| **ValidateService** | `scripts/validate_service.sh` | Deploy fails + **automatic rollback** |

## Rollout Strategy: OneAtATime

```
Instance 1: [BlockTraffic] → [Deploy] → [AllowTraffic] ✅
                                                          ↓
Instance 2:                                  [BlockTraffic] → [Deploy] → [AllowTraffic] ✅
                                                                                 ↓
Instance 3:                                                          [BlockTraffic] → [Deploy] → [AllowTraffic] ✅
```

**At any moment, at least 2 of 3 instances serve healthy traffic.** The ALB automatically stops routing to the instance being updated (via target group deregistration).

| Strategy | Time (3 instances) | Risk |
|---|---|---|
| **OneAtATime** (used) | ~5–7 min | Lowest — 2 healthy instances always |
| HalfAtATime | ~3–4 min | Medium — 1 healthy instance during deploy |
| AllAtOnce | ~2 min | Highest — brief downtime |

## Artifact Lifecycle

```mermaid
flowchart LR
    A[Local git push] --> B[GitHub Actions build]
    B --> C[zip ~16 MB]
    C --> D["S3: releases/COMMIT-SHA.zip"]
    D --> E[CodeDeploy reads]
    E --> F[EC2 /var/www/html]
    D --> G{30-day lifecycle}
    G -->|Expire| H[Auto-deleted]

    style D fill:#f8d7da,stroke:#dc3545
    style H fill:#ffcccc,stroke:#cc0000
```

Each commit produces a uniquely-named zip (`{sha}.zip`), so you can always redeploy a specific revision via CodeDeploy console by pasting the SHA.