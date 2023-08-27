provider "aws" {
  region = "eu-west-1"
}

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.6.0"
    }
  }

  required_version = "~> 1.0"
}

provider "kubectl" {
  host                   = data.terraform_remote_state.remote.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.remote.cluster_cert)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.remote.cluster_id]
    command     = "aws"
  }
}
