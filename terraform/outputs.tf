output "workspace_url" {
  description = "Open this in a browser to reach the Databricks workspace."
  value       = "https://${azurerm_databricks_workspace.this.workspace_url}"
}

# The next two outputs are exactly what Power BI Desktop asks for under
# Get data -> Azure Databricks.

output "powerbi_server_hostname" {
  description = "Power BI Desktop -> Get data -> Azure Databricks -> Server hostname"
  value       = azurerm_databricks_workspace.this.workspace_url
}

output "powerbi_http_path" {
  description = "Power BI Desktop -> Get data -> Azure Databricks -> HTTP path"
  value       = "sql/protocolv1/o/${azurerm_databricks_workspace.this.workspace_id}/${databricks_cluster.single_node.id}"
}

output "repo_path_in_workspace" {
  description = "Where the GitHub repo is checked out inside the workspace."
  value       = databricks_repo.cv.path
}

output "job_name" {
  description = "Run this under Workflows in the workspace to (re)build the tables."
  value       = databricks_job.refresh_cv.name
}
