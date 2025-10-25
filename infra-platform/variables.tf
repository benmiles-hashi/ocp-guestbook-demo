variable "cluster_name" {
  type        = string
  description = "The name of the ROSA cluster"
}

variable "openshift_version" {
  type        = string
  description = "OpenShift version to deploy"
  default = "4.19.12"
}

variable "replicas" {
  type        = number
  description = "Number of worker nodes"
  default = 2
}

variable "machine_cidr" {
  type        = string
  description = "Machine CIDR for the cluster"
  default = "10.0.0.0/16"
}

variable "service_cidr" {
  type        = string
  description = "Service CIDR for the cluster"
  default = "172.30.0.0/16"
}

variable "pod_cidr" {
  type        = string
  description = "Pod CIDR for the cluster"
  default = "10.128.0.0/14"
}

variable "host_prefix" {
  type        = number
  description = "Host prefix for the pod network"
  default = 23
}

variable "pki_root" {
  type = string
  description = "Path to PKI CA"
  default = "ocp-pki-ca"
}
variable "aws_availability_zones" {
  type        = list(string)
  description = "AWS availability zones to use"
  default = ["us-east-1a"]
}
variable "rosa_vpc_id" {
  type = string
  default = "vpc-057d6f86cf89a68de"
}
variable "compute_machine_type" {
  type        = string
  description = "EC2 instance type for worker nodes"
  default = "m5.xlarge"
}

variable "create_account_roles" {
  type        = bool
  description = "Whether to create new account roles"
}

variable "account_role_prefix" {
  type        = string
  description = "Prefix for account IAM roles"
  default = "ManagedOpenShift"
}

variable "create_oidc" {
  type        = bool
  description = "Whether to create a new OIDC config"
}

variable "oidc_config_id" {
  type        = string
  description = "OIDC config ID (if reusing an existing one)"
}

variable "create_operator_roles" {
  type        = bool
  description = "Whether to create operator IAM roles"
}

variable "operator_role_prefix" {
  type        = string
  description = "Prefix for operator IAM roles"
}

variable "ec2_metadata_http_tokens" {
  type        = string
  description = "Whether EC2 metadata requires tokens (optional/required)"
  default = "optional"
}

variable "idp_name" {
  type        = string
  description = "Name of the identity provider"
  default = "htpasswd-idp"
}

variable "idp_username" {
  type        = string
  default = "cluster-admin"
  description = "Username for the htpasswd IDP"
}

variable "idp_password" {
  type        = string
  description = "Password for the htpasswd IDP"
  sensitive   = true
}

#######
#Vault
#######

variable "vso_namespace" {
  type        = string
  description = "Namespace where the Vault Secrets Operator will be installed"
  default     = "vault-secrets-operator"
}

variable "vso_channel" {
  type        = string
  description = "Channel to use for the VSO operator"
  default     = "stable"
}

variable "vso_install_plan_approval" {
  type        = string
  description = "Install plan approval for the operator (Automatic or Manual)"
  default     = "Automatic"
}

variable "vault_address" {
  type        = string
  description = "Address of the Vault server (e.g. http://127.0.0.1:8200)"
}

variable "vault_root_token" {
  type        = string
  description = "Root token (or bootstrap token) for Vault"
  sensitive   = true
}
variable "vault_namespace" {
 type= string
 default = "admin"
}
variable "redhat_token" {
  type= string
  sensitive = true
}
##--AAP Variables--##

variable "aap_hostname" {
  type        = string
  description = "AAP/Tower controller hostname"
}

variable "aap_username" {
  type        = string
  description = "AAP username"
  default = "admin"
}

variable "aap_password" {
  type        = string
  description = "AAP password"
  sensitive   = true
}

variable "repo_url" {
  type        = string
  description = "Git repo containing playbooks"
  default = "https://github.com/benmiles-hashi/ocp-guestbook-demo.git"
}

##--Kubernetes Engine Variables
variable "sa_namespace" {
  description = "Namespace where the tf-admin SA lives"
  type        = string
  default     = "kube-system"
}

variable "sa_name_prefix" {
  description = "Prefix for the tf admin service account"
  type        = string
  default     = "tf-admin"
}