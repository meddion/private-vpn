ssh:
	ssh -i ~/.ssh/private_vpn_host ubuntu@${SERVER_IP}

ssh-port-forward:
	ssh -i ~/.ssh/private_vpn_host -L 51821:10.0.1.45:51821 ubuntu@${SERVER_IP}

client-up:
	sudo wg-quick up work

client-down:
	sudo wg-quick down work

gen-bcrypt:
	htpasswd -nbBC 10 wg-easy ${PASS_TO_ENCRYPT}


list-vms:
	@aws ec2 describe-instances \
	  --filters "Name=instance-state-name,Values=running" \
	  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value | [0],PublicIpAddress,PrivateIpAddress]' \
	  --output table | cat

tf-rm-all:
	terraform state list | cut -f 1 -d '[' | xargs -L 1  terraform state rm 

lint:
	tflint
