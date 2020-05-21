#!/usr/bin/env bash

BOLD=$(tput bold)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

PLUGIN="@alessiodf/core-chameleon"
LOG=$(mktemp /tmp/core-chameleon.XXX.log)

abort ()
{
    rm ${LOG}
    echo
    exit 0
}

heading ()
{
    echo "${RESET}${BOLD}$1${RESET}"
}

error ()
{
    heading "See ${LOG} for more details on the error."
    exit 1
}

restartprocesses ()
{
    readarray -t PROCESSES <<< `(pm2 jlist 2>/dev/null | tail -n1 | jq -r '.[] | select(.name | (endswith("-core") or endswith("-forger") or endswith("-relay"))) | .pm2_env | select(.status == "online") | .name') 2>> ${LOG}`
    if [ "$?" != "0" ] ; then
        echo "       ${RED}${BOLD}Could not get list of running processes. Restart your processes for the changes to take effect."
        error
    fi
    if [ "${PROCESSES[0]}" != "" ] ; then
        for PROCESS in "${PROCESSES[@]}"; do
            read -p "       ${BOLD}Do you want to restart the ${PROCESS} process now? [y/N]: ${RESET}" CHOICE
            if [[ "$CHOICE" =~ ^(yes|y|Y) ]] ; then
                heading "       Restarting ${PROCESS}"
                pm2 --update-env --silent restart ${PROCESS}
            fi
        done
    fi
}

GAWK=`which gawk 2> /dev/null`
TOR=`which tor 2> /dev/null`
DEB=`which apt-get 2> /dev/null`
RPM=`which yum 2> /dev/null`

trap abort INT

if ([[ -z $TOR ]] || [[ -z $GAWK ]]) && ([[ ! -z $DEB ]] || [[ ! -z $RPM ]]) ; then
    sudo echo -n
fi

if [ "$2" == "" ] ; then
    heading "Core Chameleon"
fi

readarray -t NETWORKS <<< `ls -1d ~/.config/*-core/*/plugins.js 2>> ${LOG} | cut -d "/" -f5-6`
if [ "${NETWORKS[0]}" == "" ] ; then
    echo "${RED}${BOLD}No ARK Core configuration found. Install ARK Core and try again.${RESET}"
    exit 1
fi

COREPATH=

if [ "$1" != "" ] && ! [[ -d $1/packages/core ]] ; then
    echo "${RED}${BOLD}No ARK Core installation found at $1. Check the path and try again.${RESET}"
    exit 1
else
    COREPATH=$1
fi

if [ "$COREPATH" == "" ] && ! [[ -d ~/.config/yarn/global/node_modules/@arkecosystem/core ]] ; then
    echo "${RED}${BOLD}No global ARK Core installation found. Install ARK Core and try again, or specify a path to ARK Core."
    echo "For example: ./$0 ${HOME}/ark-core ${RESET}"
    exit 1
fi

if [[ -z $GAWK ]] ; then
    heading "    => Installing GNU Awk"
    ERR=
    if [[ ! -z $DEB ]] ; then
        sudo sh -c 'apt-get update && apt-get install -y gawk' >> ${LOG} 2>>${LOG}
        ERR=$?
    elif [[ ! -z $RPM ]] ; then
        sudo sh -c 'yum update -y && yum install -y gawk' >> ${LOG} 2>>${LOG}
        ERR=$?
    else
        echo "       ${RED}${BOLD}GNU Awk is not installed on this system. Install it manually and try again."
        exit 1
    fi
    if [ "$ERR" != "0" ] ; then
        echo "       ${RED}${BOLD}GNU Awk installation failed"
        error
    fi
fi

