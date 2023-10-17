resource "oci_identity_compartment" "_" {
  name          = var.name
  description   = var.name
  enable_delete = true
}

locals {
  compartment_id = oci_identity_compartment._.id
}

data "oci_identity_availability_domains" "_" {
  compartment_id = local.compartment_id
}

data "oci_core_images" "_" {
  compartment_id           = local.compartment_id
  shape                    = var.shape
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
}

resource "oci_core_instance" "_" {
  for_each            = local.nodes
  display_name        = each.value.node_name
  availability_domain = data.oci_identity_availability_domains._.availability_domains[each.value.domain_name].name //var.availability_domain].name
  compartment_id      = local.compartment_id
  shape               = var.shape
  shape_config {
    memory_in_gbs = var.memory_in_gbs_per_node
    ocpus         = var.ocpus_per_node
  }
  source_details {
    source_id   = "ocid1.image.oc1.iad.aaaaaaaah3ahpwe2l4bpxl3q3hiz6ovnw2fmakh3ma4dnauhniktmiwxl72q" // data.oci_core_images._.images[0].id
    source_type = "image"
  }
  create_vnic_details {
    subnet_id  = oci_core_subnet._.id
    private_ip = each.value.ip_address
  }
  metadata = {
    ssh_authorized_keys = join("\n", local.authorized_keys)
    user_data           = data.cloudinit_config._[each.key].rendered
  }
  connection {
    host        = self.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.ssh.private_key_pem
  }
  provisioner "remote-exec" {
    inline = [
      "tail -f /var/log/cloud-init-output.log &",
      "cloud-init status --wait >/dev/null",
    ]
  }
  # lifecycle {
  #   ignore_changes = [
  #     metadata
  #   ]
  # }
}

locals {
  nodes = {
    for i in range(1, 1 + var.how_many_nodes) :
    i => {
      node_name   = format("node%d", i)
      domain_name = var.domains[i]
      ip_address  = var.ip_list[i] // format("10.0.0.%d", 10 + i)
      role        = i == 0 ? "controlplane" : "worker"
    }
  }
}
