# Script: checkDnsCacheAndAddToACL
# RouterOS: 7.20+
# Description: Scan DNS cache and add matching IPs to Access List with auto-renewal

:global geositeRules

# --- CONFIG ---
:global accessListName "vpnDomains"
:global leaseTime "7d"
:global renewThresholdTime "3d"

# --- function: update v4 acl ---
#
# Named arguments:
# * comment - comment for ip address
# * matches – array with dns cache entries
# * acl – access list name
# * lease – access list entry timeout
# * renew – access list entry timeout renew threshold

:local aclUpdate do={
    :log debug "[DNS ACL] Proceed $comment ($[:len $matches])"

    :foreach dns in=$matches do={

        :local addr [/ip/dns/cache get $dns data]
        :local atype [/ip/dns/cache get $dns type]
        :if ($atype="A") do={
            :set addr [:toip [/ip/dns/cache get $dns data]]
        } else {
            :set addr [:toip6 [/ip/dns/cache get $dns data]]
        }

        :if ($atype = "A") do={
            :local existing [/ip/firewall/address-list find where list=$acl and address=$addr]; # and comment=$comment]
            :if ([:len $existing] > 0) do={
                :local currentTimeout [/ip/firewall/address-list get $existing timeout]
                :if ($currentTimeout != "") do={
                    :if ($currentTimeout < [:totime $renew]) do={
                        :log debug "[DNS ACL] Refresh timeout for IPv4:$addr ($comment)"
                        /ip/firewall/address-list set $existing timeout=[:totime $lease]
                    }
                }
            } else={
                :log info "[DNS ACL] Add IPv4:$addr to $acl ($comment)"
                :onerror e in={
                    /ip/firewall/address-list add list=$acl address=$addr comment=$comment timeout=[:totime $lease]
                } do={
                    :log error "Can't add IPv4:$addr to $acl: $e"
                }
            }
        } else {
            :local existing [/ipv6/firewall/address-list find where list=$acl and address=$addr]; # and comment=$comment]
            # TODO: Mikrotik didn't search in IPv6 address-list. Find solution.
            :if ([:len $existing] > 0) do={
                :local currentTimeout [/ipv6/firewall/address-list get $existing timeout]
                :if ($currentTimeout != "") do={
                    :if ($currentTimeout < [:totime $renew]) do={
                        :log debug "[DNS ACL] Refresh timeout for IPv6:$addr ($comment)"
                        /ipv6/firewall/address-list set $existing timeout=[:totime $lease]
                    }
                }
            } else={
                :log info "[DNS ACL] Add IPv6:$addr to $acl ($comment)"
                :onerror e in={
                    /ipv6/firewall/address-list add list=$acl address=$addr comment=$comment timeout=[:totime $lease]
                } do={
                    :log error "Can't add IPv6:$addr to $acl: $e"
                }
            }        
        }
    }
}

# --- MAIN ---
:foreach fileName,rules in=$geositeRules do={
    :foreach k,v in=$rules do={
        :local rule [:pick $v 0 [:find $v "="]]
        :local value [:pick $v ([:find $v "="]+1) [:find $v "::"]]
        :local match [:pick $v ([:find $v "::"]+2) [:len $v]]
        :local comment "geocite::$fileName::$rule::$value"
        :local dnsMatches

        :if ([:find {"domain";"keyword";"regexp"} $rule] >= 0) do={
            :set dnsMatches [/ip/dns/cache all find where name~$match and (type="A" or type="AAAA")]
            :if ([:len $dnsMatches] > 0) do={
                $aclUpdate matches=$dnsMatches comment=$comment acl=$accessListName lease=$leaseTime renew=$renewThresholdTime
            }
        }
        :if ($rule = "full") do={
            :set dnsMatches [/ip/dns/cache all find where name=$match and (type="A" or type="AAAA")]
            :if ([:len $dnsMatches] > 0) do={
                $aclUpdate matches=$dnsMatches comment=$comment acl=$accessListName lease=$leaseTime renew=$renewThresholdTime
            }
        }
    }
}