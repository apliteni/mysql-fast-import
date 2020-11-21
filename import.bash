#!/usr/bin/env bash
set -e -o pipefail

# checks

if [ $# -lt 3 ] ; then
  echo "Usage: $0 TEMPLATE_NAME CLUSTER_NAME PROJECT_NAME"
  echo "Available templates: go"
  exit
fi

if ! command -v rancher &> /dev/null
then
    echo "Error: 'rancher' must be installed"
    exit
fi

if ! command -v helm &> /dev/null
then
    echo "Error: 'helm' must be installed"
    exit
fi


template=$1
clusterName=$2
projectName=$(echo $3        \
  | sed 's/\./-/g'       \
  | sed 's/\([a-z]\)\([A-Z]\)/\1-\2/g'       \
  | sed 's/\([A-Z]\{2,\}\)\([A-Z]\)/\1-\2/g' \
  | tr '[:upper:]' '[:lower:]'
  )


if [ ! -f "shared-tools/clusters/${clusterName}.sh" ] ; then
  echo "${clusterName} does not exists"
  exit
fi

# copy gitlab-ci.yml

cp "shared-tools/templates/.gitlab-ci.${template}.yml" .gitlab-ci.yml


function press_enter() {
  read -n 0 -p "Press ENTER to continue"
}

# prepare k8s namespace

echo "Make sure you're in correct context!"
rancher context switch

rancher kubectl create namespace ${projectName} || true
rancher kubectl apply -f shared-tools/helm/v3/manifests/serviceaccount.yaml --namespace=${projectName}
secretName=$(rancher kubectl -n ${projectName} get secret | awk '/^helm-deploy-/{print $1}')
kubeToken=$(rancher kubectl describe secret ${secretName} -n ${projectName} | awk '$1=="token:"{print $2}')


# env variables

echo "1. Open Project > Settings > Repository > Deploy Tokens"
echo "2. Create new deploy token with checked feature 'read_registry'. Save the created token somewhere."


echo "3. Open Gitlab > Project > Settings > CI / CD > Variables. Add variables: "
echo ""
echo "KUBE_GITLAB_USERNAME = (use deploy token name)"
echo ""

echo "KUBE_GITLAB_TOKEN = (use deploy token code)"
echo ""

echo "KUBE_CLUSTER_NAME = ${clusterName}"
echo ""
echo "KUBE_TOKEN="
echo "$kubeToken"
echo ""
press_enter


# add chart

mkdir -p ci/chart

cp "shared-tools/templates/chart/Chart.yaml" "ci/chart/Chart.yaml"
sed "s/PROJECT_NAME/$projectName/" "./ci/chart/Chart.yaml" > tmp.txt && mv tmp.txt "./ci/chart/Chart.yaml"
sed "s/PROJECT_NAME/$projectName/" "./ci/chart/values.yaml" > tmp.txt && mv tmp.txt "./ci/chart/values.yaml"

cp "shared-tools/templates/chart/values.yaml" "ci/chart/values.yaml"

echo "Please enter domain name (leave empty if no needed): "
read domainName

if [ -z "$domainName" ]
then
  sed "s/true # ingress/false # ingress /" "./ci/chart/values.yaml" > tmp.txt && mv tmp.txt "./ci/chart/values.yaml"
else
  sed "s/domainname.tld/$domainName/" "./ci/chart/values.yaml" > tmp.txt && mv tmp.txt "./ci/chart/values.yaml"
fi

echo "Done!"
