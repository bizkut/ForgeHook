# ⚒️ ForgeHook 🎣  
A hook script for randomizing hardware values in `VMID.conf`.  
Easy to use, flexible to customize, and simple to extend.  

It’s a straightforward idea that makes use of the existing Hook feature in PVE to provide more value.  
You’re welcome to adapt, modify, or integrate it into your own projects as you like.  

If this helps make the PVE community better, I’ll be more than happy. 🙏

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
# 🔧 Flexible Hook Script for Random HWID

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This project provides a **flexible hook script** to randomize HWID-related values in `VMID.conf`.  
It builds on PVE existing hook mechanism so you can extend or customize randomization independently.

> **Friendly note to patch authors 🙏**  
> In some patches (e.g., Spoofer for `pve-qemu-kvm`), certain values may be fixed (like `serial=0123456789ABCDEF0123`) to avoid constant re-randomization.  
> **That’s not a bad approach** — it’s reasonable given patch complexity.  
> This hook simply offers another path for users who need more flexibility (e.g., when certain apps/games are sensitive to fixed HDD serials).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## ⚠️ Compatibility Notes

- Tested on **pve-qemu-kvm 7 & 8**.  
  For **9 & 10**, some Spoofer patches may not expose randomization through `VMID.conf`, or may still do their own internal randomization.  
  For now, please prefer versions **7–8** when evaluating this hook.

- If you’ve built an **open, freely-randomizable Spoofer** for **9 or 10**, please let me know 🙏  
  I’m happy to publish an updated version to support it.

- You’re free to **modify** this code to suit your VM setup and the patch you use.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 💡 Why this helps

- Some patches require fixed values (e.g., `serial=0123456789ABCDEF0123`) to prevent infinite randomization loops.  
  But fixed HDD serials can be problematic in certain software/games (e.g., ban based on unchanged HDD serial).  
- With this **external hook**, you can randomize HDD serials (and other IDs) without hard-coding them in the patch, giving you **greater control**.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 🎛️ What gets randomized (examples)

> You can extend these; the lists below are included as **examples**.

- **LAN MAC** — randomize Intel E1000 MAC address (can be toggled ON/OFF)
- **HDD** — supports all types: (`ide | sata | scsi | virtio`)
- **Mainboard** — sample pool of 5 vendors
- **RAM** — sample pool of 4 vendors (configurable `VENDOR`, `SPEED`, `SERIAL`)
- **BIOS UUID** (via `smbios1`)
- **BIOS Serial** (`-smbios type=0, 1, 2, 3, 17, 8, 11`)
- **BIOS type=4** — directly uses the Host CPU values (since it always reflects the host)
- **vmgenid**

📝 **Note:** CPU spoofing is intentionally **not** included.  
If needed, set a CPU type to match the host for consistency.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 🚀 Getting Started

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 1. Enable Snippets for Hook Scripts

Proxmox already provides a Hook Script mechanism.  
It’s not complicated — you just need to know where to place the file.

Official documentation:  
https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_hookscripts

Example from the manual (for reference only — in this project we’ll edit `VMID.conf` directly, which is easier to understand):

qm set 100 --hookscript local:snippets/hookscript.pl

The keyword `local:snippets` means you must first enable **Snippets** in your storage:

Datacenter → Storage → local → Content → enable Snippets

Once Snippets is enabled, you can use Hook Scripts.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 2. Place the Files

Put the script files from this project into:

`/var/lib/vz/snippets`

This project currently includes 4 key components:

1. forgehook-once.sh
2. forgehook-repeat.sh
3. vm-restart.sh  
4. Folder log-hook

Make sure all 4 are executable:   

```
cd /var/lib/vz/snippets
```

