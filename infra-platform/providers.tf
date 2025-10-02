terraform {
  cloud {
    organization = "ben-miles-org"
    workspaces {
      name = "ocp-infra-platform"
    }
  }
}
provider "aws" {
  region = "us-east-1"
}