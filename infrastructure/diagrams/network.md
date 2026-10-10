# Network Topology

```mermaid
flowchart LR
    Internet((🌐 Internet))

    subgraph VPC["VPC · 10.0.0.0/16 · eu-central-1"]
        IGW[Internet Gateway<br/>task-manager-igw]

        subgraph AZA["AZ eu-central-1a"]
            PubA[Public Subnet A<br/>10.0.1.0/24<br/>ALB + EC2 #1]
            PrivA[Private Subnet A<br/>10.0.11.0/24<br/>RDS + Redis]
        end

        subgraph AZB["AZ eu-central-1b"]
            PubB[Public Subnet B<br/>10.0.2.0/24<br/>ALB + EC2 #2, #3]
            PrivB[Private Subnet B<br/>10.0.12.0/24<br/>RDS subnet group]
        end

        RTpub[Public Route Table<br/>0.0.0.0/0 → IGW]
        RTpriv[Private Route Table<br/>local only · no NAT]
    end

    Internet --> IGW
    IGW --> RTpub
    RTpub --> PubA
    RTpub --> PubB
    RTpriv --> PrivA
    RTpriv --> PrivB

    style VPC fill:#e8f4f8,stroke:#0073bb
    style AZA fill:#d4edda,stroke:#28a745
    style AZB fill:#cce5ff,stroke:#004085
```

## CIDR Allocation

| Component | CIDR | AZ | Purpose |
|---|---|---|---|
| VPC | `10.0.0.0/16` | — | Isolated network (65K IPs) |
| Public Subnet A | `10.0.1.0/24` | eu-central-1a | ALB + EC2 #1 |
| Public Subnet B | `10.0.2.0/24` | eu-central-1b | ALB + EC2 #2, #3 |
| Private Subnet A | `10.0.11.0/24` | eu-central-1a | RDS primary + Redis |
| Private Subnet B | `10.0.12.0/24` | eu-central-1b | RDS subnet group member |

**Why 2 AZs?** ALB requires ≥2 AZs for high availability. RDS subnet groups require ≥2 AZs even for Single-AZ deployments.

**Why /24?** 251 usable IPs per subnet is plenty for a small fleet and leaves room for growth.

## Route Tables

### Public Route Table (`public-rt`)

| Destination | Target | Purpose |
|---|---|---|
| `10.0.0.0/16` | local | Intra-VPC traffic |
| `0.0.0.0/0` | Internet Gateway | Outbound internet access |

**Associated with:** `public-subnet-a`, `public-subnet-b`

### Private Route Table (`private-rt`)

| Destination | Target | Purpose |
|---|---|---|
| `10.0.0.0/16` | local | Intra-VPC traffic only |

**Associated with:** `private-subnet-a`, `private-subnet-b`

**No NAT Gateway** — saves ~$32/month. Private subnets have no outbound internet.

## Security Group Chain

Every layer only accepts traffic from the layer in front of it — never from IPs.

```mermaid
flowchart LR
    Internet((🌐 0.0.0.0/0)) -->|80, 443| SG_ALB[task-manager-alb-sg]
    SG_ALB -->|80| SG_EC2[task-manager-ec2-sg]
    HomeIP((🏠 Your IP)) -->|22| SG_EC2
    SG_EC2 -->|3306| SG_RDS[task-manager-rds-sg]
    SG_EC2 -->|6379| SG_REDIS[task-manager-redis-sg]

    style SG_ALB fill:#d4edda,stroke:#28a745
    style SG_EC2 fill:#cce5ff,stroke:#004085
    style SG_RDS fill:#fff3cd,stroke:#ffc107
    style SG_REDIS fill:#f8d7da,stroke:#dc3545
```

| Source | Destination | Port | Purpose |
|---|---|---|---|
| `0.0.0.0/0` | `task-manager-alb-sg` | 80, 443 | Public HTTP/HTTPS |
| `task-manager-alb-sg` | `task-manager-ec2-sg` | 80 | ALB → EC2 only |
| Your IP | `task-manager-ec2-sg` | 22 | SSH for debugging |
| `task-manager-ec2-sg` | `task-manager-rds-sg` | 3306 | EC2 → MySQL |
| `task-manager-ec2-sg` | `task-manager-redis-sg` | 6379 | EC2 → Redis |

**Why SG-to-SG references (not IPs)?** When the ASG replaces an instance, the new one automatically inherits the correct access via its security group — no IP juggling required.

## Cost Decision: No NAT Gateway

| Approach | Monthly Cost | Security |
|---|---|---|
| Private EC2 + NAT Gateway | ~$32 NAT + instance | Higher (no public IP) |
| **Public EC2, no NAT** (this project) | **$0** | Medium — Security Groups still block direct access |

This project intentionally chooses cost optimization for a learning environment. Instances sit in public subnets but are protected by the SG chain (only the ALB can reach port 80, only your IP can reach port 22).

**Production upgrade:** move EC2 to private subnets + NAT Gateway — noted in README's Future Improvements.