# hAP ax3 (C53UiG+5HPaxD2HPaxD) - RouterOS 7.25.x
# STAGE 1: RUN ONCE from ether2 while router has factory AP-router defconf.
# DO NOT run master until 10.10.99.1 IP WinBox works from ether5.
# ether5 stays physically OUT of every bridge.

:if ([:len [/interface bridge port find interface=ether5]] = 0) do={ :error "ether5 is already outside the bridge. Stop and inspect the existing configuration." }
:if ([:len [/ip address find address="10.10.99.1/24"]] > 0) do={ :error "OOB address already exists. Stop rather than duplicate configuration." }

# Keep the default input firewall from dropping management while bootstrapping.
:if ([:len [/interface list member find list=LAN interface=ether5]] = 0) do={ /interface list member add list=LAN interface=ether5 comment="TEMP OOB bootstrapping" }
/ip firewall filter add chain=input in-interface=ether5 protocol=udp dst-port=67 action=accept place-before=0 comment="TEMP OOB bootstrap DHCP"
/ip firewall filter add chain=input in-interface=ether5 src-address=10.10.99.0/24 protocol=tcp dst-port=22,8291 action=accept place-before=0 comment="TEMP OOB bootstrap SSH WinBox"
/ip firewall filter add chain=input in-interface=ether5 src-address=10.10.99.0/24 protocol=icmp action=accept place-before=0 comment="TEMP OOB bootstrap ping"
/ip firewall filter add chain=forward in-interface=ether5 action=drop place-before=0 comment="TEMP OOB bootstrap no forwarding"

/interface bridge port remove [find interface=ether5]
/ip address add address=10.10.99.1/24 interface=ether5 comment="OOB management only"
/ip pool add name=pool-oob ranges=10.10.99.10-10.10.99.50
/ip dhcp-server add name=dhcp-oob interface=ether5 address-pool=pool-oob lease-time=2h disabled=no
/ip dhcp-server network add address=10.10.99.0/24 gateway=10.10.99.1 comment="OOB: intentionally no DNS server"
/tool mac-server mac-winbox set allowed-interface-list=LAN
:log warning "OOB bootstrap ready: move cable to ether5, renew PC DHCP, verify 10.10.99.1 in a NEW WinBox session; only then run stage 2."
