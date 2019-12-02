# terraform-hadoop

export TF_VAR_ssh_key= "ssh-rsa AAAAB.......="
export TF_VAR_trusted_ip_list='['10.0.0.1',"10.0.2.1"]'

In Ambari>Configs/Advanced: set dfs.namenode.datanode.registration.ip-hostname-check to false
