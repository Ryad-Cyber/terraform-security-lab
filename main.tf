terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6"
    }
  }
}

provider "docker" {
  host = "npipe:////./pipe/docker_engine"
}

# Image du serveur web
resource "docker_image" "nginx" {
  name         = "nginxinc/nginx-unprivileged:stable-alpine"
  keep_locally = true
}

# Réseau Docker dédié
resource "docker_network" "security_lab" {
  name = "terraform-security-network"
}

# Conteneur Nginx
resource "docker_container" "web" {
  name  = "terraform-secure-web"
  image = docker_image.nginx.image_id

  # Empêche l'élévation de privilèges
  security_opts = ["no-new-privileges:true"]

  # Supprime les capacités Linux supplémentaires
  capabilities {
    drop = ["ALL"]
  }

  volumes {
    host_path      = abspath("${path.module}/web/index.html")
    container_path = "/usr/share/nginx/html/index.html"
    read_only      = true
  }

  # Limite la mémoire du conteneur à 128 Mio
  memory = 128

  # Réseau du frontend
  networks_advanced {
    name = docker_network.security_lab.name
  }

  # Réseau interne pour communiquer avec le backend
  networks_advanced {
    name = docker_network.backend_network.name
  }

  # Accessible uniquement depuis le PC local
  ports {
    internal = 8080
    external = 8080
    ip       = "127.0.0.1"
  }
}

# Réseau interne réservé aux communications entre services
resource "docker_network" "backend_network" {
  name     = "terraform-backend-internal"
  internal = true
}

# Image du service backend
resource "docker_image" "backend" {
  name         = "hashicorp/http-echo:1.0"
  keep_locally = true
}

# Backend sans port publié sur Windows
resource "docker_container" "backend" {
  name  = "terraform-secure-backend"
  image = docker_image.backend.image_id

  command = [
    "-listen=:5678",
    "-text=Terraform Security Lab - Internal Backend OK"
  ]

  security_opts = ["no-new-privileges:true"]

  capabilities {
    drop = ["ALL"]
  }

  memory = 64

  networks_advanced {
    name = docker_network.backend_network.name
  }
}