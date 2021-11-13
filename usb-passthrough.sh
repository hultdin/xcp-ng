#!/bin/sh -x

product="$1"

if [ -z "$product" ]; then
  echo "Usage: `basename "$0"` PRODUCT VM"
  echo "Available products:"
  xe pusb-list params=product-desc | sed '/^\s*$/d' | cut -d ":" -f 2- | sed "s/^\s*/\"/;s/$/\"/"
  exit 0;
fi

host="$2"

if [ -z "$host" ]; then
  echo "Usage: `basename "$0"` PRODUCT VM"
  exit 0;
fi

vm=`xe vm-list name-label=${host} params=uuid | sed '/^\s*$/d' | awk '{print $5}'`

if [ -z "${vm}" ]; then
  echo "xe: no such vm \"${vm}\""
fi

echo "xe vm-shutdown uuid=${vm}"
xe vm-shutdown uuid=${vm}

# get uuid for the physical USB device
pusb=`xe pusb-list product-desc="${product}" params=uuid | sed '/^\s*$/d' | awk '{print $5}'`
if [ -z "${pusb}" ]; then
  echo "xe: no such device"
fi

# enable passthrough for the physical USB device
if [ `xe pusb-param-get uuid=${pusb}  param-name=passthrough-enabled` != "true" ]; then
  echo "xe pusb-param-set uuid=${pusb} passthrough-enabled=true"
  xe pusb-param-set uuid=${pusb} passthrough-enabled=true
fi

# get the group to which the physical USB device belongs
usb=`xe usb-group-list PUSB-uuids=${pusb} params=uuid | sed '/^\s*$/d' | awk '{print $5}'`

# ceate virtual USB and connect it to the VM
echo "xe vusb-create usb-group-uuid=${usb} vm-uuid=${vm}"
xe vusb-create usb-group-uuid=${usb} vm-uuid=${vm}

echo "xe vm-start uuid=${vm}"
xe vm-start uuid=${vm}