if [[ -z $TOR ]] ; then
    heading "    => Installing Tor"
    SYS=$([[ -L "/sbin/init" ]] && echo 'SystemD' || echo 'SystemV')
    CONTINUE=
    ERR=
    if [[ ! -z $DEB ]] ; then
        sudo sh -c 'apt-get update && apt-get install -y tor' >> ${LOG} 2>>${LOG}
        ERR=$?
        CONTINUE="yes"
    elif [[ ! -z $RPM ]] ; then
        sudo sh -c 'yum update -y && yum install -y tor' >> ${LOG} 2>>${LOG}
        ERR=$?
        CONTINUE="yes"
    else
        read -p "       ${RED}${BOLD}Automatic installation of Tor is only available for Debian or RedHat based systems. Continue anyway? [y/N]: ${RESET}" CHOICE
        if [[ ! "$CHOICE" =~ ^(yes|y|Y) ]] ; then
           exit 1
        fi
    fi
    if [ "$CONTINUE" == "yes" ] ; then
        if [ "$ERR" == "0" ] ; then
            if [[ "$SYS" == "SystemV" ]] ; then
                sudo sh -c 'service tor stop && update-rc.d tor disable' >> ${LOG} 2>>${LOG}
            else
                sudo sh -c 'systemctl stop tor && systemctl disable tor' >> ${LOG} 2>>${LOG}
            fi
            if [ "$?" != "0" ] ; then
                read -p "       ${RED}${BOLD}An error occurred while configuring Tor. Continue anyway? [y/N]: ${RESET}" CHOICE
                if [[ ! "$CHOICE" =~ ^(yes|y|Y) ]] ; then
                    error
                fi
            fi
        else
            read -p "       ${RED}${BOLD}An error occurred while installing Tor. Continue anyway? [y/N]: ${RESET}" CHOICE
            if [[ ! "$CHOICE" =~ ^(yes|y|Y) ]] ; then
               error
            fi
        fi
        if [ "$?" == "0" ] ; then
            if [[ "$SYS" == "SystemV" ]] ; then
                sudo sh -c 'service tor stop && update-rc.d tor disable' >> ${LOG} 2>>${LOG}
            else
                sudo sh -c 'systemctl stop tor && systemctl disable tor' >> ${LOG} 2>>${LOG}
            fi
            if [ "$?" != "0" ] ; then
                read -p "       ${RED}${BOLD}An error occurred while configuring Tor. Continue anyway? [y/N]: ${RESET}" CHOICE
                if [[ ! "$CHOICE" =~ ^(yes|y|Y) ]] ; then
                    error
                fi
            fi
        fi
    fi
fi

PLUGINPATH=~/.config/yarn/global/node_modules/${PLUGIN}
if [ "$COREPATH" != "" ] ; then
    PLUGINPATH=${COREPATH}/node_modules/${PLUGIN}
fi

if [[ -d $PLUGINPATH ]] ; then
    LATEST=`curl "https://registry.npmjs.org/${PLUGIN}" 2> /dev/null | jq -r .'"dist-tags"'.latest`
    if [ "$COREPATH" == "" ] ; then
        CURRENT=`< ~/.config/yarn/global/node_modules/${PLUGIN}/package.json jq -r .version`
    else
        CURRENT=`< ${COREPATH}/node_modules/${PLUGIN}/package.json jq -r .version`
    fi
    CURRENT=0.0.1
    if [[ "$LATEST" != "$CURRENT" ]] ; then
        read -p "       ${BOLD}New version ${LATEST} is available. You are using ${CURRENT}. Update now? [y/N]: ${RESET}" CHOICE
        if [[ "$CHOICE" =~ ^(yes|y|Y) ]] ; then
            heading "    => Updating Core Chameleon"
            if [ "$COREPATH" != "" ] ; then
                cd ${COREPATH}
                yarn add -W ${PLUGIN}@${LATEST} >> ${LOG} 2>>${LOG}
            else
                yarn global add ${PLUGIN}@${LATEST} >> ${LOG} 2>>${LOG}
            fi
            if [ "$?" != "0" ] ; then
                echo "       ${RED}${BOLD}Core Chameleon update failed"
                error
            else
                heading "    => Update successful"
                restartprocesses
                if [[ -f ${PLUGINPATH}/chameleon.sh ]] ; then
                    bash ${PLUGINPATH}/chameleon.sh "$1" --quiet
                    exit 0
                fi
            fi
        fi   
    fi 
