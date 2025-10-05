set -e;
DOCKER_VERSION=27.0.3
OS_TYPE=$(sudo grep -w "ID" /etc/os-release | sudo cut -d "=" -f 2 | sudo tr -d '"')
SYS_ARCH=$(sudo uname -m)
CURRENT_USER=$USER

echo "Installing requirements for: OS: $OS_TYPE"

# Check if the OS is manjaro, if so, change it to arch
if [ "$OS_TYPE" = "manjaro" ] || [ "$OS_TYPE" = "manjaro-arm" ]; then
	OS_TYPE="arch"
fi

# Check if the OS is Asahi Linux, if so, change it to fedora
if [ "$OS_TYPE" = "fedora-asahi-remix" ]; then
	OS_TYPE="fedora"
fi

# Check if the OS is popOS, if so, change it to ubuntu
if [ "$OS_TYPE" = "pop" ]; then
	OS_TYPE="ubuntu"
fi

# Check if the OS is linuxmint, if so, change it to ubuntu
if [ "$OS_TYPE" = "linuxmint" ]; then
	OS_TYPE="ubuntu"
fi

#Check if the OS is zorin, if so, change it to ubuntu
if [ "$OS_TYPE" = "zorin" ]; then
	OS_TYPE="ubuntu"
fi

if [ "$OS_TYPE" = "arch" ] || [ "$OS_TYPE" = "archarm" ]; then
	OS_VERSION="rolling"
else
	OS_VERSION=$(sudo grep -w "VERSION_ID" /etc/os-release | sudo cut -d "=" -f 2 | sudo tr -d '"')
fi

if [ "$OS_TYPE" = 'amzn' ]; then
    sudo dnf install -y findutils >/dev/null
fi

case "$OS_TYPE" in
arch | ubuntu | debian | raspbian | centos | fedora | rhel | ol | rocky | sles | opensuse-leap | opensuse-tumbleweed | almalinux | opencloudos | amzn | alpine) ;;
*)
	echo "This script only supports Debian, Redhat, Arch Linux, Alpine Linux, or SLES based operating systems for now."
	exit
	;;
esac

echo -e "---------------------------------------------"
echo "| CPU Architecture  | $SYS_ARCH"
echo "| Operating System  | $OS_TYPE $OS_VERSION"
echo "| Docker            | $DOCKER_VERSION"
echo -e "---------------------------------------------
"
echo -e "1. Installing required packages (curl, wget, git, jq, openssl). "

command_exists() {
	command -v "$@" > /dev/null 2>&1
}



	case "$OS_TYPE" in
	arch)
		sudo pacman -Sy --noconfirm --needed curl wget git git-lfs jq openssl >/dev/null || true
		;;
	alpine)
		sudo sed -i '/^#.*/community/s/^#//' /etc/apk/repositories
		sudo apk update >/dev/null
		sudo add curl wget git git-lfs jq openssl sudo unzip tar >/dev/null
		;;
	ubuntu | debian | raspbian)
		DEBIAN_FRONTEND=noninteractive sudo apt-get update -y >/dev/null
		DEBIAN_FRONTEND=noninteractive sudo apt-get install -y unzip curl wget git git-lfs jq openssl >/dev/null
		;;
	centos | fedora | rhel | ol | rocky | almalinux | opencloudos | amzn)
		if [ "$OS_TYPE" = "amzn" ]; then
			sudo dnf install -y wget git git-lfs jq openssl >/dev/null
		else
			if ! sudo command -v dnf >/dev/null; then
				sudo yum install -y dnf >/dev/null
			fi
			if ! sudo command -v curl >/dev/null; then
				sudo dnf install -y curl >/dev/null
			fi
			sudo dnf install -y wget git git-lfs jq openssl unzip >/dev/null
		fi
		;;
	sles | opensuse-leap | opensuse-tumbleweed)
		sudo zypper refresh >/dev/null
		sudo zypper install -y curl wget git git-lfs jq openssl >/dev/null
		;;
	*)
		echo "This script only supports Debian, Redhat, Arch Linux, or SLES based operating systems for now."
		exit
		;;
	esac


echo -e "2. Validating ports. "

	# check if something is running on port 80
	if sudo ss -tulnp | sudo grep ':80 ' >/dev/null; then
		echo "Something is already running on port 80" >&2
	fi

	# check if something is running on port 443
	if sudo ss -tulnp | sudo grep ':443 ' >/dev/null; then
		echo "Something is already running on port 443" >&2
	fi




echo -e "3. Installing RClone. "

    if command_exists rclone; then
		echo "RClone already installed ✅"
	else
		sudo curl https://rclone.org/install.sh | sudo bash
		RCLONE_VERSION=$(sudo rclone --version | sudo head -n 1 | sudo awk '{print $2}' | sudo sed 's/^v//')
		echo "RClone version $RCLONE_VERSION installed ✅"
	fi


