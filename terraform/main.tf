# ---------------------------------------------------------------------------
# Azure resources
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = "rg-cv-pipeline"
  location = var.location
}

# sku = "trial" gives 14 days of premium features with zero DBU charges.
# You still pay for the underlying VM while a cluster runs (covered many
# times over by the $200 free-trial credit, and the cluster auto-stops).
#
# When the 14 days are up, either destroy everything (the published Power BI
# report keeps working because it uses Import mode) or change this to
# "premium" if you ever move to a paid subscription.
resource "azurerm_databricks_workspace" "this" {
  name                = "dbw-cv-pipeline"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "trial"
}
