#!/bin/bash
# Script to update Linux system packages and Docker containers

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to handle errors
handle_error() {
    print_message "ERROR: $1" "$RED"
    exit 1
}

# Check if we're root or have sudo access
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        if ! sudo -v &>/dev/null; then
            handle_error "This script requires sudo privileges. Please run with sudo or as root."
        fi
    fi
}

# Log start time
print_message "=== Starting system update $(date) ===" "$YELLOW"

# Check for sudo access
check_sudo

# Update and upgrade system packages
print_message "Updating package lists..." "$GREEN"
sudo apt update || handle_error "Failed to update package lists"

print_message "Upgrading packages..." "$GREEN"
sudo apt upgrade -y || handle_error "Failed to upgrade packages"

print_message "Performing distribution upgrade..." "$GREEN"
sudo apt dist-upgrade -y || handle_error "Failed to perform distribution upgrade"

print_message "Removing unused packages..." "$GREEN"
sudo apt autoremove -y
sudo apt autoclean

# Check for system reboot requirement
if [ -f /var/run/reboot-required ]; then
    print_message "System requires a reboot after updates!" "$RED"
fi

# Update Snap packages if available
if command -v snap &>/dev/null; then
    print_message "=== Updating Snap packages ===" "$YELLOW"
    sudo snap refresh || print_message "Failed to update snap packages" "$RED"
fi

# Update Flatpak packages if available
if command -v flatpak &>/dev/null; then
    print_message "=== Updating Flatpak packages ===" "$YELLOW"
    sudo flatpak update -y || print_message "Failed to update flatpak packages" "$RED"
fi

# Update Docker containers
if command -v docker &>/dev/null; then
    print_message "=== Updating Docker containers ===" "$YELLOW"
    
    # Docker compose directory - change if needed
    DOCKER_DIR="/home/ians/docker"
    
    if [ -d "$DOCKER_DIR" ]; then
        cd "$DOCKER_DIR" || handle_error "Failed to change to Docker directory"
        print_message "Pulling latest images..." "$GREEN"
        docker compose pull || print_message "Failed to pull some Docker images" "$RED"
        
        print_message "Restarting containers with new images..." "$GREEN"
        docker compose up -d || print_message "Failed to restart some Docker containers" "$RED"
        
        print_message "Removing unused images..." "$GREEN"
        docker image prune -f
        
        # Check for container health
        print_message "Checking container health..." "$BLUE"
        docker ps -a --format "{{.Names}}: {{.Status}}"
    else
        print_message "Docker directory not found at $DOCKER_DIR" "$RED"
    fi
else
    print_message "Docker not found. Skipping container updates." "$BLUE"
fi

# Log completion time
print_message "=== System update completed! $(date) ===" "$YELLOW"

# Check disk space
print_message "Disk space after updates:" "$BLUE"
df -h / | grep -v "Filesystem"
