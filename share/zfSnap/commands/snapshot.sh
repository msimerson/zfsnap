#!/bin/sh

# "THE BEER-WARE LICENSE":
# The zfSnap team wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return.

PREFIX=""                           # Default prefix

# FUNCTIONS
Help() {
    cat << EOF
${0##*/} v${VERSION}

Syntax:
${0##*/} snapshot [ options ] zpool/filesystem ...

OPTIONS:
  -a ttl       = Set how long snapshot should be kept
  -e           = Return number of failed actions as exit code.
  -h           = Print this help and exit.
  -n           = Only show actions that would be performed
  -p prefix    = Use prefix for snapshots after this switch
  -P           = Don't use prefix for snapshots after this switch
  -r           = Create recursive snapshots for all zfs file systems that
                 follow this switch
  -R           = Create non-recursive snapshots for all zfs file systems that
                 follow this switch
  -s           = Don't do anything on pools running resilver
  -S           = Don't do anything on pools running scrub
  -v           = Verbose output
  -z           = Force new snapshots to have 00 seconds

LINKS:
  wiki:             https://github.com/graudeejs/zfSnap/wiki
  repository:       https://github.com/graudeejs/zfSnap
  bug tracking:     https://github.com/graudeejs/zfSnap/issues

EOF
    Exit 0
}

# MAIN
# main loop; get options, process snapshot creation
while [ "$1" ]; do
    while getopts :a:ehnp:PrRsSvz OPT; do
        case "$OPT" in
            a) TTL="$OPTARG"
               [ "$TTL" -gt 0 ] 2> /dev/null && TTL=`Seconds2TTL "$TTL"`
               ValidTTL "$TTL" || Fatal "Invalid TTL: $TTL"
               ;;
            h) Help;;
            n) DRY_RUN="true";;
            p) PREFIX="$OPTARG";;
            P) PREFIX="";;
            r) ZOPT='-r';;
            R) ZOPT='';;
            s) PopulateSkipPools 'resilver';;
            S) PopulateSkipPools 'scrub';;
            v) VERBOSE="true";;
            z) TIME_FORMAT='%Y-%m-%d_%H.%M.00';;

            :) Fatal "Option -$OPTARG requires an argument.";;
           \?) Fatal "Invalid option: -$OPTARG";;
        esac
    done

    # discard all arguments processed thus far
    shift $(($OPTIND - 1))

    # create snapshots
    if [ "$1" ]; then
        if SkipPool "$1"; then
            NTIME="${NTIME:-`date "+$TIME_FORMAT"`}"
            IsTrue $DRY_RUN && ZFS_LIST="${ZFS_LIST:-`$ZFS_CMD list -H -o name`}"

            ZFS_SNAPSHOT="$ZFS_CMD snapshot $ZOPT $1@${PREFIX}${NTIME}--${TTL}"
            if IsFalse $DRY_RUN; then
                if $ZFS_SNAPSHOT > /dev/stderr; then
                    IsTrue $VERBOSE && echo "$ZFS_SNAPSHOT ... DONE"
                else
                    IsTrue $VERBOSE && echo "$ZFS_SNAPSHOT ... FAIL"
                fi
            else
                printf '%s\n' $ZFS_LIST | grep -m 1 -q -E -e "^$1$" \
                    && echo "$ZFS_SNAPSHOT" \
                    || Err "Looks like ZFS filesystem '$1' doesn't exist"
            fi
        fi
        shift
    fi
done
