# GCP Two-Tier Student Form — Terraform + Docker + GitHub Actions

> All commands below are written for **VS Code's PowerShell terminal on
> Windows**. Steps that happen *inside* a Linux VM (after `gcloud compute
> ssh ...`) are bash, since that's the VM's own shell — those are marked
> clearly.

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

## 1. One-time local tool checks

```powershell
gcloud --version
terraform -version
docker --version
git --version
```

If any of these say "not recognized," install it first:
- gcloud: https://cloud.google.com/sdk/docs/install
- Terraform: https://developer.hashicorp.com/terraform/install
- Docker Desktop: https://www.docker.com/products/docker-desktop

---

## 2. One-time GCP setup (repeat for EACH of the 3 projects)

Log in once:

```powershell
gcloud auth login
gcloud auth application-default login
```

The second command is what lets Terraform authenticate locally (separate
from the login above).

Now run this block **three times**, changing only the `$PROJECT_ID` line
each time — first for `dev-infra-503304`, then `qa-infra-500307`, then
`prod-infra-503304`:

```powershell
$PROJECT_ID = "dev-infra-503304"

gcloud config set project $PROJECT_ID

gcloud services enable compute.googleapis.com iam.googleapis.com iamcredentials.googleapis.com cloudresourcemanager.googleapis.com iap.googleapis.com

gsutil mb -l asia-south1 "gs://$PROJECT_ID-tfstate"
gsutil versioning set on "gs://$PROJECT_ID-tfstate"

gcloud iam service-accounts create github-deployer --display-name="GitHub Actions Deployer"

$SA_EMAIL = "github-deployer@$PROJECT_ID.iam.gserviceaccount.com"

$roles = @("roles/compute.admin", "roles/iam.serviceAccountUser", "roles/storage.admin", "roles/iap.tunnelResourceAccessor")
foreach ($ROLE in $roles) {
  gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_EMAIL" --role="$ROLE"
}

gcloud iam service-accounts keys create "$PROJECT_ID-key.json" --iam-account=$SA_EMAIL
```

This produces `dev-infra-503304-key.json` (and later `qa-infra-500307-key.json`,
`prod-infra-503304-key.json`) in your current folder. These are what you
paste into GitHub secrets in step 4. Never commit them — `.gitignore`
already excludes `*.json`.

> If `gcloud iam service-accounts create github-deployer` fails with
> "already exists" on your 2nd/3rd run — that's fine, service account names
> are per-project, so it's actually creating a fresh one each time; the
> error would only happen if you reused a project ID by mistake.

---

## 3. Docker Hub setup

1. Create a Docker Hub account (or use an existing one).
2. Docker Hub → Account Settings → Security → **New Access Token**
   (read/write). Save the token somewhere — you'll paste it into a GitHub
   secret next.

Update `terraform/environments/dev.tfvars`, `qa.tfvars`, and `prod.tfvars` —
replace `REPLACE_WITH_YOUR_DOCKERHUB_USERNAME` with your real Docker Hub
username in all three files.

---

## 4. GitHub repo setup

### 4.1 Push this code

```powershell
git init
git remote add origin https://github.com/kaushalchauhan84850/GCP-two-tear-deployment.git
git add .
git commit -m "Initial two-tier infra + app"
git branch -M main
git push -u origin main
```

### 4.2 Create the three branches

```powershell
git checkout main
git checkout -b dev
git push -u origin dev

git checkout main
git checkout -b qa
git push -u origin qa

git checkout main
git checkout -b prod
git push -u origin prod
```

### 4.3 Add repository secrets

To view a key file's contents so you can copy it:

```powershell
Get-Content .\dev-infra-503304-key.json -Raw
```

Copy the full output (including the outer `{` and `}`) and paste it as the
secret value.

GitHub repo → **Settings → Secrets and variables → Actions → New repository
secret**:

| Secret name          | Value                                              |
|-----------------------|-----------------------------------------------------|
| `DOCKERHUB_USERNAME`  | your Docker Hub username                            |
| `DOCKERHUB_TOKEN`     | the access token from step 3                         |
| `GCP_SA_KEY_DEV`      | full contents of `dev-infra-503304-key.json`         |
| `GCP_SA_KEY_QA`       | full contents of `qa-infra-500307-key.json`           |
| `GCP_SA_KEY_PROD`     | full contents of `prod-infra-503304-key.json`        |

### 4.4 Branch protection (link branches → environments)

Settings → **Environments** → create `production` and require a reviewer
(this is what makes `prod.yml`'s `environment: production` pause for manual
approval before deploying). Optionally create `dev`/`qa` environments too and
attach the matching `GCP_SA_KEY_*` secret to each environment instead of the
repo level, for tighter scoping.

Settings → **Branches** → add protection rules for `dev`, `qa`, `prod` (e.g.
require PR review before merge, require the workflow to pass).

Delete the local key files once uploaded as secrets:

```powershell
Remove-Item dev-infra-503304-key.json, qa-infra-500307-key.json, prod-infra-503304-key.json
```

---

## 5. How the pipeline works (per branch)

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

## 6. First-time manual run (recommended before trusting the pipeline)

Test locally, per environment, before relying on CI. This assumes you've
already set up `terraform/.env.dev` per section 7.0 below.

```powershell
cd terraform
. ..\scripts\load-env.ps1 .env.dev

terraform init -backend-config="bucket=dev-infra-503304-tfstate" -backend-config="prefix=terraform/state/dev"

terraform plan -var-file="environments/dev.tfvars"

terraform apply -var-file="environments/dev.tfvars"
```

