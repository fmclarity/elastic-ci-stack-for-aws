AWS_REGION ?= ap-southeast-2

# -----------------------------------------
# Custom make targets
sshkey:=/tmp/.buildkite-$(queue)

check-ssh-key:
	@ key=$$(aws --region $(AWS_REGION) ec2 describe-key-pairs --key-names buildkite-$(queue) --query "KeyPairs[].KeyName" --output text); \
		if [[ $$key == buildkite-$(queue) ]]; then \
			echo "ec2 key pair buildkite-$(queue) already exists"; \
		fi

create-ssh-key:
	aws --region ${AWS_REGION} ec2 create-key-pair --key-name "buildkite-$(queue)" | jq -r ".KeyMaterial" > $(sshkey)
	if [[ ! -f "$(sshkey)" ]]; then \
		die "error: cannot find ssh key file: $(sshkey)"; \
	fi;
	chmod 600 $(sshkey)
	ssh-keygen -y -f $(sshkey) > $(sshkey).pub

put-role-policy:
	aws --region ${AWS_REGION} iam put-role-policy \
		--role-name buildkite-queue-$(queue)-Role \
		--policy-name CloudFrontPolicy \
		--policy-document file://custom_resources/iam/cloudfront_policies.json
