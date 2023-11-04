#!/bin/bash

# netector

redbg="\033[0;41m"
greenbg="\033[0;42m"
red="\033[0;31m"
redb="\033[0;91m"
yellow="\033[0;33m"
yellowb="\033[0;93m"
greenb="\033[0;92m" #9xm & 10xm = light
green="\033[0;32m"  #3xm & 4xm = dark
cyan="\033[0;36m"
cyanb="\033[0;96m"
gray="\033[0;37m"
clear="\033[0m"

maxmsec=1000
yellowmsec=800
greenmsec=500

function alert() {
    printf "\7"
    sleep 0.15
    printf "\7"
    sleep 0.15
    printf "\7"
}

function getColor() {
    if [[ $1 -lt $greenmsec ]]; then
        echo -n $greenb
    elif [[ $1 -lt $yellowmsec ]]; then
        echo -n $cyanb
    elif [[ $1 -lt $maxmsec ]]; then
        echo -n $yellowb
    else
        echo -n $redb
    fi
}

# function floatToDigit() (printf '%.0f' $1)
function floatToDigit() (echo ${1%\.*})

# function percent() (echo "$(awk 'BEGIN{print '$1'/'$2'*100}')")
function percent() {
    local val=$(echo "$1/$2*100" | bc -l)
    floatToDigit $val
}

function convertToChartVlaue() {
    local totalTimePercentage=$(percent $1 $2) # value maxValue
    # to fit the chart with 33 character hight window
    totalTimePercentage=$(($totalTimePercentage / 3))
    floatToDigit $totalTimePercentage
}

function chart() {
    local CHARTLINE=$(convertToChartVlaue $maxmsec $maxmsec) # get the highest value for chart
    local REDVALUE=$CHARTLINE
    local YELLOWVALUE=$(convertToChartVlaue $yellowmsec $maxmsec)
    local GREENVALUE=$(convertToChartVlaue $greenmsec $maxmsec)
    local VALUES=($@)              # all values in an array
    while [ $CHARTLINE -gt 0 ]; do # start the first line
        ((CHARTLINE--))
        local REDUCTION=$(($CHARTLINE)) # subtract this from the VALUE
        for VALUE in ${VALUES[@]}; do
            # CHARTVALUE=$(convertToChartVlaue $VALUE $maxmsec)
            local CHUNCK=$(($VALUE - $REDUCTION))
            if [ $CHUNCK -le 0 ]; then # check new VALUE
                echo -en "${gray}     "
            elif [[ $VALUE -le 0 ]]; then
                echo -en "${red}  -- ${gray}" # never happens
            elif [[ $VALUE -lt $GREENVALUE ]]; then
                echo -en "${green} ▓▓▓▓${gray}"
            elif [[ $VALUE -lt $YELLOWVALUE ]]; then
                echo -en "${cyan} ▓▓▓▓${gray}"
            elif [[ $VALUE -lt $REDVALUE ]]; then
                echo -en "${yellow} ▓▓▓▓${gray}"
            else
                echo -en "${red} ▓▓▓▓${gray}"
            fi
        done
        echo
    done
    echo
}

#testcmd=$(dig +timeout=3 +retry=1 google.com @8.8.8.8 | grep "Query time"| awk '{print ($4+0)}')
#testcmd=$(curl -o /dev/null -m3 -sw "%{time_total}" https://gmail.com/generate_204)

function cmd() {
    # user-agent: https://datatracker.ietf.org/doc/html/rfc9309#name-the-user-agent-line
    local userAgent="user-agent: curl/7.88.1 "
    userAgent+="(compatible; ConnectivityCheckBot/0.1; https://soon.example.com/bot/)"
    curl -o /dev/null -H "$userAgent" -m2 -sw "%{json}\n" https://gmail.com/generate_204
}

function toMiliSec() {
    local inputValue=0
    if [ "$#" -ne 0 ]; then
        inputValue=$1
    else
        inputValue=$(</dev/stdin)
    fi
    local testvalue=$(bc <<<$inputValue*1000) #seconds to miliseconds
    floatToDigit $testvalue                   #trim: ~ float to integer
}

function setTitleConnected() {
    printf '\e]2;%s\a' "Netector | $1 ms -- uptime $2 | mute: $3"
}

function setTitleDisconnected() {
    printf '\e]2;%s\a' "Netector | downtime $1 | mute: $2"
}

function clearInput() (while read -r -t 0; do read -r -t 3; done)

function toChartValues() {
    local VALUES=($@)
    local CHARTVALUES=()
    for VALUE in ${VALUES[@]}; do
        CHARTVALUES+=($(convertToChartVlaue $VALUE $maxmsec))
    done
    echo ${CHARTVALUES[@]}
}

