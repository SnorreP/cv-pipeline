# CV pipeline

My CV as a data product. The raw CV lives in this repo as CSV files, an Azure
Databricks notebook transforms them into Delta tables, and a Power BI report
imports those tables. The Databricks environment itself is defined with
Terraform, so the whole thing can be created and destroyed on demand.

```
GitHub repo (CSVs + notebook + Terraform + .pbip report)
        |
        |  terraform apply
        v
Azure Databricks workspace
        |-- Git folder (clone of this repo)
        |-- single-node cluster
        `-- job: refresh-cv-tables --> Delta tables in the `cv` schema
        |
        |  one-off Import
        v
Power BI Desktop --> Power BI Service --> Publish to web (public link)
```

The report uses **Import mode**: the data is baked into the published report,
so once it is live the Databricks workspace can be destroyed and the public
link keeps working at zero cost. The workspace only needs to exist while
building or refreshing the report.

## Repo layout

| Path | What it is |
|---|---|
| `data/en/`, `data/da/` | The CV itself, as CSVs, in English and Danish. This is the only thing to edit when the CV changes -- keep the two languages in step. |
| `databricks/01_transform_cv.py` | Notebook that turns the CSVs into Delta tables. |
| `terraform/` | Defines the workspace, cluster, Git folder and refresh job. |
| `powerbi/` | The report, saved as a Power BI Project (`.pbip`) in the "Build and publish the report" step. |
| `Dockerfile`, `compose.yaml`, `deploy.cmd` | The containerized deploy toolchain (pinned Terraform + Azure CLI). |

## Prerequisites

- An Azure subscription (the free trial works; everything here fits well
  inside the $200 credit)
- [Rancher Desktop](https://rancherdesktop.io/) (or Docker Desktop) with the
  **dockerd (moby)** container engine -- the deploy toolchain runs in a
  container, so Terraform and the Azure CLI need no local install.
  (No Docker? Installing [Terraform](https://developer.hashicorp.com/terraform/install)
  >= 1.5 and the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
  locally works too.)
- git
- Power BI Desktop, plus a work/school account for publishing

## The deploy container

Everything Azure-facing runs inside a small container image (pinned
Terraform + Azure CLI + git), so the pipeline deploys identically on any
machine. With Rancher Desktop running:

```
.\deploy.cmd
```

The first run builds the image (a few minutes; instant afterwards) and
drops you into a shell already in `terraform/`, with `terraform`, `az` and
`git` on PATH. You can also run single commands: `.\deploy.cmd terraform plan`.

How it fits together:

- The repo is mounted into the container at `/workspace`, so
  `terraform.tfvars`, `terraform.tfstate` and `.terraform.lock.hcl` live on
  your machine exactly as before. Nothing irreplaceable is inside the
  container -- you can stop using it at any time.
- Your Azure login and the downloaded providers persist in named Docker
  volumes (`cv-pipeline_azure-config`, `cv-pipeline_tf-scratch`,
  `cv-pipeline_tf-cache`), so you sign in once and `terraform init` is
  fast after the first time. `docker volume rm cv-pipeline_azure-config`
  signs you out; removing the other two just means re-downloading.
  Avoid `docker compose down -v`, which removes all three.
- Inside the container, sign in with `az login --use-device-code` (a
  container has no browser -- open the printed URL on your machine and
  enter the code). The login survives across runs for weeks.
- Tool versions are pinned in the `Dockerfile` and that is the only place
  they live. Bump a pin, run `.\deploy.cmd`, and the image rebuilds itself.
- A `No services to build` warning at startup is a harmless Docker Compose
  quirk -- the build and the command still run.
- After the first `terraform init`, commit `terraform/.terraform.lock.hcl`
  -- it pins the exact provider builds for every machine. If you ever want
  to run terraform directly on Windows again, extend it first with
  `terraform providers lock -platform=linux_amd64 -platform=windows_amd64`.

## Deploy the environment

1. Push this repo to GitHub as a **public** repo *before* running Terraform.
   The workspace clones it during `apply`, so it must exist first.
2. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`
   and fill in your subscription ID and repo URL.
