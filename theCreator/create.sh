#!/usr/bin/env bash

PID=$$
THISPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
KINANCITYPATH=$THISPATH
KINANCITY_JAR="KinanCity-core-1.4.2-SNAPSHOT.jar"

DATADIR="${THISPATH}/proxydata"
##################
# DONT FORGET TO SETUP AND CONFIGURE TOR
##################
start_number=$1
end_number=$2
prefix=$3
maildomain=$4
proxy_amount=$5
###################
maildomains=('mycatchalldomain.xyz', 'lalala@mydomain.tld') # only use if you want to use multiple/different domains (not neccesary)
multimaildomain=0 # set to if above is applicable

initial_start_number=$start_number


function Time(){
  date "+%H:%M:%S"
}

logger(){
case $1 in
'error'|'ERROR')
    echo -e "[${DATE} ${TIME}][\e[1;31m error \e[0m] $2\n" ; ;;
'warning'|'WARNING'|'warn'|'WARN')
    echo -e "[${DATE} ${TIME}][\e[1;31m warning \e[0m] $2\n" ; ;;
'success'|'SUCCESS'|'ok'|'OK')
    echo -e "[${DATE} ${TIME}][\e[1;31m ok! \e[0m] $2\n" ; ;;
'info'|'INFO')
    echo -e "\e[0m$2"; ;;
esac
}

if [[ $# -ne 5 ]] ; then
    logger error "I need more arguments" ; logger info "EXAMPLE USAGE: $0 2000 6000 blabla myzohodomain.com 75" ; 
    logger info "note: this example will create 4000 accounts from blabla2000 to blabla5999 on blabla####@myzohodomain.com using 75 proxies per 100 accounts" ;
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
	logger error "Your current account is not the owner of ${DATADIR}. Please make sure you use the correct user otherwise you will run into troubles"
  exit 1
  fi
fi

randomDay(){
local day=$(( ( RANDOM % 27 )  + 1 ))
(( day < 10 )) && day=0${day}
printf $day
}

randomMonth(){
local month=$(( ( RANDOM % 12 )  + 1 ))
(( $month < 10 )) && month=0${month}
printf $month
}

randomYear(){
local year=$(( ( RANDOM % 25 )  + 1 ))
year=$((1970 + year))
printf $year
}



createPTCAccounts(){
  x=1
  accounts=()

  while (( start_number <= end_number )); do

    multi_maindomains=0 # set to 1 if true
    username=${prefix}${start_number}
    password="Qwerty01!"
    email="${username}@${maildomain}"

    if [ $multi_maindomains == 1 ];then
      maildomain=${maildomains[$RANDOM % ${#maildomains[@]}]}
      email="${username@{maildomain}"
    fi
    
  
    dob="$(randomYear)-$(randomMonth)-$(randomDay)"
    country="NL"
    accounts+=("${username};${password};${email};${dob};${country}") 


    if [ $x -eq 100 ]; then   # This is the start of the [100] per-round batch

        # first create a csv for Kinan City
        csv=$((RANDOM)).csv
        csvfirstline='#username;password;email;dob;country'
        printf '%s\n' "${csvfirstline}" "${accounts[@]}" > "${csv}"

        # start / refresh tor proxies
        proxy_port=60000
        proxies=()

        for i in $(seq 0 $proxy_amount);do

            # control ports cannot be the same for all. So we use the uneven numbers for the proxy control ports
            proxy_control_port=$(( proxy_port + 1 ))

            # Start the actual proxies
            #echo -e "[DEBUG] proxy port = $proxy_port | proxy_control_port = $proxy_control_port | i = $i | datadir = ${DATADIR}/$proxy_port"
            tor --SocksPort $proxy_port --ControlPort $proxy_control_port --RunAsDaemon 1 --CookieAuthentication 0 --HashedControlPassword "" --PidFile tor$i.pid --DataDirectory "${DATADIR}/$proxy_port" &>/dev/null 

            # let users know we started proxies

            logger info "Proxy http://localhost:${proxy_port} has started"
            # add proxies to the proxy line to be supplied to KinanCity
            proxies+=("socks5://127.0.0.1:$proxy_port, ")

            # increment the proxy port by 2 because we use even numbers for proxy ports
            proxy_port=$((proxy_port+2))

        done


        tmp_end_number="$((start_number + x))"
        # reset i for the next round of proxy creation

        i=0
        

        # create the actual accounts using KinanCity-core
        java -jar "${KINANCITY_JAR}" -t 40 -nl -npc -a ${csv} -px $(printf '%s' "[" ${proxies[@]} "]" ) ; kinanpid=$!


        # remove the temp csv
        logger info "removing temp csv containing the accounts to be made"
        rm -f "${csv}"
        logger success "done"


       
        
        SUCCESSFUL_ACCOUNTS=$(cat result.csv | grep -E ";OK" | awk -F ';' '{ print $1","$2",ptc" }')
        SUCCESSFUL_ACCOUNTNAMES=$(printf "%s\n" ${SUCCESSFUL_ACCOUNTS} | awk -F ',' '{ print $1 }')
        FIRST_SUCCESSFUL_ACCOUNT=${SUCCESSFUL_ACCOUNTNAMES%%$'\n'*}
        LAST_SUCCESSFUL_ACCOUNT=${SUCCESSFUL_ACCOUNTNAMES##*$'\n'}

        logger info "creating temporary results file for account ${start_number} until $((start_number + x))"
        printf "%s\n" ${SUCCESSFUL_ACCOUNTS} | sort -V > "result_tmp_${prefix}${start_number}-$((start_number + x)).csv"
        logger success "done"

        logger info "appending original results.csv content to result_kinan_official.csv"
        cat result.csv >> result_kinan_official.csv
        logger info "removing result.csv"
        rm -f result.csv 
        logger success "done"

        logger info "killing kinancity - pid : $kinanpid"
        kill -9 $kinanpid &>/dev/null
        logger success "done"

        # kill the proxies
        logger info 'killing proxies'
        pkill -f "[t]or.*[S]ocksPort.*600" && logger info "Killed running proxies!" &>/dev/null
        logger success "done"
        # reset the accounts array
        accounts=()

        #  some sleep
        logger info "proceeding to the next batch"
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
  logger info "Cleanup started"
  rm -f [0-9]*.csv 
  # kill KinanCity-core if aborted
  pkill -f "[j]ava.+[K]inan"
  logger info "killed kinan"
  # kill the proxies if aborted
  pkill -f "[t]or.*[S]ocksPort*600.*" && logger info "Killed running proxies!" 
  logger info "killed proxies"


  ### SEPERATE ACCOUNTS -> MOVE GOOD ACCOUNTS TO A NEW CSV FILE IN MAPS FORMAT ( username,password,ptc )
  logger info "concatenating all the result_tmp_* files to one file : ${prefix}${initial_start_number}-${prefix}${tmp_end_number}.csv"
  cat "result_tmp_*" >> "${prefix}${initial_start_number}_${prefix}${end_number}.csv" 2>/dev/null
  rm -f "result_tmp_*" 2>/dev/null
  logger success "Done!"
  logger info "Exiting now" 
  exit 0
}

pausejob(){
  running=false
  logger info "paused"
  until $running ; do
  sleep 10
  done
  return 0
}

resumejob(){
 running=true
 logger info "running"
 return 0
}

trap cleanup_exit SIGTERM SIGINT SIGQUIT
trap resumejob SIGCONT
trap pausejob SIGTSTP

createPTCAccounts
cleanup_exit


