packer {
  required_plugins {
    docker = {
      version = ">= 0.0.7"
      source  = "github.com/hashicorp/docker"
    }
  }
}

# Variables
variable "docker_image" {
  type    = string
  default = "ubuntu:focal"
}

variable "install_auth_signing_script" {
  default = "true"
}

source "docker" "ubuntu" {
  image  = var.docker_image
  commit = true
}

build {
  sources = [
    "source.docker.ubuntu"
  ]
  provisioner "shell" {
    inline = [
      "apt update -y && apt upgrade -y && apt install sudo -y",
      "apt install git -y",
      "git clone --branch v0.16.0 https://github.com/hashicorp/terraform-aws-vault.git /tmp/terraform-aws-vault",
      "/tmp/terraform-aws-vault/modules/install-vault/install-vault --version 1.7.3"
    ]
    pause_before = "30s"
  }
  provisioner "file" {
    source      = "./files/auth/sign-request.py"
    destination = "/tmp/sign-request.py"
  }
  provisioner "file" {
    source      = "./files/tls/ca.crt.pem"
    destination = "/tmp/ca.crt.pem"
  }
  provisioner "file" {
    source      = "./files/tls/vault.crt.pem"
    destination = "/tmp/vault.crt.pem"
  }
  provisioner "file" {
    source      = "/files/tls/vault.key.pem"
    destination = "/tmp/vault.key.pem"
  }
  provisioner "shell" {
    inline = [
      "if [[ '{{user `install_auth_signing_script`}}' == 'true' ]]; then",
      "sudo mv /tmp/sign-request.py /opt/vault/scripts/",
      "else",
      "sudo rm /tmp/sign-request.py",
      "fi",
      "sudo mv /tmp/ca.crt.pem /opt/vault/tls/",
      "sudo mv /tmp/vault.crt.pem /opt/vault/tls/",
      "sudo mv /tmp/vault.key.pem /opt/vault/tls/",
      "sudo chown -R vault:vault /opt/vault/tls/",
      "sudo chmod -R 600 /opt/vault/tls",
      "sudo chmod 700 /opt/vault/tls",
      "sudo /tmp/terraform-aws-vault/modules/update-certificate-store/update-certificate-store --cert-file-path /opt/vault/tls/ca.crt.pem"
    ]
    inline_shebang = "/bin/bash -e"
  }
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y git",
      "if [[ '{{user `install_auth_signing_script`}}' == 'true' ]]; then",
      "sudo apt-get install -y python3-pip",
      "LC_ALL=C && sudo pip3 install awscli",
      "fi"
    ]
    inline_shebang = "/bin/bash -e"
  }
}