No `-var` flags needed — `dockerhub_username`, `image_tag`, and `mongo_uri`
all come from the `.env.dev` file you loaded.

Grab the frontend IP from the output and open it in a browser:

```powershell
terraform output frontend_public_ip
```

To SSH in for debugging (IAP tunnel, no public SSH port needed):

```powershell
gcloud compute ssh dev-backend-vm --zone=asia-south1-a --project=dev-infra-503304 --tunnel-through-iap

gcloud compute ssh dev-frontend-vm --zone=asia-south1-a --project=dev-infra-503304 --tunnel-through-iap
```

**Once you're inside the VM** (the prompt changes to a Linux-style prompt),
you're in bash, not PowerShell, so these work as-is:

```bash
sudo docker ps
sudo docker compose -f /opt/app/docker-compose.yml logs -f
```

Type `exit` to leave the VM and return to your local PowerShell prompt.

---

## 7. Local testing (no GCP, just Docker) — optional but recommended first

### 7.0 Set up permanent .env files (do this once)

Instead of typing `$env:VAR = "..."` every session, use `.env` files.
`.env.example` files are already in the repo as templates — copy them and
fill in your real values. These real `.env` files are gitignored, so your
secrets never get committed.

```powershell
Copy-Item backend\.env.example backend\.env
Copy-Item frontend\.env.example frontend\.env
Copy-Item terraform\.env.dev.example terraform\.env.dev
Copy-Item terraform\.env.qa.example terraform\.env.qa
Copy-Item terraform\.env.prod.example terraform\.env.prod
```

Then edit each copied `.env*` file and fill in your real Docker Hub
username and MongoDB Atlas connection string.

**`backend/.env`** and **`frontend/.env`** are picked up automatically by
`docker compose` — nothing else needed, just run `docker compose up --build`
from inside each folder and the variables load themselves.

**`terraform/.env.dev`** (and `.env.qa` / `.env.prod`) are *not* auto-loaded
by Terraform — but Terraform does auto-read any `TF_VAR_<name>` environment
variable. Load one into your current PowerShell session with the included
script (note the leading `. ` — that's "dot-sourcing", required so the
variables persist in your shell rather than a throwaway subprocess):

```powershell
cd terraform
. ..\scripts\load-env.ps1 .env.dev
```

After that, you can run `terraform plan` / `terraform apply` with **no**
`-var` flags at all — Terraform picks up `dockerhub_username`, `image_tag`,
and `mongo_uri` automatically from the environment variables you just loaded.

Open **two separate PowerShell terminals** in VS Code (use the `+` icon in
the terminal panel, or the split-terminal button).

Terminal 1 — backend:

```powershell
cd backend
docker compose up --build
```

Terminal 2 — frontend, pointing at local backend:

```powershell
cd frontend
docker compose up --build
```

Open http://localhost in a browser, submit the form, then confirm the
record landed:

```powershell
Invoke-RestMethod http://localhost:5000/students
```

(`Invoke-RestMethod` is PowerShell's equivalent of `curl` here — plain
`curl` also works since PowerShell aliases it, but `Invoke-RestMethod`
prints the JSON more readably.)

To stop both, `Ctrl+C` in each terminal, then run in each folder
(`backend/` and `frontend/`) if you want to remove the containers:

```powershell
docker compose down
```

---

## 8. Tearing down an environment

```powershell
cd terraform
. ..\scripts\load-env.ps1 .env.dev
terraform init -backend-config="bucket=dev-infra-503304-tfstate" -backend-config="prefix=terraform/state/dev"
terraform destroy -var-file="environments/dev.tfvars"
```

---

## 9. Common PowerShell gotchas (why bash examples online don't paste cleanly)

| bash | PowerShell equivalent |
|---|---|
| `VAR=value` | `$VAR = "value"` |
| `${VAR}` inside a string | `$VAR` inside a double-quoted string |
| `cmd1 && cmd2` | put on separate lines, or `cmd1; cmd2` (note: plain `;` always runs cmd2 even if cmd1 fails — `&&` in PowerShell 7+ short-circuits like bash) |
| `for x in a b c; do ...; done` | `foreach ($x in @("a","b","c")) { ... }` |
| line continuation `\` at end of line | backtick `` ` `` at end of line — but easiest is just put the whole command on one line |
| `cat file` / `rm file` / `ls` | work the same (aliased in PowerShell) |
| `curl url` | works but is aliased to `Invoke-WebRequest`; use `Invoke-RestMethod` for JSON APIs |

If you're ever unsure whether a snippet from a tutorial is bash or
PowerShell, look for `&&`, `\` line continuations, or bare `VAR=value`
without a `$` prefix — those are bash tells.

---

## 10. Security notes worth knowing

- Backend VM has **no external IP** — it can only be reached from the
  frontend's subnet (port 5000) and via IAP for SSH. It reaches Docker Hub
  through Cloud NAT.
- SSH is IAP-only (`35.235.240.0/20`), not open to the internet.
- MongoDB is only exposed on the private VM's internal network, never public.
- Rotate the `github-deployer` service account keys periodically, or better,
  switch to [Workload Identity Federation](https://github.com/google-github-actions/auth#setting-up-workload-identity-federation)
  instead of long-lived JSON keys once this is working end-to-end.
