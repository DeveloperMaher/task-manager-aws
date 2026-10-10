# High-Level Architecture

```mermaid
flowchart TB
    User([👤 Users]) -->|HTTPS| ALB[Application Load Balancer<br/>task-manager-alb<br/>Public Subnets]

    subgraph VPC["AWS VPC · 10.0.0.0/16 · eu-central-1"]
        direction TB

        subgraph PublicSubnets["Public Subnets (2 AZs)"]
            ALB
            EC2A[EC2 #1<br/>t3.micro<br/>Ubuntu 22.04 + Nginx + PHP 8.3]
            EC2B[EC2 #2<br/>t3.micro]
            EC2C[EC2 #3<br/>t3.micro]
        end

        subgraph PrivateSubnets["Private Subnets (2 AZs)"]
            RDS[(RDS MySQL 8.0<br/>db.t3.micro<br/>Single-AZ)]
            Redis[(ElastiCache Redis<br/>cache.t3.micro)]
        end

        ALB --> EC2A
        ALB --> EC2B
        ALB --> EC2C

        EC2A --> RDS
        EC2B --> RDS
        EC2C --> RDS

        EC2A --> Redis
        EC2B --> Redis
        EC2C --> Redis
    end

    subgraph Storage["Storage & Messaging"]
        S3A[("S3 · task-manager-artifacts-*<br/>Deployment zips")]
        S3U[("S3 · task-manager-app-uploads-*<br/>User attachments")]
        SNS[[SNS · task-manager-alerts<br/>Email notifications]]
        SSM[[SSM Parameter Store<br/>/task-manager/prod/*]]
    end

    EC2A --> S3U
    EC2B --> S3U
    EC2C --> S3U

    EC2A --> SNS
    EC2A --> SSM

    subgraph CICD["CI/CD Pipeline"]
        Dev([💻 Local PC]) -->|git push| GH[GitHub Repo]
        GH --> GHA[GitHub Actions<br/>Build + Test + Package]
        GHA --> S3A
        GHA -->|"OIDC (no keys)"| CD[AWS CodeDeploy]
        CD --> EC2A
        CD --> EC2B
        CD --> EC2C
    end

    subgraph Monitoring["Observability"]
        CW[CloudWatch<br/>Alarms + Metrics] --> SNS
        SNS --> Email([📧 Email Alerts])
    end

    style VPC fill:#e8f4f8,stroke:#0073bb
    style PublicSubnets fill:#d4edda,stroke:#28a745
    style PrivateSubnets fill:#fff3cd,stroke:#ffc107
    style Storage fill:#f8d7da,stroke:#dc3545
    style CICD fill:#e2d4f8,stroke:#6f42c1
    style Monitoring fill:#ffe4b5,stroke:#ff8c00
```

## Tier Responsibilities

| Tier | Components | Responsibility |
|---|---|---|
| **Presentation** | ALB + S3 (static/uploaded assets) | Receive user traffic, terminate TLS, distribute across instances |
| **Application** | 3 × EC2 (Laravel + Nginx + PHP-FPM) | Business logic, authentication, task CRUD, event publishing |
| **Data** | RDS MySQL + ElastiCache Redis + S3 | Durable relational data, fast cache/sessions, object storage |

## Request Lifecycle

```
1. Browser → ALB (public subnets, port 80)
2. ALB checks /health on each target, picks a healthy EC2
3. EC2 (Laravel):
     a. Session lookup → ElastiCache Redis
     b. Business data → RDS MySQL (cache miss → read-through to Redis)
     c. File access → S3 (signed URL generated on demand)
     d. Business event → SNS publish
4. Response → ALB → Browser
```