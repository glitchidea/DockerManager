#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'
CYAN='\033[0;36m'

# Check if Docker is installed
check_docker() {
    echo -e "${YELLOW}Checking Docker service...${NC}"
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}ERROR: Docker is not installed!${NC}"
        echo -e "${YELLOW}Info: To install Docker:${NC}"
        echo "  sudo pacman -S docker  # For Arch Linux"
        echo "  sudo apt install docker.io  # For Ubuntu/Debian"
        exit 1
    fi

    # Check if Docker service is running
    if ! systemctl is-active --quiet docker; then
        echo -e "${YELLOW}Docker service is not running. Starting automatically...${NC}"
        
        # Try to start the service
        if sudo systemctl start docker; then
            echo -e "${GREEN}Docker service started successfully!${NC}"
            sleep 1
        else
            echo -e "${RED}Failed to start Docker service!${NC}"
            echo -e "${YELLOW}To start manually:${NC}"
            echo "  sudo systemctl start docker"
            echo -e "${YELLOW}Press ENTER to continue...${NC}"
            read
        fi
    fi

    # Check if service has started
    if ! systemctl is-active --quiet docker; then
        echo -e "${RED}ERROR: Docker service is still not running. The program may not work properly.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
    fi

    # Check if user is in docker group (information only)
    if ! groups | grep -q docker; then
        echo -e "${YELLOW}Info: You may need to run Docker commands with sudo.${NC}"
        echo -e "${YELLOW}If you want to run Docker without sudo, add your user to the docker group:${NC}"
        echo "  sudo usermod -aG docker $USER"
        echo "  newgrp docker"
        echo -e "${YELLOW}Note: You may need to log out and log back in to activate the group.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
    fi

    echo -e "${GREEN}Docker is ready to use!${NC}"
    sleep 1
}

# Clear screen and show header
show_header() {
    clear
    echo -e "${CYAN}================================${NC}"
    echo -e "${GREEN}Docker Management System${NC}"
    echo -e "${CYAN}================================${NC}"
}

# List existing Docker images and containers
list_docker_resources() {
    show_header
    echo -e "\n${BLUE}Existing Docker Images:${NC}"
    docker images
    echo -e "\n${BLUE}Running Docker Containers:${NC}"
    docker ps -a
    echo -e "\nPress Enter to continue..."
    read
}

# Docker container start function
start_container() {
    local image_name=$1
    local default_container_name=$2
    local cmd=$3
    local extra_params=$4
    local os_type=$5
    
    # Check if image exists locally
    local image_exists_locally=false
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image_name}$"; then
        image_exists_locally=true
        echo -e "${GREEN}Image already exists locally: $image_name${NC}"
    else
        echo -e "${YELLOW}Image not found locally: ${image_name}${NC}"
        echo -e "${YELLOW}Checking internet connection to download...${NC}"
        
        # Check internet connection with a simple ping
        if ! curl -s --connect-timeout 3 https://registry.hub.docker.com/ -o /dev/null; then
            echo -e "${RED}ERROR: Cannot connect to Docker Hub. No internet connection available.${NC}"
            echo -e "${RED}The image is not available locally and cannot be downloaded without internet.${NC}"
            echo -e "${YELLOW}Please try again when you have an internet connection,${NC}"
            echo -e "${YELLOW}or select a different image that is already installed.${NC}"
            echo -e "${YELLOW}Press ENTER to continue...${NC}"
            read
            return 1
        fi
        
        echo -e "${YELLOW}Internet connection available. Downloading image: ${image_name}...${NC}"
        if ! docker pull "$image_name"; then
            echo -e "${RED}ERROR: Failed to download image: $image_name${NC}"
            echo -e "${YELLOW}The image might not exist, or there might be network issues.${NC}"
            echo -e "${YELLOW}Press ENTER to continue...${NC}"
            read
            return 1
        fi
        echo -e "${GREEN}Image downloaded successfully!${NC}"
    fi
    
    # Rest of the function remains the same
    # Automatic container name generation
    local auto_name=""
    local os_name="${os_type// /-}"  # Replace spaces with dashes
    
    # Create a clean name (only allowed characters)
    os_name=$(echo "$os_name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-.')
    
    # Ask for container name or generate automatically
    echo -e "\n${YELLOW}Container Naming${NC}"
    echo -e "${BLUE}--------------------${NC}"
    echo -e "Operating System: ${GREEN}$os_type${NC}"
    echo -e "\nYou can enter a name for the container or leave it blank for automatic naming."
    read -p "Container name: " container_name
    
    # Empty input check - generate automatic name
    if [ -z "$container_name" ]; then
        auto_name="${os_name}"
        echo -e "${BLUE}Using automatic naming...${NC}"
    else
        # Clean user input
        auto_name=$(echo "$container_name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-.')
        
        # If name is too short or empty, use automatic name
        if [ ${#auto_name} -lt 2 ]; then
            auto_name="${os_name}"
            echo -e "${YELLOW}The entered name is too short. Using automatic naming...${NC}"
        fi
    fi
    
    # Create a unique name (add number if containers with the same name exist)
    local container_count=1
    local final_name="${auto_name}"
    
    while docker ps -a --format '{{.Names}}' | grep -q "^${final_name}$"; do
        final_name="${auto_name}-${container_count}"
        ((container_count++))
    done
    
    if [ "$final_name" != "$auto_name" ]; then
        echo -e "${YELLOW}A container with the same name already exists. New name created: ${GREEN}$final_name${NC}"
    fi
    
    echo -e "${GREEN}Container name: $final_name${NC}"
    
    # Container permissions and settings menu
    echo -e "\n${YELLOW}Container Permissions & Settings${NC}"
    echo -e "${BLUE}-----------------------------${NC}"
    
    # Container network settings
    local network_mode=""
    echo -e "\n${CYAN}Network Mode:${NC}"
    echo "1) Default (Bridge Network)"
    echo "2) Host Network (--net=host) - Container shares host's network"
    echo "3) None (--net=none) - No network access"
    echo "4) Custom Network (connect to existing network)"
    read -p "Select network mode [1]: " network_choice
    
    case $network_choice in
        2)
            network_mode="--net=host"
            echo -e "${YELLOW}Using host network mode. Container will share host's network namespace.${NC}"
            ;;
        3)
            network_mode="--net=none"
            echo -e "${YELLOW}Using no network mode. Container will have no external network connectivity.${NC}"
            ;;
        4)
            # List available networks
            echo -e "\n${CYAN}Available Docker Networks:${NC}"
            docker network ls --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}"
            read -p "Enter network name: " custom_network
            if [ -n "$custom_network" ]; then
                # Check if network exists
                if docker network ls --format "{{.Name}}" | grep -q "^${custom_network}$"; then
                    network_mode="--net=${custom_network}"
                    echo -e "${YELLOW}Container will connect to network: ${custom_network}${NC}"
                else
                    echo -e "${RED}Network not found. Using default network.${NC}"
                fi
            fi
            ;;
        *)
            echo -e "${YELLOW}Using default bridge network.${NC}"
            ;;
    esac
    
    # Privileged mode
    local privileged_mode=""
    echo -e "\n${CYAN}Privileged Mode:${NC}"
    echo "1) Normal (Default)"
    echo "2) Privileged (--privileged) - Full access to host devices"
    read -p "Select privileged mode [1]: " privileged_choice
    
    if [ "$privileged_choice" = "2" ]; then
        privileged_mode="--privileged"
        echo -e "${RED}WARNING: Using privileged mode gives the container full access to host devices.${NC}"
        echo -e "${RED}This can pose security risks if the container is compromised.${NC}"
    fi
    
    # Port mappings
    local port_mappings=""
    echo -e "\n${CYAN}Port Mapping:${NC}"
    echo "Do you want to map any ports? (e.g., 8080:80 for mapping host port 8080 to container port 80)"
    echo "Enter port mappings separated by spaces, or press ENTER to skip"
    read -p "Port mappings: " port_input
    
    if [ -n "$port_input" ]; then
        # Process each port mapping
        for port_map in $port_input; do
            port_mappings="$port_mappings -p $port_map"
        done
        echo -e "${YELLOW}Adding port mappings: $port_mappings${NC}"
    fi
    
    # Volume mappings
    local volume_mappings=""
    echo -e "\n${CYAN}Volume Mapping:${NC}"
    echo "Do you want to map any volumes? (e.g., /host/path:/container/path)"
    echo "Enter volume mappings separated by spaces, or press ENTER to skip"
    read -p "Volume mappings: " volume_input
    
    if [ -n "$volume_input" ]; then
        # Process each volume mapping
        for volume_map in $volume_input; do
            volume_mappings="$volume_mappings -v $volume_map"
        done
        echo -e "${YELLOW}Adding volume mappings: $volume_mappings${NC}"
    fi
    
    # Environment variables
    local env_vars=""
    echo -e "\n${CYAN}Environment Variables:${NC}"
    echo "Do you want to set any environment variables? (e.g., VAR=value)"
    echo "Enter variables separated by spaces, or press ENTER to skip"
    read -p "Environment variables: " env_input
    
    if [ -n "$env_input" ]; then
        # Process each environment variable
        for env_var in $env_input; do
            env_vars="$env_vars -e $env_var"
        done
        echo -e "${YELLOW}Adding environment variables: $env_vars${NC}"
    fi
    
    # Resource limitations
    local resource_limits=""
    echo -e "\n${CYAN}Resource Limits:${NC}"
    echo "Do you want to set resource limits? (y/N)"
    read -p "Set limits: " set_limits
    
    if [[ "$set_limits" =~ ^[yY]$ ]]; then
        # Memory limit
        read -p "Memory limit (e.g., 512m, 2g, leave blank for no limit): " memory_limit
        if [ -n "$memory_limit" ]; then
            resource_limits="$resource_limits --memory=$memory_limit"
            echo -e "${YELLOW}Setting memory limit: $memory_limit${NC}"
        fi
        
        # CPU limit
        read -p "CPU limit (e.g., 0.5, 2, leave blank for no limit): " cpu_limit
        if [ -n "$cpu_limit" ]; then
            resource_limits="$resource_limits --cpus=$cpu_limit"
            echo -e "${YELLOW}Setting CPU limit: $cpu_limit${NC}"
        fi
        
        # Storage/Disk size limit
        read -p "Storage size limit (e.g., 10g, 20g, leave blank for no limit): " storage_limit
        if [ -n "$storage_limit" ]; then
            # Perform detailed check for storage-opt compatibility
            local storage_supported=false
            local storage_driver=$(docker info | grep "Storage Driver:" | cut -d ":" -f2 | tr -d " ")
            local is_xfs=false
            local has_pquota=false
            
            # Check if overlay2 driver is used
            if [[ "$storage_driver" == "overlay2" ]]; then
                # Try to identify Docker root directory
                local docker_root=$(docker info | grep "Docker Root Dir:" | cut -d ":" -f2 | tr -d " ")
                
                if [ -n "$docker_root" ]; then
                    # Check if root directory is on XFS
                    if df -T "$docker_root" 2>/dev/null | grep -q "xfs"; then
                        is_xfs=true
                        
                        # Check if pquota mount option is enabled
                        if grep -q "$docker_root" /proc/mounts && grep "$docker_root" /proc/mounts | grep -q "pquota"; then
                            has_pquota=true
                            storage_supported=true
                        fi
                    fi
                fi
            fi
            
            if $storage_supported; then
                # Adding storage limit option
                resource_limits="$resource_limits --storage-opt size=$storage_limit"
                echo -e "${GREEN}Setting storage size limit: $storage_limit${NC}"
                echo -e "${GREEN}Your system supports storage size limits.${NC}"
            else
                echo -e "${RED}WARNING: Storage size limit cannot be applied on your system.${NC}"
                echo -e "${YELLOW}Requirements for storage limits:${NC}"
                echo -e "${YELLOW}1. Docker must use overlay2 storage driver${NC} $(if [[ "$storage_driver" == "overlay2" ]]; then echo "[✓]"; else echo "[✗]"; fi)"
                echo -e "${YELLOW}2. Docker root directory must be on XFS filesystem${NC} $(if $is_xfs; then echo "[✓]"; else echo "[✗]"; fi)"
                echo -e "${YELLOW}3. XFS must be mounted with 'pquota' option${NC} $(if $has_pquota; then echo "[✓]"; else echo "[✗]"; fi)"
                echo -e "${YELLOW}The storage limit option will NOT be applied to avoid errors.${NC}"
                echo -e "${CYAN}To enable this feature, you need to:${NC}"
                echo -e "${CYAN}1. Use overlay2 storage driver${NC}"
                echo -e "${CYAN}2. Store Docker data on XFS filesystem${NC}"
                echo -e "${CYAN}3. Mount XFS with pquota option (add 'pquota' to mount options in /etc/fstab)${NC}"
                echo -e "${CYAN}4. Restart Docker service after making changes${NC}"
                
                # Ask if user wants to continue without storage limit
                read -p "Press ENTER to continue without storage limit..." -r
            fi
        fi
    fi
    
    # Remove container on exit
    local remove_on_exit=""
    echo -e "\n${CYAN}Remove Container on Exit:${NC}"
    echo "Remove container automatically when it exits? (y/N)"
    read -p "Auto-remove: " auto_remove
    
    if [[ "$auto_remove" =~ ^[yY]$ ]]; then
        remove_on_exit="--rm"
        echo -e "${YELLOW}Container will be automatically removed when it exits.${NC}"
    fi
    
    # Start the container
    echo -e "\n${BLUE}Starting container...${NC}"
    
    # Determine run mode (-it or -d)
    local run_mode=""
    if [[ "$extra_params" == *"-d"* ]]; then
        run_mode="-d"
        echo -e "${BLUE}Container will run in the background.${NC}"
    else
        run_mode="-it"
        echo -e "${BLUE}Container will run in interactive mode.${NC}"
    fi
    
    # Combine all parameters
    local all_params="$run_mode --name $final_name $network_mode $privileged_mode $port_mappings $volume_mappings $env_vars $resource_limits $remove_on_exit $extra_params"
    
    # Show the final command
    echo -e "\n${CYAN}Final Docker Command:${NC}"
    echo -e "docker run $all_params $image_name $cmd"
    echo -e "${YELLOW}Press ENTER to execute or CTRL+C to cancel...${NC}"
    read
    
    # Run the container
    if ! docker run $all_params "$image_name" $cmd; then
        echo -e "${RED}ERROR: Failed to start container!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    echo -e "${GREEN}Container started successfully: $final_name${NC}"
    
    # Show info if running in background
    if [[ "$run_mode" == "-d" ]]; then
        echo -e "\n${YELLOW}To connect to the container:${NC}"
        echo -e "  docker exec -it $final_name bash"
        echo -e "${YELLOW}To stop the container:${NC}"
        echo -e "  docker stop $final_name"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
    fi
    
    return 0
}

