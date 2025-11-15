# Script: checkDnsCacheAndAddToACL
# RouterOS: 7.20+
# Description: Scan DNS cache and add matching IPs to Access List with auto-renewal

:global domainRules

# --- CONFIG ---
:local accessListName "vpnDomains"
:local leaseTime "7d"
:local renewThresholdTime "2d"

# --- function: update acl ---
#
# Named arguments:
# * comment - comment for ip address
# * matches – array with dns cache entries
# * acl – access list name
# * lease – access list entry timeout
# * renew – access list entry timeout renew threshold

:local aclUpdate do={
    :log debug "Proceed $comment ($[:len $matches])"

    :foreach dns in=$matches do={

        :local addr [/ip/dns/cache get $dns data]
        :local existing [/ip/firewall/address-list find where list=$acl and address=$addr and comment=$comment]

        :if ([:len $existing] > 0) do={
            :local currentTimeout [/ip/firewall/address-list get $existing timeout]
            :if ($currentTimeout != "") do={
                :if ($currentTimeout < [:totime $renew]) do={
                    :log debug "[DNS ACL] Refresh timeout for $addr ($comment)"
                    /ip/firewall/address-list set $existing timeout=[:totime $lease]
                }
            }
        } else={
            :log info "[DNS ACL] Add $addr to $acl ($comment)"
            /ip/firewall/address-list add list=$acl address=$addr comment=$comment timeout=[:totime $lease]
        }
    }
}

# --- MAIN ---
:foreach fileName,rules in=$domainRules do={
    :foreach k,v in=$rules do={
        :local rule [:pick $v 0 [:find $v "="]]
        :local value [:pick $v ([:find $v "="]+1) [:find $v "::"]]
        :local match [:pick $v ([:find $v "::"]+2) [:len $v]]
        :local comment "geocite::$fileName::$rule::$value"
        :local dnsMatches

        :if ([:find {"domain";"keyword";"regexp"} $rule] >= 0) do={
            :set dnsMatches [/ip/dns/cache all find where (name~$match) && ((type="A") || (type="AAAA"))]
            :if ([:len $dnsMatches] > 0) do={
                $aclUpdate matches=$dnsMatches comment=$comment acl=$accessListName lease=$leaseTime renew=$renewThresholdTime
            }
        }
        :if ($rule = "full") do={
            :set dnsMatches [/ip/dns/cache all find where (name=$match) && ((type="A") || (type="AAAA"))]
            :if ([:len $dnsMatches] > 0) do={
                $aclUpdate matches=$dnsMatches comment=$comment acl=$accessListName lease=$leaseTime renew=$renewThresholdTime
            }
        }
    }
}