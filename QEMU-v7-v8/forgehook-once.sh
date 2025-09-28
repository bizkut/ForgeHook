#!/bin/bash

# Receive VMID and PHASE from Arguments
VMID="$1"
PHASE="$2"

# Paths
CONF="/etc/pve/qemu-server/${VMID}.conf"
HWID_PATH="/var/lib/vz/snippets/log-hook/hwid-spoofer/hwid-${VMID}"

# Helpers
randstr() { tr -dc A-Za-z0-9 </dev/urandom | head -c "$1"; }
randnum() { tr -dc 0-9 </dev/urandom | head -c "$1"; }
randuuid() { cat /proc/sys/kernel/random/uuid; }

# TAG_FORGEHOOK
TAG_FORGEHOOK="forgehook"

# [ENABLE_RANDOM_MAC] Option to enable/disable random MAC address assignment for net0 (Intel E1000)
# [ENABLE_ACPITABLE] Option to enable/disable adding custom ACPI tables to args
# 1=ON, 0=OFF
ENABLE_RANDOM_MAC=1
ENABLE_ACPITABLE=1

# Preset Mainboard (Vendor|Model|BIOS Vendor|BIOS Version)
PRESETS=(
    "ASUS|X99-E WS|American Megatrends Inc.|3501"
    "Supermicro|X10SRL-F|Supermicro|3.1"
    "ASRock|X99 WS-E/10G|American Megatrends Inc.|P3.40"
    "MSI|X99A WORKSTATION|American Megatrends Inc.|7885v18"
    "Gigabyte|GA-X99-UD7 WIFI|American Megatrends Inc.|F23"
)

# Preset Memory
RAM_BRANDS=("Samsung" "Corsair" "Kingston" "Crucial")
RAM_SPEEDS=(2133 2400 2666 3200)

# Randomize Disk Serial
rand_disk_serial() {
  tr -dc 'A-Z0-9' </dev/urandom | head -c 20
}