# Fetch tags from Docker Hub API
fetch_tags() {
    local repo=$1
    local page_size=${2:-25}  # Default show 25 results
    
    # Check if curl and jq are installed
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}ERROR: curl command not found. Please install curl.${NC}" >&2
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}ERROR: jq command not found. Please install jq.${NC}" >&2
        return 1
    fi
    
    # Check internet connection first with a simple ping to Docker Hub
    if ! curl -s --connect-timeout 3 https://hub.docker.com/ -o /dev/null; then
        echo -e "${RED}ERROR: Cannot connect to Docker Hub. Please check your internet connection.${NC}" >&2
        return 1
    fi
    
    # Fetch tags from API with timeout
    local response
    response=$(curl -s --connect-timeout 5 --max-time 10 "https://registry.hub.docker.com/v2/repositories/$repo/tags?page_size=$page_size")
    
    # Check if API responded
    if [ -z "$response" ]; then
        echo -e "${RED}ERROR: Empty response from Docker Hub API. Check your internet connection.${NC}" >&2
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$response" | jq . > /dev/null 2>&1; then
        echo -e "${RED}ERROR: Invalid response from Docker Hub API. The service might be temporarily unavailable.${NC}" >&2
        return 1
    fi
    
    # Check if there was an error in the API response
    if echo "$response" | jq -e 'has("errors")' > /dev/null && [ "$(echo "$response" | jq -r '.errors | length')" -gt 0 ]; then
        echo -e "${RED}ERROR: Docker Hub API returned an error: $(echo "$response" | jq -r '.errors[0].message')${NC}" >&2
        return 1
    fi
    
    # Get tags
    local tag_count=$(echo "$response" | jq -r '.results | length')
    
    if [ "$tag_count" -eq 0 ]; then
        echo -e "${RED}ERROR: No tags found in the specified repository.${NC}" >&2
        return 1
    fi
    
    # Return results as JSON
    echo "$response"
    return 0
}

# Dynamic tag selection menu
dynamic_tag_menu() {
    local repo=$1
    local base_image=$2
    local shell_cmd=$3
    local params=$4
    local os_name=$5
    
    show_header
    echo -e "\n${GREEN}${os_name} Versions:${NC}"
    
    # First check if we have local images for this repository/base_image
    local local_images=()
    local local_tags=()
    
    # Get locally available images for this repository
    while IFS= read -r tag; do
        if [[ ! -z "$tag" ]]; then
            local_tags+=("$tag")
        fi
    done < <(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${base_image}:" | sed "s|^${base_image}:||")
    
    # Show message based on local images availability
    if [ ${#local_tags[@]} -gt 0 ]; then
        echo -e "${GREEN}Found ${#local_tags[@]} locally installed versions.${NC}"
    else
        echo -e "${YELLOW}No local versions found.${NC}"
    fi
    
    echo -e "${YELLOW}Fetching available online versions, please wait...${NC}"
    
    # Try to fetch tags from Docker Hub
    local response
    response=$(fetch_tags "$repo" 2>/dev/null)
    local fetch_success=$?
    
    # If fetch failed and no local images, show error and exit
    if [ $fetch_success -ne 0 ] && [ ${#local_tags[@]} -eq 0 ]; then
        echo -e "${RED}Error: Cannot access Docker Hub API and no local images found.${NC}"
        echo -e "${YELLOW}Check your internet connection or try another image.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    # Special handling for Arch Linux images
    local is_arch_linux=false
    if [[ "$repo" == "archlinux/archlinux" ]]; then
        is_arch_linux=true
    fi
    
    # If fetch failed but we have local images, just use them
    if [ $fetch_success -ne 0 ]; then
        echo -e "${YELLOW}Cannot access Docker Hub API. Showing only local images.${NC}"
        # Sort the array to show newest versions first (if they follow version naming)
        IFS=$'\n' local_tags=($(sort -r <<<"${local_tags[*]}"))
        unset IFS
    else
        # Extract tags from JSON and convert to array
        local online_tags=()
        
        if [ "$is_arch_linux" = true ]; then
            # Special handling for Arch Linux: filter out SHA256 signatures
            while read -r tag; do
                # Only include tags that are not SHA256 signatures
                if [[ ! "$tag" =~ ^sha256- ]] && [[ ! "$tag" =~ \.sig$ ]]; then
                    online_tags+=("$tag")
                fi
            done < <(echo "$response" | jq -r '.results[].name')
            
            # If no valid tags were found for Arch Linux, add a default "latest" tag
            if [ ${#online_tags[@]} -eq 0 ]; then
                echo -e "${YELLOW}Warning: All tags appear to be SHA256 signatures. Adding default 'latest' tag.${NC}"
                online_tags+=("latest")
            fi
        else
            # Normal processing for other distributions
            while read -r tag; do
                online_tags+=("$tag")
            done < <(echo "$response" | jq -r '.results[].name')
        fi
        
        # Merge local and online tags, removing duplicates
        for tag in "${local_tags[@]}"; do
            # Mark local tags with [LOCAL] prefix
            tag="$tag [LOCAL]"
            online_tags=("$tag" "${online_tags[@]}")
        done
        
        # Remove duplicates but keep the [LOCAL] ones
        local_tags=()
        local seen=()
        for tag in "${online_tags[@]}"; do
            # Extract the actual tag without [LOCAL] marker
            local base_tag=$(echo "$tag" | sed 's/ \[LOCAL\]$//')
            
            # If we haven't seen this tag before, or if it's a local tag
            if [[ ! " ${seen[*]} " =~ " ${base_tag} " ]] || [[ "$tag" == *"[LOCAL]" ]]; then
                local_tags+=("$tag")
                seen+=("$base_tag")
            fi
        done
        
        # Sort the array to show newest versions first and LOCAL ones at the top
        IFS=$'\n' local_tags=($(for t in "${local_tags[@]}"; do echo "$t"; done | sort -r))
        unset IFS
    fi
    
    # Show tags
    local tag_count=${#local_tags[@]}
    
    if [ $tag_count -eq 0 ]; then
        echo -e "${RED}No tags found locally or online.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    # Pagination variables
    local page_size=10
    local current_page=1
    local total_pages=$(( (tag_count + page_size - 1) / page_size ))
    
    while true; do
        show_header
        if [ $fetch_success -ne 0 ]; then
            echo -e "\n${GREEN}${os_name} Versions (Local Only) (Page $current_page/$total_pages):${NC}"
            echo -e "${YELLOW}Internet connection not available. Showing only local images.${NC}"
        else
            echo -e "\n${GREEN}${os_name} Versions (Page $current_page/$total_pages):${NC}"
            echo -e "${YELLOW}Items marked with [LOCAL] are already downloaded.${NC}"
        fi
        
        if [ "$is_arch_linux" = true ]; then
            echo -e "${YELLOW}Note: SHA256 signatures have been filtered out.${NC}"
        fi
        
        # List tags on current page
        local start_idx=$(( (current_page - 1) * page_size ))
        local end_idx=$(( start_idx + page_size - 1 ))
        
        if [ $end_idx -ge $tag_count ]; then
            end_idx=$(( tag_count - 1 ))
        fi
        
        local option_number=1
        for (( i = start_idx; i <= end_idx; i++ )); do
            local display_tag="${local_tags[$i]}"
            if [[ "$display_tag" == *"[LOCAL]"* ]]; then
                echo -e "$option_number) ${GREEN}${display_tag}${NC}"
            else
                echo "$option_number) ${display_tag}"
            fi
            ((option_number++))
        done
        
        echo -e "\n${BLUE}Options:${NC}"
        echo "m) Enter tag manually"
        echo -e "\n${BLUE}Pagination:${NC}"
        echo "n) Next Page"
        echo "p) Previous Page"
        echo "q) Back"
        
        read -p "Your choice (1-$((option_number-1)), m, n, p, q): " choice
        
        case $choice in
            [1-9]|[1-9][0-9])
                if [ "$choice" -le "$((option_number-1))" ]; then
                    local selected_idx=$(( start_idx + choice - 1 ))
                    local selected_tag="${local_tags[$selected_idx]}"
                    
                    # Remove [LOCAL] marker if present
                    selected_tag=$(echo "$selected_tag" | sed 's/ \[LOCAL\]$//')
                    
                    local full_image="${base_image}:${selected_tag}"
                    
                    echo -e "${GREEN}Selected version: $full_image${NC}"
                    start_container "$full_image" "${os_name,,}-${selected_tag}-container" "$shell_cmd" "$params" "${os_name} ${selected_tag}"
                    return 0
                else
                    echo -e "${RED}Invalid selection!${NC}"
                fi
                ;;
            [mM])
                echo -e "\n${YELLOW}Enter tag manually:${NC}"
                echo -e "${CYAN}Available repositories: ${base_image}${NC}"
                echo -e "${YELLOW}Enter the tag (e.g., 'latest', 'base', '20230101.0.205141'):${NC}"
                read -p "Tag: " manual_tag
                
                # Check if input is not empty
                if [ -z "$manual_tag" ]; then
                    echo -e "${RED}No tag entered. Operation cancelled.${NC}"
                    sleep 1
                    continue
                fi
                
                # Confirm the selection
                local full_image="${base_image}:${manual_tag}"
                echo -e "${YELLOW}You entered: ${full_image}${NC}"
                read -p "Proceed with this tag? (y/N): " confirm
                
                if [[ ! "$confirm" =~ ^[yY]$ ]]; then
                    echo -e "${RED}Operation cancelled.${NC}"
                    sleep 1
                    continue
                fi
                
                echo -e "${GREEN}Selected version: $full_image${NC}"
                start_container "$full_image" "${os_name,,}-${manual_tag}-container" "$shell_cmd" "$params" "${os_name} ${manual_tag}"
                return 0
                ;;
            [nN])
                if [ "$current_page" -lt "$total_pages" ]; then
                    ((current_page++))
                else
                    echo -e "${YELLOW}You are already on the last page.${NC}"
                    sleep 1
                fi
                ;;
            [pP])
                if [ "$current_page" -gt 1 ]; then
                    ((current_page--))
                else
                    echo -e "${YELLOW}You are already on the first page.${NC}"
                    sleep 1
                fi
                ;;
            [qQ]) return ;;
            *)
                echo -e "${RED}Invalid selection!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Operating Systems menu
os_menu() {
    while true; do
        show_header
        
        # Check internet connection
        local internet_available=true
        if ! curl -s --connect-timeout 2 https://registry.hub.docker.com/ -o /dev/null; then
            internet_available=false
        fi
        
        # Show internet connection status
        if [ "$internet_available" = true ]; then
            echo -e "\n${GREEN}✓ Internet connection available${NC}"
        else
            echo -e "\n${RED}✗ No internet connection${NC}"
            echo -e "${YELLOW}Only local images will be available. Some options may not work properly.${NC}"
        fi
        
        echo -e "\n${GREEN}Operating Systems:${NC}"
        echo "1) Ubuntu"
        echo "2) Debian"
        echo "3) Kali Linux"
        echo "4) Alpine Linux"
        echo "5) CentOS"
        echo "6) Fedora"
        echo "7) Arch Linux"
        echo "8) OpenSUSE"
        echo "9) Gentoo"
        echo "10) Slackware"
        echo "11) NixOS"
        echo "12) Windows (demo)"
        echo "13) Windows (Linux) (demo)"
        echo "14) Show Only Local Images"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        case $choice in
            1) dynamic_tag_menu "library/ubuntu" "ubuntu" "/bin/bash" "-it" "Ubuntu" ;;
            2) dynamic_tag_menu "library/debian" "debian" "/bin/bash" "-it" "Debian" ;;
            3) dynamic_tag_menu "kalilinux/kali-rolling" "kalilinux/kali-rolling" "/bin/bash" "-it" "Kali Linux" ;;
            4) dynamic_tag_menu "library/alpine" "alpine" "/bin/sh" "-it" "Alpine" ;;
            5) dynamic_tag_menu "library/centos" "centos" "/bin/bash" "-it" "CentOS" ;;
            6) dynamic_tag_menu "library/fedora" "fedora" "/bin/bash" "-it" "Fedora" ;;
            7) dynamic_tag_menu "archlinux/archlinux" "archlinux/archlinux" "/bin/bash" "-it" "Arch Linux" ;;
            8) dynamic_tag_menu "opensuse/leap" "opensuse/leap" "/bin/bash" "-it" "OpenSUSE" ;;
            9) dynamic_tag_menu "gentoo/stage3" "gentoo/stage3" "/bin/bash" "-it" "Gentoo" ;;
            10) dynamic_tag_menu "vbatts/slackware" "vbatts/slackware" "/bin/bash" "-it" "Slackware" ;;
            11) dynamic_tag_menu "nixos/nix" "nixos/nix" "/bin/bash" "-it" "NixOS" ;;
            12) windows_menu ;;
            13) windows_linux_menu ;;
            14) show_local_images_menu ;;
            [qQ]) return ;;
            *) echo -e "${RED}Invalid selection!${NC}" ;;
        esac
    done
}

