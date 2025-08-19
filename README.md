# DockerManager 🐳

A comprehensive, interactive Docker management system that simplifies container operations through an intuitive terminal-based interface.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-Required-green.svg)](https://www.docker.com/)

## 📋 Table of Contents

- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Usage Guide](#-usage-guide)
- [Features in Detail](#-features-in-detail)
- [Examples](#-examples)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ Features

### 🖥️ Operating Systems Support
- **Linux Distributions**: Ubuntu, Debian, Kali Linux, Alpine Linux, CentOS, Fedora, Arch Linux, OpenSUSE, Gentoo, Slackware, NixOS
- **Windows Containers**: Windows Server 2019/2022/2025, Windows 10/11, Windows Nano Server, Windows Server Core
- **Windows (Linux)**: Full Windows VM support via dockurr/windows images
- **Dynamic Version Selection**: Browse and select from available Docker Hub tags

### 🗄️ Database Systems
- MySQL, PostgreSQL, MongoDB, Redis, MariaDB
- Automatic environment variable configuration
- Ready-to-use database containers

### 🌐 Web Servers
- Nginx, Apache, Tomcat
- Pre-configured port mappings
- Quick web server deployment

### 🔧 Advanced Container Management
- **Smart Container Naming**: Automatic or custom naming with conflict resolution
- **Network Configuration**: Bridge, host, custom networks with advanced options
- **Resource Limits**: CPU, memory, and storage limits
- **Volume Mapping**: Easy host-container file sharing
- **Port Mapping**: Flexible port forwarding
- **Environment Variables**: Custom environment setup
- **Privileged Mode**: Full host access when needed

### 🌐 Network Management
- Create, inspect, and delete custom networks
- Connect/disconnect containers from networks
- Support for bridge, host, overlay, macvlan, ipvlan drivers
- Advanced network configuration (subnets, gateways, IP ranges)

### 📊 System Monitoring & Maintenance
- **Live Resource Monitoring**: Real-time container stats
- **Disk Usage Analysis**: Detailed Docker storage breakdown
- **Log Management**: View, follow, and export container logs
- **Health Checks**: Container and system health monitoring
- **Cleanup Tools**: Prune unused resources safely
- **Event Monitoring**: Real-time Docker events

### 🔍 Container Operations
- **Interactive Shell Access**: Connect to running containers
- **Bulk Operations**: Delete multiple containers/images
- **Local Image Management**: Browse and use local images
- **Container Lifecycle**: Start, stop, connect, delete

## 📋 Prerequisites

- **Docker**: Must be installed and running
- **Bash**: Shell script requires bash
- **curl**: For Docker Hub API access
- **jq**: For JSON parsing (optional but recommended)
- **systemctl**: For Docker service management (Linux)

### Docker Installation

#### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install docker.io
sudo systemctl start docker
sudo systemctl enable docker
```

#### Arch Linux:
```bash
sudo pacman -S docker
sudo systemctl start docker
sudo systemctl enable docker
```

#### macOS:
```bash
# Install Docker Desktop from https://www.docker.com/products/docker-desktop
```

#### Windows:
```bash
# Install Docker Desktop from https://www.docker.com/products/docker-desktop
```

## 🚀 Installation

1. **Clone the repository:**
```bash
git clone https://github.com/glitchidea/DockerManager.git
cd DockerManager
```

2. **Make the script executable:**
```bash
chmod +x docker_manager.sh
```

3. **Run the script:**
```bash
./docker_manager.sh
```

## ⚡ Quick Start

1. **Start the application:**
```bash
./docker_manager.sh
```

2. **Select an operating system** from the main menu (e.g., Ubuntu)

3. **Choose a version** from the available tags

4. **Configure your container** with custom settings or use defaults

5. **Start your container** and begin working!

## 📖 Usage Guide

### Main Menu Options

```
1) Operating Systems     - Linux and Windows containers
2) Database Systems      - MySQL, PostgreSQL, MongoDB, etc.
3) Web Servers          - Nginx, Apache, Tomcat
4) Connect to Existing Container
5) List Docker Resources
6) Delete Container
7) Delete Image
8) Network Management
9) System Monitoring & Maintenance
```

### Operating Systems Menu

The script supports a wide range of operating systems with dynamic version selection:

- **Linux Distributions**: Browse available tags from Docker Hub
- **Windows Containers**: Full Windows container support
- **Windows (Linux)**: Windows VM containers via dockurr/windows

### Container Configuration Options

When starting a container, you can configure:

- **Container Name**: Automatic or custom naming
- **Network Mode**: Bridge, host, custom networks
- **Port Mappings**: Host:container port forwarding
- **Volume Mappings**: Host:container file sharing
- **Environment Variables**: Custom environment setup
- **Resource Limits**: CPU, memory, storage limits
- **Privileged Mode**: Full host access
- **Auto-remove**: Remove container on exit

### Network Management

Create and manage custom Docker networks:

- **Bridge Networks**: Default container networking
- **Host Networks**: Direct host network access
- **Custom Networks**: Advanced network configurations
- **Network Inspection**: Detailed network information
- **Container Connectivity**: Connect/disconnect containers

### System Monitoring

Monitor and maintain your Docker environment:

- **Resource Usage**: Live container statistics
- **Disk Usage**: Storage analysis and cleanup
- **Log Management**: View and export container logs
- **Health Checks**: System and container health
- **Event Monitoring**: Real-time Docker events

## 🔧 Features in Detail

### Dynamic Tag Selection

The script fetches available tags from Docker Hub API, allowing you to:
- Browse all available versions
- See locally cached images
- Select specific versions
- Handle network connectivity issues gracefully

### Smart Container Naming

- **Automatic Naming**: Generate names based on OS and version
- **Custom Naming**: Set your own container names
- **Conflict Resolution**: Automatically handle name conflicts
- **Validation**: Ensure valid Docker container names

### Advanced Network Configuration

Support for multiple network drivers:
- **Bridge**: Default container networking
- **Host**: Direct host network access
- **Overlay**: Swarm service networking
- **Macvlan**: MAC address assignment
- **IPvlan**: Layer 3 routing
- **None**: No networking

### Resource Management

Comprehensive resource control:
- **Memory Limits**: Set container memory usage
- **CPU Limits**: Control CPU allocation
- **Storage Limits**: Limit container storage (XFS with pquota)
- **Port Mapping**: Flexible port forwarding
- **Volume Mapping**: Persistent data storage

### Windows Container Support

Full Windows container support including:
- **Windows Server**: 2019, 2022, 2025 LTSC versions
- **Windows Client**: Windows 10/11 various builds
- **Windows Nano**: Minimal Windows containers
- **Windows Server Core**: Server without GUI
- **Windows (Linux)**: Full Windows VM via dockurr/windows

## 💡 Examples

### Start an Ubuntu Container
```bash
./docker_manager.sh
# Select: 1) Operating Systems
# Select: 1) Ubuntu
# Choose version: latest
# Container name: my-ubuntu
# Network: Default bridge
# Port mapping: 8080:80
# Start container
```

### Deploy a MySQL Database
```bash
./docker_manager.sh
# Select: 2) Database Systems
# Select: 1) MySQL
# Choose version: 8.0
# Container name: my-mysql
# Environment: MYSQL_ROOT_PASSWORD=mysecretpassword
# Port mapping: 3306:3306
# Start container
```

### Create a Custom Network
```bash
./docker_manager.sh
# Select: 8) Network Management
# Select: 2) Create New Network
# Driver: bridge
# Name: my-network
# Subnet: 172.20.0.0/16
# Gateway: 172.20.0.1
# Create network
```

### Monitor System Resources
```bash
./docker_manager.sh
# Select: 9) System Monitoring & Maintenance
# Select: 2) Container Resource Usage (Live)
# View real-time stats
# Press Ctrl+C to exit
```

## 🔍 Troubleshooting

### Common Issues

#### Docker Service Not Running
```bash
# Check Docker status
sudo systemctl status docker