echo -e "4. Installing Docker. "


# Detect if docker is installed via snap
if [ -x "$(command -v snap)" ]; then
    SNAP_DOCKER_INSTALLED=$(sudo snap list docker >/dev/null 2>&1 && echo "true" || echo "false")
    if [ "$SNAP_DOCKER_INSTALLED" = "true" ]; then
        echo " - Docker is installed via snap."
        echo "   Please note that Dokploy does not support Docker installed via snap."
        echo "   Please remove Docker with snap (snap remove docker) and reexecute this script."
        exit 1
    fi
fi

echo -e "3. Check Docker Installation. "
if ! [ -x "$(command -v docker)" ]; then
    echo " - Docker is not installed. Installing Docker. It may take a while."
    case "$OS_TYPE" in
        "almalinux")
            sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null 2>&1
            if ! [ -x "$(command -v docker)" ]; then
                echo " - Docker could not be installed automatically. Please visit https://docs.docker.com/engine/install/ and install Docker manually to continue."
                exit 1
            fi
            sudo systemctl start docker >/dev/null 2>&1
            sudo systemctl enable docker >/dev/null 2>&1
            ;;
	"opencloudos")
            # Special handling for OpenCloud OS
            echo " - Installing Docker for OpenCloud OS..."
            sudo dnf install -y docker >/dev/null 2>&1
            if ! [ -x "$(command -v docker)" ]; then
                echo " - Docker could not be installed automatically. Please visit https://docs.docker.com/engine/install/ and install Docker manually to continue."
                exit 1
            fi
            
            # Remove --live-restore parameter from Docker configuration if it exists
            if [ -f "/etc/sysconfig/docker" ]; then
                echo " - Removing --live-restore parameter from Docker configuration..."
                sudo sed -i 's/--live-restore[^[:space:]]*//' /etc/sysconfig/docker >/dev/null 2>&1
                sudo sed -i 's/--live-restore//' /etc/sysconfig/docker >/dev/null 2>&1
                # Clean up any double spaces that might be left
                sudo sed -i 's/  */ /g' /etc/sysconfig/docker >/dev/null 2>&1
            fi
            
            sudo systemctl enable docker >/dev/null 2>&1
            sudo systemctl start docker >/dev/null 2>&1
            echo " - Docker configured for OpenCloud OS"
            ;;
        "alpine")
            sudo apk add docker docker-cli-compose >/dev/null 2>&1
            sudo rc-update add docker default >/dev/null 2>&1
            sudo service docker start >/dev/null 2>&1
            if ! [ -x "$(command -v docker)" ]; then
                echo " - Failed to install Docker with apk. Try to install it manually."
                echo "   Please visit https://wiki.alpinelinux.org/wiki/Docker for more information."
                exit 1
            fi
            ;;
        "arch")
            sudo pacman -Sy docker docker-compose --noconfirm >/dev/null 2>&1
            sudo systemctl enable docker.service >/dev/null 2>&1
            if ! [ -x "$(command -v docker)" ]; then
                echo " - Failed to install Docker with pacman. Try to install it manually."
                echo "   Please visit https://wiki.archlinux.org/title/docker for more information."
                exit 1
            fi
            ;;
        "amzn")
            sudo dnf install docker -y >/dev/null 2>&1
            DOCKER_CONFIG=/usr/local/lib/docker
            sudo mkdir -p $DOCKER_CONFIG/cli-plugins >/dev/null 2>&1
            sudo curl -sL https://github.com/docker/compose/releases/latest/download/docker-compose-$(sudo uname -s)-$(sudo uname -m) -o $DOCKER_CONFIG/cli-plugins/docker-compose >/dev/null 2>&1
            sudo chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose >/dev/null 2>&1
            sudo systemctl start docker >/dev/null 2>&1
            sudo systemctl enable docker >/dev/null 2>&1
            if ! [ -x "$(command -v docker)" ]; then
                echo " - Failed to install Docker with dnf. Try to install it manually."
                echo "   Please visit https://www.cyberciti.biz/faq/how-to-install-docker-on-amazon-linux-2/ for more information."
                exit 1
            fi
            ;;
        "fedora")
            if [ -x "$(sudo command -v dnf5)" ]; then
                # dnf5 is available
                sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo --overwrite >/dev/null 2>&1
            else
                # dnf5 is not available, use dnf
                sudo dnf config-manager --add-repo=https://download.docker.com/linux/fedora/docker-ce.repo >/dev/null 2>&1
            fi
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null 2>&1
            if ! [ -x "$(command -v docker)" ]; then
                echo " - Docker could not be installed automatically. Please visit https://docs.docker.com/engine/install/ and install Docker manually to continue."
                exit 1
            fi
            sudo systemctl start docker >/dev/null 2>&1
            sudo systemctl enable docker >/dev/null 2>&1
            ;;
        *)
            if [ "$OS_TYPE" = "ubuntu" ] && [ "$OS_VERSION" = "24.10" ]; then
                echo "Docker automated installation is not supported on Ubuntu 24.10 (non-LTS release)."
                    echo "Please install Docker manually."
                exit 1
            fi
            sudo curl -s https://releases.rancher.com/install-docker/$DOCKER_VERSION.sh | sudo sh 2>&1
            if ! [ -x "$(command -v docker)" ]; then
                sudo curl -s https://get.docker.com | sudo sh -s -- --version $DOCKER_VERSION 2>&1
                if ! [ -x "$(command -v docker)" ]; then
                    echo " - Docker installation failed."
                    echo "   Maybe your OS is not supported?"
                    echo " - Please visit https://docs.docker.com/engine/install/ and install Docker manually to continue."
                    exit 1
                fi
            fi
			if [ "$OS_TYPE" = "rocky" ]; then
				sudo systemctl start docker >/dev/null 2>&1
				sudo systemctl enable docker >/dev/null 2>&1
			fi

			if [ "$OS_TYPE" = "centos" ]; then
				sudo systemctl start docker >/dev/null 2>&1
				sudo systemctl enable docker >/dev/null 2>&1
			fi


    esac
    echo " - Docker installed successfully."