# Windows (Linux) menu
windows_linux_menu() {
    show_header
    echo -e "\n${GREEN}Windows (Linux) Versions:${NC}"
    echo -e "${YELLOW}These are Windows containers that run within Linux using dockurr/windows images.${NC}"
    echo -e "${BLUE}--------------------------------------------------------------${NC}"
    echo -e "${BLUE} Value\t\tVersion\t\t\tSize${NC}"
    echo -e "${BLUE}--------------------------------------------------------------${NC}"
    
    # Windows client versions
    echo -e "${CYAN}Windows Client Systems:${NC}"
    echo -e "1) 11\t\tWindows 11 Pro\t\t5.4 GB"
    echo -e "2) 11l\t\tWindows 11 LTSC\t\t4.7 GB"
    echo -e "3) 11e\t\tWindows 11 Enterprise\t4.0 GB"
    echo -e "4) 10\t\tWindows 10 Pro\t\t5.7 GB"
    echo -e "5) 10l\t\tWindows 10 LTSC\t\t4.6 GB"
    echo -e "6) 10e\t\tWindows 10 Enterprise\t5.2 GB"
    echo -e "7) 8e\t\tWindows 8.1 Enterprise\t3.7 GB"
    echo -e "8) 7u\t\tWindows 7 Ultimate\t3.1 GB"
    echo -e "9) vu\t\tWindows Vista Ultimate\t3.0 GB"
    echo -e "10) xp\t\tWindows XP Professional\t0.6 GB"
    echo -e "11) 2k\t\tWindows 2000 Professional\t0.4 GB"
    
    # Windows server versions
    echo -e "\n${CYAN}Windows Server Systems:${NC}"
    echo -e "12) 2025\t\tWindows Server 2025\t5.6 GB"
    echo -e "13) 2022\t\tWindows Server 2022\t4.7 GB"
    echo -e "14) 2019\t\tWindows Server 2019\t5.3 GB"
    echo -e "15) 2016\t\tWindows Server 2016\t6.5 GB"
    echo -e "16) 2012\t\tWindows Server 2012\t4.3 GB"
    echo -e "17) 2008\t\tWindows Server 2008\t3.0 GB"
    echo -e "18) 2003\t\tWindows Server 2003\t0.6 GB"
    
    echo -e "\nq) Back"
    
    read -p "Your choice: " choice
    
    local version_tag=""
    local version_name=""
    
    case $choice in
        1|11) 
            version_tag="11"
            version_name="Windows 11 Pro" 
            ;;
        2|11l) 
            version_tag="11l"
            version_name="Windows 11 LTSC" 
            ;;
        3|11e) 
            version_tag="11e"
            version_name="Windows 11 Enterprise" 
            ;;
        4|10) 
            version_tag="10"
            version_name="Windows 10 Pro" 
            ;;
        5|10l) 
            version_tag="10l"
            version_name="Windows 10 LTSC" 
            ;;
        6|10e) 
            version_tag="10e"
            version_name="Windows 10 Enterprise" 
            ;;
        7|8e) 
            version_tag="8e"
            version_name="Windows 8.1 Enterprise" 
            ;;
        8|7u) 
            version_tag="7u"
            version_name="Windows 7 Ultimate" 
            ;;
        9|vu) 
            version_tag="vu"
            version_name="Windows Vista Ultimate" 
            ;;
        10|xp) 
            version_tag="xp"
            version_name="Windows XP Professional" 
            ;;
        11|2k) 
            version_tag="2k"
            version_name="Windows 2000 Professional" 
            ;;
        12|2025) 
            version_tag="2025"
            version_name="Windows Server 2025" 
            ;;
        13|2022) 
            version_tag="2022"
            version_name="Windows Server 2022" 
            ;;
        14|2019) 
            version_tag="2019"
            version_name="Windows Server 2019" 
            ;;
        15|2016) 
            version_tag="2016"
            version_name="Windows Server 2016" 
            ;;
        16|2012) 
            version_tag="2012"
            version_name="Windows Server 2012" 
            ;;
        17|2008) 
            version_tag="2008"
            version_name="Windows Server 2008" 
            ;;
        18|2003) 
            version_tag="2003"
            version_name="Windows Server 2003" 
            ;;
        [qQ]) return ;;
        *)
            echo -e "${RED}Invalid selection!${NC}"
            sleep 1
            windows_linux_menu
            return
            ;;
    esac
    
    if [ -n "$version_tag" ]; then
        # Ask for container name
        echo -e "\n${YELLOW}Container Naming${NC}"
        echo -e "${BLUE}--------------------${NC}"
        echo -e "Operating System: ${GREEN}$version_name${NC}"
        echo -e "\nYou can enter a name for the container or leave it blank for automatic naming."
        read -p "Container name: " container_name
        
        # Create a unique name for the container
        if [ -z "$container_name" ]; then
            container_name="windows-linux-${version_tag}"
        else
            # Clean user input (allow only valid docker container name characters)
            container_name=$(echo "$container_name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-._')
            
            # If name is too short or empty after cleaning, use default
            if [ ${#container_name} -lt 2 ]; then
                container_name="windows-linux-${version_tag}"
                echo -e "${YELLOW}The entered name is invalid. Using default name: ${container_name}${NC}"
            fi
        fi
        
        # Add number suffix if the container name already exists
        local container_count=1
        local original_name="$container_name"
        
        while docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; do
            container_name="${original_name}-${container_count}"
            ((container_count++))
        done
        
        if [ "$container_name" != "$original_name" ]; then
            echo -e "${YELLOW}A container with this name already exists. Using: ${GREEN}$container_name${NC}"
        fi
        
        # Ask for RAM size
        echo -e "\n${YELLOW}RAM Configuration${NC}"
        echo -e "${BLUE}------------------${NC}"
        echo -e "Please specify the RAM limit for the Windows system."
        echo -e "Default is 4G. Examples: 2G, 4G, 8G, etc."
        read -p "RAM limit (or press Enter for default): " ram_size
        
        # Set default if empty
        if [ -z "$ram_size" ]; then
            ram_size="4G"
        else
            # Validate RAM size format (should end with G or M)
            if ! [[ "$ram_size" =~ ^[0-9]+[GM]$ ]]; then
                echo -e "${YELLOW}Invalid RAM size format. Using default: 4G${NC}"
                ram_size="4G"
            fi
        fi
        
        echo -e "${GREEN}Selected version: $version_name${NC}"
        echo -e "${BLUE}Container name: $container_name${NC}"
        echo -e "${BLUE}RAM limit: $ram_size${NC}"
        echo -e "${YELLOW}Starting Windows container with terminal access...${NC}"
        
        # Build the docker run command with interactive terminal
        local cmd="docker run -it --name $container_name"
        cmd+=" -e VERSION=\"$version_tag\""
        cmd+=" -e RAM_SIZE=\"$ram_size\""
        cmd+=" dockurr/windows"
        
        echo -e "${BLUE}Running command: $cmd${NC}"
        
        # Execute the command
        if eval "$cmd"; then
            echo -e "${GREEN}Container session ended.${NC}"
            echo -e "${YELLOW}Press ENTER to continue...${NC}"
            read
        else
            echo -e "${RED}ERROR: Failed to start container!${NC}"
            echo -e "${YELLOW}Press ENTER to continue...${NC}"
            read
            return 1
        fi
    fi
}

# Check if the system is Windows
check_windows_system() {
    # Check the operating system type
    if [[ "$(uname -s)" != "MINGW"* ]] && [[ "$(uname -s)" != "CYGWIN"* ]] && [[ "$(uname -s)" != "MSYS"* ]] && [[ "$(uname -s)" != "Windows"* ]]; then
        show_header
        echo -e "\n${RED}WARNING: Windows Containers Only Work on Windows Operating Systems!${NC}"
        echo -e "\n${YELLOW}Windows container images can only be run on Windows operating systems.${NC}"
        echo -e "${YELLOW}Your current operating system: $(uname -s)${NC}"
        echo -e "\n${YELLOW}Windows containers do not work in these environments:${NC}"
        echo -e "  ${RED}• Linux operating systems${NC}"
        echo -e "  ${RED}• macOS operating systems${NC}"
        echo -e "  ${RED}• Windows Subsystem for Linux (WSL)${NC}"
        
        echo -e "\n${YELLOW}To use Windows containers, you need:${NC}"
        echo -e "  ${GREEN}• Windows 10/11 Pro${NC}"
        echo -e "  ${GREEN}• Windows Server${NC}"
        echo -e "  ${GREEN}• Docker Desktop for Windows (in Windows Container mode)${NC}"
        
        echo -e "\n${YELLOW}If you continue, commands will fail. It is recommended to use only Linux containers.${NC}"
        
        echo -e "\n${RED}Do you want to continue to this menu? (y/N): ${NC}"
        read -p "" continue_choice
        
        if [[ ! "$continue_choice" =~ ^[yY]$ ]]; then
            return 1
        fi
        
        echo -e "\n${YELLOW}Continuing, but Windows containers may not work...${NC}"
        sleep 2
    fi
    
    return 0
}

# Windows menu
windows_menu() {
    # Check if system is Windows
    if ! check_windows_system; then
        return
    fi
    
    while true; do
        show_header
        echo -e "\n${GREEN}Windows Versions:${NC}"
        echo "1) Windows Server 2019 LTSC (ltsc2019)"
        echo "2) Windows 10 1809"
        echo "3) Windows 10 1909"
        echo "4) Windows 10 2004"
        echo "5) Windows 10 20H2"
        echo "6) Specific Windows version (see all available tags)"
        echo "7) Windows Server LTSC 2022/2025"
        echo "8) Windows Insider (Preview)"
        echo "9) Windows Server Core"
        echo "10) Windows Nano Server"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        case $choice in
            1) start_container "mcr.microsoft.com/windows:ltsc2019" "windows-ltsc2019" "cmd.exe" "-it" "Windows Server 2019 LTSC" ;;
            2) start_container "mcr.microsoft.com/windows:1809" "windows-1809" "cmd.exe" "-it" "Windows 10 1809" ;;
            3) start_container "mcr.microsoft.com/windows:1909" "windows-1909" "cmd.exe" "-it" "Windows 10 1909" ;;
            4) start_container "mcr.microsoft.com/windows:2004" "windows-2004" "cmd.exe" "-it" "Windows 10 2004" ;;
            5) start_container "mcr.microsoft.com/windows:20H2" "windows-20H2" "cmd.exe" "-it" "Windows 10 20H2" ;;
            6) windows_specific_version ;;
            7) windows_server_menu ;;
            8) start_container "mcr.microsoft.com/windows/insider:latest" "windows-insider" "cmd.exe" "-it" "Windows Insider Preview" ;;
            9) windows_server_core_menu ;;
            10) windows_nano_server_menu ;;
            [qQ]) return ;;
            *) echo -e "${RED}Invalid selection!${NC}" ;;
        esac
    done
}

# Windows Server menu
windows_server_menu() {
    while true; do
        show_header
        echo -e "\n${GREEN}Windows Server Versions:${NC}"
        echo "1) Windows Server LTSC 2022"
        echo "2) Windows Server LTSC 2022 (KB5059092)"
        echo "3) Windows Server LTSC 2022 (10.0.20348.3566)"
        echo "4) Windows Server LTSC 2025"
        echo "5) Windows Server LTSC 2025 (KB5059087)"
        echo "6) Windows Server LTSC 2025 (10.0.26100.3781)"
        echo "7) View all Windows Server versions"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        case $choice in
            1) start_container "mcr.microsoft.com/windows:ltsc2022" "windows-ltsc2022" "cmd.exe" "-it" "Windows Server LTSC 2022" ;;
            2) start_container "mcr.microsoft.com/windows:ltsc2022-KB5059092" "windows-ltsc2022-KB5059092" "cmd.exe" "-it" "Windows Server LTSC 2022 KB5059092" ;;
            3) start_container "mcr.microsoft.com/windows:10.0.20348.3566" "windows-10.0.20348.3566" "cmd.exe" "-it" "Windows Server 10.0.20348.3566" ;;
            4) start_container "mcr.microsoft.com/windows:ltsc2025" "windows-ltsc2025" "cmd.exe" "-it" "Windows Server LTSC 2025" ;;
            5) start_container "mcr.microsoft.com/windows:ltsc2025-KB5059087" "windows-ltsc2025-KB5059087" "cmd.exe" "-it" "Windows Server LTSC 2025 KB5059087" ;;
            6) start_container "mcr.microsoft.com/windows:10.0.26100.3781" "windows-10.0.26100.3781" "cmd.exe" "-it" "Windows Server 10.0.26100.3781" ;;
            7) all_windows_server_versions ;;
            [qQ]) return ;;
            *) echo -e "${RED}Invalid selection!${NC}" ;;
        esac
    done
}

# Windows Server Core menu
windows_server_core_menu() {
    while true; do
        show_header
        echo -e "\n${GREEN}Windows Server Core Versions:${NC}"
        echo "1) Windows Server Core LTSC 2025"
        echo "2) Windows Server Core LTSC 2022"
        echo "3) Windows Server Core 20H2"
        echo "4) Windows Server Core 2004"
        echo "5) Windows Server Core 1909"
        echo "6) Windows Server Core LTSC 2019 (1809)"
        echo "7) Windows Server Core LTSC 2016 (1607)"
        echo "8) View all Windows Server Core versions"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        case $choice in
            1) start_container "mcr.microsoft.com/windows/servercore:ltsc2025" "servercore-ltsc2025" "cmd.exe" "-it" "Windows Server Core LTSC 2025" ;;
            2) start_container "mcr.microsoft.com/windows/servercore:ltsc2022" "servercore-ltsc2022" "cmd.exe" "-it" "Windows Server Core LTSC 2022" ;;
            3) start_container "mcr.microsoft.com/windows/servercore:20H2" "servercore-20H2" "cmd.exe" "-it" "Windows Server Core 20H2" ;;
            4) start_container "mcr.microsoft.com/windows/servercore:2004" "servercore-2004" "cmd.exe" "-it" "Windows Server Core 2004" ;;
            5) start_container "mcr.microsoft.com/windows/servercore:1909" "servercore-1909" "cmd.exe" "-it" "Windows Server Core 1909" ;;
            6) start_container "mcr.microsoft.com/windows/servercore:ltsc2019" "servercore-ltsc2019" "cmd.exe" "-it" "Windows Server Core LTSC 2019" ;;
            7) start_container "mcr.microsoft.com/windows/servercore:ltsc2016" "servercore-ltsc2016" "cmd.exe" "-it" "Windows Server Core LTSC 2016" ;;
            8) all_windows_server_core_versions ;;
            [qQ]) return ;;
            *) echo -e "${RED}Invalid selection!${NC}" ;;
        esac
    done
}

# Windows Nano Server menu
windows_nano_server_menu() {
    while true; do
        show_header
        echo -e "\n${GREEN}Windows Nano Server Versions:${NC}"
        echo "1) Windows Nano Server LTSC 2025"
        echo "2) Windows Nano Server LTSC 2022"
        echo "3) Windows Nano Server 20H2"
        echo "4) Windows Nano Server 2004"
        echo "5) Windows Nano Server 1909"
        echo "6) Windows Nano Server LTSC 2019 (1809)"
        echo "7) View all Windows Nano Server versions"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        case $choice in
            1) start_container "mcr.microsoft.com/windows/nanoserver:ltsc2025" "nanoserver-ltsc2025" "cmd.exe" "-it" "Windows Nano Server LTSC 2025" ;;
            2) start_container "mcr.microsoft.com/windows/nanoserver:ltsc2022" "nanoserver-ltsc2022" "cmd.exe" "-it" "Windows Nano Server LTSC 2022" ;;
            3) start_container "mcr.microsoft.com/windows/nanoserver:20H2" "nanoserver-20H2" "cmd.exe" "-it" "Windows Nano Server 20H2" ;;
            4) start_container "mcr.microsoft.com/windows/nanoserver:2004" "nanoserver-2004" "cmd.exe" "-it" "Windows Nano Server 2004" ;;
            5) start_container "mcr.microsoft.com/windows/nanoserver:1909" "nanoserver-1909" "cmd.exe" "-it" "Windows Nano Server 1909" ;;
            6) start_container "mcr.microsoft.com/windows/nanoserver:ltsc2019" "nanoserver-ltsc2019" "cmd.exe" "-it" "Windows Nano Server LTSC 2019" ;;
            7) all_windows_nano_server_versions ;;
            [qQ]) return ;;
            *) echo -e "${RED}Invalid selection!${NC}" ;;
        esac
    done
}

# All Windows Server versions
all_windows_server_versions() {
    show_header
    echo -e "\n${GREEN}All Windows Server Versions:${NC}"
    echo -e "${YELLOW}Please select a Windows Server version to install:${NC}"

    # Display all available Windows Server versions in a table format
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e "${CYAN} No. | Version | OS Version | Architecture${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    
    local versions=(
        "1|ltsc2025|10.0.26100.3781|multiarch"
        "2|ltsc2025-KB5059087|10.0.26100.3781|multiarch"
        "3|10.0.26100.3781|10.0.26100.3781|multiarch"
        "4|ltsc2025-amd64|10.0.26100.3781|amd64"
        "5|ltsc2025-KB5059087-amd64|10.0.26100.3781|amd64"
        "6|10.0.26100.3781-amd64|10.0.26100.3781|amd64"
        "7|ltsc2022|10.0.20348.3566|multiarch"
        "8|ltsc2022-KB5059092|10.0.20348.3566|multiarch"
        "9|10.0.20348.3566|10.0.20348.3566|multiarch"
        "10|ltsc2022-amd64|10.0.20348.3566|amd64"
        "11|ltsc2022-KB5059092-amd64|10.0.20348.3566|amd64"
        "12|10.0.20348.3566-amd64|10.0.20348.3566|amd64"
    )
    
    # Display the windows server versions
    for entry in "${versions[@]}"; do
        IFS='|' read -r num tag os_version arch <<< "$entry"
        printf " ${GREEN}%-3s${NC} | %-28s | %-15s | %-10s\n" "$num" "$tag" "$os_version" "$arch"
    done
    
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e "${YELLOW}Note: Windows Server containers might require special configuration depending on your host OS.${NC}"
    echo -e "${YELLOW}The command used will be: docker pull mcr.microsoft.com/windows:<tag>${NC}"
    echo -e "\n${BLUE}Options:${NC}"
    echo "1-${#versions[@]}) Select version by number"
    echo "q) Back"
    
    read -p "Your choice: " choice
    
    # Handle empty input
    if [ -z "$choice" ]; then
        echo -e "${YELLOW}No selection made, returning to previous menu.${NC}"
        sleep 1
        return
    fi
    
    if [[ "$choice" =~ ^[qQ]$ ]]; then
        return
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#versions[@]}" ]; then
        IFS='|' read -r num tag os_version arch <<< "${versions[$choice-1]}"
        
        echo -e "${GREEN}Selected version: $tag (OS Version: $os_version, Architecture: $arch)${NC}"
        echo -e "${YELLOW}Starting container...${NC}"
        sleep 1
        start_container "mcr.microsoft.com/windows:$tag" "windows-$tag" "cmd.exe" "-it" "Windows Server $tag"
    else
        echo -e "${RED}Invalid selection! Please enter a number between 1 and ${#versions[@]}.${NC}"
        sleep 2
    fi
}

