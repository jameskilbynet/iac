# vSphere Power Management Ansible Playbooks

Automate ESXi host power management policies across your vSphere clusters using Ansible and Semaphore. Switch between **Low Power** and **Balanced** modes on all hosts in one or more clusters with a single task.

## Playbook Structure

| File | Purpose |
|------|---------|
| `run_set_power_low.yml` | Bootstrap wrapper - installs dependencies then runs `set_power_low.yml` |
| `run_set_power_balanced.yml` | Bootstrap wrapper - installs dependencies then runs `set_power_balanced.yml` |
| `set_power_low.yml` | Core playbook - sets all hosts in specified clusters to Low Power |
| `set_power_balanced.yml` | Core playbook - sets all hosts in specified clusters to Balanced |
| `requirements.yml` | Ansible Galaxy collection requirements |

## How It Works

The bootstrap wrappers (`run_set_power_*.yml`) handle all dependency management automatically:

1. Installs the `PyVmomi` Python library
2. Installs the `community.vmware` Ansible collection to a temporary path
3. Patches the collection's Ansible version constraint for compatibility with Ansible 2.18+
4. Launches the core playbook as a subprocess with the correct collection path

This approach is necessary because `community.vmware` does not officially declare support for Ansible 2.18, and Semaphore's built-in Galaxy install caching can be unreliable.

## Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `vcenter_host` | FQDN or IP of your vCenter Server | `vcsa.lab.local` |
| `vcenter_user` | vCenter user with host config privileges | `administrator@vsphere.local` |
| `vcenter_pass` | Password for the vCenter user (mark as secret) | |
| `cluster_names` | Cluster(s) to target - single string or list | `"GPU"` or `["GPU", "Compute"]` |

## Usage

### With Semaphore

1. Create a task template pointing at `run_set_power_low.yml` or `run_set_power_balanced.yml`
2. Add the variables above to a Variable Group (mark `vcenter_pass` as secret)
3. Run the task

### Command Line

Single cluster:
```bash
ansible-playbook run_set_power_low.yml \
  -e "vcenter_host=vcsa.local" \
  -e "vcenter_user=administrator@vsphere.local" \
  -e "vcenter_pass=YourPassword" \
  -e "cluster_names=GPU"
```

Multiple clusters:
```bash
ansible-playbook run_set_power_low.yml \
  -e '{"vcenter_host":"vcsa.local","vcenter_user":"administrator@vsphere.local","vcenter_pass":"YourPassword","cluster_names":["GPU","Compute"]}'
```

## Scheduling

For energy cost savings, schedule these playbooks in Semaphore:

- **Low Power** during expensive/low-demand periods (e.g. 16:00-19:00)
- **Balanced** outside those windows to restore full performance

## Prerequisites

- Ansible 2.15+
- Network connectivity from the Ansible runner to vCenter
- A vCenter user account with host power management permissions
- All other dependencies (PyVmomi, community.vmware collection) are installed automatically by the bootstrap wrappers
