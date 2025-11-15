# Script: loadGeositeRules
# RouterOS: 7.20+
# Description: Parse domain list files and store them into global variable "geositeRules"

:global geositeRules

# --- CONFIG ---
:global geositePath;  # "geosite/"
:global geositeFiles; # {"anthropic";"groq";"openai";google-gemini"]
# https://github.com/v2ray/domain-list-community/tree/master/data

# initialize
:set geositeRules [:toarray ""]

# --- function: escape "." character ---
:local escapeDot do={
    :local str $1
    :local result ""
    :for i from=0 to=([:len $str] - 1) do={
        :local ch [:pick $str $i ($i + 1)]
        :if ($ch = ".") do={
            :set result ($result . "\\.")
        } else={
            :set result ($result . $ch)
        }
    }
    :return $result
}

# --- function: process file (recursive) ---
# Named arguments:
# * fileName - Name file inside $geositePath 
# * processFile - self for recursion
# * escape – function for escaping dots
:local processFile do={
    :global geositeRules
    :global geositePath
    :local filePath ($geositePath . $fileName)
    :local f [/file find where name=$filePath]
    :if ([:len $f] = 0) do={
        :log error "[Load Domains] File not found: $filePath"
        :return $filePath
    }

    :log info "[Load Domains] Read $filePath ..."
    :local content [/file get $filePath contents]

    :foreach line in=[:deserialize [:tolf $content] from=dsv delimiter="\n" options=dsv.plain] do={
        :set line [:tostr $line]
        :if ([:len $line] > 1 && [:pick $line 0 1] != "#") do={
            # split rule line
            :local rule
            :local value
            if ([:find $line ":"] > 1) do={
                :set rule [:pick $line 0 [:find $line ":"]];
                :set value [:pick $line ([:find $line ":"]+1) [:len $line]];
            } else={
                :set rule "domain";
                :set value $line;
            }

            # handle include
            :if ($rule = "include") do={
                :log debug "[Load Domains] Import file: $value ..."
                $processFile fileName=$value processFile=$processFile escape=$escape
                :set $rule "continue"
            }

            # add rule to array
            :if ([:find {"domain";"keyword";"regexp";"full"} $rule] >= 0) do={
                # remove attributes
                :if ([:find $value " "] > 1) do={
                    :set value [:pick $value 0 [:find $value " "]]
                }

                # generate rule match
                :local match $value
                if ([:find {"domain";"keyword";"regexp"} $rule] >= 0) do={
                    :set match [$escape $value] 
                }
                if ($rule = "domain") do={
                    :set match "$match\$"
                }
                if ($rule = "keyword") do={
                    :set match ".*$match.*"
                }

                # store rule
                :local existing ($geositeRules->$fileName)
                :if ([:typeof ($geositeRules->$fileName)] = "nothing") do={
                    :log debug "[Load Domains] set new '$fileName', $rule=$value, match=$match"
                    :set ($geositeRules->$fileName) ($rule . "=" . $value . "::" . $match)
                } else={
                    :log debug "[Load Domains] update '$fileName', add $rule=$value, match=$match"
                    :set ($geositeRules->$fileName) ($existing , ($rule . "=" . $value . "::" . $match))
                }
                :set rule "set";
            }

            # check for unknown rule
            :if ([:find {"continue";"set"} $rule] < 0) do={
                :log warning "[Load Domains] unknown rule: $line"
            }
        }

    }
}

# --- MAIN ---
:foreach fileName in=$geositeFiles do={
    $processFile fileName=$fileName processFile=$processFile escape=$escapeDot
}

:log info "[Load Domains] Loaded domain rules from: $geositePath"
:log info "[Load Domains] Files loaded: $[:len $geositeRules]"
