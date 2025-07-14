# Vagrant SLURM HPC Cluster

This Vagrant configuration sets up a full-featured SLURM-based facsimile HPC cluster using AlmaLinux (8 or 9). It includes optional Open OnDemand integration (enabled by default) provisioning virtual machines for login, compute, SLURM controller, SLURM DBD, and storage nodes, with automatic SLURM installation and configuration.

This setup has been created as a means to conduct limited testing and learning with SLURM and Open OnDemand.

---

## Configuration Overview

| Component          | Description                                                                                  |
|--------------------|----------------------------------------------------------------------------------------------|
| OS                 | Defaults to AlmaLinux 9; both AlmaLinux 8 and 9 are supported, see: `ALMA_VERSION`.        |
| SLURM              | Defaults to version `24.05.8`; configurable to 22.05 and above, see:  `SLURM_VERSION`.     |
| VMs                | 1 Login, 2 SLURM Controllers, 1 SLURM DBD, 1 Storage, N Compute nodes (defaults to 2).       |
| VM Memory per Node | Defaults to `2048` MB, see:  `VM_MEMORY`.                                                  |
| CPU Cores per Node | Defaults to `16` cores, see:  `VM_CPUS`.                                                   |
| Open OnDemand      | Optional installation enabled by default, see: `OOD_INSTALL`.                              |
| CGroups            | CGroup v2 enabled by default.                                                                |

---

## Requirements

- [Vagrant](https://www.vagrantup.com/) (>= 2.2.x)
- [VirtualBox](https://www.virtualbox.org/) (latest recommended)
- Vagrant plugin: `vagrant-reload` (used to enable CGroupV2 on Alma 8 compute nodes).

Install required plugin (if missing):

```bash
vagrant plugin install vagrant-reload
````

---

## Quick Start

1. **Clone the repository**:

```bash
git clone git@github.com:jkwmoore/Vagrant-SLURM-HPC-Cluster.git
cd Vagrant-SLURM-HPC-Cluster
```

2. **Customize Configuration in the `Vagrantfile` (Optional)**
   You can change:

* `ALMA_VERSION` — AlmaLinux 8 or 9.
* `SLURM_VERSION` — version to build from source.
* `NUM_COMPUTE_NODES` — number of compute nodes.
* `VM_MEMORY` — set to no less than 2048 MB but increase as your machine supports.
* `VM_CPUS` — set as your machine supports.
* `OOD_INSTALL` — toggle to `true` to enable Open OnDemand support, anything else will disable it.

3. **Start the cluster**:

Depending on the number of nodes you have specified and the amount of RAM allocated, check you have enough RAM and:

```bash
vagrant up
```

Note: Provisioning will take some time as it installs and configures all components.

---

## Features

* Defaults to **SLURM 24.05.8** compiled from source.
* **High-availability SLURM controllers**.
* **SLURM DBD** with MariaDB backend.
* **MUNGE** authentication across nodes.
* **NFS-shared areas from the storage node under the `/export` directory** mounting at `/home`, `/opt/software`, `/etc/slurm` and `/opt/site`.
* **CGroupV2 support** (Note: AlmaLinux 8 compute nodes will trigger a reboot to enable this).
* **Firewalls configured** per-role.
* **pdsh** environment set up for parallel node commands.
* **Open OnDemand** installed optionally on login node.

---

## Node Layout

| VM Name        | IP Address    | Role                                      |
| -------------- | ------------- | ----------------------------------------- |
| login1         | 192.168.56.10 | Login node + OOD (if enabled)             |
| storage1       | 192.168.56.11 | NFS server providing cluster wide storage |
| slurmctld1     | 192.168.56.12 | Primary controller                        |
| slurmctld2     | 192.168.56.13 | Secondary controller                      |
| slurmdbd1      | 192.168.56.14 | Slurm database daemon                     |
| compute\[1..N] | 192.168.56.2X | Compute nodes                             |

---

## Scripts Used

All provisioning is done via modular shell scripts under the `scripts/` directory:

* `common_setup.sh`
* `slurm_install.sh`
* `slurm_config_setup.sh`
* `munge_setup.sh`
* `setup_firewall.sh`
* `nfs_client_setup.sh`
* `storage_setup.sh`
* `setup_open_on_demand_server.sh`
* etc...

For each node type, you can understand which scripts are used via inspection of the `Vagrantfile`.

---

## Useful Commands

### Bring up all nodes:

```bash
vagrant up
```

### Bring up specific node:

```bash
vagrant up storage1
```

### SSH into a node:

```bash
vagrant ssh storage1
```

### Tear down all nodes (without user confirmation):

```bash
vagrant destroy -f
```

---

## Using / testing SLURM

While SSH'd into `login1`, use or test SLURM as below:

```bash
sinfo -Nle
sbatch --wrap 'sleep 10 ; echo Hello world'
/vagrant/scripts/slurm/test_scripts/submit_array_1000.sh # This really will submit 1000 jobs as a job array.
```

---

## Using / testing Open OnDemand

If Open OnDemand is installed, access via your browser at:

```
https://192.168.56.10/
```

The basic shell and interactive desktop app (with XFCE) will be setup by default and functional.

---

## General notes and warnings

* This Vagrant setup by nature is intended to be ephemeral and is not particularly secure (default passwords etc...) so:
  * Do not use this as an example of a production setup!
  * Do not run this on an untrusted network (we are using the default vagrant password!)
* The storage node (as the first node) does more than just provision itself, it also:
  * Creates an additional larger storage disk for cluster wide storage.
  * Creates and exports the cluster wide NFS storage areas.
  * Compiles SLURM RPMs from source, makes them available via repo (over `http` but GPG signed.)
  * Creates a MUNGE key and makes it available.
  * Creates a cluster wide 'site script' shared area which will automatically load via `profile.d` on each node.
  * Creates the cluster wide home directory for the `vagrant` user.
* The SLURM DBD node will setup the SLURM configuration for all SLURM daemons in addition to its own.
* The login node (as the last node) does more than just provision itself, it also:
  * Automatically provisions the `known_hosts` file with all cluster nodes for the `vagrant` user.
  * Optionally installs Open OnDemand and allows access to its running webui.
* CGroup V2 is enabled by default for compatibility with recent SLURM releases greater than (22.05+).
  * If you want to use a SLURM version lower than 22.05 you will need to amend the scripting to use version 1 CGroups!
* You can modify the bridge interface on the login node’s `public_network` setting to match your environment.

---

## License

This setup is provided under the MIT License. Modify and extend as needed.