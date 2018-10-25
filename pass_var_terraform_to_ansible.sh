#!/bin/bash

cd terraform
VAR_FILE=../ansible/terraform_vars
touch $VAR_FILE
JSON="{"
JSON=$JSON"\"kubernetes_route_table_id\":\"$(terraform output kubernetes_route_table_id)\","
JSON=$JSON"\"vpc_dns\":\"$(terraform output vpc_dns)\","
JSON=$JSON"\"kubernetes_master_url\":\"$(terraform output kubernetes_master_url)\","
JSON=$JSON"\"etcd_key_id\":\"$(echo -n $(terraform output etcd_key_id) | base64 -w 0)\","
JSON=$JSON"\"etcd_key_secret\":\"$(echo -n $(terraform output etcd_key_secret) | base64 -w 0)\","
JSON=$JSON"\"aws_region\":\"$(terraform output aws_region)\","
JSON=$JSON"\"s3_etcd_backup_bucket\":\"$(terraform output s3_etcd_backup_bucket)\","
JSON=$JSON"\"cluster_name\":\"$(terraform output cluster_name)\","
JSON=$JSON"\"secrets_bucket\":\"$(terraform output secrets_bucket)\","
JSON=$JSON"\"kubernetes_etcd_url\":\"$(terraform output kubernetes_etcd_url)\""
JSON=$JSON"}"
echo $JSON > $VAR_FILE
