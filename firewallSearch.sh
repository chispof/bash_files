#!/bin/bash

#Colores
greenColor="\e[0;32m\033[1m"
endColor="\033[0m\e[0m"
redColor="\e[0;31m\033[1m"
blueColor="\e[0;34m\033[1m"
yellowColor="\e[0;33m\033[1m"
purpleColor="\e[0;35m\033[1m"
turquoiseColor="\e[0;36m\033[1m"
grayColor="\e[0;37m\033[1m"

myKey=''
ipFW=''

function ctrl_c(){
        echo -e "\n\n${redColor}[!] Saliendo...${endDolor}\n"
        exit 1
}

#Ctrl+c
trap ctrl_c INT

function actualiza(){

        echo -e "${greenColor}[+]${endColor} ${grayColor}Actualizando políticas...${endColor}"
        curl -s -X GET "https://$ipFW/restapi/v10.1/Policies/SecurityRules?location=vsys&vsys=vsys1" --insecure -H 'X-PAN-KEY: '$mykey | jq -r '.result.entry[] | select((.action=="allow") and  (.disabled!="yes")) | { nombre: .["@name"], fuente: .source.member[], destino: .destination.member[] } | join(";")' > resumenFW.txt

        echo -e "${greenColor}[+]${endColor} ${grayColor}Actualizando objetos...${endColor}"
        curl -s -X GET "https://$ipFW/restapi/v10.1/Objects/Addresses?location=panorama-pushed&vsys=vsys1" --insecure -H 'X-PAN-KEY: '$myKey| jq -r '.result.entry[] | {nombre: .["@name"], ip: ."ip-netmask"} | join(";")' > direccionesFW.txt

        echo -e "${greenColor}[+]${endColor} ${grayColor}Actualizando grupos...${endColor}"
        curl -s -X GET "https://$ipFW/restapi/v10.1/Objects/AddressGroups?location=panorama-pushed&vsys=vsys1" --insecure -H 'X-PAN-KEY: '$myKey |  jq -r '.result.entry[] | {nombre: .["@name"], ip: .static.member[]} | join(";")' > gruposFW.txt
}

function helpPanel(){
        echo -e "\n[+] Usage:"
        echo -e "\tu) Update Objects"
        echo -e "\to) Search by Objects (nombre/ip)"
        echo -e "\ts) Search by Source (nombre/ip)"
        echo -e "\tn) Search by Name (nombre)"
        echo -e "\th) Show this help panel"
}

busquedaObjects(){
        objects=$1
        echo -e "${greenColor}\n[+]${endColor} ${grayColor}The objects asociated to ${endColor}${purpleColor}$objects${endColor} ${grayColor}are:${endColor}\n"
        grep -i $objects direccionesFW.txt | tr ";" "\t" | column --table --table-columns OBJECT,IP
        echo -e "\n"
        grep -i $objects gruposFW.txt | tr ";" "\t" | awk '{print $1}' | column --table --table-columns GROUP
}

busquedaSource(){
        sources=$1
        checker=$(cat resumenFW.txt | cut -d";" -f1,2 | grep "$sources" | awk '{print $1}')
        if [[ $checker ]]; then
                echo "$sources;;$checker" | tr "\n" "," ; echo -e "\n"

        else

                echo "$sources;;" | tr "\n" "," ; echo -e "\n"

        fi
        grupos=$(grep ${sources}$ gruposFW.txt | awk '{print $1}' FS=";" | sed 's/ /\n/g')
        grupodeGrupos=$(for i in $(echo $grupos); do grep -E "${i}$|${i};" gruposFW.txt | awk '{print $1}' FS=";" | sort -u ; done)

        for i in $grupodeGrupos; do
                grupOrg=$(cat resumenFW.txt | cut -d";" -f1,2 | grep "$i" | awk '{print $1}' FS=";" | sort -u)
                echo "$sources;$i;$grupOrg" | tr "\n" "," ; echo -e "\n"
        done

}

busquedaName(){
        name=$1
        cat resumenFW.txt | cut -d";" -f1,2 | grep -i "$name" | sort -u | tr ";" "\t" | column --table --table-columns RULE,SOURCE

        sources=$(cat resumenFW.txt | cut -d";" -f1,2 | grep -i "$name" | awk '{print $2}' FS=";" | sort -u )

        for i in $sources; do
                echo -e "\n${redColor}Grupo: ${endColor}${grayColor}$i${endColor}"
                grep ^${i} gruposFW.txt | awk '{print $2}' FS=";" | sort -u | column
        done
}
while getopts "o:s:n:hu" arg
do
        case $arg in
                u) actualiza;;
                o) objects=$OPTARG; busquedaObjects $objects;;
                s) sources="$OPTARG"; busquedaSource "$sources";;
                n) name="$OPTARG"; busquedaName "$name";;
                h) helpPanel;;
                *) helpPanel;;
        esac
done

if [[ ! $1 ]]; then
        helpPanel
fi
