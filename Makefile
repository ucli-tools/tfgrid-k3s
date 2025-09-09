.PHONY: all infrastructure platform app clean wireguard dns ping help permissions connect nextcloud nextcloud-backup nextcloud-restore nextcloud-status clean-nextcloud

# Default target
all: infrastructure platform nextcloud

# Deploy infrastructure only (ThreeFold Grid VMs)
infrastructure:
	cd scripts && bash infrastructure.sh

# Deploy platform only (K3s cluster)
platform:
	cd scripts && bash platform.sh

# Deploy applications
app:
	cd scripts && bash app.sh

# Connect to management node
connect:
	cd scripts && bash connect-management.sh

# Connect to management node and see K9s TUI
k9s:
	cd scripts && bash k9s.sh

# Clean up Terraform/OpenTofu resources
clean:
	cd scripts && bash cleantf.sh

# Set up wireguard connection
wireguard:
	cd scripts && bash wg.sh

# Configure DNS settings
dns:
	cd scripts && bash configure-dns.sh

# Ping nodes to check connectivity
ping:
	cd scripts && bash ping.sh

# Check cluster permissions
permissions:
	@echo "Checking cluster permissions..."
	@chmod +x scripts/cluster_permissions.sh
	@KUBECONFIG=$(CURDIR)/k3s.yaml ./scripts/cluster_permissions.sh

# Nextcloud application targets
nextcloud:
	cd apps/nextcloud && bash deploy.sh

nextcloud-backup:
	cd apps/nextcloud && bash backup.sh backup

nextcloud-restore:
	@echo "Usage: make nextcloud-restore BACKUP_NAME=<backup-name>"
	@cd apps/nextcloud && bash backup.sh restore $(BACKUP_NAME)

nextcloud-status:
	cd apps/nextcloud && bash deploy.sh status

clean-nextcloud:
	cd apps/nextcloud && bash deploy.sh clean

# Help information
help:
	@echo "TFGrid K3s Makefile Targets:"
	@echo "  make                - Run the complete deployment (infrastructure + platform + nextcloud)"
	@echo "  make all            - Same as 'make'"
	@echo "  make infrastructure - Deploy only ThreeFold Grid infrastructure"
	@echo "  make platform       - Deploy only K3s platform on existing infrastructure"
	@echo "  make app            - Deploy applications on existing platform"
	@echo "  make clean          - Clean up and destroy Terraform/OpenTofu resources"
	@echo "  make wireguard      - Set up the WireGuard connection"
	@echo "  make dns            - Configure DNS settings"
	@echo "  make ping           - Ping nodes to check connectivity"
	@echo "  make connect        - SSH into the management node"
	@echo "  make permissions    - Check cluster permissions"
	@echo "  make k9s            - Connect to management node and see K9s TUI"
	@echo ""
	@echo "Nextcloud Application Targets:"
	@echo "  make nextcloud         - Deploy Nextcloud AIO"
	@echo "  make nextcloud-backup  - Create Nextcloud backup"
	@echo "  make nextcloud-restore - Restore Nextcloud from backup (use BACKUP_NAME=...)"
	@echo "  make nextcloud-status  - Check Nextcloud deployment status"
	@echo "  make clean-nextcloud   - Remove Nextcloud deployment"
	@echo ""
	@echo "Examples:"
	@echo "  make app nextcloud     - Deploy Nextcloud via app dispatcher"
	@echo "  make nextcloud         - Deploy Nextcloud directly"
	@echo "  make nextcloud-restore BACKUP_NAME=nextcloud-backup-20231201"
