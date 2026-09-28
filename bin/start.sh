#!/bin/bash
# This script requires below environment variables
# INTERFACE -- interface name which it will configure
# DNN0 -- dnn of the first PDU session
# DNN_TYPE0 -- dnn type of the first pdu session
# DNN1 -- dnn of the second PDU session
# DNN_TYPE1 -- dnn type of the second pdu session
# IPERF_SERVER -- iperf server to use for iperf test

set -euo pipefail


DEFAULT_DNN0=internet
quiet=false # if quiet is false then resume with ping test

# handle optional options
while getopts F:S:qm: option; do
    case "${option}"
    in
        F) dnn0=${OPTARG};;
        S) dnn1=${OPTARG};;
        q) quiet=true;;
	m) mode=${OPTARG};;
        \?) exit 1;;
    esac
done
if [ -z ${dnn0+x} ]; then
    DNN0=$DEFAULT_DNN0
else
    DNN0=$dnn0
fi
if [ -z ${dnn1+x} ]; then
    # -S not passed: keep DNN1 from the environment if set, otherwise no DNN1
    if [ -z ${DNN1+x} ]; then
	echo "running $0 with parameters: DNN0=$DNN0, no DNN1, quiet $quiet"
    else
	echo "running $0 with parameters: DNN0=$DNN0, DNN1=$DNN1 (from env), quiet $quiet"
    fi
else
    DNN1=$dnn1
    echo "running $0 with parameters: DNN0=$DNN0, DNN1=$DNN1, quiet $quiet"
fi

# --- UE mode (mbim|qmi): default from qhat-init state file, -m overrides ---
MODE="${mode:-$(cat /run/ue-mode 2>/dev/null || echo mbim)}"

# --- QMI data path (RG255C, or RM500Q/RM520N forced to QMI) ---
if [[ "$MODE" == "qmi" ]]; then
    source qmi-net.sh  # PATH-resolved, like mbim-set-ip.sh
    echo "running $0 in QMI mode: DNN/APN=$DNN0, quiet=$quiet"
    qmi_ensure_cm "$DNN0"
    qmi_wup
    qmi_wait_ip
    if [[ "$quiet" == "false" ]]; then
        echo "-------- Perform Ping Test --------"
        ping -I "$QMI_IFACE" -c 4 8.8.8.8 || true
    fi
    exit 0
fi

# --- MBIM data path ---

#If double pdu is not needed remove DNN1 variable
DNN_TYPE0=${DNN_TYPE0:-ipv4}

#If double pdu is not needed remove DNN1 variable
DNN_TYPE0=${DNN_TYPE0:-ipv4}
DNN_TYPE1=${DNN_TYPE1:-ipv4v6}
INTERFACE=${INTERFACE:-wwan0}
DEVICE=/dev/cdc-wdm0

# Resolve the MBIM access string for a DNN. On Quectel RM500Q/Rm520N, a context
# carrying an S-NSSAI is renamed by the firmware to "<dnn>_<SST-name><SD>"
# (e.g. streaming_EMBB100000), and CID 1 cannot carry an S-NSSAI. Connecting
# with the plain DNN then selects CID 1 and the request goes out without
# S-NSSAI. Prefer the slice-carrying context when one exists for this DNN;
# otherwise keep the plain DNN (unchanged behaviour for UEs without slice).
resolve_access_string() {
    local dnn="$1" sliced
    sliced=$(mbimcli -p -d "$DEVICE" --query-provisioned-contexts 2>/dev/null \
        | awk -F"'" -v p="${dnn}_" '/Access string:/ && index($2, p) == 1 {print $2; exit}') || true
    echo "${sliced:-$dnn}"
}

echo "-------Setting up $INTERFACE for testing-------"
ifconfig $INTERFACE up

if [[ -v DNN1 ]]; then echo "---- ip link add link wwan0 name ${INTERFACE}.1 type vlan id 1"; fi
if [[ -v DNN1 ]]; then ip link add link wwan0 name $INTERFACE.1 type vlan id 1; fi
if [[ -v DNN1 ]]; then echo "---- ip link set ${INTERFACE}.1 up"; fi
if [[ -v DNN1 ]]; then ip link set $INTERFACE.1 up; fi

echo "---- mbimcli -p -d ${DEVICE} --set-radio-state=on"
mbimcli -p -d $DEVICE --set-radio-state=on
sleep 2
echo "---- mbimcli -p -d ${DEVICE} --attach-packet-service"
mbimcli -p -d $DEVICE --attach-packet-service
#echo "---- mbimcli -p -d ${DEVICE} --connect=session-id=0,access-string=${DNN0},ip-type=${DNN_TYPE0}"
#mbimcli -p -d $DEVICE --connect=session-id=0,access-string=$DNN0,ip-type=$DNN_TYPE0
ACCESS0=$(resolve_access_string "$DNN0")
echo "---- mbimcli -p -d ${DEVICE} --connect=session-id=0,access-string=${ACCESS0},ip-type=${DNN_TYPE0}"
mbimcli -p -d $DEVICE --connect=session-id=0,access-string=$ACCESS0,ip-type=$DNN_TYPE0
echo "---- mbim-set-ip.sh ${DEVICE} ${INTERFACE} 0"
mbim-set-ip.sh $DEVICE $INTERFACE 0

if [[ -v DNN1 ]]; then echo "---- mbimcli -p -d ${DEVICE} --connect=session-id=1,access-string=${DNN1},ip-type=${DNN_TYPE1}"; fi
#if [[ -v DNN1 ]]; then mbimcli -p -d $DEVICE --connect=session-id=1,access-string=$DNN1,ip-type=$DNN_TYPE1; fi
#if [[ -v DNN1 ]]; then echo "---- mbim-set-ip.sh ${DEVICE} ${INTERFACE}.1 1"; fi
if [[ -v DNN1 ]]; then ACCESS1=$(resolve_access_string "$DNN1"); fi
if [[ -v DNN1 ]]; then echo "---- mbimcli -p -d ${DEVICE} --connect=session-id=1,access-string=${ACCESS1},ip-type=${DNN_TYPE1}"; fi
if [[ -v DNN1 ]]; then mbimcli -p -d $DEVICE --connect=session-id=1,access-string=$ACCESS1,ip-type=$DNN_TYPE1; fi
if [[ -v DNN1 ]]; then mbim-set-ip.sh $DEVICE $INTERFACE.1 1; fi

DNN0_IPADDRESS=$(ip -f inet addr show $INTERFACE | awk '/inet / {print $2}')
if [[ -v DNN1 ]]; then DNN1_IPADDRESS=$(ip -f inet addr show $INTERFACE.1 | awk '/inet / {print $2}'); fi

if  [[ $quiet = "false" ]] ; then
    echo "--------Perform Ping Test --------"
    if [[ -v DNN0_IPADDRESS ]]; then ping -I $INTERFACE -c 4 8.8.8.8 ; fi
    if [[ -v DNN1_IPADDRESS ]]; then ping -I $INTERFACE.1 -c 4 8.8.8.8 ; fi
fi