# Windows specific version menu
windows_specific_version() {
    show_header
    echo -e "\n${GREEN}Available Windows Versions:${NC}"
    echo -e "${YELLOW}Please select a Windows version to install:${NC}"

    # Display all available Windows versions in a table format
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e "${CYAN} No. | Version | OS Version | Architecture${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    
    local versions=(
        "1|20H2|10.0.19042.1889|multiarch"
        "2|20H2-KB5016616|10.0.19042.1889|multiarch"
        "3|10.0.19042.1889|10.0.19042.1889|multiarch"
        "4|20H2-amd64|10.0.19042.1889|amd64"
        "5|20H2-KB5016616-amd64|10.0.19042.1889|amd64"
        "6|10.0.19042.1889-amd64|10.0.19042.1889|amd64"
        "7|2004|10.0.19041.1415|multiarch"
        "8|2004-KB5008212|10.0.19041.1415|multiarch"
        "9|10.0.19041.1415|10.0.19041.1415|multiarch"
        "10|2004-amd64|10.0.19041.1415|amd64"
        "11|2004-KB5008212-amd64|10.0.19041.1415|amd64"
        "12|10.0.19041.1415-amd64|10.0.19041.1415|amd64"
        "13|1909|10.0.18363.1556|multiarch"
        "14|1909-KB5003169|10.0.18363.1556|multiarch"
        "15|10.0.18363.1556|10.0.18363.1556|multiarch"
        "16|1909-amd64|10.0.18363.1556|amd64"
        "17|1909-KB5003169-amd64|10.0.18363.1556|amd64"
        "18|10.0.18363.1556-amd64|10.0.18363.1556|amd64"
        "19|ltsc2019|10.0.17763.7249|multiarch"
        "20|1809|10.0.17763.7249|multiarch"
        "21|1809-KB5059091|10.0.17763.7249|multiarch"
        "22|10.0.17763.7249|10.0.17763.7249|multiarch"
        "23|ltsc2019-amd64|10.0.17763.7249|amd64"
        "24|1809-amd64|10.0.17763.7249|amd64"
        "25|1809-KB5059091-amd64|10.0.17763.7249|amd64"
        "26|10.0.17763.7249-amd64|10.0.17763.7249|amd64"
    )
    
    local page_size=15
    local current_page=1
    local total_pages=$(( (${#versions[@]} + page_size - 1) / page_size ))
    
    while true; do
        show_header
        echo -e "\n${GREEN}Available Windows Versions (Page $current_page/$total_pages):${NC}"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e "${CYAN} No. | Version | OS Version | Architecture${NC}"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        
        # Calculate start and end indices for current page
        local start_idx=$(( (current_page - 1) * page_size ))
        local end_idx=$(( start_idx + page_size - 1 ))
        
        if [ $end_idx -ge ${#versions[@]} ]; then
            end_idx=$(( ${#versions[@]} - 1 ))
        fi
        
        # Display versions for current page
        for i in $(seq $start_idx $end_idx); do
            local entry="${versions[$i]}"
            IFS='|' read -r num tag os_version arch <<< "$entry"
            printf " ${GREEN}%-3s${NC} | %-20s | %-15s | %-10s\n" "$num" "$tag" "$os_version" "$arch"
        done
        
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e "${YELLOW}Note: Windows containers might require special configuration depending on your host OS.${NC}"
        echo -e "${YELLOW}The command used will be: docker pull mcr.microsoft.com/windows:<tag>${NC}"
        echo -e "\n${BLUE}Navigation:${NC}"
        echo "1-${#versions[@]}) Select version by number"
        echo "n) Next Page"
        echo "p) Previous Page"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        # Handle empty input
        if [ -z "$choice" ]; then
            echo -e "${YELLOW}No selection made, returning to previous menu.${NC}"
            sleep 1
            return
        fi
        
        # Direct number selection
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [ "$choice" -ge 1 ] && [ "$choice" -le "${#versions[@]}" ]; then
                IFS='|' read -r num tag os_version arch <<< "${versions[$choice-1]}"
                
                echo -e "${GREEN}Selected version: $tag (OS Version: $os_version, Architecture: $arch)${NC}"
                echo -e "${YELLOW}Starting container...${NC}"
                sleep 1
                start_container "mcr.microsoft.com/windows:$tag" "windows-$tag" "cmd.exe" "-it" "Windows $tag"
                return
            else
                echo -e "${RED}Invalid selection! Please enter a number between 1 and ${#versions[@]}.${NC}"
                sleep 2
            fi
        else
            # Navigation commands
            case $choice in
                [nN])
                    if [ "$current_page" -lt "$total_pages" ]; then
                        ((current_page++))
                    else
                        echo -e "${YELLOW}You are already on the last page.${NC}"
                        sleep 1
                    fi
                    ;;
                [pP])
                    if [ "$current_page" -gt 1 ]; then
                        ((current_page--))
                    else
                        echo -e "${YELLOW}You are already on the first page.${NC}"
                        sleep 1
                    fi
                    ;;
                [qQ]) 
                    return 
                    ;;
                *)
                    echo -e "${RED}Invalid selection! Please enter a valid option.${NC}"
                    sleep 1
                    ;;
            esac
        fi
    done
}

# All Windows Server Core versions
all_windows_server_core_versions() {
    show_header
    echo -e "\n${GREEN}All Windows Server Core Versions:${NC}"
    echo -e "${YELLOW}Please select a Windows Server Core version to install:${NC}"

    # Display all available Windows Server Core versions in a table format
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e "${CYAN} No. | Version | OS Version | Architecture${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    
    local versions=(
        "1|ltsc2025|10.0.26100.3781|multiarch"
        "2|ltsc2025-KB5059087|10.0.26100.3781|multiarch"
        "3|10.0.26100.3781|10.0.26100.3781|multiarch"
        "4|ltsc2025-amd64|10.0.26100.3781|amd64"
        "5|ltsc2025-KB5059087-amd64|10.0.26100.3781|amd64"
        "6|10.0.26100.3781-amd64|10.0.26100.3781|amd64"
        "7|ltsc2022|10.0.20348.3566|multiarch"
        "8|ltsc2022-KB5059092|10.0.20348.3566|multiarch"
        "9|10.0.20348.3566|10.0.20348.3566|multiarch"
        "10|ltsc2022-amd64|10.0.20348.3566|amd64"
        "11|ltsc2022-KB5059092-amd64|10.0.20348.3566|amd64"
        "12|10.0.20348.3566-amd64|10.0.20348.3566|amd64"
        "13|20H2|10.0.19042.1889|multiarch"
        "14|20H2-KB5016616|10.0.19042.1889|multiarch"
        "15|10.0.19042.1889|10.0.19042.1889|multiarch"
        "16|20H2-amd64|10.0.19042.1889|amd64"
        "17|20H2-KB5016616-amd64|10.0.19042.1889|amd64"
        "18|10.0.19042.1889-amd64|10.0.19042.1889|amd64"
        "19|2004|10.0.19041.1415|multiarch"
        "20|2004-KB5008212|10.0.19041.1415|multiarch"
        "21|10.0.19041.1415|10.0.19041.1415|multiarch"
        "22|2004-amd64|10.0.19041.1415|amd64"
        "23|2004-KB5008212-amd64|10.0.19041.1415|amd64"
        "24|10.0.19041.1415-amd64|10.0.19041.1415|amd64"
        "25|1909|10.0.18363.1556|multiarch"
        "26|1909-KB5003169|10.0.18363.1556|multiarch"
        "27|10.0.18363.1556|10.0.18363.1556|multiarch"
        "28|1909-amd64|10.0.18363.1556|amd64"
        "29|1909-KB5003169-amd64|10.0.18363.1556|amd64"
        "30|10.0.18363.1556-amd64|10.0.18363.1556|amd64"
        "31|ltsc2019|10.0.17763.7249|multiarch"
        "32|1809|10.0.17763.7249|multiarch"
        "33|1809-KB5059091|10.0.17763.7249|multiarch"
        "34|10.0.17763.7249|10.0.17763.7249|multiarch"
        "35|ltsc2019-amd64|10.0.17763.7249|amd64"
        "36|1809-amd64|10.0.17763.7249|amd64"
        "37|1809-KB5059091-amd64|10.0.17763.7249|amd64"
        "38|10.0.17763.7249-amd64|10.0.17763.7249|amd64"
        "39|ltsc2016|10.0.14393.7969|multiarch"
        "40|1607|10.0.14393.7969|multiarch"
        "41|1607-KB5055521|10.0.14393.7969|multiarch"
        "42|10.0.14393.7969|10.0.14393.7969|multiarch"
        "43|ltsc2016-amd64|10.0.14393.7969|amd64"
        "44|1607-amd64|10.0.14393.7969|amd64"
        "45|1607-KB5055521-amd64|10.0.14393.7969|amd64"
        "46|10.0.14393.7969-amd64|10.0.14393.7969|amd64"
    )
    
    # Display the windows server core versions with pagination
    local page_size=15
    local current_page=1
    local total_pages=$(( (${#versions[@]} + page_size - 1) / page_size ))
    
    while true; do
        show_header
        echo -e "\n${GREEN}Windows Server Core Versions (Page $current_page/$total_pages):${NC}"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e "${CYAN} No. | Version | OS Version | Architecture${NC}"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        
        # Calculate start and end indices for current page
        local start_idx=$(( (current_page - 1) * page_size ))
        local end_idx=$(( start_idx + page_size - 1 ))
        
        if [ $end_idx -ge ${#versions[@]} ]; then
            end_idx=$(( ${#versions[@]} - 1 ))
        fi
        
        # Display versions for current page
        for i in $(seq $start_idx $end_idx); do
            local entry="${versions[$i]}"
            IFS='|' read -r num tag os_version arch <<< "$entry"
            printf " ${GREEN}%-3s${NC} | %-28s | %-15s | %-10s\n" "$num" "$tag" "$os_version" "$arch"
        done
        
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e "${YELLOW}Note: Windows Server Core is a minimal Windows Server installation with no GUI.${NC}"
        echo -e "${YELLOW}The command used will be: docker pull mcr.microsoft.com/windows/servercore:<tag>${NC}"
        echo -e "\n${BLUE}Navigation:${NC}"
        echo "1-${#versions[@]}) Select version by number"
        echo "n) Next Page"
        echo "p) Previous Page"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        # Handle empty input - treat as back
        if [ -z "$choice" ]; then
            echo -e "${YELLOW}No selection made, returning to previous menu.${NC}"
            sleep 1
            return
        fi
        
        # Direct number selection (without 's' command)
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [ "$choice" -ge 1 ] && [ "$choice" -le "${#versions[@]}" ]; then
                IFS='|' read -r num tag os_version arch <<< "${versions[$choice-1]}"
                
                echo -e "${GREEN}Selected version: $tag (OS Version: $os_version, Architecture: $arch)${NC}"
                echo -e "${YELLOW}Starting container...${NC}"
                sleep 1
                start_container "mcr.microsoft.com/windows/servercore:$tag" "servercore-$tag" "cmd.exe" "-it" "Windows Server Core $tag"
                return
            else
                echo -e "${RED}Invalid selection! Please enter a number between 1 and ${#versions[@]}.${NC}"
                sleep 2
            fi
        else
            # Navigation commands
            case $choice in
                [nN])
                    if [ "$current_page" -lt "$total_pages" ]; then
                        ((current_page++))
                    else
                        echo -e "${YELLOW}You are already on the last page.${NC}"
                        sleep 1
                    fi
                    ;;
                [pP])
                    if [ "$current_page" -gt 1 ]; then
                        ((current_page--))
                    else
                        echo -e "${YELLOW}You are already on the first page.${NC}"
                        sleep 1
                    fi
                    ;;
                [qQ]) 
                    return 
                    ;;
                *)
                    echo -e "${RED}Invalid selection! Please enter a valid option.${NC}"
                    sleep 1
                    ;;
            esac
        fi
    done
}

# All Windows Nano Server versions
all_windows_nano_server_versions() {
    show_header
    echo -e "\n${GREEN}All Windows Nano Server Versions:${NC}"
    echo -e "${YELLOW}Please select a Windows Nano Server version to install:${NC}"

    # Display all available Windows Nano Server versions in a table format
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e "${CYAN} No. | Version | OS Version | Architecture${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    
    local versions=(
        "1|ltsc2025|10.0.26100.3781|multiarch"
        "2|ltsc2025-KB5059087|10.0.26100.3781|multiarch"
        "3|10.0.26100.3781|10.0.26100.3781|multiarch"
        "4|ltsc2025-amd64|10.0.26100.3781|amd64"
        "5|ltsc2025-KB5059087-amd64|10.0.26100.3781|amd64"
        "6|10.0.26100.3781-amd64|10.0.26100.3781|amd64"
        "7|ltsc2022|10.0.20348.3566|multiarch"
        "8|ltsc2022-KB5059092|10.0.20348.3566|multiarch"
        "9|10.0.20348.3566|10.0.20348.3566|multiarch"
        "10|ltsc2022-amd64|10.0.20348.3566|amd64"
        "11|ltsc2022-KB5059092-amd64|10.0.20348.3566|amd64"
        "12|10.0.20348.3566-amd64|10.0.20348.3566|amd64"
        "13|20H2|10.0.19042.1889|multiarch"
        "14|20H2-KB5016616|10.0.19042.1889|multiarch"
        "15|10.0.19042.1889|10.0.19042.1889|multiarch"
        "16|20H2-amd64|10.0.19042.1889|amd64"
        "17|20H2-KB5016616-amd64|10.0.19042.1889|amd64"
        "18|10.0.19042.1889-amd64|10.0.19042.1889|amd64"
        "19|2004|10.0.19041.1415|multiarch"
        "20|2004-KB5008212|10.0.19041.1415|multiarch"
        "21|10.0.19041.1415|10.0.19041.1415|multiarch"
        "22|2004-amd64|10.0.19041.1415|amd64"
        "23|2004-KB5008212-amd64|10.0.19041.1415|amd64"
        "24|10.0.19041.1415-amd64|10.0.19041.1415|amd64"
        "25|1909|10.0.18363.1556|multiarch"
        "26|1909-KB5003169|10.0.18363.1556|multiarch"
        "27|10.0.18363.1556|10.0.18363.1556|multiarch"
        "28|1909-amd64|10.0.18363.1556|amd64"
        "29|1909-KB5003169-amd64|10.0.18363.1556|amd64"
        "30|10.0.18363.1556-amd64|10.0.18363.1556|amd64"
        "31|ltsc2019|10.0.17763.7249|multiarch"
        "32|1809|10.0.17763.7249|multiarch"
        "33|1809-KB5059091|10.0.17763.7249|multiarch"
        "34|10.0.17763.7249|10.0.17763.7249|multiarch"
        "35|ltsc2019-amd64|10.0.17763.7249|amd64"
        "36|1809-amd64|10.0.17763.7249|amd64"
        "37|1809-KB5059091-amd64|10.0.17763.7249|amd64"
        "38|10.0.17763.7249-amd64|10.0.17763.7249|amd64"
    )
    
    # Display the windows nano server versions with pagination
    local page_size=15
    local current_page=1
    local total_pages=$(( (${#versions[@]} + page_size - 1) / page_size ))
    
    while true; do
        show_header
        echo -e "\n${GREEN}Windows Nano Server Versions (Page $current_page/$total_pages):${NC}"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e "${CYAN} No. | Version | OS Version | Architecture${NC}"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        
        # Calculate start and end indices for current page
        local start_idx=$(( (current_page - 1) * page_size ))
        local end_idx=$(( start_idx + page_size - 1 ))
        
        if [ $end_idx -ge ${#versions[@]} ]; then
            end_idx=$(( ${#versions[@]} - 1 ))
        fi
        
        # Display versions for current page
        for i in $(seq $start_idx $end_idx); do
            local entry="${versions[$i]}"
            IFS='|' read -r num tag os_version arch <<< "$entry"
            printf " ${GREEN}%-3s${NC} | %-28s | %-15s | %-10s\n" "$num" "$tag" "$os_version" "$arch"
        done
        
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e "${YELLOW}Note: Windows Nano Server is a highly optimized container OS with minimal footprint.${NC}"
        echo -e "${YELLOW}The command used will be: docker pull mcr.microsoft.com/windows/nanoserver:<tag>${NC}"
        echo -e "\n${BLUE}Navigation:${NC}"
        echo "1-${#versions[@]}) Select version by number"
        echo "n) Next Page"
        echo "p) Previous Page"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        # Handle empty input - treat as back
        if [ -z "$choice" ]; then
            echo -e "${YELLOW}No selection made, returning to previous menu.${NC}"
            sleep 1
            return
        fi
        
        # Direct number selection (without 's' command)
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [ "$choice" -ge 1 ] && [ "$choice" -le "${#versions[@]}" ]; then
                IFS='|' read -r num tag os_version arch <<< "${versions[$choice-1]}"
                
                echo -e "${GREEN}Selected version: $tag (OS Version: $os_version, Architecture: $arch)${NC}"
                echo -e "${YELLOW}Starting container...${NC}"
                sleep 1
                start_container "mcr.microsoft.com/windows/nanoserver:$tag" "nanoserver-$tag" "cmd.exe" "-it" "Windows Nano Server $tag"
                return
            else
                echo -e "${RED}Invalid selection! Please enter a number between 1 and ${#versions[@]}.${NC}"
                sleep 2
            fi
        else
            # Navigation commands
            case $choice in
                [nN])
                    if [ "$current_page" -lt "$total_pages" ]; then
                        ((current_page++))
                    else
                        echo -e "${YELLOW}You are already on the last page.${NC}"
                        sleep 1
                    fi
                    ;;
                [pP])
                    if [ "$current_page" -gt 1 ]; then
                        ((current_page--))
                    else
                        echo -e "${YELLOW}You are already on the first page.${NC}"
                        sleep 1
                    fi
                    ;;
                [qQ]) 
                    return 
                    ;;
                *)
                    echo -e "${RED}Invalid selection! Please enter a valid option.${NC}"
                    sleep 1
                    ;;
            esac
        fi
    done
}

# Database systems menu
database_menu() {
    while true; do
        show_header
        echo -e "\n${GREEN}Database Systems:${NC}"
        echo "1) MySQL"
        echo "2) PostgreSQL"
        echo "3) MongoDB"
        echo "4) Redis"
        echo "5) MariaDB"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        case $choice in
            1) dynamic_tag_menu "library/mysql" "mysql" "" "-d -e MYSQL_ROOT_PASSWORD=root" "MySQL" ;;
            2) dynamic_tag_menu "library/postgres" "postgres" "" "-d -e POSTGRES_PASSWORD=postgres" "PostgreSQL" ;;
            3) dynamic_tag_menu "library/mongo" "mongo" "" "-d" "MongoDB" ;;
            4) dynamic_tag_menu "library/redis" "redis" "" "-d" "Redis" ;;
            5) dynamic_tag_menu "library/mariadb" "mariadb" "" "-d -e MYSQL_ROOT_PASSWORD=root" "MariaDB" ;;
            [qQ]) return ;;
            *) echo -e "${RED}Invalid selection!${NC}" ;;
        esac
    done
}

# Web servers menu
webserver_menu() {
    while true; do
        show_header
        echo -e "\n${GREEN}Web Servers:${NC}"
        echo "1) Nginx"
        echo "2) Apache"
        echo "3) Tomcat"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        case $choice in
            1) 
                dynamic_tag_menu "library/nginx" "nginx" "" "-d -p 80:80" "Nginx"
                echo -e "${BLUE}You can visit http://localhost in your browser.${NC}"
                ;;
            2) 
                dynamic_tag_menu "library/httpd" "httpd" "" "-d -p 8080:80" "Apache"
                echo -e "${BLUE}You can visit http://localhost:8080 in your browser.${NC}"
                ;;
            3) 
                dynamic_tag_menu "library/tomcat" "tomcat" "" "-d -p 8888:8080" "Tomcat"
                echo -e "${BLUE}You can visit http://localhost:8888 in your browser.${NC}"
                ;;
            [qQ]) return ;;
            *) echo -e "${RED}Invalid selection!${NC}" ;;
        esac
    done
}

# Connect to Docker container
connect_to_container() {
    show_header
    echo -e "\n${YELLOW}Existing containers:${NC}"
    
    # List containers and number them
    local containers=()
    local container_count=0
    
    echo -e "${CYAN}No.    CONTAINER ID     IMAGE                    STATUS                  NAMES${NC}"
    echo -e "${CYAN}----   ------------     -----                    ------                  -----${NC}"
    
    while IFS= read -r container_line; do
        ((container_count++))
        containers+=("$container_line")
        
        # Parse container information
        local container_id=$(echo "$container_line" | awk '{print $1}')
        local image=$(echo "$container_line" | awk '{print $2}')
        local status=$(echo "$container_line" | awk '{print $5}')
        local name=$(echo "$container_line" | awk '{print $NF}')
        
        # Print formatted output
        printf "${GREEN}%-6s${NC} %-17s %-24s %-22s %s\n" "[$container_count]" "$container_id" "$image" "$status" "$name"
    done < <(docker ps -a --format "{{.ID}} {{.Image}} {{.Status}} {{.Names}}" | sort -k 3)
    
    if [ $container_count -eq 0 ]; then
        echo -e "${RED}No containers found in the system!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    echo -e "\n${GREEN}Enter the row number, ID, or name of the container you want to connect to:${NC}"
    read container_input
    
    # Check if input is empty
    if [ -z "$container_input" ]; then
        echo -e "${RED}Invalid input!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    local container_id=""
    
    # Check if row number
    if [[ "$container_input" =~ ^[0-9]+$ ]] && [ "$container_input" -le "$container_count" ] && [ "$container_input" -gt 0 ]; then
        container_id=$(echo "${containers[$container_input-1]}" | awk '{print $1}')
        echo -e "${BLUE}Selected container ID: $container_id${NC}"
    else
        # ID or name entered directly
        container_id="$container_input"
    fi
    
    # Check if container exists (by name or ID)
    if ! docker ps -a --format '{{.ID}}' | grep -q "^$container_id$" && ! docker ps -a --format '{{.Names}}' | grep -q "^$container_id$"; then
        echo -e "${RED}ERROR: Container not found!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    # Check if container is a dockurr/windows container
    if docker ps -a --format '{{.Image}} {{.ID}} {{.Names}}' | grep -E "dockurr/windows" | grep -q "$container_id"; then
        show_header
        local container_name=$(docker ps -a --format '{{.Names}}' --filter "id=$container_id" || docker ps -a --format '{{.Names}}' --filter "name=$container_id")
        
        echo -e "\n${CYAN}====================================================================================${NC}"
        echo -e "${CYAN}IMPORTANT: How to Connect to Your Windows Container${NC}"
        echo -e "${CYAN}====================================================================================${NC}"
        echo -e "${YELLOW}The container '${GREEN}${container_name}${YELLOW}' is a Windows virtual machine container.${NC}"
        echo -e "${YELLOW}This type of container does NOT support direct shell access with docker exec.${NC}"
        echo -e "${YELLOW}Instead, you can access your Windows container in two ways:${NC}"
        echo -e "\n${GREEN}1. Web Interface (during installation and for initial access):${NC}"
        echo -e "   ${BLUE}• Open your web browser and go to: ${GREEN}http://localhost:8006${NC}"
        echo -e "   ${BLUE}• This provides a web-based viewer to see and interact with Windows${NC}"
        echo -e "\n${GREEN}2. Remote Desktop (RDP) once installation is complete:${NC}"
        echo -e "   ${BLUE}• Use any RDP client to connect to: ${GREEN}localhost:3389${NC}"
        echo -e "   ${BLUE}• Username: ${GREEN}Docker${NC}"
        echo -e "   ${BLUE}• Password: ${GREEN}admin${NC}"
        echo -e "\n${YELLOW}To start the container if it's stopped:${NC}"
        echo -e "   ${BLUE}docker start ${container_name}${NC}"
        echo -e "${CYAN}====================================================================================${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 0
    fi
    
    # Check if container is running
    if ! docker ps --format '{{.ID}}' | grep -q "^$container_id$" && ! docker ps --format '{{.Names}}' | grep -q "^$container_id$"; then
        echo -e "${YELLOW}Container is stopped. Starting it...${NC}"
        if ! docker start "$container_id"; then
            echo -e "${RED}ERROR: Failed to start container!${NC}"
            echo -e "${YELLOW}Press ENTER to continue...${NC}"
            read
            return 1
        fi
        echo -e "${GREEN}Container started successfully!${NC}"
    fi
    
    # Check which shell is available in the container
    local shell_cmd="/bin/bash"
    if ! docker exec "$container_id" which bash >/dev/null 2>&1; then
        if docker exec "$container_id" which sh >/dev/null 2>&1; then
            shell_cmd="/bin/sh"
            echo -e "${YELLOW}Bash not found, using sh instead.${NC}"
        else
            echo -e "${RED}ERROR: No shell found in the container!${NC}"
            echo -e "${YELLOW}This may be a specialized container without a shell.${NC}"
            echo -e "${YELLOW}Press ENTER to continue...${NC}"
            read
            return 1
        fi
    fi
    
    # Connect to the container
    echo -e "${GREEN}Connecting to container ($shell_cmd)...${NC}"
    echo -e "${BLUE}Use 'exit' command to exit the container.${NC}"
    echo -e "${BLUE}======================================================${NC}"
    if ! docker exec -it "$container_id" $shell_cmd; then
        echo -e "${RED}ERROR: Failed to connect to container!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    echo -e "${GREEN}Container connection closed.${NC}"
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
    return 0
}

# Delete container function
delete_container() {
    show_header
    echo -e "\n${YELLOW}Existing containers:${NC}"
    
    # List containers and number them
    local containers=()
    local container_count=0
    
    echo -e "${CYAN}No.    CONTAINER ID     IMAGE                    STATUS                  NAMES${NC}"
    echo -e "${CYAN}----   ------------     -----                    ------                  -----${NC}"
    
    while IFS= read -r container_line; do
        ((container_count++))
        containers+=("$container_line")
        
        # Parse container information
        local container_id=$(echo "$container_line" | awk '{print $1}')
        local image=$(echo "$container_line" | awk '{print $2}')
        local status=$(echo "$container_line" | awk '{print $5}')
        local name=$(echo "$container_line" | awk '{print $NF}')
        
        # Print formatted output
        printf "${GREEN}%-6s${NC} %-17s %-24s %-22s %s\n" "[$container_count]" "$container_id" "$image" "$status" "$name"
    done < <(docker ps -a --format "{{.ID}} {{.Image}} {{.Status}} {{.Names}}" | sort -k 3)
    
    if [ $container_count -eq 0 ]; then
        echo -e "${RED}No containers found in the system!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    echo -e "\n${RED}Enter the row numbers, container IDs, or names of the containers you want to delete:${NC}"
    echo -e "${YELLOW}For multiple selections, separate with commas (e.g., 1,3,5 or container1,container2)${NC}"
    echo -e "${YELLOW}Press 'q' to cancel the deletion.${NC}"
    read container_input
    
    # Check if canceled
    if [[ "$container_input" =~ ^[qQ]$ ]]; then
        echo -e "${BLUE}Deletion canceled.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 0
    fi
    
    # Check if input is empty
    if [ -z "$container_input" ]; then
        echo -e "${RED}Invalid input!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    # Split comma-separated input
    IFS=',' read -ra container_inputs <<< "$container_input"
    
    # Track success and failure
    local success_count=0
    local failed_count=0
    local not_found_count=0
    
    local containers_to_delete=()
    local container_details=()
    
    # Process each input and prepare identifiers for deletion
    for input in "${container_inputs[@]}"; do
        local input_trimmed=$(echo "$input" | xargs)  # Trim whitespace
        
        if [ -z "$input_trimmed" ]; then
            continue
        fi
        
        local container_id=""
        local container_name=""
        
        # Check if row number
        if [[ "$input_trimmed" =~ ^[0-9]+$ ]] && [ "$input_trimmed" -le "$container_count" ] && [ "$input_trimmed" -gt 0 ]; then
            container_line="${containers[$input_trimmed-1]}"
            container_id=$(echo "$container_line" | awk '{print $1}')
            container_name=$(echo "$container_line" | awk '{print $NF}')
            
            # Check if container still exists (double check)
            if ! docker ps -a --format '{{.ID}}' | grep -q "^$container_id$"; then
                echo -e "${RED}Container not found: Container #$input_trimmed${NC}"
                ((not_found_count++))
                continue
            fi
            
            containers_to_delete+=("$container_id")
            container_details+=("$container_name (ID: $container_id)")
            echo -e "${BLUE}Selected container: $container_name (ID: $container_id)${NC}"
        else
            # ID or name entered directly
            local found=false
            
            # Check if it's a valid container ID
            if docker ps -a --format '{{.ID}} {{.Names}}' | grep -q "^$input_trimmed"; then
                container_id="$input_trimmed"
                container_name=$(docker ps -a --format '{{.Names}}' --filter "id=$input_trimmed")
                found=true
            fi
            
            # Check if it's a valid container name
            if ! $found && docker ps -a --format '{{.Names}} {{.ID}}' | grep -q "^$input_trimmed "; then
                container_name="$input_trimmed"
                container_id=$(docker ps -a --format '{{.ID}}' --filter "name=$input_trimmed")
                found=true
            fi
            
            if ! $found; then
                echo -e "${RED}Container not found: $input_trimmed${NC}"
                ((not_found_count++))
                continue
            fi
            
            containers_to_delete+=("$container_id")
            container_details+=("$container_name (ID: $container_id)")
            echo -e "${BLUE}Selected container: $container_name (ID: $container_id)${NC}"
        fi
    done
    
    # Check if any containers were found for deletion
    if [ ${#containers_to_delete[@]} -eq 0 ]; then
        echo -e "${RED}No valid containers selected for deletion.${NC}"
        if [ $not_found_count -gt 0 ]; then
            echo -e "${RED}$not_found_count container(s) not found.${NC}"
        fi
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    # Ask for confirmation
    echo -e "${RED}WARNING: This will permanently delete ${#containers_to_delete[@]} container(s) and their data!${NC}"
    read -p "Do you want to continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${BLUE}Deletion canceled.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 0
    fi
    
    # Process each container
    for i in "${!containers_to_delete[@]}"; do
        local container_id="${containers_to_delete[$i]}"
        local detail="${container_details[$i]}"
        
        echo -e "\n${YELLOW}Processing: $detail${NC}"
        
        # Check if container is running and stop it if necessary
        if docker ps --format '{{.ID}}' | grep -q "^$container_id$"; then
            echo -e "${YELLOW}Container is running. Stopping it...${NC}"
            if ! docker stop "$container_id"; then
                echo -e "${RED}ERROR: Failed to stop container: $detail${NC}"
                ((failed_count++))
                continue
            fi
            echo -e "${GREEN}Container stopped.${NC}"
        fi
        
        # Delete the container
        echo -e "${YELLOW}Deleting container...${NC}"
        if ! docker rm "$container_id"; then
            echo -e "${RED}ERROR: Failed to delete container: $detail${NC}"
            ((failed_count++))
        else
            echo -e "${GREEN}Successfully deleted: $detail${NC}"
            ((success_count++))
        fi
    done
    
    # Summary of deletion
    echo -e "\n${BLUE}Deletion Summary:${NC}"
    echo -e "${GREEN}$success_count container(s) deleted successfully.${NC}"
    
    if [ $failed_count -gt 0 ]; then
        echo -e "${RED}$failed_count container(s) failed to delete.${NC}"
    fi
    
    if [ $not_found_count -gt 0 ]; then
        echo -e "${RED}$not_found_count container(s) not found.${NC}"
    fi
    
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
    return 0
}

# Delete image function
delete_image() {
    show_header
    echo -e "\n${YELLOW}Existing Docker Images:${NC}"
    
    # List images and number them
    local images=()
    local image_count=0
    
    echo -e "${CYAN}No.    REPOSITORY               TAG        IMAGE ID       SIZE${NC}"
    echo -e "${CYAN}----   ----------               ---        --------       ----${NC}"
    
    while IFS= read -r image_line; do
        ((image_count++))
        images+=("$image_line")
        
        # Parse image information
        local repo=$(echo "$image_line" | awk '{print $1}')
        local tag=$(echo "$image_line" | awk '{print $2}')
        local image_id=$(echo "$image_line" | awk '{print $3}')
        local size=$(echo "$image_line" | awk '{print $NF}')
        
        # Print formatted output
        printf "${GREEN}%-6s${NC} %-24s %-10s %-14s %s\n" "[$image_count]" "$repo" "$tag" "$image_id" "$size"
    done < <(docker images --format "{{.Repository}} {{.Tag}} {{.ID}} {{.Size}}")
    
    if [ $image_count -eq 0 ]; then
        echo -e "${RED}No images found in the system!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    echo -e "\n${RED}Enter the row numbers, IMAGE IDs, or repository:tag of the images you want to delete:${NC}"
    echo -e "${YELLOW}For multiple selections, separate with commas (e.g., 1,3,5 or ubuntu:latest,debian:latest)${NC}"
    echo -e "${YELLOW}Press 'q' to cancel the deletion.${NC}"
    read image_input
    
    # Check if canceled
    if [[ "$image_input" =~ ^[qQ]$ ]]; then
        echo -e "${BLUE}Deletion canceled.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 0
    fi
    
    # Check if input is empty
    if [ -z "$image_input" ]; then
        echo -e "${RED}Invalid input!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    # Split comma-separated input
    IFS=',' read -ra image_inputs <<< "$image_input"
    
    # Track success and failure
    local success_count=0
    local failed_count=0
    local in_use_count=0
    local not_found_count=0
    
    local images_to_delete=()
    
    # Process each input and prepare identifiers for deletion
    for input in "${image_inputs[@]}"; do
        local input_trimmed=$(echo "$input" | xargs)  # Trim whitespace
        
        if [ -z "$input_trimmed" ]; then
            continue
        fi
        
        local image_identifier=""
        
        # Check if row number
        if [[ "$input_trimmed" =~ ^[0-9]+$ ]] && [ "$input_trimmed" -le "$image_count" ] && [ "$input_trimmed" -gt 0 ]; then
            image_line="${images[$input_trimmed-1]}"
            local repo=$(echo "$image_line" | awk '{print $1}')
            local tag=$(echo "$image_line" | awk '{print $2}')
            image_identifier="${repo}:${tag}"
            
            # Check if image still exists (double check)
            if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$image_identifier$"; then
                echo -e "${RED}Image not found: $image_identifier${NC}"
                ((not_found_count++))
                continue
            fi
            
            # Check if image is used by any containers
            local used_containers=$(docker ps -a --format '{{.Image}} {{.Names}}' | grep -E "^$image_identifier" || true)
            if [ -n "$used_containers" ]; then
                echo -e "${RED}Image $image_identifier is being used by containers and cannot be deleted:${NC}"
                echo "$used_containers" | awk '{print "  - " $2 " (using " $1 ")"}'
                ((in_use_count++))
                continue
            fi
            
            images_to_delete+=("$image_identifier")
            echo -e "${BLUE}Selected image: $image_identifier${NC}"
        else
            # ID or repository:tag entered directly
            image_identifier="$input_trimmed"
            
            # Check if image exists
            if ! docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -q "$image_identifier"; then
                echo -e "${RED}Image not found: $image_identifier${NC}"
                ((not_found_count++))
                continue
            fi
            
            # Check if image is used by any containers
            local used_containers=$(docker ps -a --format '{{.Image}} {{.Names}}' | grep -E "^$image_identifier" || true)
            if [ -n "$used_containers" ]; then
                echo -e "${RED}Image $image_identifier is being used by containers and cannot be deleted:${NC}"
                echo "$used_containers" | awk '{print "  - " $2 " (using " $1 ")"}'
                ((in_use_count++))
                continue
            fi
            
            images_to_delete+=("$image_identifier")
            echo -e "${BLUE}Selected image: $image_identifier${NC}"
        fi
    done
    
    # Check if any images were found and available for deletion
    if [ ${#images_to_delete[@]} -eq 0 ]; then
        echo -e "${RED}No valid images selected for deletion.${NC}"
        if [ $not_found_count -gt 0 ]; then
            echo -e "${RED}$not_found_count image(s) not found.${NC}"
        fi
        if [ $in_use_count -gt 0 ]; then
            echo -e "${RED}$in_use_count image(s) in use by containers.${NC}"
        fi
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 1
    fi
    
    # Ask for confirmation
    echo -e "${RED}WARNING: This will permanently delete ${#images_to_delete[@]} image(s)!${NC}"
    read -p "Do you want to continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${BLUE}Deletion canceled.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return 0
    fi
    
    # Delete the images
    echo -e "${YELLOW}Deleting images...${NC}"
    for image in "${images_to_delete[@]}"; do
        echo -e "${YELLOW}Deleting $image...${NC}"
        if docker rmi "$image"; then
            echo -e "${GREEN}Successfully deleted: $image${NC}"
            ((success_count++))
        else
            echo -e "${RED}Failed to delete: $image${NC}"
            ((failed_count++))
        fi
    done
    
    # Summary of deletion
    echo -e "\n${BLUE}Deletion Summary:${NC}"
    echo -e "${GREEN}$success_count image(s) deleted successfully.${NC}"
    
    if [ $failed_count -gt 0 ]; then
        echo -e "${RED}$failed_count image(s) failed to delete.${NC}"
    fi
    
    if [ $not_found_count -gt 0 ]; then
        echo -e "${RED}$not_found_count image(s) not found.${NC}"
    fi
    
    if [ $in_use_count -gt 0 ]; then
        echo -e "${RED}$in_use_count image(s) in use by containers.${NC}"
    fi
    
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
    return 0
}

# Main menu
main_menu() {
    while true; do
        show_header
        echo -e "\n${GREEN}Main Menu:${NC}"
        echo "1) Operating Systems"
        echo "2) Database Systems"
        echo "3) Web Servers"
        echo "4) Connect to Existing Container"
        echo "5) List Docker Resources"
        echo "6) Delete Container"
        echo "7) Delete Image"
        echo "8) Network Management"
        echo "9) System Monitoring & Maintenance"
        echo "q) Exit"
        
        read -p "Your choice: " choice
        
        case $choice in
            1) os_menu ;;
            2) database_menu ;;
            3) webserver_menu ;;
            4) connect_to_container ;;
            5) list_docker_resources ;;
            6) delete_container ;;
            7) delete_image ;;
            8) network_management_menu ;;
            9) system_monitoring_menu ;;
            [qQ]) 
                clear
                exit 0 
                ;;
            *) echo -e "${RED}Invalid selection!${NC}" ;;
        esac
    done
}

