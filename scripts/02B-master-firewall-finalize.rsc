# hAP ax3, STAGE 2B: firewall + finalization. Run ONLY after 02A.
# Run from ether5 / 10.10.99.1, NOT ether2 or WiFi.
# Fill in admin + backup secrets below; stage 2B is independent of 2A globals.
# Test with /import ... verbose=yes dry-run; then import for real.

:global adminUser "myadmin"
:global adminPass "REPLACE_WITH_LONG_ADMIN_PASSWORD"
:global sshKeyFile "id_ed25519.pub"
:global backupPass "REPLACE_WITH_LONG_BACKUP_PASSWORD"
:global wifiCountry
:global ssid20
:global pass20
:global ssid30
:global pass30
:global ssid40
:global pass40
:global wgPrivate
:global wgPublic
:global wgEndpoint
:global wgPort
:global wgAddress
:global backupJob
:if ([:len [/interface bridge find name=br-clients]] = 0) do={ :error "Run stage 2A first: br-clients missing." }
:if ([:len [/interface vlan find name=vlan10-pc]] = 0) do={ :error "Run stage 2A first: vlan10-pc missing." }
:if ($adminUser="admin") do={ :error "Use a new named administrator; do not replace the factory admin here." }
:if ([:len [/user find name=$adminUser]] > 0) do={ :error "Chosen admin already exists. Stop and inspect." }
:if (($adminPass="REPLACE_WITH_LONG_ADMIN_PASSWORD") || ([:len $adminPass] < 16)) do={ :error "Set an admin password of at least 16 characters." }
:if (($backupPass="REPLACE_WITH_LONG_BACKUP_PASSWORD") || ([:len $backupPass] < 24)) do={ :error "Set a backup passphrase of at least 24 characters." }

# ---- SECTION J. NEW FIREWALL AND NAT (APPEND BEFORE DISABLING defconf) ----
# DNS port 53 interception applies to all client VLANs (NOT to ether5).
/ip firewall nat add chain=dstnat in-interface-list=CLIENT_VLANS protocol=udp dst-port=53 action=redirect to-ports=53 comment="MASTER: client UDP DNS to sinkhole"
/ip firewall nat add chain=dstnat in-interface-list=CLIENT_VLANS protocol=tcp dst-port=53 action=redirect to-ports=53 comment="MASTER: client TCP DNS to sinkhole"
/ip firewall nat add chain=srcnat src-address=10.10.10.0/24 out-interface-list=WAN action=masquerade comment="MASTER: VLAN10 direct Xfinity NAT"
/ip firewall nat add chain=srcnat out-interface=wg-proton action=masquerade comment="MASTER: Proton clients NAT"

# INPUT: only ether5 can administer the router.
/ip firewall filter add chain=input connection-state=established,related,untracked action=accept comment="MASTER: input established"
/ip firewall filter add chain=input connection-state=invalid action=drop comment="MASTER: input invalid"
/ip firewall filter add chain=input in-interface=ether1 protocol=udp src-port=67 dst-port=68 action=accept comment="MASTER: ISP DHCP replies"
/ip firewall filter add chain=input in-interface=ether5 protocol=icmp action=accept comment="MASTER: OOB ICMP"
/ip firewall filter add chain=input in-interface=ether5 src-address=10.10.99.0/24 protocol=tcp dst-port=22,8291 action=accept comment="MASTER: OOB SSH WinBox only"
/ip firewall filter add chain=input in-interface=ether5 protocol=udp dst-port=67 action=accept comment="MASTER: OOB DHCP only"
/ip firewall filter add chain=input in-interface-list=CLIENT_VLANS protocol=udp dst-port=53,67 action=accept comment="MASTER: VLAN DNS DHCP"
/ip firewall filter add chain=input in-interface-list=CLIENT_VLANS protocol=tcp dst-port=53 action=accept comment="MASTER: VLAN DNS TCP"
/ip firewall filter add chain=input action=drop comment="MASTER: input default deny"

# FORWARD: NO FastTrack on the policy-routed VLANs. Explicit fasttrack only PC <-> WAN.
/ip firewall filter add chain=forward in-interface=ether5 action=drop comment="MASTER: OOB cannot forward"
/ip firewall filter add chain=forward connection-state=invalid action=drop comment="MASTER: forward invalid"
/ip firewall filter add chain=forward connection-state=established,related src-address=10.10.10.0/24 out-interface-list=WAN action=fasttrack-connection hw-offload=yes comment="MASTER: PC->WAN FastTrack only"
/ip firewall filter add chain=forward connection-state=established,related dst-address=10.10.10.0/24 in-interface-list=WAN action=fasttrack-connection hw-offload=yes comment="MASTER: WAN->PC FastTrack only"
/ip firewall filter add chain=forward connection-state=established,related,untracked action=accept comment="MASTER: forward established"
/ip firewall filter add chain=forward in-interface=vlan10-pc out-interface-list=WAN action=accept comment="MASTER: PC to WAN"
/ip firewall filter add chain=forward in-interface=vlan20-mobile out-interface-list=IOT_VLANS action=accept comment="MASTER: mobile may initiate IoT connections"
/ip firewall filter add chain=forward in-interface-list=VPN_VLANS out-interface=wg-proton action=accept comment="MASTER: VPN clients to WG ONLY"
/ip firewall filter add chain=forward action=drop comment="MASTER: forward default deny"

