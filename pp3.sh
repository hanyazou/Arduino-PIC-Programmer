#!/bin/bash -eu

# Author: hanyazou@gmail.com

usage() {
    echo "picprog [options] [commands]"
    echo "command:"
    echo "   write <.hex> write firmware to the target"
    echo "        install download and setup required packages"
    echo "         update upload .ino to Arduino"
    echo "        cleanup delete downloaded packages"
    echo "option:"
    echo "--target <name> specify target MCU"
    echo "  --tool <name> specify tool FQBN"
    echo "  --port <name> specify serial device"
    echo "      --verbose enable verbose output"
    echo "         --help display this message"
}

main() {
    setup

    local cmd_write=false
    local cmd_install=false
    local cmd_update=false
    local cmd_cleanup=false
    local done=false
    while (( $# > 0 )); do
        case "$1" in
        write)
            cmd_write=true
            shift
            opt_input_file="$1"
            ;;
        install)
            cmd_install=true
            ;;        update)
            cmd_update=true
            ;;
        cleanup)
            cmd_cleanup=true
            ;;
        -t|--target)
            shift
            opt_target_mcu="$1"
            ;;
        --tool)
            shift
            opt_tool_fqbn="$1"
            ;;
        --port)
            shift
            opt_port="$1"
            ;;
        -v|--verbose)
            opt_verbose=true
            ;;
        -h|--help)
            usage
            done=true
            ;;
        -*)
            echo unknown option "'"$1"'"
            usage
            exit 1
            ;;
        *)
            echo invalid argument "'"$1"'"
            usage
            exit 1
            ;;
        esac
        shift
    done

    if $done; then
        exit 0
    fi

    if $cmd_install && ! install; then
        exit 1
    fi

    if ! $cmd_cleanup && [ ! -e $download/done ] && ! install; then
        exit 1
    fi

    if $cmd_update && ! update; then
        exit 1
    fi

    if $cmd_write && ! write; then
        exit 1
    fi

    if $cmd_cleanup && ! cleanup; then
        exit 1
    fi

    exit 0
}

setup() {
    download=arduino/download
    export PATH=$download/bin:$PATH

    opt_target_mcu=18f47q43
    opt_tool_fqbn=arduino:avr:leonardo
    opt_port=auto
    opt_verbose=false

    rm -f .tmp*
}

prepair_port() {
    ACLI_OPTS=""
    ACLI_OPTS+=" --config-file ./arduino-cli.yaml"
    if $opt_verbose; then
        ACLI_OPTS+=" --verbose"
    fi

    if [ "$opt_port" == "auto" ]; then
        opt_port=$( arduino-cli board list | grep -e $opt_tool_fqbn | grep -e '^/dev/' | \
                        awk '{ print $1 }' )
        if [ "$opt_port" != "" ]; then
            echo "Board $opt_tool_fqbn is found at port $opt_port"
            return 0
        else
            echo "Board $opt_tool_fqbn is not found"
            return 1
        fi
    fi
}

install() {
    if [ ! -x ./pp3 ]; then
        gcc -Wall pp3.c -o pp3
    fi
    if [ ! -e $download/bin/arduino-cli ]; then
        mkdir -p $download/bin
        BINDIR=$download/bin sh arduino/arduino-cli-install.sh 0.29.0
    fi
    mkdir -p $download/Arduino15/libraries
    ln -sf $project_dir $download/Arduino15/libraries/
    
    arduino-cli core update-index || exit 1
    arduino-cli core install arduino:avr@1.8.6 || exit 1
    touch $download/done
}

update() {
    local sketch=./arduino/arduino-sketch

    if ! prepair_port; then
        return 1
    fi

    echo arduino-cli compile $ACLI_OPTS --fqbn $opt_tool_fqbn $sketch
    arduino-cli compile $ACLI_OPTS --fqbn $opt_tool_fqbn $sketch || exit 1

    echo arduino-cli upload $ACLI_OPTS --fqbn $opt_tool_fqbn --port $opt_port --verify $sketch
    arduino-cli upload $ACLI_OPTS --fqbn $opt_tool_fqbn --port $opt_port --verify $sketch || exit 1
}

write() {
    if ! prepair_port; then
        return 1
    fi

    if $opt_verbose; then
        echo $project_dir/pp3 -c $opt_port -v 3 -t $opt_target_mcu "$opt_input_file"
        $project_dir/pp3 -c $opt_port -v 3 -t $opt_target_mcu "$opt_input_file"
    else
        $project_dir/pp3 -c $opt_port -v 2 -t $opt_target_mcu "$opt_input_file"
    fi
}

cleanup() {
    rm -rf pp3
    rm -rf $download
    rm -rf .tmp*
}

highlight() {
    echo ==============================
    echo "$*" | sed -e 's/^\.//'
    echo ==============================
}

project_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd $project_dir

main $*

