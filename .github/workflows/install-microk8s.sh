#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2021 Authors of KubeArmor

# Ensure kubectl is installed
if ! command -v kubectl &> /dev/null
then
    echo "kubectl could not be found, installing..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# Detect the container runtime
if [ "$RUNTIME" == "" ]; then
    if [ -S /var/run/docker.sock ]; then
        RUNTIME="docker"
    elif [ -S /var/run/crio/crio.sock ]; then
        RUNTIME="crio"
    else # default
        RUNTIME="containerd"
    fi
fi

# Install microk8s
sudo snap install microk8s --classic
sudo ufw allow in on cni0 && sudo ufw allow out on cni0
sudo ufw default allow routed
sleep 60

sudo usermod -a -G microk8s $USER
newgrp microk8s
sudo chown -R $USER ~/.kube
# Add the export command to the .bashrc file
echo "export KUBECONFIG=/var/snap/microk8s/current/credentials/client.config" >> ~/.bashrc

# Source the .bashrc file to apply the changes
source ~/.bashrc

# Get the list of pods in all namespaces
kubectl get po -A


# Wait for control plane to initialize
# echo "waiting for control plane to initialize"
# sleep 20
# K0S_CONFIG="/var/lib/k0s/pki/admin.conf"
# while [ ! -f $K0S_CONFIG ]; do
#     echo "waiting for control plane to initialize"
#     sleep 5
# done

# # Set kubeconfig - minikube does it automatically
# KUBEDIR=$HOME/.kube
# KUBECONFIG=$KUBEDIR/config
# [[ ! -d $KUBEDIR ]] && mkdir -p $KUBEDIR
# if [ -f $KUBECONFIG ]; then
#     echo "Found $KUBECONFIG already in place ... backing it up to $KUBECONFIG.backup"
#     cp $KUBECONFIG $KUBECONFIG.backup
# fi

# sudo k0s kubeconfig admin > $KUBECONFIG
# export KUBECONFIG=$KUBECONFIG
# echo "export KUBECONFIG=$KUBECONFIG" | tee -a ~/.bashrc

# echo "wait for initialization"
# sleep 15

runtime="15 minute"
endtime=$(date -ud "$runtime" +%s)

while [[ $(date -u +%s) -le $endtime ]]
do
    status=$(kubectl get pods -A -o jsonpath={.items[*].status.phase})
    [[ $(echo $status | grep -v Running | wc -l) -eq 0 ]] && break
    echo "wait for initialization"
    sleep 1
done

# kubectl patch daemonset kube-router -n kube-system --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args/5", "value": "--metrics-port=8082"}]'
# sleep 10
kubectl get pods -A
