```bash
#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
#
# Added IOMMU functionality as requested by user.

header_info() {
  clear
  cat <<'EOF'
    ____    ________    ____            __      ____            __        ____
   / __ \ |  / / ____/   / __ \____  _____/ /_    / __/___  _____/ /_____ _/ / /
  / /_/ / | / / __/     / /_/ / __ \/ ___/ __/    / // __ \/ ___/ __/ __ `/ / /
 / ____/| |/ / /___    / ____/ /_/ (__  ) /_    _/ // / / (__  ) /_/ /_/ / / /
/_/     |___/_____/   /_/     \____/____/\__/   /___/_/ /_/____/\__/\__,_/_/_/

EOF
}

RD=$(echo "\033[01;31m")
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

set -euo pipefail
shopt -s inherit_errexit nullglob

msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

start_routines() {
  header_info
  REBOOT_REQUIRED_FOR_IOMMU=false

  CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "SOURCES" --menu "The package manager will use the correct sources to update and install packages on your Proxmox VE server.\n \nCorrect Proxmox VE sources?" 14 58 2 \
    "yes" " " \
    "no" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  yes)
    msg_info "Correcting Proxmox VE Sources"
    cat <<EOF >/etc/apt/sources.list
deb http://deb.debian.org/debian bookworm main contrib
deb http://deb.debian.org/debian bookworm-updates main contrib
deb http://security.debian.org/debian-security bookworm-security main contrib
EOF
    echo 'APT::Get::Update::SourceListWarnings::NonFreeFirmware "false";' >/etc/apt/apt.conf.d/no-bookworm-firmware.conf
    msg_ok "Corrected Proxmox VE Sources"
    ;;
  no)
    msg_error "Selected no to Correcting Proxmox VE Sources"
    ;;
  esac

  CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "PVE-ENTERPRISE" --menu "The 'pve-enterprise' repository is only available to users who have purchased a Proxmox VE subscription.\n \nDisable 'pve-enterprise' repository?" 14 58 2 \
    "yes" " " \
    "no" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  yes)
    msg_info "Disabling 'pve-enterprise' repository"
    if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
      sed -i "s/^deb/#deb/g" /etc/apt/sources.list.d/pve-enterprise.list
    else
      echo "# deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise" >/etc/apt/sources.list.d/pve-enterprise.list
    fi
    msg_ok "Disabled 'pve-enterprise' repository"
    ;;
  no)
    msg_error "Selected no to Disabling 'pve-enterprise' repository"
    ;;
  esac

  CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "PVE-NO-SUBSCRIPTION" --menu "The 'pve-no-subscription' repository provides access to all of the open-source components of Proxmox VE.\n \nEnable 'pve-no-subscription' repository?" 14 58 2 \
    "yes" " " \
    "no" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  yes)
    msg_info "Enabling 'pve-no-subscription' repository"
    echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >/etc/apt/sources.list.d/pve-no-subscription.list
    msg_ok "Enabled 'pve-no-subscription' repository"
    ;;
  no)
    msg_error "Selected no to Enabling 'pve-no-subscription' repository"
    ;;
  esac

  CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "CEPH PACKAGE REPOSITORIES" --menu "The 'Ceph Package Repositories' provides access to both the 'no-subscription' and 'enterprise' repositories (initially disabled).\n \nCorrect 'ceph package sources?" 14 58 2 \
    "yes" " " \
    "no" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  yes)
    msg_info "Correcting 'ceph package repositories'"
    cat <<EOF >/etc/apt/sources.list.d/ceph.list
