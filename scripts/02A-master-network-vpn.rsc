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
:if (($pass20="REPLACE_WITH_MOBILE_5G_PASSWORD") || ([:len $pass20] < 12)) do={ :error "Set the VLAN20 WiFi password." }
:if (($pass30="REPLACE_WITH_IOT_5G_PASSWORD") || ([:len $pass30] < 12)) do={ :error "Set the VLAN30 WiFi password." }
:if (($pass40="REPLACE_WITH_IOT_24G_PASSWORD") || ([:len $pass40] < 12)) do={ :error "Set the VLAN40 WiFi password." }
:if ($wgPrivate="REPLACE_WITH_PROTON_WG_PRIVATE_KEY") do={ :error "Set the Proton client private key." }
:if ($wgPublic="REPLACE_WITH_PROTON_WG_PEER_PUBLIC_KEY") do={ :error "Set the Proton peer public key." }
:if ($wgEndpoint="REPLACE_WITH_PROTON_WG_ENDPOINT_IP") do={ :error "Set the Proton endpoint IP from its .conf file." }

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

:log warning "STAGE 2A COMPLETE: all client bridge ports and WiFi are still disabled. Commit Safe Mode; import stage 2B."