3. `.\deploy.cmd` -- you land in a shell in `terraform/`. In it:
   ```
   az login --use-device-code
   terraform init
   terraform apply
   ```
   Workspace creation is the slow part -- expect 5-10 minutes. The first
   `init` writes `terraform/.terraform.lock.hcl` on your machine -- commit
   it (see "The deploy container").
4. `terraform output` shows the workspace URL and the two values Power BI
   will need (`powerbi_server_hostname` and `powerbi_http_path`).

## Run the pipeline

Open the workspace URL, go to **Workflows**, and run **refresh-cv-tables**.
The first run takes ~5 minutes extra while the cluster starts. Alternatively,
open the notebook under **Workspace -> Repos** and hit **Run all**.

### Two languages, one report

The CV is committed in both English (`data/en/`) and Danish (`data/da/`),
and the pipeline loads **both**. Every table carries a `language` column,
a `languages` dimension joins to all of them, and a single slicer on the
report switches everything at once -- so one published link serves Danish
and English applications alike.

The report's own words switch too. Section headings, captions and button
text are not typed into the report: they live in `data/<lang>/labels.csv`
and reach the canvas as measures, so the language slicer moves them along
with the CV content. To reword a heading, edit the CSV -- not the report.

The slicer is single-select with the selection forced, so exactly one
language is always applied and the report can never render half-empty.

When adding to the CV, keep the two folders in step: same tables, same
columns, same number of rows, and the same `sort_order` values (that
column, rather than a DAX ranking, is what orders roles and skills
identically in both languages).

## Build and publish the report

1. Power BI Desktop -> **Get data -> Azure Databricks**.
2. Paste `powerbi_server_hostname` and `powerbi_http_path` from the
   Terraform outputs, and choose **Import**.
3. Sign in with a **Personal Access Token** (the Microsoft Entra ID option
   only accepts work/school accounts -- with a personal Microsoft account
   it fails with "you can't use a personal account here"). Generate the
   token in the workspace: avatar (top right) -> **Settings** ->
   **Developer** -> **Access tokens** -> **Generate new token**, scope
   **BI Tools**. Copy it immediately (shown once) and paste it into the
   Personal Access Token option in Power BI. Tokens die with the
   workspace: after every `terraform destroy` + re-apply, generate a
   fresh one. If Power BI remembers a failed sign-in and won't ask again:
   *File -> Options and settings -> Data source settings -> Clear
   permissions*.

   The cluster must be running for this step -- run the job first, or start
   the cluster from the Compute page.
4. Tick the tables in the `cv` schema and load.
5. Build the report. In *File -> Options -> Preview features*, enable
   **Power BI Project (.pbip) save option**, then save the report into
   `powerbi/` and commit -- `.pbip` projects are plain text and diff
   properly in git, unlike `.pbix`.
6. Publish to the Power BI Service, then *File -> Embed report ->
   Publish to web* for the public link. (Publish to web must be enabled by
   the tenant admin -- check this early. The Service also requires a
   work/school account -- a personal Microsoft account cannot publish.)

## Tear down

```
.\deploy.cmd terraform destroy
```

The published report keeps working -- Import mode means the data travels
with it.

## Updating the CV later

1. Edit the CSVs, commit, push.
2. `.\deploy.cmd terraform apply` to recreate the workspace (if destroyed).
   If the Azure login has expired, run `.\deploy.cmd`, sign in again with
   `az login --use-device-code`, then `terraform apply`.
3. In the workspace, open the Git folder and **pull** so the checkout picks
   up the new commit (the clone does not update itself).
4. Run **refresh-cv-tables**. If the workspace was recreated, update the
   connection in Power BI Desktop (*Transform data -> Data source settings*)
   with the new `powerbi_server_hostname` and `powerbi_http_path` from
   `terraform output` -- a rebuilt workspace gets a new hostname and HTTP
   path -- and generate a fresh Personal Access Token in the new workspace
   (the old token died with the old one; see "Build and publish the
   report"). Then **Refresh**, republish, and
   `.\deploy.cmd terraform destroy` again. About 30 minutes end to end.
