# ============================================================================
# hAP ax3 (C53UiG+5HPaxD2HPaxD) - RouterOS 7.25.x, wifi-qcom
# STAGE 2: IMPORT ONCE FROM VERIFIED ETHER5 OOB IP WINBOX SESSION.
# Intended ONLY for factory AP-router defconf AFTER 01-ether5-bootstrap.rsc.
# NOT A GENERIC RE-APPLICABLE / UPGRADE SCRIPT.
# Secret characters: use long alphanumeric/underscore/hyphen passwords to avoid
# RouterOS string interpolation inside the generated backup scheduler script.
# Upload SSH public key (not private key) to Files before running.
# Import with /import file-name=02-master-configuration.rsc verbose=yes dry-run
# Then /import file-name=02-master-configuration.rsc verbose=yes
# ============================================================================

# ---- SECTION A. FILL IN SECRETS AND PREFERENCES IN THIS FILE ----
:global adminUser "myadmin"
:global adminPass "REPLACE_WITH_LONG_ADMIN_PASSWORD"
:global sshKeyFile "id_ed25519.pub"
:global wifiCountry "United States"
:global ssid20 "Home-Mobile-5G"
:global pass20 "REPLACE_WITH_MOBILE_5G_PASSWORD"
:global ssid30 "Home-IoT-5G"
:global pass30 "REPLACE_WITH_IOT_5G_PASSWORD"
:global ssid40 "Home-IoT-24G"
:global pass40 "REPLACE_WITH_IOT_24G_PASSWORD"
:global wgPrivate "REPLACE_WITH_PROTON_WG_PRIVATE_KEY"
:global wgPublic "REPLACE_WITH_PROTON_WG_PEER_PUBLIC_KEY"
:global wgEndpoint "REPLACE_WITH_PROTON_WG_ENDPOINT_IP"
:global wgPort 51820
:global wgAddress "10.2.0.2/30"
:global backupPass "REPLACE_WITH_LONG_BACKUP_PASSWORD"

# ---- SECTION B. FAIL FAST BEFORE MODIFYING THE ROUTER ----
:if ([:len [/interface bridge find name=br-clients]] > 0) do={ :error "br-clients exists; master is one-time only. Inspect the partial config before retrying." }
:if ([:len [/interface bridge find name=bridge]] = 0) do={ :error "Expected factory bridge 'bridge' is absent. Do not run over an unknown configuration." }
:if ([:len [/interface list find name=WAN]] = 0) do={ :error "Expected factory WAN interface list is missing." }
:if ([:len [/ip firewall filter find where comment~"defconf"]] = 0) do={ :error "Expected factory defconf filter rules missing; stop before appending replacement rules." }
:if ([:len [/ip firewall nat find where comment~"defconf"]] = 0) do={ :error "Expected factory defconf NAT rule missing; stop before replacing NAT." }
:if ([:len [/interface bridge port find interface=ether5]] > 0) do={ :error "ether5 is in a bridge; run/validate bootstrap first." }
:if ([:len [/ip address find interface=ether5 address="10.10.99.1/24"]] = 0) do={ :error "OOB address is missing; run bootstrap first." }
:if ([:len [/interface wifi find default-name=wifi1]] = 0) do={ :error "wifi1 missing; check wifi-qcom installation." }
:if ([:len [/interface wifi find default-name=wifi2]] = 0) do={ :error "wifi2 missing; check wifi-qcom installation." }
:if ([:len [/interface wifi find name=wifi1-iot5]] > 0) do={ :error "Virtual WiFi name already exists; stop and inspect." }
:if ($adminUser="admin") do={ :error "Use a new named administrator; do not replace the factory admin here." }
:if ([:len [/user find name=$adminUser]] > 0) do={ :error "Chosen admin already exists. Stop and inspect." }
:if (($adminPass="REPLACE_WITH_LONG_ADMIN_PASSWORD") || ([:len $adminPass] < 16)) do={ :error "Set an admin password of at least 16 characters." }
:if (($pass20="REPLACE_WITH_MOBILE_5G_PASSWORD") || ([:len $pass20] < 12)) do={ :error "Set the VLAN20 WiFi password." }
:if (($pass30="REPLACE_WITH_IOT_5G_PASSWORD") || ([:len $pass30] < 12)) do={ :error "Set the VLAN30 WiFi password." }
:if (($pass40="REPLACE_WITH_IOT_24G_PASSWORD") || ([:len $pass40] < 12)) do={ :error "Set the VLAN40 WiFi password." }
:if ($wgPrivate="REPLACE_WITH_PROTON_WG_PRIVATE_KEY") do={ :error "Set the Proton client private key." }
:if ($wgPublic="REPLACE_WITH_PROTON_WG_PEER_PUBLIC_KEY") do={ :error "Set the Proton peer public key." }
:if ($wgEndpoint="REPLACE_WITH_PROTON_WG_ENDPOINT_IP") do={ :error "Set the Proton endpoint IP from its .conf file." }
:if (($backupPass="REPLACE_WITH_LONG_BACKUP_PASSWORD") || ([:len $backupPass] < 24)) do={ :error "Set a backup passphrase of at least 24 characters." }

