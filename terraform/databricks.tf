# ---------------------------------------------------------------------------
# Everything in this file lives INSIDE the Databricks workspace.
# ---------------------------------------------------------------------------

data "databricks_current_user" "me" {
  depends_on = [azurerm_databricks_workspace.this]
}

# Always resolves to the latest Long Term Support Databricks runtime,
# so this never goes stale.
data "databricks_spark_version" "lts" {
  long_term_support = true
  depends_on        = [azurerm_databricks_workspace.this]
}

# Clones the GitHub repo into the workspace as a Git folder. The notebook
# and CSVs the cluster sees are therefore exactly what is committed to git.
# Works without any credentials as long as the GitHub repo is PUBLIC.
# (For a private repo you would add a databricks_git_credential resource
# with a GitHub personal access token.)
resource "databricks_repo" "cv" {
  url          = var.github_repo_url
  git_provider = "gitHub"
  path         = "${data.databricks_current_user.me.repos}/cv-pipeline"
}

# One single-node cluster does double duty:
#   1. runs the transformation notebook
#   2. is the endpoint Power BI connects to for the one-off Import
#
# Why not a serverless SQL warehouse? Azure free-trial subscriptions are
# capped at 4 vCPUs and generally cannot use serverless compute, and a
# classic SQL warehouse needs ~16 vCPUs. This 4-vCPU single node is the
# biggest thing guaranteed to start on a free trial. See
# serverless-warehouse.tf.optional for the upgrade path.
resource "databricks_cluster" "single_node" {
  cluster_name  = "cv-single-node"
  spark_version = data.databricks_spark_version.lts.id
  node_type_id  = var.node_type_id
  num_workers   = 0

  # New workspaces are secure-by-default and reject the legacy
  # NO_ISOLATION mode (which is what an unset access mode falls back to).
  # Dedicated single-user mode is the supported equivalent for a
  # personal cluster: only you can attach to it.
  data_security_mode = "SINGLE_USER"
  single_user_name   = data.databricks_current_user.me.user_name

  # Shuts itself down after 15 idle minutes -- protects your credit.
  autotermination_minutes = 15

  # These three settings are the standard recipe for a single-node cluster.
  spark_conf = {
    "spark.databricks.cluster.profile" = "singleNode"
    "spark.master"                     = "local[*]"
  }

  custom_tags = {
    "ResourceClass" = "SingleNode"
  }
}

# "Refresh my CV" as one click. Deliberately reuses the cluster above
# instead of a separate job cluster: the free trial's 4-vCPU quota only
# fits one cluster at a time. (In a production setup you'd give the job
# its own job cluster.)
resource "databricks_job" "refresh_cv" {
  name = "refresh-cv-tables"

  task {
    task_key            = "transform_cv"
    existing_cluster_id = databricks_cluster.single_node.id

    notebook_task {
      # The .py file in the repo appears as a notebook (no extension)
      # inside the workspace.
      notebook_path = "${databricks_repo.cv.path}/databricks/01_transform_cv"
    }
  }
}