# Show only local images
show_local_images_menu() {
    show_header
    echo -e "\n${GREEN}Local Docker Images:${NC}"
    
    # Get unique repositories
    local repos=()
    local repo_count=0
    
    echo -e "${CYAN}Loading local images...${NC}"
    
    while IFS= read -r repo_tag; do
        if [[ ! -z "$repo_tag" ]]; then
            # Split repository and tag
            local repo=$(echo "$repo_tag" | cut -d':' -f1)
            local tag=$(echo "$repo_tag" | cut -d':' -f2-)
            
            # Check if we already have this repository
            local found=false
            for existing_repo in "${repos[@]}"; do
                if [[ "$existing_repo" == "$repo" ]]; then
                    found=true
                    break
                fi
            done
            
            # If not found, add it
            if ! $found; then
                repos+=("$repo")
                ((repo_count++))
            fi
        fi
    done < <(docker images --format "{{.Repository}}:{{.Tag}}" | sort)
    
    # Display repositories
    if [ $repo_count -eq 0 ]; then
        echo -e "${RED}No local images found!${NC}"
        echo -e "${YELLOW}You can download images using the main menu options.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    echo -e "\n${GREEN}Found $repo_count local repositories:${NC}"
    echo -e "${CYAN}No.    REPOSITORY${NC}"
    echo -e "${CYAN}----   ----------${NC}"
    
    for i in "${!repos[@]}"; do
        printf "${GREEN}%-6s${NC} %s\n" "[$((i+1))]" "${repos[$i]}"
    done
    
    echo -e "\n${YELLOW}Select a repository to see available tags:${NC}"
    echo -e "q) Back"
    
    read -p "Your choice: " choice
    
    # Check if canceled
    if [[ "$choice" =~ ^[qQ]$ ]]; then
        return
    fi
    
    # Check if input is a valid number
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "$repo_count" ] && [ "$choice" -gt 0 ]; then
        local selected_repo="${repos[$choice-1]}"
        show_local_tags_menu "$selected_repo"
    else
        echo -e "${RED}Invalid selection!${NC}"
        sleep 1
    fi
}