# Start Docker service
sudo systemctl start docker

# Enable Docker on boot
sudo systemctl enable docker
```

#### Permission Denied
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker

# Or use sudo
sudo ./docker_manager.sh
```

#### Network Connectivity Issues
- Check internet connection
- Verify Docker Hub accessibility
- Use local images when offline
- Check firewall settings

#### Windows Container Issues
- Ensure Windows containers are enabled
- Check Docker Desktop settings
- Verify Windows container mode
- Use Linux containers as alternative

### Error Messages

#### "Docker is not installed"
Install Docker following the prerequisites section.

#### "Cannot connect to Docker Hub"
Check internet connection and Docker Hub accessibility.

#### "Container name already exists"
The script will automatically resolve name conflicts.

#### "Storage limit not supported"
Storage limits require XFS filesystem with pquota option.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Code Style
- Follow bash scripting best practices
- Add comments for complex logic
- Maintain consistent formatting
- Test on multiple platforms

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Docker community for excellent documentation
- Contributors and users of this project
- Open source community for inspiration

## 📞 Support

If you encounter any issues or have questions:

1. Check the [troubleshooting](#-troubleshooting) section
2. Search existing [issues](https://github.com/glitchidea/DockerManager/issues)
3. Create a new issue with detailed information

---

**Made with ❤️ for the Docker community**
