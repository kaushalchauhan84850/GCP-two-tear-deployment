# GCP Two-Tier Student Form — Terraform + Docker + GitHub Actions

Two-tier architecture:
- **Frontend VM** (public, tag `frontend`) — Node/Express app serving the student
  details HTML form. It's the only thing exposed to the internet (port 80).
- **Backend VM** (private, tag `backend`, no external IP) — Node/Express API +
  MongoDB, running as two containers via docker-compose. Only reachable from
  the frontend subnet on port 5000, and via IAP for SSH.

Three environments, one branch each, one GCP project each:

| Branch | GCP Project ID       |
|--------|-----------------------|
| dev    | dev-infra-503304      |
| qa     | qa-infra-500307        |
| prod   | prod-infra-503304     |

Repo: https://github.com/kaushalchauhan84850/GCP-two-tear-deployment

---

## 0. Repo layout

```
frontend/          Node app + student form (Dockerfile, docker-compose.yml)
backend/            Node API + Mongo (Dockerfile, docker-compose.yml)
terraform/          VPC, firewall, 2 VMs, per-env tfvars
.github/workflows/  dev.yml, qa.yml, prod.yml pipelines
```

---

## 1. One-time GCP setup (repeat for EACH of the 3 projects)

Install `gcloud` and log in:

```bash
gcloud auth login
```

For **each** project (`dev-infra-503304`, `qa-infra-500307`, `prod-infra-503304`):

```bash
PROJECT_ID=dev-infra-503304   # change per project

gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iap.googleapis.com

# Bucket to hold Terraform remote state for this env
gsutil mb -l asia-south1 gs://${PROJECT_ID}-tfstate
gsutil versioning set on gs://${PROJECT_ID}-tfstate

# Service account that GitHub Actions will use to deploy
gcloud iam service-accounts create github-deployer \
  --display-name="GitHub Actions Deployer"

SA_EMAIL="github-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

for ROLE in roles/compute.admin roles/iam.serviceAccountUser \
            roles/storage.admin roles/iap.tunnelResourceAccessor; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" --role="$ROLE"
done

# Key for GitHub secret (download once, then delete locally after upload)
gcloud iam service-accounts keys create ${PROJECT_ID}-key.json \
  --iam-account=$SA_EMAIL
```

> Note: `dev-infra-503304-key.json`, `qa-infra-500307-key.json`,
> `prod-infra-503304-key.json` are what you'll paste into GitHub secrets in
> step 3. Never commit them (`.gitignore` already excludes `*.json`).

---

## 2. Docker Hub setup

1. Create a Docker Hub account/repo (or let `docker push` auto-create
   `student-frontend` / `student-backend` under your username).
2. Create an access token: Docker Hub → Account Settings → Security →
   **New Access Token** (read/write). Save it — you'll add it as a GitHub secret.

Update `terraform/environments/*.tfvars` — replace
`REPLACE_WITH_YOUR_DOCKERHUB_USERNAME` with your real Docker Hub username in
all three files.

---

## 3. GitHub repo setup

### 3.1 Push this code

```bash
git init
git remote add origin https://github.com/kaushalchauhan84850/GCP-two-tear-deployment.git
git add .
git commit -m "Initial two-tier infra + app"
git branch -M main
git push -u origin main
```

### 3.2 Create the three branches

```bash
git checkout -b dev  && git push -u origin dev
git checkout -b qa   && git push -u origin qa
git checkout -b prod && git push -u origin prod
```

### 3.3 Add repository secrets
GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret name          | Value                                              |
|-----------------------|-----------------------------------------------------|
| `DOCKERHUB_USERNAME`  | your Docker Hub username                            |
| `DOCKERHUB_TOKEN`     | the access token from step 2                        |
| `GCP_SA_KEY_DEV`      | full contents of `dev-infra-503304-key.json`         |
| `GCP_SA_KEY_QA`       | full contents of `qa-infra-500307-key.json`           |
| `GCP_SA_KEY_PROD`     | full contents of `prod-infra-503304-key.json`        |

