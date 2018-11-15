#!/bin/bash

if [ ! -f /usr/bin/kubectl ] || [ ! -f /root/.kube/config ]; then
  echo "Cannot communicate with Kubernetes, missing mounts"
fi

if [ "$(kubectl get deploy cuckoo | wc -l)" -gt 0 ]; then
  kubectl delete deploy cuckoo
fi

if [ "$1" == "default" ]; then
  if [ "$(kubectl get cm cuckoo | wc -l)" -gt 0 ]; then
    kubectl delete cm cuckoo
  fi
  kubectl create cm cuckoo --from-file /root/.cuckoo/auxiliary.conf \
    --from-file /root/.cuckoo/cuckoo.conf \
    --from-file /root/.cuckoo/kvm.conf \
    --from-file /root/.cuckoo/memory.conf \
    --from-file /root/.cuckoo/processing.conf \
    --from-file /root/.cuckoo/reporting.conf \
    --from-file /root/.cuckoo/routing.conf
fi

kubectl create -f /tmp/deploy.yml

exit 0