# ---- SECTION C. CREATE NEW L3 INTERFACE LISTS (LEAVE defconf ALONE FOR NOW) ----
/interface list add name=OOB comment="Management ONLY on physical ether5"
/interface list add name=CLIENT_VLANS comment="Client-facing routed VLANs"
/interface list add name=VPN_VLANS comment="Fail-closed Proton clients"
/interface list add name=IOT_VLANS comment="Untrusted IoT VLANs"
/interface list member add list=OOB interface=ether5
:if ([:len [/interface list member find list=WAN interface=ether1]] = 0) do={ /interface list member add list=WAN interface=ether1 }

# ---- SECTION D. WAN / BRIDGE / ROUTED VLAN INTERFACES ----
:if ([:len [/ip dhcp-client find interface=ether1]] = 0) do={ /ip dhcp-client add interface=ether1 add-default-route=yes use-peer-dns=no use-peer-ntp=no disabled=no } else={ /ip dhcp-client set [find interface=ether1] add-default-route=yes use-peer-dns=no use-peer-ntp=no disabled=no }
/interface bridge add name=br-clients vlan-filtering=no frame-types=admit-only-vlan-tagged comment="VLAN aware client bridge; no OOB port"
/interface vlan add interface=br-clients name=vlan10-pc vlan-id=10 comment="PC-only; NOT management"
/interface vlan add interface=br-clients name=vlan20-mobile vlan-id=20
/interface vlan add interface=br-clients name=vlan30-iot5 vlan-id=30
/interface vlan add interface=br-clients name=vlan40-iot24 vlan-id=40
/interface list member add list=CLIENT_VLANS interface=vlan10-pc
/interface list member add list=CLIENT_VLANS interface=vlan20-mobile
/interface list member add list=CLIENT_VLANS interface=vlan30-iot5
/interface list member add list=CLIENT_VLANS interface=vlan40-iot24
/interface list member add list=VPN_VLANS interface=vlan20-mobile
/interface list member add list=VPN_VLANS interface=vlan30-iot5
/interface list member add list=VPN_VLANS interface=vlan40-iot24
/interface list member add list=IOT_VLANS interface=vlan30-iot5
/interface list member add list=IOT_VLANS interface=vlan40-iot24

# ---- SECTION E. IPv4 SUBNETS + DHCP (OOB DHCP ALREADY EXISTS) ----
/ip address add address=10.10.10.1/24 interface=vlan10-pc comment="PC VLAN 10 gateway"
/ip address add address=10.10.20.1/24 interface=vlan20-mobile
/ip address add address=10.10.30.1/24 interface=vlan30-iot5
/ip address add address=10.10.40.1/24 interface=vlan40-iot24
/ip pool add name=pool10 ranges=10.10.10.10-10.10.10.250
/ip pool add name=pool20 ranges=10.10.20.10-10.10.20.250
/ip pool add name=pool30 ranges=10.10.30.10-10.10.30.250
/ip pool add name=pool40 ranges=10.10.40.10-10.10.40.250
/ip dhcp-server add name=dhcp10 interface=vlan10-pc address-pool=pool10 lease-time=8h disabled=no
/ip dhcp-server add name=dhcp20 interface=vlan20-mobile address-pool=pool20 lease-time=8h disabled=no
/ip dhcp-server add name=dhcp30 interface=vlan30-iot5 address-pool=pool30 lease-time=8h disabled=no
/ip dhcp-server add name=dhcp40 interface=vlan40-iot24 address-pool=pool40 lease-time=8h disabled=no
/ip dhcp-server network add address=10.10.10.0/24 gateway=10.10.10.1 dns-server=10.10.10.1
/ip dhcp-server network add address=10.10.20.0/24 gateway=10.10.20.1 dns-server=10.10.20.1
/ip dhcp-server network add address=10.10.30.0/24 gateway=10.10.30.1 dns-server=10.10.30.1
/ip dhcp-server network add address=10.10.40.0/24 gateway=10.10.40.1 dns-server=10.10.40.1

# ---- SECTION F. WIFI SECURITY + BSS (NO DYNAMIC VLAN TAGGING) ----
# We place each WiFi BSS into an untagged bridge access port with the right PVID.
/interface wifi security add name=sec20 authentication-types=wpa2-psk,wpa3-psk passphrase=$pass20 wps=disable
/interface wifi security add name=sec30 authentication-types=wpa2-psk,wpa3-psk passphrase=$pass30 wps=disable
/interface wifi security add name=sec40 authentication-types=wpa2-psk passphrase=$pass40 wps=disable
/interface wifi datapath add name=dp-client-bridge-managed client-isolation=no
/interface wifi set [find default-name=wifi1] configuration.mode=ap configuration.ssid=$ssid20 configuration.country=$wifiCountry channel.band=5ghz-ax security=sec20 datapath=dp-client-bridge-managed disabled=yes
/interface wifi add name=wifi1-iot5 master-interface=wifi1 configuration.mode=ap configuration.ssid=$ssid30 security=sec30 datapath=dp-client-bridge-managed disabled=yes
/interface wifi set [find default-name=wifi2] configuration.mode=ap configuration.ssid=$ssid40 configuration.country=$wifiCountry channel.band=2ghz-ax security=sec40 datapath=dp-client-bridge-managed disabled=yes

