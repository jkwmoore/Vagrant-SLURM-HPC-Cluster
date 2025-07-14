# -*- mode: ruby -*-
# vi: set ft=ruby :

# Note - we always enable CGroupV2 at the moment consider the following support:
#
#-------------------------------------------------------------------------------
# | Slurm Version   | CGroupV1 Support      | CGroupV2 Support      |
# |-----------------|-----------------------|-----------------------|
# | < 22.05         | Supported             | Not Supported         |
# | 22.05 - 24.02   | Supported             | Supported             |
# | >= 25.05        | Deprecated (⚠️)       | Supported (✅)        |
#-------------------------------------------------------------------------------
#
# Keep in mind that a hybrid mode with both CGroup versions enabled is NOT supported.
#
# --- Configuration ---
# AlmaLinux version: 8 or 9
ALMA_VERSION = 9
# SLURM version to compile from source
SLURM_VERSION = "24.05.8"
# Number of compute nodes
NUM_COMPUTE_NODES = 2
# Memory for each VM in MB
# Note, trying less that 2GB of RAM seems to break the install process for the storage node.
VM_MEMORY = 2048     
# CPUs for each VM
VM_CPUS = 16
# Install Open on Demand?
OOD_INSTALL = "true"
# --- End Configuration ---

# --- Plugin Check ---
puts "[INFO] Checking required Vagrant plugins..."

required_plugins = %w[vagrant-reload]
missing_plugins = required_plugins.select { |plugin| !Vagrant.has_plugin?(plugin) }

if !missing_plugins.empty?
  abort <<-ERROR

‼️  Missing required Vagrant plugins:

    #{missing_plugins.join(", ")}

💡  To fix, run:
    vagrant plugin install #{missing_plugins.join(" ")}

  ERROR
end

