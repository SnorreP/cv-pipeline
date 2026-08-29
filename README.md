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
| `data/` | The CV itself, as CSVs. This is the only thing to edit when the CV changes. |
| `databricks/01_transform_cv.py` | Notebook that turns the CSVs into Delta tables. |
| `terraform/` | Defines the workspace, cluster, Git folder and refresh job. |
| `powerbi/` | The report, saved as a Power BI Project (`.pbip`) in Phase 3. |

## Prerequisites

- An Azure subscription (the free trial works; everything here fits well
  inside the $200 credit)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5,
  [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), git
- Power BI Desktop, plus a work/school account for publishing

## Deploy the environment

1. Push this repo to GitHub as a **public** repo *before* running Terraform.
   The workspace clones it during `apply`, so it must exist first.
2. `az login`
3. ```
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   ```
   then fill in your subscription ID and repo URL in `terraform.tfvars`.
4. ```
   terraform init
   terraform apply
   ```
   Workspace creation is the slow part -- expect 5-10 minutes.
5. `terraform output` shows the workspace URL and the two values Power BI
   will need (`powerbi_server_hostname` and `powerbi_http_path`).

## Run the pipeline

Open the workspace URL, go to **Workflows**, and run **refresh-cv-tables**.
The first run takes ~5 minutes extra while the cluster starts. Alternatively,
open the notebook under **Workspace -> Repos** and hit **Run all**.

## Build and publish the report

1. Power BI Desktop -> **Get data -> Azure Databricks**.
2. Paste `powerbi_server_hostname` and `powerbi_http_path` from the
   Terraform outputs. Choose **Import**, and sign in with **Microsoft
   Entra ID** using the same account you use for Azure.

   The cluster must be running for this step -- run the job first, or start
   the cluster from the Compute page.
3. Tick the tables in the `cv` schema and load.
4. Build the report. In *File -> Options -> Preview features*, enable
   **Power BI Project (.pbip) save option**, then save the report into
   `powerbi/` and commit -- `.pbip` projects are plain text and diff
   properly in git, unlike `.pbix`.
5. Publish to the Power BI Service, then *File -> Embed report ->
   Publish to web* for the public link. (Publish to web must be enabled by
   the tenant admin -- check this early.)

## Tear down

```
terraform destroy
```

The published report keeps working -- Import mode means the data travels
with it.

## Updating the CV later

1. Edit the CSVs, commit, push.
2. `terraform apply` to recreate the workspace (if destroyed).
3. In the workspace, open the Git folder and **pull** so the checkout picks
   up the new commit (the clone does not update itself).
4. Run **refresh-cv-tables**, then **Refresh** in Power BI Desktop,
   republish, and destroy again. About 30 minutes end to end.
