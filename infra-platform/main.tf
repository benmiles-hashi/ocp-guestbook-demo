provider "rhcs" {
  token = var.redhat_token
}
module "rosa_hcp" {
  source  = "terraform-redhat/rosa-hcp/rhcs"
  version = "1.7.0"

  cluster_name             = var.cluster_name
  openshift_version        = var.openshift_version
  replicas                 = var.replicas
  machine_cidr             = var.machine_cidr
  service_cidr             = var.service_cidr
  pod_cidr                 = var.pod_cidr
  host_prefix              = var.host_prefix
  aws_subnet_ids           = var.aws_subnet_ids
  aws_availability_zones   = var.aws_availability_zones
  compute_machine_type     = var.compute_machine_type
  create_account_roles     = var.create_account_roles
  account_role_prefix      = var.account_role_prefix
  create_oidc              = var.create_oidc
  oidc_config_id           = var.oidc_config_id
  create_operator_roles    = var.create_operator_roles
  operator_role_prefix     = var.operator_role_prefix
  ec2_metadata_http_tokens = var.ec2_metadata_http_tokens
  create_admin_user        = true
  admin_credentials_username = "cluster-admin"
  admin_credentials_password = "P@ssw0rd@12345!"
}
#admin_credentials_username = "cluster-admin"
#admin_credentials_password = "P@ssw0rd@12345!"