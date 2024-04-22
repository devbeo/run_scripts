#!/bin/bash

# Initialize variables
user_name=""
user_pw=""
user_ssh_pubkey=""
ssh_port=""

# Parse input parameters
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -user_name)
        user_name="$2"
        shift
        shift
        ;;
        -user_pw)
        user_pw="$2"
        shift
        shift
        ;;
        -user_ssh_pubkey)
        user_ssh_pubkey="$2"
        shift
        shift
        ;;
        -ssh_port)
        ssh_port="$2"
        shift
        shift
        ;;
        *)
        shift
        ;;
    esac
done

# Check if required parameters are provided
if [[ -z $user_name ]]; then
    echo "User name is required. Please provide the -user_name parameter."
    exit 1
fi

if [[ -z $user_pw ]]; then
    echo "User password is required. Please provide the -user_pw parameter."
    exit 1
fi

# Create user with sudo privilege
sudo useradd -m -s /bin/bash $user_name
sudo usermod -aG sudo $user_name
echo "$user_name:$user_pw" | sudo chpasswd

# Change SSH Key if provided
if [[ ! -z $user_ssh_pubkey ]]; then
    sudo mkdir /home/$user_name/.ssh
    echo "$user_ssh_pubkey" | sudo tee -a /home/$user_name/.ssh/authorized_keys
    sudo chmod 700 /home/$user_name/.ssh
    sudo chmod 600 /home/$user_name/.ssh/authorized_keys
    sudo chown -R $user_name:$user_name /home/$user_name/.ssh
fi

# Configure sudo to not prompt for password
echo "$user_name ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/$user_name

# Update and upgrade packages
sudo apt update -y
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" full-upgrade

# Install required packages
sudo apt install -y zsh git curl

# Set user default shell to zsh
sudo chsh -s $(which zsh) $user_name

# Install zimfw for zsh
sudo -u $user_name sh -c 'curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh'

# Install Docker
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Install docker packages
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# Allow non-privileged users to run Docker commands
sudo usermod -aG docker $user_name

# Clean history
sudo history -cw

# Reboot the server to apply changes
sudo reboot
