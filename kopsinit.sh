#!/bin/bash

#Install kops
curl -LO https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x kops-linux-amd64
sudo mv kops-linux-amd64 /usr/local/bin/kops

#Install Kubectl
curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

#Install awscli & jq
sudo apt-get update
sudo apt-get -y install awscli
sudo apt-get -y install jq

#Create kops user and group
aws iam create-group --group-name kops

aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops

aws iam create-user --user-name kops

aws iam add-user-to-group --user-name kops --group-name kops

aws iam create-access-key --user-name kops > accesskey.json

#Configure AWS Credentials
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY=$(cat accesskey.json | jq .AccessKey.AccessKeyId | cut -d'"' -f 2)
export AWS_SECRET_KEY=$(cat accesskey.json | jq .AccessKey.SecretAccessKey | cut -d'"' -f 2)
#rm accesskey.json

#Prepare the cluster
export KOPS_CLUSTER_NAME=k8s.webappdemo.net

#Create an SSH key
ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa|echo -e 'y\n' > ~/dev/null

#Create bucket
bucket=kops-bucket-k8s-webappdemo
aws s3api create-bucket --bucket ${bucket} --region us-east-1
aws s3api put-bucket-versioning --bucket ${bucket} --versioning-configuration Status=Enabled


#Export the S3 Bucket
export KOPS_STATE_STORE=s3://${bucket}

#Create the cluster configuration
kops create cluster --name ${KOPS_CLUSTER_NAME} --topology public --state s3://${bucket} --cloud aws --master-size t2.medium --master-count 3 --master-zones us-east-1a,us-east-1b --node-size t2.medium --node-count 4 \
--zones us-east-1a,us-east-1b \
--ssh-public-key ~/.ssh/id_rsa.pub \

#Create the cluster
kops export kubecfg --admin

KEY=$(aws s3 ls s3://${bucket}/${KOPS_CLUSTER_NAME}/pki/private/ca/ | awk '{print $4}' | grep .*.key)
CERT=$(aws s3 ls s3://${bucket}/${KOPS_CLUSTER_NAME}/pki/issued/ca/ | awk '{print $4}' | grep .*.crt)

aws s3 cp s3://${bucket}/${KOPS_CLUSTER_NAME}/pki/private/ca/$KEY ca.key
aws s3 cp s3://${bucket}/${KOPS_CLUSTER_NAME}/pki/issued/ca/$CERT ca.crt

kops update cluster --name ${KOPS_CLUSTER_NAME} --yes

#Validate cluster configuration
kops validate cluster --wait 10m

#Aply the k8s dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml

#Export master url to the bucket
kubectl cluster-info | grep "control plane.*" | cut -d" " -f7 > masterurl.html
aws s3 cp MaterUrl.html s3://${bucket}/MasterUrl.html