# Show tags for a selected local repository
show_local_tags_menu() {
    local repo=$1
    
    while true; do
        show_header
        echo -e "\n${GREEN}Local Tags for: $repo${NC}"
        
        # Get tags for selected repository
        local tags=()
        local tag_count=0
        
        echo -e "${CYAN}Loading tags...${NC}"
        
        while IFS= read -r tag; do
            if [[ ! -z "$tag" ]]; then
                tags+=("$tag")
                ((tag_count++))
            fi
        done < <(docker images --format "{{.Tag}}" --filter "reference=$repo" | sort)
        
        # Display tags
        if [ $tag_count -eq 0 ]; then
            echo -e "${RED}No tags found for $repo!${NC}"
            echo -e "${YELLOW}Press ENTER to continue...${NC}"
            read
            return
        fi
        
        echo -e "\n${GREEN}Found $tag_count tags:${NC}"
        echo -e "${CYAN}No.    TAG             IMAGE ID       SIZE${NC}"
        echo -e "${CYAN}----   ---             --------       ----${NC}"
        
        local image_data=()
        
        # Get image IDs and sizes
        while IFS= read -r line; do
            image_data+=("$line")
        done < <(docker images --format "{{.Tag}}|{{.ID}}|{{.Size}}" --filter "reference=$repo")
        
        # Display tags with image IDs and sizes
        for i in "${!tags[@]}"; do
            local tag="${tags[$i]}"
            local image_id=""
            local size=""
            
            # Find image ID and size for this tag
            for data in "${image_data[@]}"; do
                IFS='|' read -r data_tag data_id data_size <<< "$data"
                if [[ "$data_tag" == "$tag" ]]; then
                    image_id="$data_id"
                    size="$data_size"
                    break
                fi
            done
            
            printf "${GREEN}%-6s${NC} %-15s %-14s %s\n" "[$((i+1))]" "$tag" "$image_id" "$size"
        done
        
        echo -e "\n${YELLOW}Select a tag to start a container:${NC}"
        echo -e "q) Back"
        
        read -p "Your choice: " choice
        
        # Check if canceled
        if [[ "$choice" =~ ^[qQ]$ ]]; then
            return
        fi
        
        # Check if input is a valid number
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "$tag_count" ] && [ "$choice" -gt 0 ]; then
            local selected_tag="${tags[$choice-1]}"
            local full_image="$repo:$selected_tag"
            
            # Determine shell command based on image
            local shell_cmd="/bin/bash"
            if [[ "$repo" == *"alpine"* ]]; then
                shell_cmd="/bin/sh"
            fi
            
            # Start container with the selected image
            echo -e "${GREEN}Starting container with: $full_image${NC}"
            
            # Extract OS name from repository
            local os_name=$(basename "$repo")
            start_container "$full_image" "${os_name}-${selected_tag}-container" "$shell_cmd" "-it" "$repo $selected_tag"
            
            # After container exits, return to menu
            continue
        else
            echo -e "${RED}Invalid selection!${NC}"
            sleep 1
        fi
    done
}

# Network Management Menu
network_management_menu() {
    while true; do
        show_header
        echo -e "\n${GREEN}Docker Network Management:${NC}"
        echo "1) List Networks"
        echo "2) Create New Network"
        echo "3) Inspect Network"
        echo "4) Connect Container to Network"
        echo "5) Disconnect Container from Network"
        echo "6) Delete Network"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        case $choice in
            1) list_networks ;;
            2) create_network ;;
            3) inspect_network ;;
            4) connect_container_to_network ;;
            5) disconnect_container_from_network ;;
            6) delete_network ;;
            [qQ]) return ;;
            *) echo -e "${RED}Invalid selection!${NC}" ;;
        esac
    done
}