Vagrant.configure("2") do |config|

  # Define the network for internal communication
  PRIVATE_NETWORK_IP_PREFIX = "192.168.56."

  # --- Base Box Configuration ---
  config.vm.box = "almalinux/8"
  if ALMA_VERSION == 9
    config.vm.box = "almalinux/9"
  end

  # --- Storage Node ---
  config.vm.define "storage1" do |storage|
    storage.vm.hostname = "storage1"
    storage.vm.network "private_network", ip: "#{PRIVATE_NETWORK_IP_PREFIX}11"

    storage.vm.provider "virtualbox" do |vb|
      vb.memory = VM_MEMORY
      vb.cpus = VM_CPUS
      vb.name = "storage1"

      # Detect VBoxManage path based on platform
      vboxmanage_path = if RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/
        "C:\\Program Files\\Oracle\\VirtualBox\\VBoxManage.exe"
      else
        "VBoxManage"
      end

      # Get VirtualBox's default machine folder
      default_machine_folder_line = `"#{vboxmanage_path}" list systemproperties`.lines.find { |l| l.include?("Default machine folder") }
      machine_folder = default_machine_folder_line&.split(":", 2)&.last&.strip
      machine_folder ||= File.expand_path("~/VirtualBox VMs") # Fallback path

      # Construct path for additional disk next to root disk
      disk_path = File.join(machine_folder, vb.name, "storage1-data.vdi")

      # Create disk only if it doesn't exist
      unless File.exist?(disk_path)
        vb.customize [
          "createhd",
          "--filename", disk_path,
          "--format", "VDI",
          "--size", "60000"
        ]
      end

      # Attach the second disk
      vb.customize [
        "storageattach", :id,
        "--storagectl", "SATA Controller",
        "--port", 1,
        "--device", 0,
        "--type", "hdd",
        "--medium", disk_path
      ]
    end

    storage.vm.provision "shell", inline: <<-SHELL
      set -euo pipefail

      # Find root disk (e.g., where / is mounted)
      ROOT_DISK=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]//g' | xargs basename)

      # Find the other disk (assuming only 2 disks total)
      TARGET_DISK=$(lsblk -dno NAME | grep -v "$ROOT_DISK")

      echo "Root disk: $ROOT_DISK"
      echo "Target disk: $TARGET_DISK"

      if [ -z "$TARGET_DISK" ]; then
        echo "No extra disk found. Aborting."
        exit 1
      fi

      if ! lsblk /dev/$TARGET_DISK | grep -q "^├─"; then
        echo "Creating partition and filesystem on /dev/$TARGET_DISK"
        sudo parted -s /dev/$TARGET_DISK mklabel gpt
        sudo parted -s /dev/$TARGET_DISK mkpart primary ext4 0% 100%
        sleep 1
        sudo mkfs.ext4 /dev/${TARGET_DISK}1
      fi

      UUID=$(sudo blkid -s UUID -o value /dev/${TARGET_DISK}1)
      sudo mkdir -p /export
      grep -q "$UUID" /etc/fstab || echo "UUID=$UUID /export ext4 defaults 0 0" | sudo tee -a /etc/fstab
      sudo mount /export
    SHELL

    storage.vm.provision "shell", path: "scripts/common_setup.sh", args: [ALMA_VERSION, NUM_COMPUTE_NODES, PRIVATE_NETWORK_IP_PREFIX]
    storage.vm.provision "shell", path: "scripts/storage_setup.sh", args: [SLURM_VERSION, PRIVATE_NETWORK_IP_PREFIX]
    storage.vm.provision "shell", path: "scripts/nfs_client_setup.sh"
    storage.vm.provision "shell", path: "scripts/munge_setup.sh", args: ["storage"]
    storage.vm.provision "shell", path: "scripts/create_site_scripts.sh"
    storage.vm.provision "shell", path: "scripts/pdsh_setup.sh", args: [NUM_COMPUTE_NODES]
    storage.vm.provision "shell", path: "scripts/create_user_home_dir.sh",  args: ["vagrant"]
    storage.vm.provision "shell", path: "scripts/setup_user_ssh_key.sh",  args: ["vagrant"]
    storage.vm.provision "shell", path: "scripts/setup_firewall.sh",  args: ["storage", PRIVATE_NETWORK_IP_PREFIX]
  end

  # --- SlurmDBD Node ---
  config.vm.define "slurmdbd1" do |db|
    db.vm.hostname = "slurmdbd1"
    db.vm.network "private_network", ip: "#{PRIVATE_NETWORK_IP_PREFIX}14"
    db.vm.provider "virtualbox" do |vb|
      vb.memory = VM_MEMORY
      vb.cpus = VM_CPUS
    end
    db.vm.provision "shell", path: "scripts/common_setup.sh", args: [ALMA_VERSION, NUM_COMPUTE_NODES, PRIVATE_NETWORK_IP_PREFIX]
    db.vm.provision "shell", path: "scripts/mariadb_setup.sh"
    db.vm.provision "shell", path: "scripts/nfs_client_setup.sh"
    db.vm.provision "shell", path: "scripts/munge_setup.sh", args: ["client"]
    db.vm.provision "shell", path: "scripts/slurm_repo_setup.sh"
    db.vm.provision "shell", path: "scripts/slurm_config_setup.sh"
    db.vm.provision "shell", path: "scripts/slurm_install.sh", args: ["dbd"]
    db.vm.provision "shell", path: "scripts/slurm_services_setup.sh", args: ["dbd"]
    db.vm.provision "shell", path: "scripts/pdsh_setup.sh", args: [NUM_COMPUTE_NODES]
    db.vm.provision "shell", path: "scripts/setup_firewall.sh",  args: ["dbd", PRIVATE_NETWORK_IP_PREFIX]
  end

  # --- SlurmCTLD Nodes (High Availability) ---
  ["1", "2"].each do |i|
    config.vm.define "slurmctld#{i}" do |controller|
      controller.vm.hostname = "slurmctld#{i}"
      controller.vm.network "private_network", ip: "#{PRIVATE_NETWORK_IP_PREFIX}#{11 + i.to_i}"
      controller.vm.provider "virtualbox" do |vb|
        vb.memory = VM_MEMORY
        vb.cpus = VM_CPUS
      end
      controller.vm.provision "shell", path: "scripts/common_setup.sh", args: [ALMA_VERSION, NUM_COMPUTE_NODES, PRIVATE_NETWORK_IP_PREFIX]
      controller.vm.provision "shell", path: "scripts/nfs_client_setup.sh"
      if i == "1"
        controller.vm.provision "shell", path: "scripts/munge_setup.sh", args: ["client"]
      else
        controller.vm.provision "shell", path: "scripts/munge_setup.sh", args: ["client"]
      end
      controller.vm.provision "shell", path: "scripts/slurm_repo_setup.sh"
      controller.vm.provision "shell", path: "scripts/slurm_install.sh", args: ["controller"]
      controller.vm.provision "shell", path: "scripts/slurm_services_setup.sh", args: ["controller"]
      controller.vm.provision "shell", path: "scripts/pdsh_setup.sh", args: [NUM_COMPUTE_NODES]
      controller.vm.provision "shell", path: "scripts/setup_firewall.sh",  args: ["controller", PRIVATE_NETWORK_IP_PREFIX]
    end
  end

  # --- Compute Nodes ---
  (1..NUM_COMPUTE_NODES).each do |i|
    config.vm.define "compute#{i}" do |compute|
      compute.vm.hostname = "compute#{i}"
      compute.vm.network "private_network", ip: "#{PRIVATE_NETWORK_IP_PREFIX}#{20 + i}"
      compute.vm.provider "virtualbox" do |vb|
        vb.memory = VM_MEMORY
        vb.cpus = VM_CPUS
      end

      # --- Enable cgroup v2 and reboot if needed ---
      if ALMA_VERSION == 8
        compute.vm.provision "shell", path: "scripts/enable_cgroupv2.sh"
        compute.vm.provision "reload"  # <-- plugin-provided hook
      end

      # --- Standard provisioning scripts ---
      compute.vm.provision "shell", path: "scripts/common_setup.sh", args: [ALMA_VERSION, NUM_COMPUTE_NODES, PRIVATE_NETWORK_IP_PREFIX]
      compute.vm.provision "shell", path: "scripts/nfs_client_setup.sh"
      compute.vm.provision "shell", path: "scripts/create_site_profile_loader.sh"
      compute.vm.provision "shell", path: "scripts/munge_setup.sh", args: ["client"]
      compute.vm.provision "shell", path: "scripts/slurm_repo_setup.sh"
      compute.vm.provision "shell", path: "scripts/slurm_install.sh", args: ["compute"]
      compute.vm.provision "shell", path: "scripts/slurm_services_setup.sh", args: ["compute"]
      compute.vm.provision "shell", path: "scripts/pdsh_setup.sh", args: [NUM_COMPUTE_NODES]
      compute.vm.provision "shell", path: "scripts/setup_firewall.sh",  args: ["compute", PRIVATE_NETWORK_IP_PREFIX]

      if OOD_INSTALL == "true"
        compute.vm.provision "shell", path: "scripts/setup_compute_open_on_demand_depds.sh"
      end
    end
  end

  # --- Login Node ---
  config.vm.define "login1" do |login|
    login.vm.hostname = "login1"
    login.vm.network "private_network", ip: "#{PRIVATE_NETWORK_IP_PREFIX}10"
    login.vm.network "public_network", bridge: "en0: Wi-Fi (AirPort)", type: "dhcp" # Change bridge interface as needed
    login.vm.provider "virtualbox" do |vb|
      vb.memory = VM_MEMORY
      vb.cpus = VM_CPUS
    end
    login.vm.provision "shell", path: "scripts/common_setup.sh", args: [ALMA_VERSION, NUM_COMPUTE_NODES, PRIVATE_NETWORK_IP_PREFIX]
    login.vm.provision "shell", path: "scripts/nfs_client_setup.sh"
    login.vm.provision "shell", path: "scripts/create_site_profile_loader.sh"
    login.vm.provision "shell", path: "scripts/slurm_repo_setup.sh"
    login.vm.provision "shell", path: "scripts/munge_setup.sh", args: ["client"]
    login.vm.provision "shell", path: "scripts/slurm_install.sh", args: ["client"]
    login.vm.provision "shell", path: "scripts/pdsh_setup.sh", args: [NUM_COMPUTE_NODES]
    login.vm.provision "shell", path: "scripts/add_known_hosts.sh"
    login.vm.provision "shell", path: "scripts/setup_firewall.sh",  args: ["login", PRIVATE_NETWORK_IP_PREFIX]
    if OOD_INSTALL == "true"
      login.vm.provision "shell", path: "scripts/setup_open_on_demand_server.sh",  args: [PRIVATE_NETWORK_IP_PREFIX]
    end
  end

end
