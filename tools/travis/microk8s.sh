#!/usr/bin/env bash

set -e
set -o pipefail

sudo snap install microk8s --classic --channel=1.17/stable

# do this in advance, so that microk8s running as sudo doesn't create it
mkdir -p ~/.kube

# Download and install misc packages and utilities
pushd /tmp
  # Download and install kubectl
  (curl -LO https://storage.googleapis.com/kubernetes-release/release/v${TRAVIS_KUBE_VERSION}/bin/linux/arm64/kubectl && \
       sudo cp kubectl /usr/local/bin/kubectl && \
       sudo chmod a+rx /usr/local/bin/kubectl) &

  # Download and install helm
  #  curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh && chmod +x get_helm.sh && ./get_helm.sh
  if [ -n "$NEEDS_HELM" ]; then
      # Need socat for helm to forward connections to tiller on ubuntu 16.04
      (sudo apt-get update && sudo apt install -y socat) &

      PLATFORM=`uname | tr '[:upper:]' '[:lower:]'`
      echo "Downloading this helm: https://storage.googleapis.com/kubernetes-helm/helm-v${TRAVIS_HELM_VERISON}-${PLATFORM}-arm.tar.gz"
      curl -L "https://storage.googleapis.com/kubernetes-helm/helm-v${TRAVIS_HELM_VERSION}-${PLATFORM}-arm64.tar.gz" | tar zxf -
      sudo cp ${PLATFORM}-arm64/helm /usr/local/bin
      sudo cp ${PLATFORM}-arm64/tiller /usr/local/bin
      sudo chmod +x /usr/local/bin/{helm,tiller}
  fi

  # Download and install openshift-client
  if [ -n "$NEEDS_OC" ]; then
      PLATFORM=`uname | tr '[:upper:]' '[:lower:]'`
      echo "Downloading this oc: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${TRAVIS_OC_VERISON}/openshift-client-${PLATFORM}.tar.gz"
      curl -L "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${TRAVIS_OC_VERISON}/openshift-client-${PLATFORM}.tar.gz" | tar zxf -
      sudo cp oc /usr/local/bin
      sudo chmod +x /usr/local/bin/oc
      oc version

      echo "Downloading this odo: https://mirror.openshift.com/pub/openshift-v4/clients/odo/latest/odo-${PLATFORM}-arm64"
      sudo sh -c "curl -L https://mirror.openshift.com/pub/openshift-v4/clients/odo/latest/odo-${PLATFORM}-arm64 -o /usr/local/bin/odo"
      sudo chmod +x /usr/local/bin/odo
      odo version
  fi

  # wait for the kubectl download and socat installation
  wait
popd

# waiting till microk8s is ready
echo "waiting for microk8s to become available"
sudo microk8s.status --wait-ready
echo "microk8s is ready for e-business"

# smash the microk8s config into the place kubectl expects it to be found
echo "smashing microk8s kubeconfig into .kube/config"
sudo sh -c "microk8s.kubectl config view --raw > /tmp/kubeconfig"
sudo chmod a+r /tmp/kubeconfig
sudo chmod -R a+r ~/.kube
cp /tmp/kubeconfig ~/.kube/config
echo "smashing microk8s kubeconfig into .kube/config [SUCCESS]"

# Pods running in kube-system namespace should have cluster-admin role
kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default

kubectl version -o json

if [ -n "$NEEDS_HELM" ]; then
    # Install tiller into the cluster
    /usr/local/bin/helm init --service-account default

    # helm 2 versus kubernetes 1.16+
    # See https://github.com/helm/helm/issues/6374#issuecomment-533427268
    # helm init --service-account tiller --override spec.selector.matchLabels.'name'='tiller',spec.selector.matchLabels.'app'='helm' --output yaml | sed 's@apiVersion: extensions/v1beta1@apiVersion: apps/v1@' | kubectl apply -f -

    # Wait for tiller to be ready
    TIMEOUT=0
    TIMEOUT_COUNT=60
    set +e
    until [ $TIMEOUT -eq $TIMEOUT_COUNT ]; do
        TILLER_STATUS=$(kubectl -n kube-system get pods -o wide | grep tiller-deploy | awk '{print $3}')
        TILLER_READY_COUNT=$(kubectl -n kube-system get pods -o wide | grep tiller-deploy | awk '{print $2}')
        if [[ "$TILLER_STATUS" == "Running" ]] && [[ "$TILLER_READY_COUNT" == "1/1" ]]; then
            break
        fi
        echo "Waiting for tiller to be ready"
        kubectl -n kube-system get pods -o wide
        let TIMEOUT=TIMEOUT+1
        sleep 5
    done

    if [ $TIMEOUT -eq $TIMEOUT_COUNT ]; then
        echo "Failed to install tiller"

        # Dump lowlevel logs to help diagnose failure to start tiller
        $HOME/dind-cluster.sh dump
        kubectl -n kube-system describe pods
        exit 1
    fi
fi

echo "microk8s setup script done"
