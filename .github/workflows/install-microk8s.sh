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

# Install MicroK8s
sudo snap install microk8s --classic

# Configure UFW
sudo ufw allow in on cni0 && sudo ufw allow out on cni0
sudo ufw default allow routed

# Wait for MicroK8s to be ready
sudo microk8s status --wait-ready

# Add current user to microk8s group and update permissions
sudo usermod -a -G microk8s $USER
newgrp microk8s

# Create the .kube directory if it doesn't exist
mkdir -p ~/.kube

# Ensure the .kube directory is owned by the current user
sudo chown -R $USER ~/.kube

# Fix permissions on MicroK8s credentials
sudo chown -R $USER:$USER /var/snap/microk8s/current/credentials
sudo chmod -R 750 /var/snap/microk8s/current/credentials

# Add the export command to the .bashrc file if it's not already there
if ! grep -q "export KUBECONFIG=/var/snap/microk8s/current/credentials/client.config" ~/.bashrc; then
    echo "export KUBECONFIG=/var/snap/microk8s/current/credentials/client.config" >> ~/.bashrc
fi

# Source the .bashrc file to apply the changes
source ~/.bashrc

# Alternatively, export KUBECONFIG directly for the current session
export KUBECONFIG=/var/snap/microk8s/current/credentials/client.config
sleep 30
# Test accessing the Kubernetes cluster
kubectl get po -A
kubectl apply -f https://raw.githubusercontent.com/kubearmor/KubeArmor/main/tests/k8s_env/ksp/pre-run-pod.yaml
sleep 30
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