# List networks
list_networks() {
    show_header
    echo -e "\n${GREEN}Docker Networks:${NC}"
    
    if ! docker network ls --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}"; then
        echo -e "${RED}Failed to list networks.${NC}"
    fi
    
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Create new network
create_network() {
    show_header
    echo -e "\n${GREEN}Create New Docker Network:${NC}"
    echo -e "${YELLOW}Please select the network driver:${NC}"
    
    echo "1) bridge (default, for standalone containers)"
    echo "2) host (use host's networking directly, no isolation)"
    echo "3) overlay (for swarm services across multiple Docker daemons)"
    echo "4) macvlan (assign MAC address to container, appears as physical device)"
    echo "5) none (disable networking)"
    echo "6) ipvlan (similar to macvlan but uses Layer 3 routing)"
    echo "q) Cancel"
    
    read -p "Your choice: " driver_choice
    
    local driver=""
    case $driver_choice in
        1) driver="bridge" ;;
        2) driver="host" ;;
        3) driver="overlay" ;;
        4) driver="macvlan" ;;
        5) driver="none" ;;
        6) driver="ipvlan" ;;
        [qQ]) return ;;
        *) 
            echo -e "${RED}Invalid selection!${NC}"
            sleep 2
            return
            ;;
    esac
    
    read -p "Enter network name: " net_name
    
    # Validate network name
    if [ -z "$net_name" ]; then
        echo -e "${RED}Network name cannot be empty.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    # Check if network already exists
    if docker network ls --format "{{.Name}}" | grep -q "^$net_name$"; then
        echo -e "${RED}A network with this name already exists.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    # Additional options based on driver
    local extra_opts=""
    
    if [ "$driver" == "bridge" ]; then
        read -p "Do you want to set a custom subnet? (y/N): " use_subnet
        if [[ "$use_subnet" =~ ^[yY]$ ]]; then
            read -p "Enter subnet CIDR (e.g., 172.20.0.0/16): " subnet
            if [ ! -z "$subnet" ]; then
                extra_opts="--subnet=$subnet"
                
                read -p "Enter gateway IP (or leave empty for auto): " gateway
                if [ ! -z "$gateway" ]; then
                    extra_opts="$extra_opts --gateway=$gateway"
                fi
                
                read -p "Enter IP range (e.g., 172.20.10.0/24) (or leave empty): " ip_range
                if [ ! -z "$ip_range" ]; then
                    extra_opts="$extra_opts --ip-range=$ip_range"
                fi
            fi
        fi
        
        read -p "Enable internal network (no external access)? (y/N): " internal
        if [[ "$internal" =~ ^[yY]$ ]]; then
            extra_opts="$extra_opts --internal"
        fi
    elif [ "$driver" == "macvlan" ] || [ "$driver" == "ipvlan" ]; then
        echo -e "${YELLOW}For ${driver} networks, you need to specify the parent interface.${NC}"
        echo -e "${CYAN}Available interfaces on this host:${NC}"
        ip -o link show | grep -v "lo" | awk -F': ' '{print $2}'
        
        read -p "Enter parent interface: " parent
        if [ ! -z "$parent" ]; then
            extra_opts="--parent=$parent"
            
            read -p "Enter subnet CIDR (e.g., 192.168.1.0/24): " subnet
            if [ ! -z "$subnet" ]; then
                extra_opts="$extra_opts --subnet=$subnet"
                
                read -p "Enter gateway IP (usually your router, e.g., 192.168.1.1): " gateway
                if [ ! -z "$gateway" ]; then
                    extra_opts="$extra_opts --gateway=$gateway"
                fi
            fi
        else
            echo -e "${RED}Parent interface is required for ${driver} networks.${NC}"
            echo -e "${YELLOW}Press ENTER to continue...${NC}"
            read
            return
        fi
    fi
    
    # Create the network
    echo -e "${YELLOW}Creating network with the following settings:${NC}"
    echo -e "  Name: ${GREEN}$net_name${NC}"
    echo -e "  Driver: ${GREEN}$driver${NC}"
    if [ ! -z "$extra_opts" ]; then
        echo -e "  Additional options: ${GREEN}$extra_opts${NC}"
    fi
    
    read -p "Proceed? (Y/n): " confirm
    if [[ ! "$confirm" =~ ^[nN]$ ]]; then
        if docker network create --driver=$driver $extra_opts "$net_name"; then
            echo -e "${GREEN}Network $net_name created successfully!${NC}"
        else
            echo -e "${RED}Failed to create network.${NC}"
        fi
    else
        echo -e "${YELLOW}Network creation cancelled.${NC}"
    fi
    
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Inspect network
inspect_network() {
    show_header
    echo -e "\n${GREEN}Inspect Docker Network:${NC}"
    
    # Get list of networks
    local networks=()
    local net_count=0
    
    echo -e "${CYAN}Available networks:${NC}"
    echo -e "${CYAN}ID          NAME                  DRIVER     SCOPE${NC}"
    
    while IFS= read -r line; do
        ((net_count++))
        networks+=("$line")
        
        # Parse network information
        local net_id=$(echo "$line" | awk '{print $1}')
        local net_name=$(echo "$line" | awk '{print $2}')
        local net_driver=$(echo "$line" | awk '{print $3}')
        local net_scope=$(echo "$line" | awk '{print $4}')
        
        # Print formatted output
        printf "${GREEN}%-3s${NC} %-12s %-20s %-10s %-10s\n" "[$net_count]" "$net_id" "$net_name" "$net_driver" "$net_scope"
    done < <(docker network ls --format "{{.ID}} {{.Name}} {{.Driver}} {{.Scope}}" | sort)
    
    if [ $net_count -eq 0 ]; then
        echo -e "${RED}No networks found!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    echo -e "\n${YELLOW}Enter the row number, network ID, or name to inspect:${NC}"
    echo -e "q) Cancel"
    read network_input
    
    if [[ "$network_input" =~ ^[qQ]$ ]]; then
        return
    fi
    
    local network_id=""
    
    # Check if input is a row number
    if [[ "$network_input" =~ ^[0-9]+$ ]] && [ "$network_input" -le "$net_count" ] && [ "$network_input" -gt 0 ]; then
        network_id=$(echo "${networks[$network_input-1]}" | awk '{print $2}')
    else
        # Assume direct ID or name input
        network_id=$network_input
    fi
    
    # Check if network exists
    if ! docker network inspect "$network_id" > /dev/null 2>&1; then
        echo -e "${RED}Network not found: $network_id${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    # Display network information
    echo -e "\n${GREEN}Network details:${NC}"
    
    # Use a pager for better readability
    docker network inspect "$network_id" | less
}

# Connect container to network
connect_container_to_network() {
    show_header
    echo -e "\n${GREEN}Connect Container to Network:${NC}"
    
    # List containers
    local containers=()
    local container_count=0
    
    echo -e "${CYAN}Available containers:${NC}"
    echo -e "${CYAN}ID          NAME                  STATUS              NETWORKS${NC}"
    
    while IFS= read -r line; do
        ((container_count++))
        containers+=("$line")
        
        # Parse container information
        local container_id=$(echo "$line" | awk '{print $1}')
        local container_name=$(echo "$line" | awk '{print $2}')
        local container_status=$(echo "$line" | awk '{print $3}')
        local container_networks=$(echo "$line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i}')
        
        # Print formatted output
        printf "${GREEN}%-3s${NC} %-12s %-20s %-20s %s\n" "[$container_count]" "$container_id" "$container_name" "$container_status" "$container_networks"
    done < <(docker ps -a --format "{{.ID}} {{.Names}} {{.Status}} {{.Networks}}" | sort)
    
    if [ $container_count -eq 0 ]; then
        echo -e "${RED}No containers found!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    echo -e "\n${YELLOW}Enter the row number, container ID, or name to connect:${NC}"
    echo -e "q) Cancel"
    read container_input
    
    if [[ "$container_input" =~ ^[qQ]$ ]]; then
        return
    fi
    
    local container_id=""
    
    # Check if input is a row number
    if [[ "$container_input" =~ ^[0-9]+$ ]] && [ "$container_input" -le "$container_count" ] && [ "$container_input" -gt 0 ]; then
        container_id=$(echo "${containers[$container_input-1]}" | awk '{print $1}')
    else
        # Assume direct ID or name input
        container_id=$container_input
    fi
    
    # Check if container exists
    if ! docker ps -a --format '{{.ID}} {{.Names}}' | grep -q "$container_id"; then
        echo -e "${RED}Container not found: $container_id${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    # List networks
    local networks=()
    local net_count=0
    
    echo -e "\n${CYAN}Available networks:${NC}"
    echo -e "${CYAN}ID          NAME                  DRIVER     SCOPE${NC}"
    
    while IFS= read -r line; do
        ((net_count++))
        networks+=("$line")
        
        # Parse network information
        local net_id=$(echo "$line" | awk '{print $1}')
        local net_name=$(echo "$line" | awk '{print $2}')
        local net_driver=$(echo "$line" | awk '{print $3}')
        local net_scope=$(echo "$line" | awk '{print $4}')
        
        # Print formatted output
        printf "${GREEN}%-3s${NC} %-12s %-20s %-10s %-10s\n" "[$net_count]" "$net_id" "$net_name" "$net_driver" "$net_scope"
    done < <(docker network ls --format "{{.ID}} {{.Name}} {{.Driver}} {{.Scope}}" | sort)
    
    if [ $net_count -eq 0 ]; then
        echo -e "${RED}No networks found!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    echo -e "\n${YELLOW}Enter the row number, network ID, or name to connect to:${NC}"
    echo -e "q) Cancel"
    read network_input
    
    if [[ "$network_input" =~ ^[qQ]$ ]]; then
        return
    fi
    
    local network_id=""
    
    # Check if input is a row number
    if [[ "$network_input" =~ ^[0-9]+$ ]] && [ "$network_input" -le "$net_count" ] && [ "$network_input" -gt 0 ]; then
        network_id=$(echo "${networks[$network_input-1]}" | awk '{print $2}')
    else
        # Assume direct ID or name input
        network_id=$network_input
    fi
    
    # Check if network exists
    if ! docker network ls --format '{{.ID}} {{.Name}}' | grep -q "$network_id"; then
        echo -e "${RED}Network not found: $network_id${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    # Connect container to network
    if docker network connect "$network_id" "$container_id"; then
        echo -e "${GREEN}Successfully connected container to network!${NC}"
    else
        echo -e "${RED}Failed to connect container to network.${NC}"
    fi
    
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Disconnect container from network
disconnect_container_from_network() {
    show_header
    echo -e "\n${GREEN}Disconnect Container from Network:${NC}"
    
    # List container-network pairs
    local container_networks=()
    local pair_count=0
    
    echo -e "${CYAN}Container-Network connections:${NC}"
    echo -e "${CYAN}No.    CONTAINER              NETWORK${NC}"
    echo -e "${CYAN}----   ---------              -------${NC}"
    
    # This is a bit complex, so we'll use a temporary file to store results
    local temp_file=$(mktemp)
    
    # Get containers and their networks
    docker ps -a --format '{{.Names}}' | while read container; do
        docker inspect --format='{{range $net,$v := .NetworkSettings.Networks}}{{printf "%s %s\n" $.Name $net}}{{end}}' "$container" >> "$temp_file"
    done
    
    # Read and display the container-network pairs
    while IFS= read -r line; do
        ((pair_count++))
        container_networks+=("$line")
        
        # Parse information
        local container=$(echo "$line" | awk '{print $1}')
        local network=$(echo "$line" | awk '{print $2}')
        
        # Print formatted output
        printf "${GREEN}%-6s${NC} %-22s %-22s\n" "[$pair_count]" "$container" "$network"
    done < "$temp_file"
    
    rm "$temp_file"
    
    if [ $pair_count -eq 0 ]; then
        echo -e "${RED}No container-network connections found!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    echo -e "\n${YELLOW}Enter the number of the connection to disconnect:${NC}"
    echo -e "q) Cancel"
    read pair_input
    
    if [[ "$pair_input" =~ ^[qQ]$ ]]; then
        return
    fi
    
    # Check if input is a valid number
    if [[ "$pair_input" =~ ^[0-9]+$ ]] && [ "$pair_input" -le "$pair_count" ] && [ "$pair_input" -gt 0 ]; then
        local pair="${container_networks[$pair_input-1]}"
        local container=$(echo "$pair" | awk '{print $1}')
        local network=$(echo "$pair" | awk '{print $2}')
        
        # Ask for confirmation
        echo -e "${YELLOW}You are about to disconnect ${GREEN}$container${YELLOW} from network ${GREEN}$network${YELLOW}.${NC}"
        read -p "Proceed? (Y/n): " confirm
        
        if [[ ! "$confirm" =~ ^[nN]$ ]]; then
            # Disconnect container from network
            if docker network disconnect "$network" "$container"; then
                echo -e "${GREEN}Successfully disconnected container from network!${NC}"
            else
                echo -e "${RED}Failed to disconnect container from network.${NC}"
            fi
        else
            echo -e "${YELLOW}Operation cancelled.${NC}"
        fi
    else
        echo -e "${RED}Invalid selection!${NC}"
    fi
    
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Delete network
delete_network() {
    show_header
    echo -e "\n${GREEN}Delete Docker Network:${NC}"
    
    # Get list of networks
    local networks=()
    local net_count=0
    
    echo -e "${CYAN}Available networks:${NC}"
    echo -e "${CYAN}ID          NAME                  DRIVER     SCOPE${NC}"
    
    while IFS= read -r line; do
        ((net_count++))
        networks+=("$line")
        
        # Parse network information
        local net_id=$(echo "$line" | awk '{print $1}')
        local net_name=$(echo "$line" | awk '{print $2}')
        local net_driver=$(echo "$line" | awk '{print $3}')
        local net_scope=$(echo "$line" | awk '{print $4}')
        
        # Print formatted output
        printf "${GREEN}%-3s${NC} %-12s %-20s %-10s %-10s\n" "[$net_count]" "$net_id" "$net_name" "$net_driver" "$net_scope"
    done < <(docker network ls --format "{{.ID}} {{.Name}} {{.Driver}} {{.Scope}}" | grep -v "bridge\|host\|none" | sort)
    
    if [ $net_count -eq 0 ]; then
        echo -e "${RED}No user-defined networks found! Default networks (bridge, host, none) cannot be deleted.${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    echo -e "\n${RED}Enter the row numbers, network IDs, or names of the networks you want to delete:${NC}"
    echo -e "${YELLOW}For multiple selections, separate with commas (e.g., 1,3,5 or networkA,networkB)${NC}"
    echo -e "q) Cancel"
    read network_input
    
    if [[ "$network_input" =~ ^[qQ]$ ]]; then
        return
    fi
    
    # Split comma-separated input
    IFS=',' read -ra network_inputs <<< "$network_input"
    
    # Track success and failure
    local success_count=0
    local failed_count=0
    local in_use_count=0
    local not_found_count=0
    
    for input in "${network_inputs[@]}"; do
        local input_trimmed=$(echo "$input" | xargs)  # Trim whitespace
        
        if [ -z "$input_trimmed" ]; then
            continue
        fi
        
        local network_id=""
        
        # Check if input is a row number
        if [[ "$input_trimmed" =~ ^[0-9]+$ ]] && [ "$input_trimmed" -le "$net_count" ] && [ "$input_trimmed" -gt 0 ]; then
            network_id=$(echo "${networks[$input_trimmed-1]}" | awk '{print $2}')
            echo -e "${BLUE}Selected network: $network_id${NC}"
        else
            # Assume direct ID or name input
            network_id=$input_trimmed
        fi
        
        # Check if network exists
        if ! docker network ls --format '{{.ID}} {{.Name}}' | grep -q "$network_id"; then
            echo -e "${RED}Network not found: $network_id${NC}"
            ((not_found_count++))
            continue
        fi
        
        # Try to delete the network
        if docker network rm "$network_id" 2>/dev/null; then
            echo -e "${GREEN}Successfully deleted network: $network_id${NC}"
            ((success_count++))
        else
            # Check if network is in use
            if docker network inspect "$network_id" 2>/dev/null | grep -q "Containers"; then
                echo -e "${RED}Network $network_id is in use by containers and cannot be deleted.${NC}"
                ((in_use_count++))
            else
                echo -e "${RED}Failed to delete network: $network_id${NC}"
                ((failed_count++))
            fi
        fi
    done
    
    # Summary of deletion
    echo -e "\n${BLUE}Deletion Summary:${NC}"
    echo -e "${GREEN}$success_count network(s) deleted successfully.${NC}"
    
    if [ $failed_count -gt 0 ]; then
        echo -e "${RED}$failed_count network(s) failed to delete.${NC}"
    fi
    
    if [ $in_use_count -gt 0 ]; then
        echo -e "${RED}$in_use_count network(s) in use by containers.${NC}"
    fi
    
    if [ $not_found_count -gt 0 ]; then
        echo -e "${RED}$not_found_count network(s) not found.${NC}"
    fi
    
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
}

# System Monitoring & Maintenance Menu
system_monitoring_menu() {
    while true; do
        show_header
        echo -e "\n${GREEN}Docker System Monitoring & Maintenance:${NC}"
        echo "1) System Information & Status"
        echo "2) Container Resource Usage (Live)"
        echo "3) Disk Usage & Cleanup"
        echo "4) Prune Unused Resources (Images, Containers, Networks, Volumes)"
        echo "5) Docker Events Monitor (Live)"
        echo "6) Docker Logs Viewer"
        echo "7) Export Container Logs"
        echo "8) Health Check"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        case $choice in
            1) docker_system_info ;;
            2) docker_container_stats ;;
            3) docker_disk_usage ;;
            4) docker_prune_resources ;;
            5) docker_events_monitor ;;
            6) docker_logs_viewer ;;
            7) docker_export_logs ;;
            8) docker_health_check ;;
            [qQ]) return ;;
            *) echo -e "${RED}Invalid selection!${NC}" ;;
        esac
    done
}

