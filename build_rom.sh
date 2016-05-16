#!/bin/bash

SYNC=0
CLOBBER=0

eval `resize`
SIZE="$(( $LINES / 2 )) $(( $COLUMNS / 2 ))"

function req_menu() {
    dialog --separate-output --title "Build Menu" --checklist "Choose tasks to do before build:" $(( $LINES / 2 )) $(( $COLUMNS / 2 )) $(( $(( $LINES / 2 )) - 8 )) \
        "Repo Sync" "Choose whether to sync before build." $SYNC \
        "Make Clobber" "Choose whether to make clobber before build." $CLOBBER 2>results

    while read choice
    do
    case $choice in
        "Repo Sync") SYNC=1;;
        "Make Clobber") CLOBBER=1;;
        *) echo $choice;;
    esac
    done < results
}

function sync() {
    if [ $SYNC -eq 1 ]; then
        repo sync -j$(nproc) --force-sync 2>/dev/null | dialog --title "repo sync -j$(nproc) --force-sync" --programbox $LINES $COLUMNS
    fi
}

function lunch() {
    . build/envsetup.sh > /dev/null
    deviceList=""
    count=1

    for device in "${LUNCH_MENU_CHOICES[@]}"
    do
        deviceList="$deviceList $count $device OFF"
        count=$(( $count + 1 ))
    done

    deviceList="$deviceList $count Custom ON"
    dialog --title "Lunch Menu" --radiolist "Choose a lunch combo" $LINES $COLUMNS $(( LINES - 8 )) $deviceList 2>/tmp/build.tmp
    orderNumber=$(cat /tmp/build.tmp)
    if [ $orderNumber -eq $count ]; then
        custom_lunch
    else
        orderName=${LUNCH_MENU_CHOICES[$(( $orderNumber - 1 ))]}
        lunch $orderName | dialog --title "Please Wait - This will take a minute: lunch $orderName" --programbox $LINES $COLUMNS
    fi
}

function custom_lunch() {
    dialog --title "Custom Lunch" --inputbox "Enter your device name, e.g. shamu" $SIZE 2>/tmp/build.tmp
    orderName=$(cat /tmp/build.tmp)
    breakfast $orderName | dialog --title "Please Wait - This will take a minute: breakfast $orderName" --programbox $LINES $COLUMNS
}

function clobber() {
    if [ $CLOBBER -eq 1 ]; then
        make clobber | dialog --title "make clobber" --programbox $LINES $COLUMNS
    fi
}

function build() {
    dialog --title "Build Menu" --radiolist "Choose a build option" $LINES $COLUMNS $(( LINES - 8 )) 1 "Regular Build" "ON" 2 "Background Build (allows you to disconnect from ssh while building)" "OFF" 2>/tmp/build.tmp

    buildOpt=$(cat /tmp/build.tmp)

    get_target

    if [ $buildOpt -eq 1 ]; then
        build_normal
    elif [ $buildOpt -eq 2 ]; then
        build_ssh
    fi
}

function get_target() {
    dialog --title "Target Menu" --radiolist "Choose a build target" $LINES $COLUMNS $(( LINES - 8 )) 1 "bacon" "OFF" 2 "otapackage" "OFF" 3 "Other" "ON" 2>/tmp/build.tmp
    targetNum=$(cat /tmp/build.tmp)

    if [ $targetNum -eq 1 ]; then
        target=bacon
    elif [ $targetNum -eq 2 ]; then
        target=otapackage
    elif [ $targetNum -eq 3 ]; then
        get_custom_target
    fi
}

function get_custom_target() {
    dialog --title "Custom Target" --inputbox "Enter your ROM's target name" $SIZE 2>/tmp/build.tmp
    target=$(cat /tmp/build.tmp)
}

function build_normal() {
    make -j$(nproc) $target | dialog --title "make -j$(nproc) $target" --programbox $LINES $COLUMNS
}

function build_ssh() {
    dialog --title "Note" --msgbox "To watch the build progress after logging out, use $0 watch\nLikewise, use $0 log to output the whole log" $SIZE
    rm -f nohup.out && nohup make -j$(nproc) $target &
    watch_build
}

function cleanup() {
    rm -f /tmp/build.tmp
}

function watch_build() {
    watch -t -c -n 0.2 tail -n $(( $LINES - 1 )) nohup.out
}

function cat_build() {
    cat nohup.out
}

if [ "$1" == "watch" ]; then
    watch_build
    exit
elif [ "$1" == "log" ]; then
    cat_build
    exit
fi

req_menu
sync
lunch
clobber
build
cleanup
