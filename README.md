## HA Kubernetes from scratch on AWS using Terraform + Ansible

The main objectives of this project is to provide an easy way to deploy a HA Kubernetes cluster that you have full control of it. Different from commands like `kube-up.sh` that creates the whole infra and then makes it difficult for you to manage it later, the idea here is to use only Terraform and Ansible.


### Overview

The cluster is separeted in 4 main roles:

**1. etcd**
 - **What?** It's a key-value database used by Kubernetes master.
 - **Implementation:** A set of instances responsible for running etcd servers that peers with each other. These instances are distributed between different AZ's.

**2. master**
 - **What?** The services needed to manage the Kubernetes cluster: API server, controller manager and scheduler.
 - **Implementation:** Multiple instances distributed in differet AZ's that communicates with the etcd cluster.

**3. minion**
 - **What?** Services needed to run pods on the host: Docker, Kube Proxy and Kubelet.
 - **Implementation:** Multiple instances able to communicate with the master and receive the scheduled pods.

**4. deployer**
 - **What?** Way for executing `kubectl` commands in the cluster and setting AWS route table according to the minions ip.
 - **Implementation:** Machine that has credentials to access the master and AWS CLI.

### Prerequisites

First you will need an AWS instance or AWS credentials that has rights for managing the infrastructure.

In the host, you will need to install the following dependecies:

- **Ansible**

```shell
sudo easy_install pip
sudo pip install ansible
sudo mkdir /etc/ansible/
sudo chmod 757 -R /etc/ansible/
```




- **Terraform**


```shell
mkdir terraform
cd terraform/
wget https://releases.hashicorp.com/terraform/0.9.5/terraform_0.9.5_linux_amd64.zip
unzip terraform_0.9.5_linux_amd64.zip
echo "export PATH=$PWD:$PATH" >> ~/.bashrc
export PATH=$PWD:$PATH
cd ..

```


- CFSSL (Generate certificates)

```shell
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl

wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

```


- Clone the project
```shell
git clone git@github.com:fernandoruaro/kubernetes.git
export PROJECT_PATH=$PWD/kubernetes

```

- Create the private key

```shell
cd $PROJECT_PATH
export KEY_NAME=cluster_key #SET A NAME FOR YOUR KEY HERE
mkdir keys
cd keys
#Generate the keys inside the keys directory
ssh-keygen -t rsa -b 4096 -C "Kubernetes Cluster Key" -f "${KEY_NAME}" -N ""
cd ..
#This will send the public key to terraform
echo public_key=\"$(cat "keys/${KEY_NAME}.pub")\" >> terraform/terraform.tfvars

```

### Running Steps


**1. Terraform**

```shell
cd $PROJECT_PATH/terraform
export TF_VAR_control_cidr=$(wget -qO- http://ipecho.net/plain)/32
terraform get
terraform plan
terraform apply


```
**2. Updating Ansible variables according to Terraform**

```shell
cd $PROJECT_PATH
./pass_var_terraform_to_ansible.sh

```

```shell
cd $PROJECT_PATH/keys
echo '{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}' > ca-config.json


echo '{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}' > ca-csr.json


cfssl gencert -initca ca-csr.json | cfssljson -bare ca

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "MASTER_PRIVATE_IP_1",
    "MASTER_PRIVATE_IP_2",
    "MASTER_PRIVATE_IP_3",
    "kubernetes.default.svc"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Cluster",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes



ssh-keygen -t rsa -f github -N ''

ssh-keygen -t rsa -b 4096 -C 'executive_alerts_cluster_config@travis-ci.org' -f deploy_rsa -N ''

```



**3. Ansible**


**3.0. Ansible - dependencies**

```shell
cd $PROJECT_PATH/ansible
ansible-galaxy install -r requirements.yml

```


**3.1. Ansible - 01-basic-requirements**


```shell
ansible-playbook 01-basic-requirements.yaml --private-key=../keys/${KEY_NAME} --extra-vars "@terraform_vars"  --extra-vars "newrelic_license_key=INSERT_YOUR_KEY_HERE"

```

**3.2. Ansible - 02-etcd-cluster**

```shell
ansible-playbook 02-etcd-cluster.yaml --private-key=../keys/${KEY_NAME} --extra-vars "@terraform_vars"

```

**3.3. Ansible - 03-master-cluster**

```shell
ansible-playbook 03-master-cluster.yaml --private-key=../keys/${KEY_NAME} --extra-vars "@terraform_vars"

```

**3.4. Ansible - 04-minions-and-kube-services**

```shell
ansible-playbook 04-minions-and-kube-services.yaml --private-key=../keys/${KEY_NAME} --extra-vars "@terraform_vars"

```
