#!/bin/sh

control_c() {
    exit
}

trap control_c SIGINT

main()
{
  MENU=$(dialog --title "WPA_TUI" \
    --menu "Please Make a choice" 0 0 0 \
      1 "Add a wifi"\
      2 "Connect to a wifi"\
      3 "Remove pre-existing wifi networks"\
      4 "(Wifibox) [SUDO] reload wifi" 3>&1 1>&2 2>&3 3>&-);
      
  case $MENU in
    1) add_wifi;;
    2) enable_wifi;;
    3) remove_wifi;;
    4) reload_wifi;;
  esac
}

add_wifi()
{
  NW_ID=$(expr $(wpa_cli list_networks | wc -l | awk '{print $1}') - 2)
  wpa_cli scan

  sleep 5 | dialog --title "Add a Wifi" \
      --progressbox "Please Wait an instant..." 0 40

  dialog --title "Add a Wifi" \
     --msgbox "Write the name of the network you want to connect to." 0 0

  SSID=$( \
    dialog --title "Add a Wifi" \
      --inputbox "$(wpa_cli scan_results | sed 20q)" 0 0 3>&1 1>&2 2>&3 3>&- \
  );

  if [ $(echo "$SSID" | wc -w | awk '{print $1}') -e 0 ]; then 
    dialog --title "Add a Wifi" \
     --msgbox "No name given, going back to main menu" 0 0
    main
    exit;
  fi;

  KEY=$( \
    dialog --title "Add a Wifi" \
      --inputbox "Enter Key type (leave blank for WPA-PSK, \"NONE\" for no passwords):" 0 40 3>&1 1>&2 2>&3 3>&- \
  );
  if [ "$KEY" == "" ]; then KEY="WPA-PSK"; fi 
  
  wpa_cli add_network
  echo "wpa_cli set_network $NW_ID 'ssid' '\"$SSID\"'" | sh

  if [ "$KEY" == "NONE" ]; then
    wpa_cli enable_network $NW_ID
    wpa_cli save_config
    main
    exit;
  fi


  PSK=$( \
    dialog --title "Add a Wifi" \
      --inputbox "Enter your password" 0 0 3>&1 1>&2 2>&3 3>&- \
  );

  wpa_cli set_network $NW_ID 'key_mgmt' "$KEY"
  if [ "$KEY" == "WPA-EAP" ]; then 
    USR=$(\
      dialog --title "Add a Wifi" \
          --inputbox "enter your username" 0 0 3>&1 1>&2 2>&3 3>&- \
    );
    wpa_cli set_network $NW_ID 'eap' 'PEAP'
    echo "wpa_cli set_network $NW_ID 'password' '\"$PSK\"'" | sh
    echo "wpa_cli set_network $NW_ID 'identity' '\"$USR\"'" | sh
  fi

  if [ "KEY" == "WPA-PSK" ]; then
    echo "wpa_cli set_network $NW_ID 'psk' '\"$PSK\"'" | sh
  fi

  wpa_cli enable_network $NW_ID
  wpa_cli save_config 

  main
}

enable_wifi()
{
  CHOICES=$( \
    dialog --title "Enable networks" \
      --inputbox "Enter ID of wifi you want to connect to $(echo; echo; wpa_cli list_networks | grep "^[0-9]")" 0 0 "" 3>&1 1>&2 2>&3 3>&-);
  if [ "$CHOICES" == "" ]; then main; exit; fi
  wpa_cli disable_network all
  wpa_cli enable_network $CHOICES
  wpa_cli save_config
  wpa_cli reconfigure
  main
}

remove_wifi()
{
  CHOICES=$( \
    dialog --title "Remove networks" \
      --inputbox "Enter wifis you want to have deleted $(echo; echo; wpa_cli list_networks | grep "^[0-9]")" 0 0 "" 3>&1 1>&2 2>&3 3>&-);
  if [ "$CHOICES" == "" ]; then main; exit; fi
  echo $CHOICES | xargs wpa_cli remove_network
  echo $CHOICES | xargs wpa_cli remove_network
  wpa_cli save_config
  wpa_cli reconfigure
  main
}

reload_wifi()
{
  sudo service netif stop && sudo service wifibox restart && sudo service netif start wifibox0
}

main

