#!/bin/sh -x

product="$1"

if [ -z "$product" ]; then
  echo "Usage: `basename "$0"` PRODUCT VM"
  echo "Available products:"
  xe pusb-list params=product-desc | sed '/^\s*$/d' | cut -d ":" -f 2- | sed "s/^\s*/\"/;s/$/\"/"
  exit 0;
fi

host="$2"

vm=`xe vm-list name-label=${host} params=uuid | sed '/^\s*$/d' | awk '{print $5}'`

if [ -z "${vm}" ]; then
  echo "xe: no such vm \"${vm}\""
fi

# shutdown the VM
echo "xe vm-shutdown uuid=${vm}"
xe vm-shutdown uuid=${vm}

# At times the default Emulation of USB parameter of VMs is set to False.So, during those cases, we will not be able to start the VMs after attaching the USB.
# The VM start will fail with error "  The server failed to handle your request, due to an internal error.  The given message may give details useful for debugging the problem.
# message: xenopsd internal error: Device_common.QMP_Error(26, "{\"error\":{\"class\":\"GenericError\",\"desc\":\"Bus 'usb-bus.0' not found\",\"data\":{}},\"id\":\"qmp-000018-26\"}") 
echo "xe vm-param-set uuid=${vm}  platform:usb=True"
xe vm-param-set uuid=${vm} platform:usb=True

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

# get the group to which the physical USB device is connected
usb=`xe usb-group-list PUSB-uuids=${pusb} params=uuid | sed '/^\s*$/d' | awk '{print $5}'`

# create virtual USB and connect to VM
echo "xe vusb-create usb-group-uuid=${usb} vm-uuid=${vm}"
xe vusb-create usb-group-uuid=${usb} vm-uuid=${vm}

# start VM
echo "xe vm-start uuid=${vm}"
xe vm-start uuid=${vm}