# Switch from defconf firewall only AFTER a complete replacement has been added.
/ip firewall filter disable [find where comment~"defconf"]
/ip firewall nat disable [find where comment~"defconf"]
# Bootstrap rules are no longer needed; replacement firewall now protects OOB.
/ip firewall filter remove [find where comment~"TEMP OOB bootstrap"]

# ---- SECTION K. REMOVE OLD FACTORY BRIDGE SERVICES (NOT OOB) ----
:if ([:len [/ip dhcp-server find name=defconf]] > 0) do={ /ip dhcp-server remove [find name=defconf] }
:if ([:len [/ip dhcp-server network find address="192.168.88.0/24"]] > 0) do={ /ip dhcp-server network remove [find address="192.168.88.0/24"] }
:if ([:len [/ip address find address="192.168.88.1/24"]] > 0) do={ /ip address remove [find address="192.168.88.1/24"] }
:if ([:len [/ip pool find name=default-dhcp]] > 0) do={ /ip pool remove [find name=default-dhcp] }
:if ([:len [/interface bridge port find bridge=bridge]] > 0) do={ :error "Old bridge still has a port. Inspect /interface bridge port before removing it." }
:if ([:len [/interface bridge find name=bridge]] > 0) do={ /interface bridge remove [find name=bridge] }
# Remove only the temporary LAN-list membership; do not clear every list.
/interface list member remove [find where comment="TEMP OOB bootstrapping"]

# ---- SECTION L. MANAGEMENT HARDENING ----
/ip service set telnet disabled=yes
/ip service set ftp disabled=yes
/ip service set www disabled=yes
/ip service set www-ssl disabled=yes
/ip service set api disabled=yes
/ip service set api-ssl disabled=yes
/ip service set ssh address=10.10.99.0/24 disabled=no
/ip service set winbox address=10.10.99.0/24 disabled=no
/ip ssh set strong-crypto=yes password-authentication=yes-if-no-key
/ip neighbor discovery-settings set discover-interface-list=OOB
/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=OOB
/tool mac-server ping set enabled=no
/tool bandwidth-server set enabled=no
/ip proxy set enabled=no
/ip socks set enabled=no
/ip upnp set enabled=no
/ip cloud set ddns-enabled=no update-time=no
/user add name=$adminUser group=full password=$adminPass comment="Named administrator (verify then disable factory admin)"
:if ([:len [/file find name=$sshKeyFile]] > 0) do={ /user ssh-keys import public-key-file=$sshKeyFile user=$adminUser } else={ :log warning "Public SSH key absent: use WinBox on ether5 to import it later." }

# ---- SECTION M. WEEKLY ENCRYPTED BINARY BACKUP + REDACTED EXPORT ----
# The scheduled script will contain the encryption password in its source;
# use a separate, strong, alphanumeric backup passphrase. Off-router copies essential.
:global backupJob ("/system backup save name=router-weekly encryption=aes-sha256 password=\"" . $backupPass . "\"\r\n/export file=router-weekly-redacted\r\n:log info \"MASTER: weekly encrypted backup and export completed\"")
/system script add name=weekly-encrypted-backup policy=ftp,read,write,sensitive source=$backupJob
/system scheduler add name=weekly-encrypted-backup-schedule start-date=2026-11-15 start-time=03:00:00 interval=7d on-event=weekly-encrypted-backup policy=ftp,read,write,sensitive

# ---- SECTION N. ACTIVATE TAGGED BRIDGE / LOAD ADLIST ----
/interface bridge set br-clients vlan-filtering=yes
# Only bring clients online AFTER VLAN filtering and firewall default-deny are active.
/interface bridge port enable [find interface=ether2]
/interface bridge port enable [find interface=ether3]
/interface bridge port enable [find interface=ether4]
/interface bridge port enable [find interface=wifi1]
/interface bridge port enable [find interface=wifi1-iot5]
/interface bridge port enable [find interface=wifi2]
/interface wifi enable [find default-name=wifi1]
/interface wifi enable [find default-name=wifi2]
/interface wifi enable [find name=wifi1-iot5]
:onerror adErr in={ /ip dns adlist add url="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" ssl-verify=yes } do={ :log warning ("Adlist download problem; check NTP/DNS/connectivity: " . $adErr) }

# Forget setup globals in the router script environment. The uploaded RSC
# still contains secrets until YOU remove that file under WinBox -> Files.
:set adminUser
:set adminPass
:set sshKeyFile
:set wifiCountry
:set ssid20
:set pass20
:set ssid30
:set pass30
:set ssid40
:set pass40
:set wgPrivate
:set wgPublic
:set wgEndpoint
:set wgPort
:set wgAddress
:set backupPass
:set backupJob
:log warning "MASTER COMPLETE: test from ether5; then independently test each VLAN and Proton. Verify new admin before disabling factory admin."
