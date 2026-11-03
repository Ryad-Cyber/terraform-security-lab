# 🔐 Terraform Security Lab

### Secure Infrastructure as Code · Docker Hardening · Network Segmentation · DevSecOps

A hands-on cybersecurity project built on **Windows 11 with Docker Desktop**. Terraform provisions a local, containerized infrastructure with a static Nginx frontend and an isolated HTTP Echo backend. The lab combines least-privilege controls, network segmentation, runtime verification, and a security-check workflow using TFLint, Checkov, Trivy, and GitHub Actions.

---

## 🎯 Project Objectives

1. Provision Docker infrastructure reproducibly with Terraform.
2. Separate externally reachable and internal-only network paths.
3. Reduce container privileges and limit resource consumption.
4. Check the deployed controls with Docker commands.
5. Review Terraform code and container images with complementary security tools.
6. Make verification results easy to inspect through machine-readable reports.

---

## 🏗️ Infrastructure Architecture

```text
Windows host / browser
        │
        │ http://127.0.0.1:8080
        ▼
┌──────────────────────────────────────────────┐
│ terraform-secure-web                         │
│ Nginx unprivileged · static security page    │
│ Networks: frontend + internal backend        │
└──────────────────────┬───────────────────────┘
                       │ Docker internal DNS
                       │ terraform-backend-internal
                       ▼
             ┌───────────────────────────┐
             │ terraform-secure-backend  │
             │ HashiCorp HTTP Echo :5678 │
             │ No published host port    │
             └───────────────────────────┘
```

[main.tf](main.tf) creates two networks and two containers:

| Network | Connected services | Purpose |
| --- | --- | --- |
| `terraform-security-network` | Nginx frontend | Dedicated frontend network |
| `terraform-backend-internal` | Nginx frontend and HTTP Echo backend | Service-to-service path with `internal = true` |

The frontend binds port 8080 to **127.0.0.1** on the Windows host. The backend is reachable from the frontend through Docker networking, but has **no published host port**. The Nginx page is a static dashboard; frontend-to-backend connectivity is verified separately with a container command.

---

## 🛡️ Security Controls

| Control | Implementation | Verification |
| --- | --- | --- |
| Non-root processes | Unprivileged Nginx and HTTP Echo image defaults | `docker exec ... id`, `docker inspect ... Config.User` |
| Privilege escalation restriction | `no-new-privileges:true` on both containers | `docker inspect ... SecurityOpt` |
| Linux capabilities | `drop = ["ALL"]` on both containers | `docker inspect ... CapDrop` |
| Resource limits | 128 MiB for Nginx; 64 MiB for HTTP Echo | Terraform configuration and Docker inspection |
| Frontend exposure | Host binding to `127.0.0.1:8080` | `docker port terraform-secure-web` |
| Backend isolation | Internal Docker network; no published backend port | `docker network inspect`, `docker port terraform-secure-backend` |
| Page integrity | `web/index.html` mounted read-only | Terraform configuration |

The non-root identities depend on the selected images; `main.tf` does not set an explicit `user` value. These controls reduce exposure without implying complete isolation from the Docker host.

---

## 🧰 Technologies & Security Tooling

| Tool | Role in the project |
| --- | --- |
| **Terraform** | Define, validate, plan, provision, and remove the Docker infrastructure. |
| **Docker Desktop** | Run the Linux containers and inspect their networks and runtime settings. |
| **Nginx Unprivileged** | Serve the local frontend without a root process. |
| **HashiCorp HTTP Echo** | Provide a small backend for internal-network connectivity checks. |
| **TFLint** | Lint Terraform code for language and configured plugin rules; no AWS ruleset is needed for this Docker lab. |
| **Checkov** | Analyze the Terraform configuration for security and policy findings. |
| **Trivy** | Scan both container images for known vulnerabilities. Findings vary with image digests and the vulnerability database. |
| **GitHub Actions** | Automate checks on repository changes and make security reports available for review. |

### CI/CD verification flow

```text
Terraform format & validation
          ↓
TFLint + Checkov (code)
          ↓
Trivy (Nginx + backend images)
          ↓
Review reports / GitHub Actions artifacts
```

The checks cover different layers: Terraform and TFLint assess configuration quality, Checkov analyzes infrastructure-as-code security, and Trivy assesses image packages. A reported finding calls for review in the context of this local lab; it is not by itself proof of exploitability or a successful deployment.

---

## 🚀 Deployment Guide

### Prerequisites

- Windows 11 and Docker Desktop running **Linux containers**.
- Terraform CLI and PowerShell.
- Docker Desktop running and accessible through the named pipe configured in `main.tf`.
- TFLint, Checkov, and Trivy installed separately for the additional security checks.

### 1. Clone the repository

```powershell
git clone https://github.com/Ryad-Cyber/terraform-security-lab.git
cd terraform-security-lab
```

### 2. Initialize Terraform

```powershell
terraform init
```

This installs the locked Docker provider dependency.

### 3. Check formatting and configuration

```powershell
terraform fmt -check
terraform validate
```

### 4. Review the deployment plan

```powershell
terraform plan
```

