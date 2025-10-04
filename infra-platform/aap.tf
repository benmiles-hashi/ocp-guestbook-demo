terraform {
  required_providers {
    aap = {
      source  = "ansible/aap"
      version = "~> 1.0"   # check for latest
    }
  }
}

provider "aap" {
  # configure with your AAP/Tower host & credentials
  hostname = var.aap_hostname
  username = var.aap_username
  password = var.aap_password
  insecure = true
}

# 1. Project
resource "aap_project" "playbooks_project" {
  name        = "OCP Playbooks Project"
  description = "Git repo with ocp-tfe-admin-sa-setup.yml and ocp-vso-operator-install.yml"
  organization_id = 1                      # adjust for your org
  scm_type    = "git"
  scm_url     = var.repo_url               # e.g. https://github.com/you/ocp-playbooks.git
  scm_branch  = "main"
  scm_update_on_launch = true
}

# 2. Inventory
resource "aap_inventory" "localhost" {
  name            = "Localhost Inventory"
  description     = "Local connection for API-driven playbooks"
  organization_id = 1
  variables = <<EOT
---
all:
  hosts:
    localhost:
      ansible_connection: local
EOT
}

# 3. Job Template: tf-admin SA setup
resource "aap_job_template" "tf_admin_sa" {
  name            = "OCP - TF Admin SA Setup"
  job_type        = "run"
  inventory_id    = aap_inventory.localhost.id
  project_id      = aap_project.playbooks_project.id
  playbook        = "ocp-tfe-admin-sa-setup.yml"
  credential_ids  = [] # add Vault or SCM creds here if needed
}

# 4. Job Template: VSO Operator install
resource "aap_job_template" "vso_operator_install" {
  name            = "OCP - VSO Operator Install"
  job_type        = "run"
  inventory_id    = aap_inventory.localhost.id
  project_id      = aap_project.playbooks_project.id
  playbook        = "ocp-vso-operator-install.yml"
  credential_ids  = [] # add Vault or SCM creds here if needed
}

# 5. Workflow Job Template
resource "aap_workflow_job_template" "ocp_workflow" {
  name        = "OCP Workflow: SA Setup + VSO Install"
  organization_id = 1
}

# 6. Workflow Nodes
resource "aap_workflow_job_template_node" "node_tf_admin" {
  workflow_job_template_id = aap_workflow_job_template.ocp_workflow.id
  unified_job_template_id  = aap_job_template.tf_admin_sa.id
}

resource "aap_workflow_job_template_node" "node_vso_operator" {
  workflow_job_template_id = aap_workflow_job_template.ocp_workflow.id
  unified_job_template_id  = aap_job_template.vso_operator_install.id

  # Run after SA setup succeeds
  success_nodes = [aap_workflow_job_template_node.node_tf_admin.id]
}