# ---- SECTION G. ACCESS PORTS AND EXPLICIT VLAN MEMBERSHIP ----
# Re-home existing defconf bridge ports rather than deleting them blindly.
:if ([:len [/interface bridge port find interface=ether2]] > 0) do={ /interface bridge port set [find interface=ether2] bridge=br-clients pvid=10 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes } else={ /interface bridge port add bridge=br-clients interface=ether2 pvid=10 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes }
:if ([:len [/interface bridge port find interface=ether3]] > 0) do={ /interface bridge port set [find interface=ether3] bridge=br-clients pvid=20 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes } else={ /interface bridge port add bridge=br-clients interface=ether3 pvid=20 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes }
:if ([:len [/interface bridge port find interface=ether4]] > 0) do={ /interface bridge port set [find interface=ether4] bridge=br-clients pvid=30 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes } else={ /interface bridge port add bridge=br-clients interface=ether4 pvid=30 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes }
:if ([:len [/interface bridge port find interface=wifi1]] > 0) do={ /interface bridge port set [find interface=wifi1] bridge=br-clients pvid=20 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes } else={ /interface bridge port add bridge=br-clients interface=wifi1 pvid=20 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes }
:if ([:len [/interface bridge port find interface=wifi1-iot5]] > 0) do={ /interface bridge port set [find interface=wifi1-iot5] bridge=br-clients pvid=30 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes } else={ /interface bridge port add bridge=br-clients interface=wifi1-iot5 pvid=30 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes }
:if ([:len [/interface bridge port find interface=wifi2]] > 0) do={ /interface bridge port set [find interface=wifi2] bridge=br-clients pvid=40 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes } else={ /interface bridge port add bridge=br-clients interface=wifi2 pvid=40 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged disabled=yes }
/interface bridge vlan add bridge=br-clients vlan-ids=10 tagged=br-clients untagged=ether2
/interface bridge vlan add bridge=br-clients vlan-ids=20 tagged=br-clients untagged=ether3,wifi1
/interface bridge vlan add bridge=br-clients vlan-ids=30 tagged=br-clients untagged=ether4,wifi1-iot5
/interface bridge vlan add bridge=br-clients vlan-ids=40 tagged=br-clients untagged=wifi2

# ---- SECTION H. TIME, IPv6, DNS (WITH VALIDATED TLS) ----
/system clock set time-zone-autodetect=yes
/system ntp client set enabled=yes
/system ntp client servers add address=162.159.200.1
/system ntp client servers add address=162.159.200.123
/ipv6 settings set disable-ipv6=yes
/ip dns static add name=cloudflare-dns.com type=A address=1.1.1.1 comment="Pinned DoH bootstrap name"
/ip dns set servers=1.1.1.1,1.0.0.1 use-doh-server="https://cloudflare-dns.com/dns-query" verify-doh-cert=yes allow-remote-requests=yes cache-size=32768KiB

# ---- SECTION I. PROTON WIREGUARD: FAIL-CLOSED (NO ISP FALLBACK) ----
/interface wireguard add name=wg-proton mtu=1420 listen-port=13231 private-key=$wgPrivate comment="ProtonVPN exit; fail closed"
/interface wireguard peers add interface=wg-proton public-key=$wgPublic endpoint-address=$wgEndpoint endpoint-port=$wgPort allowed-address=0.0.0.0/0 persistent-keepalive=25s
/ip address add address=$wgAddress interface=wg-proton
/routing table add name=proton_wg fib
/ip route add dst-address=0.0.0.0/0 gateway=10.2.0.1@main routing-table=proton_wg distance=1 comment="Proton WG for VLAN20/30/40 ONLY"
# Keep locally addressed packets on main; the forward firewall still denies unauthorized cross-VLAN flows.
/routing rule add dst-address=10.10.0.0/16 action=lookup-only-in-table table=main comment="Resolve local networks in main"
/routing rule add src-address=10.10.20.0/24 action=lookup-only-in-table table=proton_wg comment="VLAN20 no WAN fallback"
/routing rule add src-address=10.10.30.0/24 action=lookup-only-in-table table=proton_wg comment="VLAN30 no WAN fallback"
/routing rule add src-address=10.10.40.0/24 action=lookup-only-in-table table=proton_wg comment="VLAN40 no WAN fallback"
/ip firewall mangle add chain=forward out-interface=wg-proton protocol=tcp tcp-flags=syn action=change-mss new-mss=clamp-to-pmtu comment="MASTER: WG TCP MSS clamp"

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