else
    echo " - Docker is installed."
fi


echo -e "5. Setting up Docker Swarm"

		# Check if the node is already part of a Docker Swarm
		if sudo docker info | sudo grep -q 'Swarm: active'; then
			echo "Already part of a Docker Swarm ✅"
		else
			# Get IP address
			get_ip() {
				local ip=""

				# Try IPv4 with multiple services
				# First attempt: ifconfig.io
				ip=$(sudo curl -4s --connect-timeout 5 https://ifconfig.io 2>/dev/null)

				# Second attempt: icanhazip.com
				if [ -z "$ip" ]; then
					ip=$(sudo curl -4s --connect-timeout 5 https://icanhazip.com 2>/dev/null)
				fi

				# Third attempt: ipecho.net
				if [ -z "$ip" ]; then
					ip=$(sudo curl -4s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null)
				fi

				# If no IPv4, try IPv6 with multiple services
				if [ -z "$ip" ]; then
					# Try IPv6 with ifconfig.io
					ip=$(sudo curl -6s --connect-timeout 5 https://ifconfig.io 2>/dev/null)

					# Try IPv6 with icanhazip.com
					if [ -z "$ip" ]; then
						ip=$(sudo curl -6s --connect-timeout 5 https://icanhazip.com 2>/dev/null)
					fi

					# Try IPv6 with ipecho.net
					if [ -z "$ip" ]; then
						ip=$(sudo curl -6s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null)
					fi
				fi

				if [ -z "$ip" ]; then
					echo "Error: Could not determine server IP address automatically (neither IPv4 nor IPv6)." >&2
					echo "Please set the ADVERTISE_ADDR environment variable manually." >&2
					echo "Example: export ADVERTISE_ADDR=<your-server-ip>" >&2
					exit 1
				fi

				echo "$ip"
			}
			advertise_addr=$(get_ip)
			echo "Advertise address: $advertise_addr"

			# Initialize Docker Swarm
			sudo docker swarm init --advertise-addr $advertise_addr
			echo "Swarm initialized ✅"
		fi
	

echo -e "6. Setting up Network"

	# Check if the dokploy-network already exists
	if sudo docker network ls | sudo grep -q 'dokploy-network'; then
		echo "Network dokploy-network already exists ✅"
	else
		# Create the dokploy-network if it doesn't exist
		if sudo docker network create --driver overlay --attachable dokploy-network; then
			echo "Network created ✅"
		else
			echo "Failed to create dokploy-network ❌" >&2
			exit 1
		fi
	fi


echo -e "7. Setting up Directories"

	# Check if the /etc/dokploy directory exists
	if [ -d /etc/dokploy ]; then
		echo "/etc/dokploy already exists ✅"
	else
		# Create the /etc/dokploy directory
		sudo mkdir -p /etc/dokploy
		sudo chmod 777 /etc/dokploy

		echo "Directory /etc/dokploy created ✅"
	fi


	sudo mkdir -p "/etc/dokploy" && sudo mkdir -p "/etc/dokploy/traefik" && sudo mkdir -p "/etc/dokploy/traefik/dynamic" && sudo mkdir -p "/etc/dokploy/logs" && sudo mkdir -p "/etc/dokploy/applications" && sudo mkdir -p "/etc/dokploy/compose" && sudo mkdir -p "/etc/dokploy/ssh" && sudo mkdir -p "/etc/dokploy/traefik/dynamic/certificates" && sudo mkdir -p "/etc/dokploy/monitoring" && sudo mkdir -p "/etc/dokploy/registry" && sudo mkdir -p "/etc/dokploy/schedules" && sudo mkdir -p "/etc/dokploy/volume-backups"
	sudo chmod 700 "/etc/dokploy/ssh"
	

echo -e "8. Setting up Traefik"

	if [ -f "/etc/dokploy/traefik/dynamic/acme.json" ]; then
		sudo chmod 600 "/etc/dokploy/traefik/dynamic/acme.json"
	fi
	if [ -f "/etc/dokploy/traefik/traefik.yml" ]; then
		echo "Traefik config already exists ✅"
	else
		echo "providers:
  swarm:
    exposedByDefault: false
    watch: true
  docker:
    exposedByDefault: false
    watch: true
    network: dokploy-network
  file:
    directory: /etc/dokploy/traefik/dynamic
    watch: true
entryPoints:
  web:
    address: ':80'
  websecure:
    address: ':443'
    http3:
      advertisedPort: 443
    http:
      tls:
        certResolver: letsencrypt
api:
  insecure: true
certificatesResolvers:
  letsencrypt:
    acme:
      email: test@localhost.com
      storage: /etc/dokploy/traefik/dynamic/acme.json
      httpChallenge:
        entryPoint: web" | sudo tee /etc/dokploy/traefik/traefik.yml > /dev/null
	fi
	

echo -e "9. Setting up Middlewares"

	if [ -f "/etc/dokploy/traefik/dynamic/middlewares.yml" ]; then
		echo "Middlewares config already exists ✅"
	else
		echo "http:
  middlewares:
    redirect-to-https:
      redirectScheme:
        scheme: https
        permanent: true" | sudo tee /etc/dokploy/traefik/dynamic/middlewares.yml > /dev/null
	fi
	

echo -e "10. Setting up Traefik Instance"

	    # Check if dokpyloy-traefik exists
		if sudo docker service inspect dokploy-traefik > /dev/null 2>&1; then
			echo "Migrating Traefik to Standalone..."
			sudo docker service rm dokploy-traefik
			sudo sleep 8
			echo "Traefik migrated to Standalone ✅"
		fi
			
		if sudo docker inspect dokploy-traefik > /dev/null 2>&1; then
			echo "Traefik already exists ✅"
		else
			# Create the dokploy-traefik container
			TRAEFIK_VERSION=3.1.2
			sudo docker run -d 				--name dokploy-traefik 				--network dokploy-network 				--restart unless-stopped 				-v /etc/dokploy/traefik/traefik.yml:/etc/traefik/traefik.yml 				-v /etc/dokploy/traefik/dynamic:/etc/dokploy/traefik/dynamic 				-v /var/run/docker.sock:/var/run/docker.sock 				-p 443:443 				-p 80:80 				-p 443:443/udp 				traefik:v$TRAEFIK_VERSION
			echo "Traefik version $TRAEFIK_VERSION installed ✅"
		fi
	

echo -e "11. Installing Nixpacks"

	if command_exists nixpacks; then
		echo "Nixpacks already installed ✅"
	else
	    export NIXPACKS_VERSION=1.29.1
        sudo bash -c "$(sudo curl -fsSL https://nixpacks.com/install.sh)"
		echo "Nixpacks version $NIXPACKS_VERSION installed ✅"
	fi


echo -e "12. Installing Buildpacks"

	SUFFIX=""
	if [ "$SYS_ARCH" = "aarch64" ] || [ "$SYS_ARCH" = "arm64" ]; then
		SUFFIX="-arm64"
	fi
	if command_exists pack; then
		echo "Buildpacks already installed ✅"
	else
		BUILDPACKS_VERSION=0.35.0
		sudo curl -sSL "https://github.com/buildpacks/pack/releases/download/v0.35.0/pack-v$BUILDPACKS_VERSION-linux$SUFFIX.tgz" | sudo tar -C /usr/local/bin/ --no-same-owner -xzv pack
		echo "Buildpacks version $BUILDPACKS_VERSION installed ✅"
	fi


echo -e "13. Installing Railpack"

	if command_exists railpack; then
		echo "Railpack already installed ✅"
	else
	    export RAILPACK_VERSION=0.0.37
		sudo bash -c "$(sudo curl -fsSL https://railpack.com/install.sh)"
		echo "Railpack version $RAILPACK_VERSION installed ✅"
	fi

				