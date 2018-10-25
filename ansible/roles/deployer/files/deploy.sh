#!/bin/bash

log_info () {
  echo "[$(date)] ${1}"
}

main () {
  set -e
  set -u

  enviroment=${1:-staging}
  delay=${2:-5}
  branch_env=$enviroment

  if [[ $enviroment = 'default-production' ]]; then
    enviroment=default
  fi

  if [[ $enviroment = 'default-staging' ]]; then
    enviroment=default
  fi

  secrets_bucket=${SECRETS_BUCKET:-secrets-kube-01}
  secrets_path="${HOME}/deploy/${enviroment}/secrets"
  github_org=${GITHUB_ORG:-meltwater}
  github_repo=${GITHUB_REPO:-executive_alerts_cluster_config}
  repo_path="${HOME}/deploy/${enviroment}/${github_repo}"
  repo_secrets_path="${repo_path}/secrets"
  configmaps_path="${repo_path}/configmaps"

  log_info "Deploying ${enviroment}."
  clone_repo $branch_env $github_org $github_repo $repo_path

  fetch_secrets $enviroment $secrets_bucket $secrets_path
  check_secrets $secrets_path $repo_secrets_path
  create_namespace $enviroment
  apply_secrets $enviroment $secrets_path
  apply_configmaps $enviroment $configmaps_path
  apply_config $enviroment "$repo_path/mlabs-oi"
  cleanup $repo_path $secrets_path

  log_info "Deployed ${enviroment}."
  get_status $enviroment $delay
}

clone_repo () {
  branch_env=$1
  org=$2
  repo=$3
  repo_path=$4
  branch="deploy-${branch_env}"
  ssh_key="${HOME}/.ssh/github"
  repo_url="git@github.com:${org}/${repo}.git"

  log_info "Adding ssh key ${ssh_key} to ssh-agent."
  eval "$(ssh-agent -s)"
  ssh-add $ssh_key

  log_info "Removing ${repo_path}"
  rm -rf $repo_path

  log_info "Cloning ${repo_url}#${branch} to ${repo_path}."
  echo
  git clone --branch $branch --depth 2 $repo_url $repo_path
  echo

  log_info "Deploying this commit:"
  echo
  (cd $repo_path && git --no-pager log -1)
  echo

  log_info "Removing Kubernetes jobs."
  rm -rf $repo_path/jobs

  log_info "Removing non-Kubernetes YAML files."
  rm -rf $repo_path/*.yml

  log_info "Removing CircleCI files."
  rm -rf $repo_path/.circleci
}

fetch_secrets () {
  enviroment=$1
  bucket=$2
  secrets_path=$3
  bucket_path="s3://${bucket}/${enviroment}"

  log_info "Removing ${secrets_path}."
  rm -rf $secrets_path

  log_info "Creating ${secrets_path}."
  mkdir -p $secrets_path

  log_info "Fetching secrets from ${bucket_path} to ${secrets_path}."
  echo
  aws s3 cp --recursive $bucket_path $secrets_path
  echo
}

check_secrets () {
  secrets_path=$1
  repo_secrets_path=$2
  secrets_list="${HOME}/deploy/${enviroment}-secrets.txt"
  repo_secrets_list="${HOME}/deploy/${enviroment}-repo-secrets.txt"

  log_info "Checking list of required secrets in ${repo_secrets_path} is identical to ${secrets_path}."
  (cd $secrets_path && find . -type f > $secrets_list)
  (cd $repo_secrets_path && find . -type f > $repo_secrets_list)
  echo
  diff $secrets_list $repo_secrets_list
  echo
  rm -rf $secrets_list $repo_secrets_list

  log_info "Removing ${repo_secrets_path}."
  rm -rf $repo_secrets_path
}

create_namespace () {
  enviroment=$1
  kubectl get namespace ${enviroment} || kubectl create namespace $enviroment
}

apply_secrets () {
  enviroment=$1
  secrets_path=$2

  log_info "Creating all Kubernetes secrets for namespace ${enviroment} from files in ${secrets_path}."

  (cd $secrets_path \
    && find * -type d -exec \
      kubectl --namespace=$enviroment delete --ignore-not-found secret {} \; \
    && find * -type d -exec \
      kubectl --namespace=$enviroment create secret generic {} --from-file={} \;)
}

apply_configmaps () {
  enviroment=$1
  configmaps_path=$2

  log_info "Creating all Kubernetes ConfigMaps for namespace ${enviroment} from files in ${configmaps_path}."

  if [[ -d $configmaps_path ]]; then
    (cd $configmaps_path \
      && find * -type d -exec \
        kubectl --namespace=$enviroment delete --ignore-not-found configmap {} \; \
      && find * -type d -exec \
        kubectl --namespace=$enviroment create configmap {} --from-file={} \;)
    rm -rf $configmaps_path
  fi
}

apply_config () {
  enviroment=$1
  repo_path=$2

  if [[ $enviroment = 'default' ]]; then
    log_info "Deleting Kubernetes configuration for namespace ${enviroment} in ${repo_path}."
    echo
    kubectl delete --namespace=$enviroment \
      --ignore-not-found --recursive --filename $repo_path
    echo
  fi

  # TODO: See https://github.com/kubernetes/kubernetes/issues/35149.
  cron_path="${repo_path}/cron"
  if [[ -d $cron_path ]]; then
    log_info "Deleting Kubernetes cron for namespace ${enviroment} in ${cron_path}."
    echo
    kubectl delete --namespace=$enviroment \
      --ignore-not-found --recursive --filename $cron_path
    echo
  fi

  log_info "Applying Kubernetes configuration for namespace ${enviroment} in ${repo_path}."
  echo
  kubectl apply --namespace=$enviroment --recursive --filename $repo_path
  echo
}

cleanup () {
  repo_path=$1
  secrets_path=$2

  log_info "Removing ${secrets_path}."
  rm -rf $secrets_path

  log_info "Restoring ${repo_path}."
  (cd $repo_path && git checkout .)
}

get_status () {
  enviroment=$1
  wait=$2

  log_info "Waiting ${wait} seconds to get pod status."
  sleep $wait
  echo
  kubectl --namespace=$enviroment get pods
  echo
}

main ${1:-$DEPLOY_ENV} ${2:-$DEPLOY_DELAY}
