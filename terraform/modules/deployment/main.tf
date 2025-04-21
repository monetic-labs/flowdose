locals {
  backend_app_dir    = var.backend_app_dir != "" ? var.backend_app_dir : "/root/app"
  storefront_app_dir = var.storefront_app_dir != "" ? var.storefront_app_dir : "/root/app"
}

# Deploy backend service
resource "null_resource" "deploy_backend" {
  # Only run deployment if the environment file has changed or force_deploy is true
  triggers = {
    env_upload_id      = var.backend_env_upload_id
    force_deploy       = var.force_deploy_backend
    deploy_script_hash = md5(file("${path.module}/scripts/deploy_backend.sh"))
    droplet_id         = var.backend_droplet_id
  }

  # Create necessary directories first
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${local.backend_app_dir}"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.backend_droplet_ip
    }
  }

  # Transfer deployment script to server
  provisioner "file" {
    source      = "${path.module}/scripts/deploy_backend.sh"
    destination = "${local.backend_app_dir}/deploy.sh"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.backend_droplet_ip
    }
  }

  # Execute deployment script
  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.backend_app_dir}/deploy.sh",
      "${local.backend_app_dir}/deploy.sh ${local.backend_app_dir} ${var.node_env}"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.backend_droplet_ip
    }
  }
}

# Deploy storefront service
resource "null_resource" "deploy_storefront" {
  # Only run deployment if the environment file has changed or force_deploy is true
  triggers = {
    env_upload_id      = var.frontend_env_upload_id
    force_deploy       = var.force_deploy_storefront
    deploy_script_hash = md5(file("${path.module}/scripts/deploy_storefront.sh"))
    droplet_id         = var.storefront_droplet_id
  }

  # Create necessary directories first
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${local.storefront_app_dir}"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.storefront_droplet_ip
    }
  }

  # Transfer deployment script to server
  provisioner "file" {
    source      = "${path.module}/scripts/deploy_storefront.sh"
    destination = "${local.storefront_app_dir}/deploy.sh"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.storefront_droplet_ip
    }
  }

  # Execute deployment script
  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.storefront_app_dir}/deploy.sh",
      "${local.storefront_app_dir}/deploy.sh ${local.storefront_app_dir} ${var.node_env} https://api-${var.environment}.flowdose.xyz"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
      host        = var.storefront_droplet_ip
    }
  }
} 