else
    heading "    => Installing Core Chameleon"
    if [ "$COREPATH" != "" ] ; then
        cd ${COREPATH}
        yarn add -W ${PLUGIN} >> ${LOG} 2>>${LOG}
    else    
        yarn global add ${PLUGIN} >> ${LOG} 2>>${LOG}
    fi
    if [ "$?" != "0" ] ; then
        echo "       ${RED}${BOLD}Core Chameleon installation failed"
        error
    fi
fi

if [ "$?" == "0" ] ; then
    heading "    => Configuring Core Chameleon"
    if [ "${#NETWORKS[@]}" == "1" ] ; then
        CORE=${NETWORKS[0]}
    else
        heading "       Multiple Core networks found. Please choose the one you want: "
        I=1
        for SELECTION in "${NETWORKS[@]}"; do
            heading "           ${I} => ${SELECTION}"
            ((I++))
        done
        PROMPT="Please enter your choice"
        while true ; do
            read -p "       ${BOLD}${PROMPT}: " CHOICE
            if [[ $CHOICE != ?([0-9]) || "$CHOICE" -lt 1 || "$CHOICE" -gt ${#NETWORKS[@]} ]] ; then
                PROMPT="Invalid choice. Please try again"
            else
                CORE=${NETWORKS[${CHOICE}-1]}
                break
            fi
        done
    fi
    heading "       Configuring for ${CORE}"
    if [ ! -z "`grep ${PLUGIN} ~/.config/${CORE}/plugins.js`" ] ; then
        ACTION="remove"
        read -p "       ${BOLD}Core Chameleon is currently present in your Core configuration. Would you like to remove it? [y/N]: ${RESET}" CHOICE
    else
        ACTION="add"
        read -p "       ${BOLD}Core Chameleon is not currently present in your Core configuration. Would you like to add it? [y/N]: ${RESET}" CHOICE
    fi
    ESCAPED=${PLUGIN//\//\\\/}
    if [[ "$CHOICE" =~ ^(yes|y|Y) ]] ; then
        if [[ "$ACTION" == "remove" ]] ; then
            awk -i inplace "/${ESCAPED}/ {on=1} on && /@/ && !/${ESCAPED}/ {on=0} {if (!on) print}" ~/.config/${CORE}/plugins.js 2>> ${LOG}
            if [ "$?" == "0" ] ; then
                heading "       Removed Core Chameleon from ${CORE} configuration"
            else
                echo "       ${RED}${BOLD}Failed to remove Core Chameleon for ${CORE}"
                error
            fi
        else
            awk -i inplace "/@arkecosystem\/core-p2p/ {on=1} on && /@/ && !/@arkecosystem\/core-p2p/ {print \"    \\\"${ESCAPED}\\\": {\n        enabled: true,\n    },\"; on=0} {print}" ~/.config/${CORE}/plugins.js 2>> ${LOG}
            if [ "$?" == "0" ] ; then
                heading "       Added Core Chameleon to ${CORE} configuration"
            else
                echo "       ${RED}${BOLD}Failed to add Core Chameleon for ${CORE}"
                error
            fi
        fi
        restartprocesses
    else
        heading "       No changes made"
    fi
    heading "    => Finished"
fi

if [[ -d $PLUGINPATH ]] ; then
    if [[ ! -f ${PLUGINPATH}/chameleon.sh ]] ; then
        cp "$0" ${PLUGINPATH}/chameleon.sh >> ${LOG} 2> ${LOG}
    fi
    if [[ -f ~/.bashrc ]] && [[ -z "`grep chameleon ~/.bashrc`" ]] ; then
        echo "alias chameleon='bash ${PLUGINPATH}/chameleon.sh'" >> ~/.bashrc
        echo
        heading "You may now delete `readlink -f "$0"`. To reconfigure or update Core Chameleon in future, type 'chameleon'."
        exec ${BASH}
    fi
fi

rm ${LOG}