# deb https://enterprise.proxmox.com/debian/ceph-quincy bookworm enterprise
# deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription
# deb https://enterprise.proxmox.com/debian/ceph-reef bookworm enterprise
# deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription
EOF
    msg_ok "Corrected 'ceph package repositories'"
    ;;
  no)
    msg_error "Selected no to Correcting 'ceph package repositories'"
    ;;
  esac

  CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "PVETEST" --menu "The 'pvetest' repository can give advanced users access to new features and updates before they are officially released.\n \nAdd (Disabled) 'pvetest' repository?" 14 58 2 \
    "yes" " " \
    "no" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  yes)
    msg_info "Adding 'pvetest' repository and set disabled"
    echo "# deb http://download.proxmox.com/debian/pve bookworm pvetest" >/etc/apt/sources.list.d/pvetest.list
    msg_ok "Added 'pvetest' repository"
    ;;
  no)
    msg_error "Selected no to Adding 'pvetest' repository"
    ;;
  esac

  CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "SUBSCRIPTION NAG" --menu "This will disable the nag message reminding you to purchase a subscription every time you log in to the web interface.\n \nDisable subscription nag?" 14 58 2 \
    "yes" " " \
    "no" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  yes)
    whiptail --backtitle "Proxmox VE Helper Scripts" --msgbox --title "Support Subscriptions" "Supporting the software's development team is essential. Check their official website's Support Subscriptions for pricing. Without their dedicated work, we wouldn't have this exceptional software." 10 58
    msg_info "Disabling subscription nag"
    echo "DPkg::Post-Invoke { \"if [ -s /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ] && ! grep -q -F 'NoMoreNagging' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; then echo 'Removing subscription nag from UI...'; sed -i '/data\.status/{s/\!//;s/active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; fi\" };" >/etc/apt/apt.conf.d/no-nag-script
    apt --reinstall install proxmox-widget-toolkit &>/dev/null
    msg_ok "Disabled subscription nag (Delete browser cache)"
    ;;
  no)
    whiptail --backtitle "Proxmox VE Helper Scripts" --msgbox --title "Support Subscriptions" "Supporting the software's development team is essential. Check their official website's Support Subscriptions for pricing. Without their dedicated work, we wouldn't have this exceptional software." 10 58
    msg_error "Selected no to Disabling subscription nag"
    rm -f /etc/apt/apt.conf.d/no-nag-script 2>/dev/null
    ;;
  esac
  

  if ! systemctl is-active --quiet pve-ha-lrm; then
    CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "HIGH AVAILABILITY" --menu "Enable high availability?" 10 58 2 \
      "yes" " " \
      "no" " " 3>&2 2>&1 1>&3)
    case $CHOICE in
    yes)
      msg_info "Enabling high availability"
      systemctl enable -q --now pve-ha-lrm
      systemctl enable -q --now pve-ha-crm
      systemctl enable -q --now corosync
      msg_ok "Enabled high availability"
      ;;
    no)
      msg_error "Selected no to Enabling high availability"
      ;;
    esac
  fi

  if systemctl is-active --quiet pve-ha-lrm; then
    CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "HIGH AVAILABILITY" --menu "If you plan to utilize a single node instead of a clustered environment, you can disable unnecessary high availability (HA) services, thus reclaiming system resources.\n\nIf HA becomes necessary at a later stage, the services can be re-enabled.\n\nDisable high availability?" 18 58 2 \
      "yes" " " \
      "no" " " 3>&2 2>&1 1>&3)
    case $CHOICE in
    yes)
      msg_info "Disabling high availability"
      systemctl disable -q --now pve-ha-lrm
      systemctl disable -q --now pve-ha-crm
      msg_ok "Disabled high availability"
      CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "COROSYNC" --menu "Disable Corosync for a Proxmox VE Cluster?" 10 58 2 \
        "yes" " " \
        "no" " " 3>&2 2>&1 1>&3)
      case $CHOICE in
      yes)
        msg_info "Disabling Corosync"
        systemctl disable -q --now corosync
        msg_ok "Disabled Corosync"
        ;;
      no)
        msg_error "Selected no to Disabling Corosync"
        ;;
      esac
      ;;
    no)
      msg_error "Selected no to Disabling high availability"
      ;;
    esac
  fi

  # -- IOMMU SECTION --
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "IOMMU (PCI Passthrough)" --yesno "Enable IOMMU to allow passing through hardware (e.g., GPUs) to VMs?\n\nThis will modify system boot files and requires a reboot. Ensure VT-d / AMD-Vi is enabled in your BIOS/UEFI first." 14 58); then
      CPU_VENDOR=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "CPU VENDOR" --menu "Select your CPU Vendor." 12 58 2 \
          "Intel" "Enable Intel VT-d" \
          "AMD" "Enable AMD-Vi" 3>&2 2>&1 1>&3)

      case $CPU_VENDOR in
      Intel)
          IOMMU_PARAM="intel_iommu=on"
          ;;
      AMD)
          IOMMU_PARAM="amd_iommu=on"
          ;;
      *)
          IOMMU_PARAM=""
          ;;
      esac

      if [ -n "$IOMMU_PARAM" ]; then
          msg_info "Enabling IOMMU for $CPU_VENDOR"
          # Edit GRUB
          if ! grep -q "GRUB_CMDLINE_LINUX_DEFAULT=.*${IOMMU_PARAM}" /etc/default/grub; then
              sed -i.bak 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 '"$IOMMU_PARAM"'"/' /etc/default/grub
              update-grub &>/dev/null
          fi

          # Add Modules
          MODULES="vfio\nvfio_iommu_type1\nvfio_pci\nvfio_virqfd"
          for module in $MODULES; do
              if ! grep -q "^${module}$" /etc/modules; then
                  echo "$module" >> /etc/modules
              fi
          done

          msg_info "Updating Initramfs"
          update-initramfs -u -k all &>/dev/null
          REBOOT_REQUIRED_FOR_IOMMU=true
          msg_ok "IOMMU for $CPU_VENDOR Enabled"
      else
          msg_error "No CPU vendor selected. Skipped IOMMU setup."
      fi
  else
      msg_error "Selected no to Enabling IOMMU"
  fi
  # -- END IOMMU SECTION --

  CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "UPDATE" --menu "\nUpdate Proxmox VE now?" 11 58 2 \
    "yes" " " \
    "no" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  yes)
    msg_info "Updating Proxmox VE (Patience)"
    apt-get update &>/dev/null
    apt-get -y dist-upgrade &>/dev/null
    msg_ok "Updated Proxmox VE"
    ;;
  no)
    msg_error "Selected no to Updating Proxmox VE"
    ;;
  esac
  
  local reboot_prompt="\nReboot Proxmox VE now? (recommended)"
  if [[ ${REBOOT_REQUIRED_FOR_IOMMU} == true ]]; then
    reboot_prompt="\nIOMMU has been configured. A reboot is REQUIRED to apply changes.\n\nReboot Proxmox VE now?"
  fi
  CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "REBOOT" --menu "$reboot_prompt" 12 58 2 \
    "yes" " " \
    "no" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  yes)
    msg_info "Rebooting Proxmox VE"
    sleep 2
    msg_ok "Completed Post Install Routines"
    reboot
    ;;
  no)
    msg_error "Selected no to Rebooting Proxmox VE (Reboot REQUIRED for IOMMU if enabled)"
    msg_ok "Completed Post Install Routines"
    ;;
  esac
}

header_info
echo -e "\nThis script will Perform Post Install Routines.\n"
while true; do
  read -p "Start the Proxmox VE Post Install Script (y/n)?" yn
  case $yn in
  [Yy]*) break ;;
  [Nn]*)
    clear
    exit
    ;;
  *) echo "Please answer yes or no." ;;
  esac
done

if ! pveversion | grep -Eq "pve-manager/8\.[0-9]+"; then
  msg_error "This version of Proxmox Virtual Environment is not supported"
  echo -e "Requires Proxmox Virtual Environment Version 8.x."
  echo -e "Exiting..."
  sleep 2
  exit
fi

start_routines
```
