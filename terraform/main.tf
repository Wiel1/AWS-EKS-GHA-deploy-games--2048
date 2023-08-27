
data "terraform_remote_state" "remote" {
  backend = "s3"
  config =  {
    bucket = "technologiesoutcomes-terraform-backend"
    key = "eks/simpleeks-terraform.tfstate"
    region = "eu-west-1"
  }
}

resource "kubectl_manifest" "games_2048_namespace" {
    yaml_body = file("${path.module}/config/games-2048/2048_namespace_v254.yaml")
}

resource "kubectl_manifest" "games_2048_deployment" {
    yaml_body = file("${path.module}/config/games-2048/2048_deployment_v254.yaml")
}

resource "kubectl_manifest" "games_2048_service" {
    yaml_body = file("${path.module}/config/games-2048/2048_service_v254.yaml")
}

resource "kubectl_manifest" "games_2048_ingress" {
    yaml_body = file("${path.module}/config/games-2048/2048_ingress_v254.yaml")
}
