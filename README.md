# Terraform Security Lab

**Infrastructure as Code · Container Security · DevSecOps**

Built and validated on Windows 11 with Docker Desktop, this lab provisions a small containerized infrastructure with Terraform. It combines a static Nginx frontend, an HTTP Echo backend, network segmentation, container hardening, and a reproducible DevSecOps verification flow.

> **Scope:** Windows 11, Docker Desktop in Linux-container mode, and the Docker provider for Terraform. This project does not deploy resources to AWS or expose a public cloud service.

## Objectives

- Define the infrastructure and its security controls as code.
- Limit container privileges and host exposure.
- Separate the frontend network from backend-only communication.
- Validate Terraform configuration and inspect the deployed controls.
- Assess the Terraform code and container images with dedicated security tools.

## Architecture

```text
Windows host / browser
       │  http://127.0.0.1:8080
       ▼
terraform-secure-web  (Nginx, static dashboard)
       ├── terraform-security-network
       └── terraform-backend-internal  [internal = true]
                         │
                         ▼
          terraform-secure-backend  (HTTP Echo :5678)
          No published host port
```

[main.tf](main.tf) provisions the two Docker networks, the two images, and the two containers. The frontend joins both networks and publishes port 8080 **only on 127.0.0.1**. The backend joins only `terraform-backend-internal` and has no published port. The Nginx page is a static dashboard; connectivity to HTTP Echo is checked separately through the internal Docker network.

![Terraform deployment](screenshots/01_Terraform_Infrastructure_Deployed.png)

*Terraform provisions the local Docker resources.*

![Docker network configuration](screenshots/03_Network_Configuration.png)

*The frontend network and the internal backend network are configured separately.*

## Security controls

| Control | Implementation in the lab | How to inspect it |
| --- | --- | --- |
| Non-root execution | Unprivileged Nginx image and HTTP Echo image defaults | `docker exec terraform-secure-web id`; `docker inspect terraform-secure-backend --format '{{.Config.User}}'` |
| No privilege escalation | `security_opts = ["no-new-privileges:true"]` on both containers | `docker inspect` |
| Reduced Linux capabilities | `capabilities { drop = ["ALL"] }` on both containers | `docker inspect` |
| Resource limits | Frontend: 128 MiB; backend: 64 MiB | Terraform configuration and `docker inspect` |
| Local frontend access | `127.0.0.1:8080` host binding | `docker port terraform-secure-web` |
| Backend isolation | Internal Docker network; no published backend port | `docker network inspect`; `docker port terraform-secure-backend` |
| Read-only page mount | `web/index.html` mounted read-only | Terraform configuration |

The non-root identities come from the selected images rather than an explicit `user` setting in Terraform. These controls reduce exposure; they do not make the containers or the Docker host immune to compromise.

![Container security controls](screenshots/02_Container_Security_Controls.png)

*Inspection of the container runtime settings and local port binding.*

![Backend network isolation](screenshots/05_Backend_Network_Isolation.png)

*The backend has no published host port; the frontend can reach it on the internal network.*

![Internal network security](screenshots/06_Internal_Network_Security.png)

*Inspection of the internal network and backend runtime identity.*

## Security verification workflow

The tools address different layers; one does not replace the others.

| Tool | Role |
| --- | --- |
| **Terraform** | Format and validate HCL, preview changes, provision and remove the lab. |
| **TFLint** | Lint Terraform configuration for language and provider-related issues. This Docker lab does not require an AWS ruleset. |
| **Checkov** | Static security analysis of Terraform resources and configuration. Findings require review in the context of a local lab. |
| **Trivy** | Scan the Nginx and HTTP Echo container images for known vulnerabilities. Results depend on the image digest and vulnerability database at scan time. |
| **GitHub Actions** | CI/CD environment for running these checks on repository changes and retaining machine-readable reports as workflow artifacts. |

Run the checks from the repository root. Install TFLint, Checkov, and Trivy separately if you want to run their respective commands.

```powershell
terraform init
terraform fmt -check
terraform validate
tflint --init
tflint
checkov -d . --framework terraform
trivy image nginxinc/nginx-unprivileged:stable-alpine
trivy image hashicorp/http-echo:1.0
```

Export machine-readable reports:

```powershell
New-Item -ItemType Directory -Force reports | Out-Null
tflint --format json > reports/tflint.json
checkov -d . --framework terraform -o json > reports/checkov.json
trivy image --format json --output reports/trivy-nginx.json nginxinc/nginx-unprivileged:stable-alpine
trivy image --format json --output reports/trivy-backend.json hashicorp/http-echo:1.0
```

The GitHub Actions verification flow follows the same order: check formatting and validity, run TFLint and Checkov on the code, then scan both container images with Trivy. Machine-readable reports can be retained as workflow artifacts for review. The commands above allow the same checks to be run locally.

## Run the lab

### Prerequisites

- Windows 11 with Docker Desktop running Linux containers.
- Terraform CLI and PowerShell.
- Docker daemon available through the Windows named pipe configured in `main.tf`.

```powershell
git clone https://github.com/Ryad-Cyber/terraform-security-lab.git
cd terraform-security-lab
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Review the plan before approving `terraform apply`. The frontend is available at **http://localhost:8080**.

![Local Nginx dashboard](screenshots/04_Secure_Web_Server.png)

*The static page served by the locally deployed Nginx container.*

### Inspect the running infrastructure

```powershell
docker ps
docker exec terraform-secure-web id
docker inspect terraform-secure-web --format '{{json .HostConfig.SecurityOpt}}'
docker inspect terraform-secure-web --format '{{json .HostConfig.CapDrop}}'
docker inspect terraform-secure-backend --format '{{.Config.User}}'
docker network inspect terraform-backend-internal --format '{{.Internal}}'
docker port terraform-secure-backend
docker exec terraform-secure-web wget -qO- http://terraform-secure-backend:5678
curl.exe -I http://localhost:8080
```

The inspection commands check the active containers and networks. `docker port terraform-secure-backend` should show no published mapping. To remove only the resources managed by this Terraform configuration:

```powershell
terraform destroy
```

## Repository contents

```text
main.tf                  Terraform Docker infrastructure
web/index.html           Static Nginx dashboard
screenshots/             Six deployment and security-control captures
.terraform.lock.hcl      Provider dependency lock file
README.md                Project documentation
```

Terraform state and provider binaries are excluded from version control. This is a **local learning lab**, not a production deployment; production use would also require a review of secrets, image pinning, monitoring, patching, and deployment controls.

## Author

**Ryad Boujenan** · Cybersecurity engineering student, EMSI Casablanca  
[Portfolio](https://ryad-cyber.github.io/) · [GitHub](https://github.com/Ryad-Cyber)