```
chmod +x *.*
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 3. File Overview

### 🔹 forgehook-once.sh
- Runs only **once**.  
- Uses `tags:` to trigger execution (no need to manually edit `VMID.conf`).  
- Just add the tag `forgehook` (all lowercase) in the VM’s settings via the Proxmox Web UI,  
  and this script will automatically run.  
- After the randomization completes, the tag `forgehook` is automatically removed —  
  indicating the process is finished and it will run only once.

### 🔹 forgehook-repeat.sh
- Similar to **forgehook-once.sh**, but does **not** require the `forgehook` tag.  
- Runs automatically without adding any tag.  
- While running, a temporary tag `forgehook-repeat` will appear in the Proxmox Web UI.  
  After completion, this tag is automatically removed — indicating the process finished successfully.  
- Use this if you want the VM’s **HWID to be randomized every time** the VM starts.

### 🔹 vm-restart.sh
- Works **together with the above hooks**.  
- This script will **stop the VM and start it again** so that all randomized values are fully applied.  
- By forcing a full stop/start cycle, it guarantees the VM always receives the new values right from the very first run.  

### 🔹 log-hook (folder)
- Stores logs of generated HWIDs.  
- Files are named `/log-hook/hwid-spoofer/hwid-<VMID>`.  
- Ensures **no duplicate randomization** across VMs (e.g., if 5 mainboards exist, it won’t pick the same one twice until all have been used).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 4. Configure `VMID.conf`

Location:  
`/etc/pve/qemu-server/${VMID}.conf`

Place this line at the **very bottom** of the configuration file,  
or follow the placement shown in the example.  

(Other positions will also work, as long as the keyword and value are written correctly!)

```
hookscript: local:snippets/forgehook-once.sh
```

**VMID.conf Example:**

args: -cpu host,....(your custom values)....   
hookscript: local:snippets/forgehook-once.sh   
hostpci0: 0000:02:00.0,mdev=nvidia-54   
machine: pc-q35-7.2   

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 🔧 5. Options in `forgehook`

- I added toggle options to make randomization more convenient. Some programs inside the VM don’t like getting a new LAN MAC every time, so you can turn MAC randomization on/off for flexibility with different games and apps.  
  1 = enable, 0 = disable  
  `ENABLE_RANDOM_MAC=1`

- Based on feedback from @t4bby, there is also a toggle for adding custom **ACPI tables** in args.   
This improves flexibility today and serves as a pattern for future on/off switches in other parts of the code.    
  `ENABLE_ACPITABLE=1`

- **Presets for Mainboard & BIOS**  
  You can freely add vendors, models, BIOS vendors, and versions. In the example below, five X99 boards are provided.  
  Tip: pick real boards that match your host CPU so things look consistent and realistic.  
   
  PRESETS=(   
      "ASUS|X99-E WS|American Megatrends Inc.|3501"   
      "Supermicro|X10SRL-F|Supermicro|3.1"   
      "ASRock|X99 WS-E/10G|American Megatrends Inc.|P3.40"   
      "MSI|X99A WORKSTATION|American Megatrends Inc.|7885v18"   
      "Gigabyte|GA-X99-UD7 WIFI|American Megatrends Inc.|F23"   
  )   
  
- **Presets for RAM**  
  Just like the mainboard presets, you can customize freely.  
    
  RAM_BRANDS=("Samsung" "Corsair" "Kingston" "Crucial")   
  RAM_SPEEDS=(2133 2400 2666 3200)  

👉 For other values (HDD, UUID, etc.), no manual setup is required.    
I aligned the behavior with the approach from **Li Xiaoliu** & **DadaShuai666**.    
If a field shouldn’t be randomized, it’s set to a realistic default string to keep things authentic.   

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 🔄 Re-randomizing with `forgehook-once.sh`

1. **Stop** the VM.  
2. Open the **Proxmox Web UI** and select the VM you want to re-randomize.  
3. Click the **pencil icon** to edit tags.  
4. Add a new tag: type `forgehook` (all lowercase).  
5. You will now see the `forgehook` tag appear Beside the number VM.  
6. **Start** the VM.  
7. The script will randomize the HWID.  
   Once it finishes, the `forgehook` tag is automatically removed —  
   indicating the process completed successfully.  

🥳 This method is easier than the old way of editing values directly in `VMID.conf`.  

💡 It offers more flexibility and convenience — and if you have many VMs to randomize,  
   this approach makes the process much simpler and more reliable.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 🔄 Using `forgehook-repeat.sh` for re-randomization on every start   

1. **Stop** the VM  
2. Edit the file: `/etc/pve/qemu-server/${VMID}.conf`  
3. Change from:  
   hookscript: local:snippets/forgehook-once.sh  
   to:  
   hookscript: local:snippets/forgehook-repeat.sh  
4. Save the file  
5. **Start** the VM  

🔭 You will see the tag `forgehook-repeat` appear.  
After a short while, it disappears automatically once the randomization is complete.  

🤖 Behavior of `forgehook-repeat`:  
- The system will re-randomize **only when you start the VM again**.   

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 🙏 Acknowledgements

I’d like to take a moment to thank the people whose work and ideas inspired ForgeHook:

- **zhaodice**  
  One of the earliest developers I came across in the PVE community.  
  Your work lit the spark for me to pursue a childhood dream — making a single computer powerful enough to be shared with my family.  

- **Li Xiaoliu & DadaShuai666**  
  Both of you have been a huge source of motivation.  
  Your QEMU spoofers opened doors for me and many others, letting us enjoy games that once struggled with anti-cheat systems.  
  I remain a big fan and continue to follow your projects. Thank you for everything you’ve given to this community.  

- **Scrut1ny**  
  A talented creator in the Linux virtualization scene.  
  Many of your adaptations and ideas inspired my own.  
  Even though my main focus is on PVE, your work has broadened what’s possible and brought valuable variety to this space.  

---

## 🏘️ Contributors & Ideas

- **t4bby**   
  Suggested using **dmidecode** to fetch CPU values directly, reducing complexity.  
  Also introduced the idea of adding an **enable/disable option for custom ACPI tables** in args,  
  which makes the codebase more flexible and user-friendly.

---

✨ And to everyone I haven’t mentioned by name:  
your contributions have been just as valuable.  
Each idea, patch, and shared insight has helped this community grow stronger together —  
and made it a place where learning and creativity can also be fun. 🙌

---

💡 This is my very first GitHub project.  
If anything looks unusual, please forgive me — I’m still learning, and I used Google Translate to help with the English wording.  

Thank you all for your hard work and for making this community stronger. 🙌
