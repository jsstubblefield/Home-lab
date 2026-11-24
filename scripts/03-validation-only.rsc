# hAP ax3: read-only audit commands after 02-master-configuration.rsc
/system resource print
/interface bridge print detail
/interface bridge port print detail
/interface bridge vlan print detail
/interface vlan print
/interface wifi print detail
/ip address print
/ip dhcp-server print
/ip dhcp-client print detail
/ip dns print
/ip dns adlist print
/interface wireguard print
/interface wireguard peers print detail
/routing rule print
/ip route print detail where routing-table=proton_wg
/ip firewall filter print stats
/ip firewall nat print stats
/ip service print
/tool mac-server mac-winbox print
/user print
/system scheduler print
/log print where topics~"error|warning"