### 3.4 Branch protection (link branches → environments)
Settings → **Environments** → create `production` and require a reviewer
(this is what makes `prod.yml`'s `environment: production` pause for manual
approval before deploying). Optionally create `dev`/`qa` environments too and
attach the matching `GCP_SA_KEY_*` secret to each environment instead of the
repo level, for tighter scoping.

Settings → **Branches** → add protection rules for `dev`, `qa`, `prod` (e.g.
require PR review before merüge, require the workflow to pass).

Delete the local key files once uploaded as secrets:
```bash
rm dev-infra-503304-key.json qa-infra-500307-key.json prod-infra-503304-key.json
```

---

## 4. How the pipeline works (per branch)

Each of `.github/workflows/dev.yml`, `qa.yml`, `prod.yml` triggers **only** on
push to its own branch and runs 3 jobs in sequence:

1. **build-and-push** — builds `frontend/Dockerfile` and `backend/Dockerfile`,
   pushes `yourusername/student-frontend:<env>` and `:...-backend:<env>` to
   Docker Hub.
2. **terraform** — authenticates to that env's GCP project, runs
   `terraform init` (remote state in that project's GCS bucket) and
   `terraform apply` against `environments/<env>.tfvars`, provisioning the
   VPC/firewall/VMs on first run (or no-op if unchanged).
3. **redeploy-containers** — SSHes into both VMs over IAP (no public SSH
   needed) and runs `docker compose pull && docker compose up -d`, so a code
   change on an existing VM gets the new image without a full recreate.

So: **push to `dev` → only dev-infra-503304 is touched. Push to `qa` → only
qa-infra-500307. Push to `prod` → prod-infra-503304, gated by manual approval.**

---

## 5. First-time manual run (recommended before trusting the pipeline)

Test locally, per environment, before relying on CI:

```bash
cd terraform
terraform init \
  -backend-config="bucket=dev-infra-503304-tfstate" \
  -backend-config="prefix=terraform/state/dev"

terraform plan -var-file="environments/dev.tfvars" \
  -var="dockerhub_username=YOUR_DOCKERHUB_USERNAME"

terraform apply -var-file="environments/dev.tfvars" \
  -var="dockerhub_username=YOUR_DOCKERHUB_USERNAME"
```

Grab the frontend IP from the output and open it in a browser:
```bash
terraform output frontend_public_ip
```

To SSH in for debugging (IAP tunnel, no public SSH port needed):
```bash
gcloud compute ssh dev-backend-vm --zone=asia-south1-a \
  --project=dev-infra-503304 --tunnel-through-iap

gcloud compute ssh dev-frontend-vm --zone=asia-south1-a \
  --project=dev-infra-503304 --tunnel-through-iap
```

Check containers on either VM:
```bash
sudo docker ps
sudo docker compose -f /opt/app/docker-compose.yml logs -f
```

---

## 6. Local testing (no GCP, just Docker) — optional but recommended first

```bash
# terminal 1: backend + mongo
cd backend
docker compose up --build

# terminal 2: frontend, pointing at local backend
cd frontend
BACKEND_URL=http://localhost:5000 docker compose up --build
```
Open http://localhost — submit the form, then confirm the record landed:
```bash
curl http://localhost:5000/students
```

---

## 7. Tearing down an environment

```bash
cd terraform
terraform init -backend-config="bucket=dev-infra-503304-tfstate" \
  -backend-config="prefix=terraform/state/dev"
terraform destroy -var-file="environments/dev.tfvars" \
  -var="dockerhub_username=YOUR_DOCKERHUB_USERNAME"
```

---

## 8. Security notes worth knowing

- Backend VM has **no external IP** — it can only be reached from the
  frontend's subnet (port 5000) and via IAP for SSH. It reaches Docker Hub
  through Cloud NAT.
- SSH is IAP-only (`35.235.240.0/20`), not open to the internet.
- MongoDB is only exposed on the private VM's internal network, never public.
- Rotate the `github-deployer` service account keys periodically, or better,
  switch to [Workload Identity Federation](https://github.com/google-github-actions/auth#setting-up-workload-identity-federation)
  instead of long-lived JSON keys once this is working end-to-end.
