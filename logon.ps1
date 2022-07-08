# Get config from Terraform
$tf = terraform output --json | ConvertFrom-Json
$username = $tf.username.value
$ip_address = $tf.ip_address.value
$port = $tf.ssh_port.value

# Login to server
ssh -o "StrictHostKeyChecking=no" -i "$HOME\.ssh\cloud" "$username@$ip_address" -p $port