# Randomize MAC Address Intel E1000
rand_mac_e1000() {
    OUI_LIST=(
        "00:13:20"  # Intel PRO/1000 MT
        "00:1B:21"  # Intel PRO/1000 GT
        "00:1C:C0"  # Intel PRO/1000 MT PCIe
        "00:0E:0C"  # Intel PRO/1000 PT
    )
    OUI=${OUI_LIST[$RANDOM % ${#OUI_LIST[@]}]}
    B1=$(printf '%02X' $((RANDOM % 256)))
    B2=$(printf '%02X' $((RANDOM % 256)))
    B3=$(printf '%02X' $((RANDOM % 256)))

    echo "$OUI:$B1:$B2:$B3"
}

# =============================
# =====> Hook Status pre-start
# =============================
if [[ "$PHASE" == "pre-start" ]]; then

    # Check Tags FORGEHOOK
    if grep -qE "^tags:.*(^|[;,[:space:]])${TAG_FORGEHOOK}([;,[:space:]]|$)" "$CONF"; then

        # Create Folder hwid-spoofer
        mkdir -p /var/lib/vz/snippets/log-hook/hwid-spoofer/
        OLD_PRESET=""
        [[ -f "$HWID_PATH" ]] && OLD_PRESET=$(cat "$HWID_PATH")
    
        while true; do
            NEW_PRESET="${PRESETS[$RANDOM % ${#PRESETS[@]}]}"
            [[ "$NEW_PRESET" != "$OLD_PRESET" ]] && break
        done
    
        # Split the selected preset string into separate variables
        # (Vendor | Model | BIOS Vendor | BIOS Version)
        MBD_VENDOR=$(echo "$NEW_PRESET" | cut -d '|' -f 1)
        MBD_MODEL=$(echo "$NEW_PRESET" | cut -d '|' -f 2)
        BIOS_VENDOR=$(echo "$NEW_PRESET" | cut -d '|' -f 3)
        BIOS_VERSION=$(echo "$NEW_PRESET" | cut -d '|' -f 4)
    
        # Randomize system identifiers (UUID, BIOS date/release, etc.)
        UUID=$(randuuid)
        BIOS_DATE=$(date +'%m/%d/%Y')
        BIOS_RELEASE=$(awk -v r=$((RANDOM % 31 + 10)) 'BEGIN{printf "%.1f", r/10}') #(Random 1.0 - 4.0)
    
        # Randomize Memory
        RAM_BRAND=${RAM_BRANDS[$RANDOM % ${#RAM_BRANDS[@]}]}
        RAM_SPEED=${RAM_SPEEDS[$RANDOM % ${#RAM_SPEEDS[@]}]}
        RAM_SERIAL=$(tr -dc 'A-Z0-9' </dev/urandom | head -c 8)
        RAM_PART="$(tr -dc 'A-Z0-9' </dev/urandom | head -c 12)-$(tr -dc 'A-Z0-9' </dev/urandom | head -c 5)"
        ASSET_RAM="$(tr -dc '0-9' </dev/urandom | head -c 10)"
    
        # Get CPU info from dmidecode (SMBIOS type 4)
        # Added via PR by @t4bby (for CPU host-passthrough support)
        DMIDECODE_MANUFACTURER=$(dmidecode -t 4 | grep 'Manufacturer:' | head -n1 | awk -F': ' '{print $2}')
        DMIDECODE_VERSION=$(dmidecode -t 4 | grep 'Version:' | head -n1 | awk -F': ' '{print $2}')
        DMIDECODE_SOCKET=$(dmidecode -t 4 | grep 'Upgrade: Socket ' | head -n1 | sed 's/Upgrade: Socket //' | xargs)
        DMIDECODE_MAX_SPEED=$(dmidecode -t 4 | grep 'Max Speed:' | head -n1 | awk -F': ' '{print $2}' | awk '{print $1}')
        DMIDECODE_CUR_SPEED=$(dmidecode -t 4 | grep 'Current Speed:' | head -n1 | awk -F': ' '{print $2}' | awk '{print $1}')
        DMIDECODE_SERIAL=$(dmidecode -t 4 | grep 'Serial Number:' | head -n1 | awk -F': ' '{print $2}')
        DMIDECODE_ASSET=$(dmidecode -t 4 | grep 'Asset Tag:' | head -n1 | awk -F': ' '{print $2}' | xargs)
        DMIDECODE_PART=$(dmidecode -t 4 | grep 'Part Number:' | head -n1 | awk -F': ' '{print $2}' | xargs)
    
        # Check String DMIDECODE_MAX_SPEED
        if [[ "$DMIDECODE_MAX_SPEED" =~ ^[0-9]+$ ]]; then
            FINAL_DMIDECODE_MAX_SPEED=$DMIDECODE_MAX_SPEED
        else
            # Random CPU MaxSpeed 500–1500 step 100
            OFFSET=$(( ( (RANDOM % 11) + 5 ) * 100 ))
            FINAL_DMIDECODE_MAX_SPEED=$((DMIDECODE_CUR_SPEED + OFFSET))
        fi
    
        # Add args in VMID.conf
        sed -i '/^args:/d' "$CONF"
    
        ARGS_LIST=()
    
        # Add custom ACPI tables if ENABLE_ACPITABLE=1
        if [[ "$ENABLE_ACPITABLE" -eq 1 ]]; then
            ARGS_LIST+=("-acpitable file=/root/ssdt.aml")
            ARGS_LIST+=("-acpitable file=/root/ssdt-ec.aml")
            ARGS_LIST+=("-acpitable file=/root/hpet.aml")
        fi
    
        ARGS_LIST+=("-cpu host,hypervisor=off,vmware-cpuid-freq=false,enforce=false,host-phys-bits=true")
        ARGS_LIST+=("-smbios type=0,vendor=\"$BIOS_VENDOR\",version=\"$BIOS_VERSION\",date=\"$BIOS_DATE\",release=$BIOS_RELEASE")
        ARGS_LIST+=("-smbios type=1,manufacturer=\"$MBD_VENDOR\",product=\"$MBD_MODEL\",version=\"$BIOS_VERSION\",serial=\"Default string\",sku=\"Default string\",family=\"Default string\"")
        ARGS_LIST+=("-smbios type=2,manufacturer=\"$MBD_VENDOR\",product=\"$MBD_MODEL\",version=\"$BIOS_VERSION\",serial=\"Default string\",asset=\"Default string\",location=\"Slot0\"")
        ARGS_LIST+=("-smbios type=3,manufacturer=\"$MBD_VENDOR\",version=\"$BIOS_VERSION\",serial=\"Default string\",asset=\"Default string\",sku=\"Default string\"")
        ARGS_LIST+=("-smbios type=4,sock_pfx=\"$DMIDECODE_SOCKET\",manufacturer=\"$DMIDECODE_MANUFACTURER\",version=\"$DMIDECODE_VERSION\",max-speed=$FINAL_DMIDECODE_MAX_SPEED,current-speed=$DMIDECODE_CUR_SPEED,serial=\"$DMIDECODE_SERIAL\",asset=\"$DMIDECODE_ASSET\",part=\"$DMIDECODE_PART\"")
        ARGS_LIST+=("-smbios type=17,loc_pfx=\"ChannelA-DIMM0\",manufacturer=\"$RAM_BRAND\",speed=$RAM_SPEED,serial=\"$RAM_SERIAL\",part=\"$RAM_PART\",bank=\"BANK 0\",asset=\"$ASSET_RAM\"")
        ARGS_LIST+=("-smbios type=8,internal_reference=\"CPU FAN\",external_reference=\"Not Specified\",connector_type=0xFF,port_type=0xFF")
        ARGS_LIST+=("-smbios type=8,internal_reference=\"J3C1 - GMCH FAN\",external_reference=\"Not Specified\",connector_type=0xFF,port_type=0xFF")
        ARGS_LIST+=("-smbios type=8,internal_reference=\"J2F1 - LAI FAN\",external_reference=\"Not Specified\",connector_type=0xFF,port_type=0xFF")
        ARGS_LIST+=("-smbios type=11,value=\"Default string\"")
    
        ARGS="${ARGS_LIST[*]}"
    
        echo "args: $ARGS" >> "$CONF"
    
        # Mirror SMBIOS type=1 into 'smbios1:' entry so it also appears in Proxmox Web UI
        sed -i '/^smbios1:/d' "$CONF"
        SMBIOS1="base64=1,uuid=$UUID,manufacturer=$(echo -n $MBD_VENDOR | base64),product=$(echo -n $MBD_MODEL | base64),version=$(echo -n $BIOS_VERSION | base64),serial=$(echo -n "Default string" | base64),sku=$(echo -n "Default string" | base64),family=$(echo -n "Default string" | base64)"
        echo "smbios1: $SMBIOS1" >> "$CONF"
    
        # Random vmgenid Key in VMID.conf
        sed -i '/^vmgenid:/d' "$CONF"
        VMGENID=$(randuuid)
        echo "vmgenid: $VMGENID" >> "$CONF"
    
        # Randomize MAC address for net0 (Intel E1000) if ENABLE_RANDOM_MAC=1
        if [[ "$ENABLE_RANDOM_MAC" -eq 1 ]]; then
            NEWMAC=$(rand_mac_e1000)
            sed -E -i "s|^(net0:[[:space:]]*[^=]+=)[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}((,.*)?)$|\1${NEWMAC}\3|g" "$CONF"
        fi

        TMP_CONF="$(mktemp)"
        PATCHED=0

        # Randomize serial= For (virtio|scsi|ide|sata)
        while IFS= read -r line || [[ -n "$line" ]]; do
          cr=""
          if [[ "$line" == *$'\r' ]]; then
            cr=$'\r'
            line=${line%$'\r'}
          fi
        
          if [[ "$line" =~ ^[[:space:]]*(virtio|scsi|ide|sata)[0-9]+: ]]; then
            SERIAL_DISK="$(rand_disk_serial)"

            line="$(
              printf '%s\n' "$line" | sed -E '
                :a
                s/(^|,)[[:space:]]*serial=[^,]*//; ta
              '
            )"

            line="$(
              printf '%s\n' "$line" | sed -E '
                s/,,+/,/g;       # ,, → ,
                s/:,/:/g;        # :,
                s/,$//           # Cut comma
              '
            )"

            line="${line},serial=${SERIAL_DISK}"
        
            PATCHED=1
          fi

          printf '%s%s\n' "$line" "$cr" >> "$TMP_CONF"
        done < "$CONF"
        
        if [[ "$PATCHED" -eq 1 ]]; then
          mv "$TMP_CONF" "$CONF"
        else
          rm -f "$TMP_CONF"
        fi

        echo "$NEW_PRESET" > "$HWID_PATH"

        # --- Tag cleared successfully
        sed -i "s/;${TAG_FORGEHOOK}//; s/,${TAG_FORGEHOOK}//; s/ ${TAG_FORGEHOOK}//; s/^tags: ${TAG_FORGEHOOK}\$/tags:/" "$CONF"
        
        # This code will help the VM to get the latest changes by stopping the VM and starting the VM automatically (because the Hook Script is running when the VM is started, the VM will not get the latest random values, so this code helps the VM to get the latest changed values).
        setsid /var/lib/vz/snippets/vm-restart.sh "$VMID" > /dev/null 2>&1 < /dev/null &
    fi
fi
