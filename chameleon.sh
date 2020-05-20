#!/usr/bin/env bash

BOLD=$(tput bold)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

PLUGIN="@alessiodf/core-chameleon"
LOG=$(mktemp /tmp/core-chameleon.XXX.log)
heading ()
{
    echo "${RESET}${BOLD}$1${RESET}"
}

error ()
{
    heading "See ${LOG} for more details on the error."
    exit 1
}

TOR=`which tor 2> /dev/null`
DEB=`which apt-get 2> /dev/null`
RPM=`which yum 2> /dev/null`

if [[ -z $TOR ]] && ([[ ! -z $DEB ]] || [[ ! -z $RPM ]]) ; then
    sudo echo -n
fi
heading "Core Chameleon"

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
    if [[ "$LATEST" != "$CURRENT" ]] ; then
        heading "    => Updating Plugin from ${CURRENT} to ${LATEST}"
        if [ "$COREPATH" != "" ] ; then
            cd ${COREPATH}
            yarn add -W ${PLUGIN}@${LATEST} >> ${LOG} 2>>${LOG}
        else
            yarn global add ${PLUGIN}@${LATEST} >> ${LOG} 2>>${LOG}
        fi
        if [ "$?" != "0" ] ; then
            echo "       ${RED}${BOLD}Plugin update failed"
            error
        else
            heading "       Plugin successfully updated. Restart your processes to use the new version."
        fi   
    fi 
else
    heading "    => Installing Plugin"
    if [ "$COREPATH" != "" ] ; then
        cd ${COREPATH}
        yarn add -W ${PLUGIN} >> ${LOG} 2>>${LOG}
    else    
        yarn global add ${PLUGIN} >> ${LOG} 2>>${LOG}
    fi
    if [ "$?" != "0" ] ; then
        echo "       ${RED}${BOLD}Plugin installation failed"
        error
    fi
fi

if [ "$?" == "0" ] ; then
    heading "    => Configuring Plugin"
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
    if [ ! -z "$(cat ~/.config/$CORE/plugins.js | grep $PLUGIN)" ] ; then
        ACTION="remove"
        read -p "       ${BOLD}Plugin is currently present in your Core configuration. Would you like to remove it? [y/N]: ${RESET}" CHOICE
    else
        ACTION="add"
        read -p "       ${BOLD}Plugin is not currently present in your Core configuration. Would you like to add it? [y/N]: ${RESET}" CHOICE
    fi
    ESCAPED=${PLUGIN//\//\\\/}
    if [[ "$CHOICE" =~ ^(yes|y|Y) ]] ; then
        if [[ "$ACTION" == "remove" ]] ; then
            sed -i "/\s\s\s\s\"${ESCAPED}\"/,/^\s\s\s\s}/d" ~/.config/${CORE}/plugins.js 2>> ${LOG}
            if [ "$?" == "0" ] ; then
                heading "       Removed plugin from ${CORE} configuration. Restart your processes for the changes to take effect."
            else
                echo "       ${RED}${BOLD}Failed to remove plugin for ${CORE}"
                error
            fi
        else
            sed -i "/@arkecosystem\/core-state/i \ \ \ \ \"${ESCAPED}\": {\n\ \ \ \ \ \ \ enabled: true,\n\ \ \ \ }," ~/.config/${CORE}/plugins.js 2>> ${LOG}
            if [ "$?" == "0" ] ; then
                heading "       Added plugin to ${CORE} configuration. Restart your processes for the changes to take effect."
            else
                echo "       ${RED}${BOLD}Failed to add plugin for ${CORE}"
                error
            fi
        fi
    else
        heading "       No changes made"
    fi
    heading "    => Finished"
fi