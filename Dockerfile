# Deploy toolchain for this repo: terraform + azure-cli + git.
#
# The image holds TOOLS ONLY. The repo is bind-mounted at /workspace at
# runtime (see compose.yaml), so terraform.tfvars, terraform.tfstate and
# the CSVs never enter an image layer.
#
# Every version is pinned here and nowhere else. To bump one, edit it and
# run .\deploy.cmd -- the --build flag picks the change up automatically.

# Azure CLI comes pre-pinned in Microsoft's own image (az is a Python app
# with ~80 dependencies -- installing it yourself is the fragile path).
# Pinned by tag AND digest: the tag documents intent, the digest makes it
# immutable. When bumping, resolve the new digest with:
#   docker buildx imagetools inspect mcr.microsoft.com/azure-cli:<tag>
# Base OS is Azure Linux 3 -> package manager is tdnf.
FROM mcr.microsoft.com/azure-cli:2.89.0@sha256:0926e9e5230a66eac8061beab122ffee5750c4fb924a7b5608c8d3cdd3511158

# Repo requires >= 1.5.0 (terraform/providers.tf).
ARG TERRAFORM_VERSION=1.15.9
ARG TARGETARCH=amd64

# git: so the Git folder clone URL and any terraform module fetching work,
# and for emergency use on the mounted repo. unzip/ca-certificates: for the
# terraform download below.
RUN tdnf install -y git unzip ca-certificates && tdnf clean all

# Providers download into a named volume (see compose.yaml), so a wiped
# .terraform never costs a ~300MB re-download. CHECKPOINT_DISABLE stops
# terraform phoning home to check for upgrades past our pin. (Set before
# the install layer below so its `terraform version` check is covered too.)
ENV TF_PLUGIN_CACHE_DIR=/tf-cache \
    CHECKPOINT_DISABLE=1

# Terraform: official HashiCorp release zip, verified against the
# SHA256SUMS file published alongside it. A typo'd version or a tampered
# zip fails the build loudly.
RUN curl -fsSLO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" \
 && curl -fsSLO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
 && sha256sum --check --ignore-missing "terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
 && unzip "terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" terraform -d /usr/local/bin \
 && rm -f "terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" "terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
 && terraform version

# The bind-mounted repo appears owned by a foreign uid, which git would
# refuse with 'dubious ownership' -- pre-approve the mount point. And the
# host checkout uses CRLF (core.autocrlf=true on Windows), so container
# git must agree or `git status` would show every file as modified.
RUN git config --system --add safe.directory /workspace \
 && git config --system core.autocrlf true \
 # so terraform doesn't complain if the image is ever run without the
 # compose volume mounted over /tf-cache
 && install -d /tf-cache

WORKDIR /workspace/terraform
CMD ["bash"]
