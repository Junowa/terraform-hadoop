# terraform-hadoop

This project deploys hadoop ambari cluster.

To use it:

```
export TF_VAR_ssh_key= "ssh-rsa AAAAB.......="
export TF_VAR_trusted_ip_list='['10.0.0.1',"10.0.2.1"]'
terraform init
terraform plan
terraform apply
```

Post-configuration settings:

Connect to Ambari > Configs> Advanced.

Set dfs.namenode.datanode.registration.ip-hostname-check to false