function netector() {
    # tput smcup
    SECONDS=1
    local dis=false
    local disTemp=false
    local tailValues=()
    local chartValues=()
    local maxarray=15
    local mute=0
    local showGraph=1
    while true; do
        # echo
        # local result=$(
        #     { stdout=$(cmd); returncode=$?; } 2>&1
        #     printf ". . . - - - . . .\n"
        #     printf "%s\n" "$stdout"
        #     exit "$returncode"
        # )
        # local var_out=${result#*this line is the separator$'\n'}
        # local var_err=${result%$'\n'this line is the separator*}
        # local returncode=$?
        local resultjson=$(cmd)
        local exitCode=$(echo $resultjson | jq .exitcode)
        local errorMsg=$(echo $resultjson | jq .errormsg)

        # local lookupTime=$(echo $resultjson | jq .time_namelookup | toMiliSec)
        # local tcpHandshakeTime=$(
        #     echo $resultjson | jq .time_connect | toMiliSec | awk '{print $1-'$lookupTime'}'
        # )
        # local sslHandshakeTime=$(
        #     echo $resultjson | jq .time_appconnect | toMiliSec | awk '{print $1-'$tcpHandshakeTime'}'
        # )
        # local untilHttpStartTime=$(echo $resultjson | jq .time_starttransfer | toMiliSec)
        local totalTime=$(echo $resultjson | jq .time_total | toMiliSec)

        # local downloadSpeed=$(echo $resultjson | jq .speed_download)
        # local uploadSpeed=$(echo $resultjson | jq .speed_upload)

        # local responseCode=$(echo $resultjson | jq .response_code)
        # local remoteIp=$(echo $resultjson | jq .remote_ip)
        # local certs=$(echo $resultjson | jq .certs)
        # printf "\n\n"
        # clear
        local graphValue=0
        local txtColor=$gray
        local sleepValue=0
        local outputHead1=''
        local outputChart=''
        local outputTail=''
        if [[ $exitCode -gt 0 ]] && [[ $dis = false ]]; then
            # skip the first error (where there is a lot of noise)
            if [[ $disTemp = false ]]; then
                disTemp=true
                SECONDS=3 # set terminal's second counter to 3
            else
                dis=true
                [[ $mute -eq 0 ]] && alert
                SECONDS=6
            fi
            outputHead1=$(printf "${redbg} ❌ disconnected!!! :(( ${clear}")
            outputHead1+=$(printf "${red} ⚠️ $exitCode: $errorMsg ${clear}\n")
            tailValue=-1
            [[ $showGraph -eq 1 ]] && chartValue=-1
        elif [[ $exitCode -gt 0 ]]; then
            [[ $mute -eq 0 ]] && printf "\7"
            dis=true
            outputHead1=$(printf "${yellow} ❌ still disconnected!!! :(( ${clear}")
            outputHead1+=$(printf "${red} ⚠️ $exitCode: $errorMsg ${clear}\n")
            tailValue=-1
            [[ $showGraph -eq 1 ]] && chartValue=-1
            sleepValue=8
        elif [[ $dis = true ]]; then
            dis=false
            disTemp=false
            SECONDS=1
            [[ $mute -eq 0 ]] && alert
            outputHead1=$(printf "${greenbg} 📶 connected! :D ${clear}")
            txtColor=$cyanb
            tailValue=$totalTime
            [[ $showGraph -eq 1 ]] && chartValue=$(convertToChartVlaue $totalTime $maxmsec)
            sleepValue=1
        else
            disTemp=false
            tailValue=$totalTime
            [[ $showGraph -eq 1 ]] && chartValue=$(convertToChartVlaue $totalTime $maxmsec)
            txtColor=$(getColor $totalTime)

            sleepValue=1
        fi
        local elapsed=$(date -ud @${SECONDS} +"%H:%M:%S")
        if [[ $exitCode -eq 0 ]]; then
            outputHead1+=$(printf "${txtColor} 🔄 $totalTime ms ${clear}\n")
            outputHead1+=$(setTitleConnected $totalTime $elapsed $mute)
        else
            outputHead1+=$(setTitleDisconnected $elapsed $mute)
        fi
        local outputHead2=$(printf "${gray} 🔌 $elapsed${clear}\n")
        local tailValues+=($tailValue)
        [[ $showGraph -eq 1 ]] && chartValues+=($chartValue)
        if [[ ${#tailValues[@]} -gt $maxarray ]]; then
            tailValues=("${tailValues[@]:1}")
            chartValues=("${chartValues[@]:1}")
        fi
        if [[ $showGraph -eq 1 ]]; then
            # echo
            outputChart=$(chart ${chartValues[@]})
            outputTail=$(printf ' %-4s' "${tailValues[@]}")
        fi
        read -r -t .1 -sn 1 input
        if [[ $input == "m" ]] || [[ $input == "M" ]]; then
            ((mute ^= 1))
            clearInput
        elif [[ $input == "g" ]] || [[ $input == "G" ]]; then
            ((showGraph ^= 1))
            chartValues=($(toChartValues ${tailValues[@]}))
            # printf ' %-4s' "${chartValues[@]}"
            clearInput
            echo
        elif [[ $input == "q" ]] || [[ $input == "Q" ]]; then
            echo
            break
        else
            clearInput
        fi
        # read -d '' -t 0.6 -n 10000
        # sleep .4
        # tput clear
        [[ $showGraph -eq 1 ]] && printf "\n\n"
        echo "$outputHead"
        echo "$outputHead1"
        echo "$outputHead2"
        if [[ $showGraph -eq 1 ]]; then
            echo
            echo "$outputChart"
            echo
            echo -n "$outputTail"
        fi
        sleep $sleepValue
    done
    # tput rmcup
    exit
}

netector