Check the planned networks, images, ports, mounts, and security settings before applying changes.

### 5. Deploy the lab

```powershell
terraform apply
```

Approve the plan when prompted. Terraform manages the two containers and their networks.

### 6. Inspect the running services

```powershell
docker ps
```

Look for `terraform-secure-web` and `terraform-secure-backend`.

### 7. Open the frontend

Visit **http://localhost:8080**. The Nginx container serves the local Terraform Security Lab dashboard.

---

## 🧪 Security Validation

Run these checks after deployment. Each command inspects a specific property rather than relying only on the dashboard.

### 1. Confirm non-root execution

```powershell
docker exec terraform-secure-web id
docker inspect terraform-secure-backend --format '{{.Config.User}}'
```

The selected images should run as non-root users; the original lab evidence shows UID 101 for Nginx and UID 65532 for the backend.

### 2. Inspect privilege restrictions

```powershell
docker inspect terraform-secure-web --format '{{json .HostConfig.SecurityOpt}}'
docker inspect terraform-secure-web --format '{{json .HostConfig.CapDrop}}'
docker inspect terraform-secure-backend --format '{{json .HostConfig.SecurityOpt}}'
docker inspect terraform-secure-backend --format '{{json .HostConfig.CapDrop}}'
```

Check for `no-new-privileges:true` and `ALL` in the dropped capabilities.

### 3. Confirm network segmentation and port exposure

```powershell
docker network inspect terraform-backend-internal --format '{{.Internal}}'
docker port terraform-secure-web
docker port terraform-secure-backend
```

The backend network should be internal, the frontend should bind to localhost, and the backend should have no published port.

### 4. Test internal connectivity and frontend availability

```powershell
docker exec terraform-secure-web wget -qO- http://terraform-secure-backend:5678
curl.exe -I http://localhost:8080
```

The first command checks Docker-internal DNS and reachability; the second requests the local frontend.

### 5. Lint and scan the Terraform configuration

```powershell
tflint --init
tflint
checkov -d . --framework terraform
```

TFLint examines Terraform conventions. Checkov produces policy findings for the HCL configuration; review each finding against the lab's local scope.

### 6. Scan the container images

```powershell
trivy image nginxinc/nginx-unprivileged:stable-alpine
trivy image hashicorp/http-echo:1.0
```

To export machine-readable reports:

```powershell
New-Item -ItemType Directory -Force reports | Out-Null
tflint --format json > reports/tflint.json
checkov -d . --framework terraform -o json > reports/checkov.json
trivy image --format json --output reports/trivy-nginx.json nginxinc/nginx-unprivileged:stable-alpine
trivy image --format json --output reports/trivy-backend.json hashicorp/http-echo:1.0
```

The same sequence can be orchestrated in GitHub Actions, with the report files retained as workflow artifacts.

---

## 📸 Screenshots & Evidence

The original six captures document the deployed infrastructure and the checks performed against it.

### 01 — Terraform deployment

![Terraform infrastructure deployed](screenshots/01_Terraform_Infrastructure_Deployed.png)

*Terraform provisions and tracks the local Docker resources.*

### 02 — Container security controls

![Container security controls](screenshots/02_Container_Security_Controls.png)

*Runtime inspection of user identity, restrictions, memory, and the local port binding.*

### 03 — Network configuration

![Docker network configuration](screenshots/03_Network_Configuration.png)

*The dedicated frontend network and the internal service network.*

### 04 — Nginx security dashboard

![Secure web server](screenshots/04_Secure_Web_Server.png)

*The static page served by the locally deployed Nginx container.*

### 05 — Backend network isolation

![Backend network isolation](screenshots/05_Backend_Network_Isolation.png)

*Frontend-to-backend communication without a published backend host port.*

### 06 — Internal network security

![Internal network security](screenshots/06_Internal_Network_Security.png)

*Inspection of the internal Docker network and backend execution context.*

---

## 📂 Repository Structure

```text
terraform-security-lab/
├── main.tf
├── .terraform.lock.hcl
├── .gitignore
├── README.md
├── web/
│   └── index.html
└── screenshots/
    ├── 01_Terraform_Infrastructure_Deployed.png
    ├── 02_Container_Security_Controls.png
    ├── 03_Network_Configuration.png
    ├── 04_Secure_Web_Server.png
    ├── 05_Backend_Network_Isolation.png
    └── 06_Internal_Network_Security.png
```

Terraform state and downloaded providers are excluded from version control. Report commands above write to a local `reports/` directory.

---

## ♻️ Cleanup & Scope

```powershell
terraform destroy
```

This removes resources managed by this configuration, not unrelated Docker containers.

This is a **local security lab**, not a production deployment. Docker network segmentation and container hardening reduce risk but do not replace production controls such as image pinning, secrets management, patching, monitoring, and change review.

---

## 👤 Author

**Ryad Boujenan**  
Cybersecurity engineering student — EMSI Casablanca  
Focus: Cloud Security · SOC / Blue Team · Infrastructure Security

[Portfolio](https://ryad-cyber.github.io/) · [GitHub](https://github.com/Ryad-Cyber)
