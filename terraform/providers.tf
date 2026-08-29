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
provider "databricks" {
  host      = azurerm_databricks_workspace.this.workspace_url
  auth_type = "azure-cli"
}
