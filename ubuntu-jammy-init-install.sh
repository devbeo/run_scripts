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

# Configure SSH settings
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
# Change SSH port if provided
if [[ ! -z $ssh_port ]]; then
    sudo sed -i "s/#Port 22/Port $ssh_port/g" /etc/ssh/sshd_config
fi

# Restart SSH service
sudo systemctl restart ssh

# Get the current hostname from /etc/hostname
current_hostname=$(cat /etc/hostname)

# Add the current hostname to /etc/hosts with IP address 127.0.1.1
if [[ ! -z $current_hostname ]]; then
    echo "127.0.1.1 $current_hostname" | sudo tee -a /etc/hosts
fi

# Update and upgrade packages
echo "\$nrconf{restart} = 'a';" | sudo tee -a /etc/needrestart/conf.d/90-autorestart.conf
echo "\$nrconf{kernelhints} = -1;" | sudo tee -a /etc/needrestart/conf.d/90-autorestart.conf
sudo apt update -y
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" full-upgrade

# Install required packages
sudo apt install -y zsh git curl

# Set user default shell to zsh
sudo chsh -s $(which zsh) $user_name

# Install zimfw for zsh
sudo -u $user_name sh -c 'curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh'
echo "skip_global_compinit=1" | sudo tee -a /home/$user_name/.zshenv

# Reboot the server to apply changes
sudo reboot