# Docker System Information
docker_system_info() {
    show_header
    echo -e "\n${GREEN}Docker System Information:${NC}"
    
    echo -e "${YELLOW}Docker Version:${NC}"
    docker version
    
    echo -e "\n${YELLOW}Docker System Info:${NC}"
    docker system info
    
    echo -e "\n${YELLOW}Docker System Status:${NC}"
    docker system df -v
    
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Docker Container Resource Usage (Live)
docker_container_stats() {
    show_header
    echo -e "\n${GREEN}Container Resource Usage (Live):${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit the live view.${NC}"
    echo -e "${YELLOW}Starting in 3 seconds...${NC}"
    sleep 3
    
    docker stats --all
    
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Docker Disk Usage & Cleanup
docker_disk_usage() {
    while true; do
        show_header
        echo -e "\n${GREEN}Docker Disk Usage & Cleanup:${NC}"
        
        echo -e "${CYAN}Current Docker Disk Usage:${NC}"
        docker system df -v
        
        echo -e "\n${YELLOW}Cleanup Options:${NC}"
        echo "1) Remove all unused containers, networks, images, and volumes"
        echo "2) Remove dangling images (no tags)"
        echo "3) Remove all unused images (not just dangling)"
        echo "4) Remove stopped containers"
        echo "5) Remove unused volumes"
        echo "6) Remove unused networks"
        echo "7) Clean Docker Build Cache"
        echo "q) Back"
        
        read -p "Your choice: " choice
        
        case $choice in
            1)
                echo -e "${YELLOW}Removing all unused containers, networks, images, and volumes...${NC}"
                read -p "Are you sure? This will remove ALL unused resources (y/N): " confirm
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    docker system prune -a --volumes
                fi
                ;;
            2)
                echo -e "${YELLOW}Removing dangling images...${NC}"
                docker image prune
                ;;
            3)
                echo -e "${YELLOW}Removing all unused images...${NC}"
                read -p "Are you sure? This will remove ALL unused images (y/N): " confirm
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    docker image prune -a
                fi
                ;;
            4)
                echo -e "${YELLOW}Removing stopped containers...${NC}"
                docker container prune
                ;;
            5)
                echo -e "${YELLOW}Removing unused volumes...${NC}"
                read -p "Are you sure? This will remove ALL unused volumes and their data (y/N): " confirm
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    docker volume prune
                fi
                ;;
            6)
                echo -e "${YELLOW}Removing unused networks...${NC}"
                docker network prune
                ;;
            7)
                echo -e "${YELLOW}Cleaning Docker Build Cache...${NC}"
                read -p "Are you sure? This will clear all build cache (y/N): " confirm
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    docker builder prune -a
                fi
                ;;
            [qQ]) return ;;
            *)
                echo -e "${RED}Invalid selection!${NC}"
                sleep 1
                ;;
        esac
        
        echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
        read
    done
}

# Docker Prune Resources
docker_prune_resources() {
    show_header
    echo -e "\n${GREEN}Prune Unused Docker Resources:${NC}"
    
    echo -e "${YELLOW}Current Docker Disk Usage:${NC}"
    docker system df
    
    echo -e "\n${RED}WARNING: This will remove all unused containers, networks, images (not used by any container), and volumes.${NC}"
    echo -e "${RED}         This operation cannot be undone and may remove substantial amounts of data.${NC}"
    read -p "Do you want to continue? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}Removing all unused Docker resources...${NC}"
        docker system prune -a --volumes
        
        echo -e "\n${GREEN}Cleanup complete!${NC}"
    else
        echo -e "${YELLOW}Operation cancelled.${NC}"
    fi
    
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Docker Events Monitor
docker_events_monitor() {
    show_header
    echo -e "\n${GREEN}Docker Events Monitor (Live):${NC}"
    echo -e "${YELLOW}This will show Docker events in real-time.${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit the live view.${NC}"
    echo -e "${YELLOW}Starting in 3 seconds...${NC}"
    sleep 3
    
    # Run docker events
    docker events --format 'Time: {{.Time}} | Type: {{.Type}} | Action: {{.Action}} | {{.Actor.Attributes.name}}'
    
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Docker Logs Viewer
docker_logs_viewer() {
    show_header
    echo -e "\n${GREEN}Docker Logs Viewer:${NC}"
    
    # List containers
    local containers=()
    local container_count=0
    
    echo -e "${CYAN}Available containers:${NC}"
    echo -e "${CYAN}ID          NAME                  STATUS              CREATED${NC}"
    
    while IFS= read -r line; do
        ((container_count++))
        containers+=("$line")
        
        # Parse container information
        local container_id=$(echo "$line" | awk '{print $1}')
        local container_name=$(echo "$line" | awk '{print $2}')
        local container_status=$(echo "$line" | awk '{print $3}')
        local container_created=$(echo "$line" | awk '{print $4, $5, $6}')
        
        # Print formatted output
        printf "${GREEN}%-3s${NC} %-12s %-20s %-20s %s\n" "[$container_count]" "$container_id" "$container_name" "$container_status" "$container_created"
    done < <(docker ps -a --format "{{.ID}} {{.Names}} {{.Status}} {{.CreatedAt}}" | sort)
    
    if [ $container_count -eq 0 ]; then
        echo -e "${RED}No containers found!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    echo -e "\n${YELLOW}Enter the row number, container ID, or name to view logs:${NC}"
    echo -e "q) Cancel"
    read container_input
    
    if [[ "$container_input" =~ ^[qQ]$ ]]; then
        return
    fi
    
    local container_id=""
    
    # Check if input is a row number
    if [[ "$container_input" =~ ^[0-9]+$ ]] && [ "$container_input" -le "$container_count" ] && [ "$container_input" -gt 0 ]; then
        container_id=$(echo "${containers[$container_input-1]}" | awk '{print $1}')
    else
        # Assume direct ID or name input
        container_id=$container_input
    fi
    
    # Check if container exists
    if ! docker ps -a --format '{{.ID}} {{.Names}}' | grep -q "$container_id"; then
        echo -e "${RED}Container not found: $container_id${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    # Ask for log options
    echo -e "\n${YELLOW}Log Options:${NC}"
    echo "1) View last 100 log lines"
    echo "2) View logs with timestamps"
    echo "3) Follow logs (live view)"
    echo "4) View all logs"
    echo "5) Custom log options"
    echo "q) Cancel"
    
    read -p "Your choice: " log_option
    
    if [[ "$log_option" =~ ^[qQ]$ ]]; then
        return
    fi
    
    local log_cmd=""
    
    case $log_option in
        1) log_cmd="docker logs --tail=100 $container_id" ;;
        2) log_cmd="docker logs --timestamps $container_id" ;;
        3) 
            echo -e "${YELLOW}Following logs... Press Ctrl+C to stop.${NC}"
            sleep 2
            log_cmd="docker logs --follow $container_id"
            ;;
        4) log_cmd="docker logs $container_id" ;;
        5)
            echo -e "\n${YELLOW}Custom log options:${NC}"
            read -p "Enter number of lines to show (blank for all): " tail_lines
            read -p "Include timestamps? (y/N): " timestamps
            read -p "Follow logs? (y/N): " follow_logs
            
            log_cmd="docker logs"
            
            if [ ! -z "$tail_lines" ]; then
                log_cmd="$log_cmd --tail=$tail_lines"
            fi
            
            if [[ "$timestamps" =~ ^[yY]$ ]]; then
                log_cmd="$log_cmd --timestamps"
            fi
            
            if [[ "$follow_logs" =~ ^[yY]$ ]]; then
                echo -e "${YELLOW}Following logs... Press Ctrl+C to stop.${NC}"
                sleep 2
                log_cmd="$log_cmd --follow"
            fi
            
            log_cmd="$log_cmd $container_id"
            ;;
        *) 
            echo -e "${RED}Invalid selection!${NC}"
            sleep 1
            return
            ;;
    esac
    
    # View logs
    echo -e "\n${GREEN}Viewing logs for container: $container_id${NC}"
    eval "$log_cmd"
    
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Docker Export Logs
docker_export_logs() {
    show_header
    echo -e "\n${GREEN}Export Container Logs:${NC}"
    
    # List containers
    local containers=()
    local container_count=0
    
    echo -e "${CYAN}Available containers:${NC}"
    echo -e "${CYAN}ID          NAME                  STATUS              CREATED${NC}"
    
    while IFS= read -r line; do
        ((container_count++))
        containers+=("$line")
        
        # Parse container information
        local container_id=$(echo "$line" | awk '{print $1}')
        local container_name=$(echo "$line" | awk '{print $2}')
        local container_status=$(echo "$line" | awk '{print $3}')
        local container_created=$(echo "$line" | awk '{print $4, $5, $6}')
        
        # Print formatted output
        printf "${GREEN}%-3s${NC} %-12s %-20s %-20s %s\n" "[$container_count]" "$container_id" "$container_name" "$container_status" "$container_created"
    done < <(docker ps -a --format "{{.ID}} {{.Names}} {{.Status}} {{.CreatedAt}}" | sort)
    
    if [ $container_count -eq 0 ]; then
        echo -e "${RED}No containers found!${NC}"
        echo -e "${YELLOW}Press ENTER to continue...${NC}"
        read
        return
    fi
    
    echo -e "\n${YELLOW}Enter the row number, container ID, or name to export logs:${NC}"
    echo -e "q) Cancel"
    read container_input
    
    if [[ "$container_input" =~ ^[qQ]$ ]]; then
        return
    fi
    
    local container_id=""
    local container_name=""
    
    # Check if input is a row number
    if [[ "$container_input" =~ ^[0-9]+$ ]] && [ "$container_input" -le "$container_count" ] && [ "$container_input" -gt 0 ]; then
        local container_line="${containers[$container_input-1]}"
        container_id=$(echo "$container_line" | awk '{print $1}')
        container_name=$(echo "$container_line" | awk '{print $2}')
    else
        # Assume direct ID or name input
        container_id=$container_input
        
        # Try to get name if ID was provided
        if docker ps -a --format '{{.ID}} {{.Names}}' | grep -q "^$container_id"; then
            container_name=$(docker ps -a --format '{{.Names}}' --filter "id=$container_id")
        else
            # Try to get ID if name was provided
            if docker ps -a --format '{{.Names}}' | grep -q "^$container_id$"; then
                container_name=$container_id
                container_id=$(docker ps -a --format '{{.ID}}' --filter "name=$container_id")
            else
                echo -e "${RED}Container not found: $container_id${NC}"
                echo -e "${YELLOW}Press ENTER to continue...${NC}"
                read
                return
            fi
        fi
    fi
    
    # Default log filename
    local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local filename="${container_name:-container}_logs_$timestamp.txt"
    
    # Ask for file name
    echo -e "\n${YELLOW}Exporting logs for container: $container_name${NC}"
    echo -e "${YELLOW}Default filename: $filename${NC}"
    read -p "Enter a different filename (or press ENTER to use default): " custom_filename
    
    if [ ! -z "$custom_filename" ]; then
        filename=$custom_filename
    fi
    
    # Include timestamps?
    read -p "Include timestamps? (Y/n): " include_timestamps
    local timestamp_opt=""
    if [[ ! "$include_timestamps" =~ ^[nN]$ ]]; then
        timestamp_opt="--timestamps"
    fi
    
    # Export logs
    echo -e "${YELLOW}Exporting logs to $filename...${NC}"
    if docker logs $timestamp_opt $container_id > "$filename" 2>&1; then
        echo -e "${GREEN}Logs successfully exported to: $filename${NC}"
        echo -e "${YELLOW}File size: $(du -h "$filename" | cut -f1)${NC}"
    else
        echo -e "${RED}Failed to export logs.${NC}"
    fi
    
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Docker Health Check
docker_health_check() {
    show_header
    echo -e "\n${GREEN}Docker Health Check:${NC}"
    
    echo -e "${YELLOW}System Overview:${NC}"
    echo -e "${CYAN}Docker Version:${NC} $(docker --version)"
    echo -e "${CYAN}Total Containers:${NC} $(docker ps -a -q | wc -l)"
    echo -e "${CYAN}Running Containers:${NC} $(docker ps -q | wc -l)"
    echo -e "${CYAN}Total Images:${NC} $(docker images -q | wc -l)"
    echo -e "${CYAN}Total Volumes:${NC} $(docker volume ls -q | wc -l)"
    echo -e "${CYAN}Total Networks:${NC} $(docker network ls -q | wc -l)"
    
    # Docker daemon status
    echo -e "\n${YELLOW}Docker Daemon Status:${NC}"
    if systemctl is-active docker &>/dev/null; then
        echo -e "${GREEN}Docker daemon is active and running.${NC}"
    else
        echo -e "${RED}Docker daemon is not running!${NC}"
    fi
    
    # Disk space warnings
    echo -e "\n${YELLOW}Disk Space Status:${NC}"
    local docker_disk_usage=$(docker system df -v | grep "Total" | head -n 1 | awk '{print $4}')
    
    if [ ! -z "$docker_disk_usage" ]; then
        local docker_disk_percent=$(echo $docker_disk_usage | sed 's/%//')
        
        if [ "$docker_disk_percent" -gt 85 ]; then
            echo -e "${RED}WARNING: Docker is using $docker_disk_usage of disk space!${NC}"
            echo -e "${RED}Consider running disk cleanup to free up space.${NC}"
        elif [ "$docker_disk_percent" -gt 70 ]; then
            echo -e "${YELLOW}NOTICE: Docker is using $docker_disk_usage of disk space.${NC}"
            echo -e "${YELLOW}You might want to clean up unused resources soon.${NC}"
        else
            echo -e "${GREEN}Disk usage is at $docker_disk_usage - OK${NC}"
        fi
    fi
    
    # Container health status
    echo -e "\n${YELLOW}Container Health Status:${NC}"
    echo -e "${CYAN}ID          NAME                  STATUS              HEALTH${NC}"
    
    # Get container health info
    docker ps -a --format "{{.ID}} {{.Names}} {{.Status}} {{.Health}}" | while read -r line; do
        local id=$(echo "$line" | awk '{print $1}')
        local name=$(echo "$line" | awk '{print $2}')
        local status=$(echo "$line" | awk '{print $3}')
        local health=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ \t]*//')
        
        # Color-code the health status
        if [[ "$health" == *"healthy"* ]]; then
            health="${GREEN}$health${NC}"
        elif [[ "$health" == *"unhealthy"* ]]; then
            health="${RED}$health${NC}"
        elif [[ "$health" == *"starting"* ]]; then
            health="${YELLOW}$health${NC}"
        elif [[ "$status" == *"Up"* ]]; then
            health="${CYAN}No health check defined${NC}"
        else
            health="${YELLOW}Not running${NC}"
        fi
        
        printf "%-12s %-20s %-20s %s\n" "$id" "$name" "$status" "$health"
    done
    
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read
}

# Check Docker and start main menu
check_docker
main_menu 