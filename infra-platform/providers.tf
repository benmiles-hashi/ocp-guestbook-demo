terraform {
  cloud {
    organization = "ben-miles-org"
    workspaces {
      name = "ocp-infra-platform"
    }
  }
}