# ---------------------------------------------------------------------------
# Providers
#
# Two providers work together here:
#   - azurerm    creates Azure resources (resource group, Databricks workspace)
#   - databricks creates things INSIDE that workspace (cluster, git folder, job)
#
# Both authenticate through your Azure CLI session, so the only setup you
# need is `az login` before running terraform (from the deploy container:
# `az login --use-device-code`). No tokens or secrets.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.60"
    }
  }
}

provider "azurerm" {
  features {}
  # azurerm v4 requires the subscription to be set explicitly.
  subscription_id = var.subscription_id
}

# Points at the workspace defined in main.tf. Terraform understands the
# dependency: it creates the workspace first, then connects to it.
#
# One trap: if a change forces the WORKSPACE itself to be replaced (e.g.
# a new location), this host becomes unknown during planning and every
# databricks_* resource errors with a misleading "azure-cli auth: not
# configured". Since those resources die with the workspace anyway, drop
# them from state first, then apply:
#   terraform state rm databricks_repo.cv databricks_cluster.single_node databricks_job.refresh_cv
provider "databricks" {
  host      = azurerm_databricks_workspace.this.workspace_url
  auth_type = "azure-cli"
}
