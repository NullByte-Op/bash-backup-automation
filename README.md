## Project overview
Simple backup script who written in bash for automating backup process.


## Architecture
The script operates through a straightforward sequential workflow:

* **Locking Mechanism:** Utilizes a temporary file (`/tmp/phoneBackup.lock`) to ensure only one instance runs at a time.
* **Configuration Parsing:** Automatically detects and reads backup paths and connection details from `.yaml` files using `yq`.
* **Connectivity Check:** Uses `nc` (Netcat) to verify that the target host's IP and port are reachable before initiating any transfer.
* **Data Synchronization:** Runs `rsync` over SSH to pull differential changes from the remote source directories to the local destinations.
* **Logging & Rotation:** Writes operational logs and applies a fallback size-check rotation if the system `logrotate` utility is missing.


## Features

* **Execution Locking:** Prevents concurrent script executions by utilizing a temporary lock file (`/tmp/phoneBackup.lock`).
* **Dynamic Configurations:** Parses multiple target profiles and backup directories from `.yaml` files using `yq`.
* **Pre-flight Connectivity Check:** Validates host availability via `nc` (Netcat) prior to triggering transfers to prevent operational timeouts.
* **Differential Synchronization:** Leverages `rsync` over SSH to sync files incrementally, reducing bandwidth consumption.
* **Automated Log Rotation:** Dynamically adjusts log paths based on user privileges and deploys an internal fallback mechanism to rotate logs at 1MB up to 3 generations if system `logrotate` is absent.

## Installation

The following system dependencies are required for installing that:
‍‍‍``` sudo apt install yq netcat rsync ```

Grant executable permissions to the script:
```bash
git clone https://github.com/NullByte-Op/Backup-script && cd Backup-script/
chmod +x phoneBackup.sh
./phoneBackup.sh
```

## Configuration

Place your configuration files with a .yaml extension inside the script's configuration directory ($HOME/bin/scripts/backup_script/). The script automatically scans and processes all valid YAML files found in this path.

### Examples

Example configuration file (phone.yaml):
```yaml
title: "Phone"
ip: "192.168.1.50"
port: 1111
username: "u0_a368"
backups:
  Images:
    src: "storage/dcim/Camera/"
    dst: "/home/gameover/files/Phone/s24/camera/"
```

Manual script invocation:
```bash
./phoneBackup.sh
```

## Logs

- Root Users: Logs are written to /var/log/backups/backup_script.log.

- Non-Root Users: Logs are written to ~/.local/var/backups/backup_script.log.

- Log files are automatically checked; if a file exceeds 1MB, the internal rotation engine archives it up to three historical versions (.1, .2, .3).


## CRON

To automate the execution, append the script to your crontab environment (crontab -e). Example for running daily at 2:00 AM:

```bash
0 2 * * * /home/gameover/bin/scripts/backup_script/phoneBackup.sh
```

## Troubleshooting

- Error: Script is already running: Occurs if a lock file exists. If a prior execution was abruptly terminated, manually clear it using: rm /tmp/phoneBackup.lock.

- Host unreachable errors: Occurs if the destination target is offline or the specified SSH port is blocked. Verify local network connection status and device port parameters.

- Invalid YAML syntax: The script runs a pre-validation phase on configurations. Files with syntax errors will be safely skipped during the loop.