# ── AWS / EKS ──────────────────────────────────────────────────
region       = "ap-south-1"
cluster_name = "three-tier-cluster"
vpc_cidr     = "10.0.0.0/16"


# ── ArgoCD / GitHub ────────────────────────────────────────────
github_repo_url = "https://github.com/Aishwini08/End-to-End-Kubernetes-Three-Tier-Project.git"
github_username = "Aishwini08"

# DO NOT paste your token here — pass it as an environment variable:
#   export TF_VAR_github_token="ghp_xxxxxxxxxxxxxxxxxxxx"
# Then run: terraform apply
