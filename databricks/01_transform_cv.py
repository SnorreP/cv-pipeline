# Databricks notebook source
# MAGIC %md
# MAGIC # CV data pipeline
# MAGIC
# MAGIC Reads the raw CSV files from this repo's `data/` folder, cleans and
# MAGIC enriches them with PySpark, and saves the results as Delta tables in
# MAGIC the **`cv`** schema. The Power BI report imports those tables.
# MAGIC
# MAGIC Run it either through the **`refresh-cv-tables`** job that Terraform
# MAGIC created (Workflows in the left menu), or interactively with **Run all**.

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Configuration

# COMMAND ----------

import os

from pyspark.sql import functions as F

SCHEMA = "cv"

# The CV exists in English and Danish, and BOTH are loaded. Every table
# carries a `language` column, and a `languages` dimension joins to all of
# them, so a single slicer in the report switches the whole page -- content
# and the report's own headings alike. No re-run is needed to change
# language, which is why there is no language parameter on the job.
LANGUAGES = ["en", "da"]

# Inside a Databricks Git folder, a notebook's working directory is the
# folder the notebook file sits in (<repo>/databricks), so the CSVs are one
# level up in <repo>/data/<language>. If this ever misbehaves, hardcode it:
# DATA_DIR = "/Workspace/Repos/<your-user>/cv-pipeline/data"
DATA_DIR = os.path.join(os.path.dirname(os.getcwd()), "data")
print(f"Reading CSVs from: {DATA_DIR}")
print(f"Languages: {', '.join(LANGUAGES)}")

spark.sql(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. Helpers

# COMMAND ----------

def _read(path: str):
    # The file: prefix tells Spark this is a plain file path, which works
    # here because the cluster is single-node.
    return (
        spark.read
        .option("header", True)
        .option("inferSchema", True)  # fine for data this small
        .csv(f"file:{path}")
    )


def load_csv(name: str):
    """Read one table in EVERY language and stack the results.

    Each language's rows are tagged with a `language` column, which is what
    the report's language slicer filters on. Column order is normalised so
    the union never depends on how the CSVs happen to be written.
    """
    frames = []
    for lang in LANGUAGES:
        df = _read(os.path.join(DATA_DIR, lang, f"{name}.csv")).withColumn("language", F.lit(lang))
        frames.append(df)
    combined = frames[0]
    for df in frames[1:]:
        combined = combined.unionByName(df.select(combined.columns))
    return combined


def save_table(df, name: str):
    """Overwrite one Delta table in the cv schema."""
    (
        df.write
        .format("delta")
        .mode("overwrite")
        .option("overwriteSchema", "true")  # lets you add/rename columns freely
        .saveAsTable(f"{SCHEMA}.{name}")
    )
    print(f"Saved {SCHEMA}.{name} ({df.count()} rows)")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Experience
# MAGIC
# MAGIC A blank `end_date` in the CSV means "current role". From the two dates
# MAGIC we derive `is_current` and the duration of each role, so the report
# MAGIC never has to calculate anything itself.

# COMMAND ----------

experience = (
    load_csv("experience")
    .withColumn("start_date", F.to_date("start_date"))
    .withColumn("end_date", F.to_date("end_date"))
    .withColumn("is_current", F.col("end_date").isNull())
    .withColumn(
        "duration_months",
        F.round(
            F.months_between(
                F.coalesce(F.col("end_date"), F.current_date()),
                F.col("start_date"),
            )
        ).cast("int"),
    )
    .withColumn("duration_years", F.round(F.col("duration_months") / 12, 1))
)

save_table(experience, "experience")
display(experience)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. Education, skills and projects

# COMMAND ----------

education = (
    load_csv("education")
    .withColumn("start_date", F.to_date("start_date"))
    .withColumn("end_date", F.to_date("end_date"))
)
save_table(education, "education")

# COMMAND ----------

skills = (
    load_csv("skills")
    .withColumn("skill", F.trim("skill"))
    .withColumn("category", F.trim("category"))
    .withColumn("proficiency", F.col("proficiency").cast("int"))
    .withColumn("years_experience", F.col("years_experience").cast("double"))
)
save_table(skills, "skills")

# COMMAND ----------

projects = load_csv("projects").withColumn("year", F.col("year").cast("int"))
save_table(projects, "projects")

# COMMAND ----------

# The profile paragraphs and the reference quote are one row each -- they
# carry no metrics, but they belong in the model so the report can pull
# every word of the CV from the same place as the numbers.
save_table(load_csv("profile"), "profile")
save_table(load_csv("testimonials"), "testimonials")

# COMMAND ----------

# MAGIC %md
# MAGIC ### The report's own words
# MAGIC
# MAGIC Section headings, captions and button text live here rather than
# MAGIC being typed into the report, so the language slicer switches the
# MAGIC whole page instead of just the CV content.

# COMMAND ----------

save_table(load_csv("labels"), "labels")

# The dimension the slicer sits on. It is not language-specific -- one row
# per language, joined to every other table on `language`.
languages = _read(os.path.join(DATA_DIR, "languages.csv"))
save_table(languages, "languages")

# `tech_stack` is a semicolon-separated list in the CSV. Exploding it into
# one row per (project, technology) pair lets Power BI count projects per
# technology -- a small but visible example of why the transformation
# layer exists.
project_technologies = (
    projects
    .withColumn("technology", F.explode(F.split("tech_stack", ";")))
    .withColumn("technology", F.trim("technology"))
    .select("language", "project", "technology")
)
save_table(project_technologies, "project_technologies")
display(project_technologies)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Summary metrics
# MAGIC
# MAGIC A per-language long-format table, kept only as a convenience for
# MAGIC anyone querying the schema directly. The report does NOT use it --
# MAGIC its cards compute the same numbers live in DAX, which keeps them
# MAGIC correct under the language slicer and de-duplicates overlapping
# MAGIC roles (a plain sum of durations would double-count them).

# COMMAND ----------

cv_summary = (
    experience.groupBy("language")
    .agg(
        F.round(F.sum("duration_months") / 12, 1).alias("years_of_experience"),
        F.countDistinct("company").cast("double").alias("employers"),
    )
    .join(skills.groupBy("language").agg(F.count("*").cast("double").alias("skills")), "language")
    .join(projects.groupBy("language").agg(F.count("*").cast("double").alias("projects")), "language")
)

save_table(cv_summary, "cv_summary")
display(cv_summary)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. What Power BI should import
# MAGIC
# MAGIC The cell below prints the full name of every table this notebook
# MAGIC produced. In Power BI Desktop: **Get data -> Azure Databricks**, enter
# MAGIC the server hostname and HTTP path from `terraform output`, choose
# MAGIC **Import**, sign in with your Azure account, and tick these tables.

# COMMAND ----------

catalog = spark.sql("SELECT current_catalog()").first()[0]
tables = spark.sql(f"SHOW TABLES IN {SCHEMA}").collect()

print(f"Catalog: {catalog}\nSchema:  {SCHEMA}\n")
for t in tables:
    print(f"  {catalog}.{SCHEMA}.{t.tableName}")
