#!/usr/bin/env bash

PID=$$
THISPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )""
KINANCITYPATH=$THISPATH
KINANCITY_JAR="KinanCity-core-1.3.3-SNAPSHOT.jar"

DATADIR="${THISPATH}/proxydata"

start_number=$1
end_number=$2
prefix=$3
maildomain=$4
proxy_amount=$5


initial_start_number=$start_number

function err(){
  printf "\e[38;05;160m [error] \e[0m %s\n" "$@"
}
function warn(){
  printf "\e[38;05;220m [warning] \e[0m %s\n" "$@"
}
function info(){
  printf "\e[38;05;15m [info] \e[0m %s\n" "$@"
}
function ws1(){
  echo -e "\n" 
}
function Time(){
  date "+%H:%M:%S"
}


if [[ $# -ne 5 ]] ; then
    ws1 ; err "I need more arguments" ; ws1 ; info "EXAMPLE USAGE: $0 2000 6000 blabla zoho.com 200" ; ws1 ; info "note: this example will create 4000 accounts from blabla2000 to blabla5999 on blabla####@maildomain.tld" ; ws1 ; ws1
    exit 1
fi


Date(){
	date "+%d-%m-%y" 
}
TimeStamp(){
	echo -e -n "$(Date) $(Time)"
}

if [ -w $THISPATH ]; then
  if [ ! -d ${DATADIR} ]; then
    mkdir ${DATADIR} 2>/dev/null
  fi
  datadirowner=$(stat -c %u "${DATADIR}") 
  if [ "${UID}" -ne "${datadirowner}" ]; then
	err "Your current account is not the owner of ${DATADIR}. Please make sure you use the correct user otherwise you will run into troubles"
  exit 1
  fi
fi

randomDay(){
local day=$(( ( RANDOM % 30 )  + 1 ))
(( day < 10 )) && day=0${day}
printf $day
}

randomMonth(){
local month=$(( ( RANDOM % 12 )  + 1 ))
(( $month < 10 )) && month=0${month}
printf $month
}

randomYear(){
local year=$(( ( RANDOM % 30 )  + 1 ))
year=$((1970 + year))
printf $year
}



createPTCAccounts(){
x=1
accounts=()

while (( start_number <= end_number )); do

username=${prefix}${start_number}
password="Qwerty01!"
email="${username}@${maildomain}"
dob="$(randomYear)-$(randomMonth)-$(randomDay)"
country="NL"
accounts+=("${username};${password};${email};${dob};${country}") 


    if [ $x -eq 100 ]; then   # This is the start of the [100] per-round batch

        # first create a csv for Kinan City
        csv=$((RANDOM)).csv
        csvfirstline='#username;password;email;dob;country'
        printf '%s\n' "${csvfirstline}" "${accounts[@]}" > "${csv}"

        # start / refresh tor proxies
        proxy_port=50000
        proxies=()

        for i in $(seq 0 $proxy_amount);do

            # control ports cannot be the same for all. So we use the uneven numbers for the proxy control ports
            proxy_control_port=$(( proxy_port + 1 ))

            # Start the actual proxies
	    echo -e "[DEBUG] proxy port = $proxy_port | proxy_control_port = $proxy_control_port | i = $i | datadir = ${DATADIR}/$proxy_port"
            tor --SocksPort $proxy_port --ControlPort $proxy_control_port --RunAsDaemon 1 --CookieAuthentication 0 --HashedControlPassword "" --PidFile tor$i.pid --DataDirectory "${DATADIR}/$proxy_port" &>/dev/null

            # let users know we started proxies

            info "Proxy http://localhost:${proxy_port} has started"
            # add proxies to the proxy line to be supplied to KinanCity
            proxies+=("socks5://127.0.0.1:$proxy_port, ")

            # increment the proxy port by 2 because we use even numbers for proxy ports
            proxy_port=$((proxy_port+2))

        done

        # reset i for the next round of proxy creation
        i=0

        # create the actual accounts using KinanCity-core
        java -jar "${KINANCITY_JAR}" -t 100 -nl -npc -a ${csv} -px $(printf '%s' "[" ${proxies[@]} "]" ) -ck 04fe42680e60edcc847b4d9fc3b1e899
	## -t 100

        # remove the temp csv
        rm -f "${csv}"

        # kill KinanCity-core when finished the batch
        pkill -f "[j]ava.+[K]inan"

        # kill the proxies
        pkill -f "[t]or.*[S]ocksPort" && info "Killed running proxies!" 

        # reset the accounts array
        accounts=()

        #  some sleep
        info "proceeding to the next batch"
        sleep 10
        x=0
        fi 

  # increment x by 1
  x=$(( x + 1 ))

  #increment start number by 1
  start_number=$(( start_number + 1 ))
done
return 0
}

running=true

cleanup_exit(){
  info "Cleanup started"
  rm -f [0-9]*.csv 
  # kill KinanCity-core if aborted
  pkill -f "[j]ava.+[K]inan"
  info "killed kinan"
  # kill the proxies if aborted
  pkill -f "[t]or.*[S]ocksPort" && info "Killed running proxies!" 
  info "killed proxies"


  ### SEPERATE ACCOUNTS -> MOVE GOOD ACCOUNTS TO A NEW CSV FILE IN MAPS FORMAT ( username,password,ptc )

  cat result.csv &>/dev/null | grep -E ";OK;" | sort | awk -F ';' '{ print $1","$2",ptc" }'  >> kinan_success_accounts_${prefix}${initial_start_number}-${prefix}${end_number}.csv &>/dev/null
  info "moved successfully created accounts to kinan_success_accounts_${prefix}${initial_start_number}-${prefix}${end_number}.csv"

  cat result.csv &>/dev/null | grep -E ";ERROR;"  >> kinan_failed_accounts_${prefix}${initial_start_number}-${prefix}${end_number}.csv
  rm -f result.csv
  info "moved failed accounts to kinan_success_accounts_${prefix}${initial_start_number}-${prefix}${end_number}.csv"

  info "Done!"
  info "Exiting now" 
  exit 0
}

pausejob(){
  running=false
  info "paused"
  until $running ; do
  sleep 10
  done
  return 0
}

resumejob(){
 running=true
 info "running"
 return 0
}

trap cleanup_exit SIGTERM SIGINT SIGQUIT
trap resumejob SIGCONT
trap pausejob SIGTSTP

createPTCAccounts || cleanup_exit


