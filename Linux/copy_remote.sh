#!/bin/bash
rsa_key="rsa key path"
user="remote server login"
server_ip="remote server IP"
remote_path="remote server path"
local_path="local directory to copy to"

#copy file from remote Linux server to local Linux mashine
scp -i $rsa_key $user@$server_ip:$remote_path/file_name $local_path

#copy entire directory from remote Linux server to local Linux mashine
scp -i $rsa_key $user@$server_ip:$remote_path/* $local_path



