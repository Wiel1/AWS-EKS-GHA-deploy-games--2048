resource "kubectl_manifest" "namespace" {
    yaml_body = file("${path.module}/config/namespace_v254.yaml")
}

resource "kubectl_manifest" "deployment" {
    yaml_body = file("${path.module}/config/deployment_v254.yaml")
}

resource "kubectl_manifest" "games_2048_service" {
    yaml_body = file("${path.module}/config/games-2048/2048_service_v254.yaml")
}

resource "kubectl_manifest" "games_2048_ingress" {
    yaml_body = file("${path.module}/config/games-2048/2048_ingress_v254.yaml")
}
