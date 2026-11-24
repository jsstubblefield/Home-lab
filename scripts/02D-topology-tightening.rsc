# ============================================================================
# hAP ax3 - STAGE 2D (ADD-ON): topology tightening for John's actual layout.
# Run ONCE after 02B (and after 02C if you use it), from ether5, Safe Mode.
# NOT idempotent. Dry-run first:
#   /import file-name=02D-topology-tightening.rsc verbose=yes dry-run
#
# Layout this encodes (confirmed 2026-11-21):
#   VLAN10 PC        - total isolation, direct WAN, no VPN, no router access
#   VLAN20 Mobile    - 5GHz Wi-Fi + ether3 (guests use both), via Proton WG
#   VLAN30 IoT 5GHz  - ether4 = Google Cast (WIRED only), Wi-Fi = Eight Sleep Pod
#   VLAN40 IoT 2.4GHz- smart light bulbs only, via Proton WG
#   ether5 OOB       - laptop/PC Ethernet for WinBox, nothing else, no Internet
#   Backups          - MANUAL golden backups only. No weekly scheduler.
# ============================================================================

:if ([:len [/interface bridge find name=br-clients]] = 0) do={ :error "br-clients missing; run 02A/02B first." }
:if ([:len [/ip firewall filter find where comment="02D: iot to local drop"]] > 0) do={ :error "02D already applied. Inspect before retrying." }

# ---- SECTION A. REMOVE THE WEEKLY BACKUP (REPLACED BY MANUAL GOLDEN BACKUPS) ----
# Guarded: no error if 02B's Section M was already deleted before import.
:if ([:len [/system scheduler find name=weekly-encrypted-backup-schedule]] > 0) do={ /system scheduler remove [find name=weekly-encrypted-backup-schedule] }
:if ([:len [/system script find name=weekly-encrypted-backup]] > 0) do={ /system script remove [find name=weekly-encrypted-backup] }
:log info "02D: weekly backup scheduler/script removed (manual golden backups only)."

# ---- SECTION B. EXPLICIT, LOGGED INTER-VLAN DROPS ----
# The 02B default drop already blocks these; these rules exist for VISIBILITY
# and defense-in-depth if a future accept rule is ever inserted in the wrong
# place. They must sit BEFORE the MASTER forward default-deny, and they only
# match connection-state=new, so established return traffic (IoT replies to
# a Mobile-initiated session, etc.) is untouched - it is accepted earlier.
:local fwdDrop [:pick [/ip firewall filter find where comment="MASTER: forward default deny"] 0]
:if ([:len $fwdDrop] = 0) do={ :error "MASTER forward default-deny not found; stop rather than append drops after it." }
# IoT (30/40) must never INITIATE to any local subnet (PC, Mobile, each other, OOB).
/ip firewall filter add chain=forward connection-state=new in-interface-list=IOT_VLANS dst-address=10.10.0.0/16 action=drop log=yes log-prefix="XVLAN-IOT: " place-before=$fwdDrop comment="02D: iot to local drop"
# PC (10) must never initiate to any local subnet either. PC -> its own gateway
# is INPUT chain (DNS/DHCP only), not forward, so this does not affect it.
/ip firewall filter add chain=forward connection-state=new in-interface=vlan10-pc dst-address=10.10.0.0/16 action=drop log=yes log-prefix="XVLAN-PC: " place-before=$fwdDrop comment="02D: pc to local drop"
# NO client VLAN may initiate to the OOB management subnet, Mobile included.
# (Mobile -> IoT is dst 10.10.30/40.x, not .99.x, so management still works.)
/ip firewall filter add chain=forward connection-state=new in-interface-list=CLIENT_VLANS dst-address=10.10.99.0/24 action=drop log=yes log-prefix="XVLAN-OOB: " place-before=$fwdDrop comment="02D: clients to oob drop"
:log info "02D: explicit logged inter-VLAN drops installed (IoT->local, PC->local, any client->OOB)."

# ---- SECTION C. VLAN30 L2 ISOLATION: CAST (ether4) vs EIGHT SLEEP (wifi) ----
# Firewall rules govern ROUTED (cross-VLAN) traffic only. Inside VLAN30,
# the wired Cast and the Wi-Fi Pod share one L2 bridge and could talk
# directly, invisible to the firewall. Equal bridge-port horizons stop
# port-to-port forwarding between them; both still reach the gateway
# (the bridge CPU port is not horizon-bound), so Mobile management via
# L3 routing is unaffected.
/interface bridge port set [find interface=ether4] horizon=10
/interface bridge port set [find interface=wifi1-iot5] horizon=10
:log info "02D: VLAN30 split horizon set on ether4 + wifi1-iot5 (Cast and Pod cannot talk at L2)."

# ---- SECTION D. OOB LEASE LOGGING: KNOW WHEN SOMETHING PLUGS INTO ether5 ----
# Any DHCP lease on the management port is an event worth a log line.
# \$ variables are evaluated by the DHCP server at lease time, not at import.
/ip dhcp-server set dhcp-oob lease-script=":log warning (\"OOB-LEASE: ether5 lease granted to \" . \$leaseActMAC . \" at \" . \$leaseActIP)"
:log info "02D: ether5 DHCP lease logging enabled on dhcp-oob."

:log warning "02D COMPLETE: test (1) Mobile can still Cast and reach the Pod app path, (2) Pod and Cast still get Internet via Proton, (3) a phone on VLAN20 cannot ping the PC, and watch /log for XVLAN- drops."
