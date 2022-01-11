#!/bin/sh -x

pif="$1"

if [ -z "${pif}" ]; then
  echo "Usage: `basename "$0"` INTERFACE"
  exit 0;
fi

uuid=`xe pif-list device=${pif} params=uuid | sed '/^\s*$/d' | awk '{print $5}'`
if [ -z "${uuid}" ]; then
  echo "xe: no interface named ${pif}"
  exit 0;
fi

br="`ovs-vsctl port-to-br ${pif} 2>/dev/null`"
if [ $? != 0 -o -z "${br}" ]; then
  echo "ovs-vsctl: no bridge associated with ${pif}"
  exit 0;
fi

# set the physical interface to promiscuous mode
if !xe pif-param-get uuid=${uuid} param-name=other-config param-key=promiscuous > /dev/null 2>&1; then
  echo "xe pif-param-set uuid=${uuid} other-config:promiscuous=\"true\""
  xe pif-param-set uuid=${uuid} other-config:promiscuous="true"
else
  if [ `xe pif-param-get uuid=${uuid} param-name=other-config param-key=promiscuous` != "true" ]; then
    echo "xe pif-param-set uuid=${uuid} other-config:promiscuous=\"true\""
    xe pif-param-set uuid=${uuid} other-config:promiscuous="true"
  fi
fi

# set all virtual interfaces associated with the physical interface to promiscuous mode
for uuid in `xe vif-list network-name-label=${pif} params=uuid | sed '/^\s*$/d' | awk '{print $5}'`; do
  if !xe vif-param-get uuid=${uuid} param-name=other-config param-key=promiscuous > /dev/null 2>&1; then
    echo "xe vif-param-set uuid=${uuid} other-config:promiscuous=\"true\""
    xe vif-param-set uuid=${uuid} other-config:promiscuous="true"
  else
    if [ `xe vif-param-get uuid=${uuid} param-name=other-config param-key=promiscuous` != "true" ]; then
      echo "xe vif-param-set uuid=${uuid} other-config:promiscuous=\"true\""
      xe vif-param-set uuid=${uuid} other-config:promiscuous="true"
    fi
  fi
done

# connect all virtual interfaces associated with the physical interface to the existing bridge
for vif in `ovs-vsctl list-ifaces ${br} | grep -v ${pif}`; do
  echo "ovs-vsctl -- set Bridge ${br} mirrors=@m -- --id=@${pif} get Port ${pif} -- --id=@${vif} get Port ${vif} -- --id=@m create Mirror name=${pif}-mirror select-src-port=@${pif} select-dst-port=@${pif} output-port=@${vif}"
  ovs-vsctl -- set Bridge ${br} mirrors=@m -- --id=@${pif} get Port ${pif} -- --id=@${vif} get Port ${vif} -- --id=@m create Mirror name=${pif}-mirror select-src-port=@${pif} select-dst-port=@${pif} output-port=@${vif}
done
