AWS_REGION ?= ap-southeast-2

# -----------------------------------------
# Custom make targets
sshkey:=/tmp/.buildkite-$(queue)

ifeq ($(queue),)
  $(error environment variable 'queue' must be specified)
endif

check-ssh-key:
	@key=$$(aws --region $(AWS_REGION) ec2 describe-key-pairs --key-names buildkite-$(queue) --query "KeyPairs[].KeyName" --output text); \
		if [[ $$key == buildkite-$(queue) ]]; then \
			echo "ec2 key pair buildkite-$(queue) already exists"; \
		fi

## Create EC2 key pairs
create-ssh-key:
	@echo creating ec2 key pairs named 'buildkite-$(queue)'
	@aws --region ${AWS_REGION} ec2 create-key-pair --key-name "buildkite-$(queue)" | jq -r ".KeyMaterial" > $(sshkey)
	@if [[ ! -f "$(sshkey)" ]]; then \
		die "error: cannot find ssh key file: $(sshkey)"; \
	fi;
	@chmod 600 $(sshkey)
	@ssh-keygen -y -f $(sshkey) > $(sshkey).pub

## Append customised iam policies to buildkite agent iam role
put-role-policy:
	@echo appending custom iam policies to buildkite agent iam role
	@aws --region ${AWS_REGION} iam put-role-policy \
		--role-name buildkite-queue-$(queue)-Role \
		--policy-name BuildkiteCustomPolicy \
		--policy-document file://custom_resources/iam/buildkite_custom_policies.json


## Upload buildkite bot user ssh private key to buildkite secret s3 bucket to be able to clone github repos
upload-private-key-buildkite:
	@secret_bucket=$$(aws --region $(AWS_REGION) cloudformation describe-stack-resources \
									--stack-name buildkite-queue-$(queue) --logical-resource-id ManagedSecretsBucket \
									--query "StackResources[*].PhysicalResourceId" --output text); \
	echo uploading ssh private key $(sshkey) to buildkite secret s3 bucket '$$secret_bucket'; \
	aws s3 cp --acl private --sse AES256 $(sshkey) s3://$$secret_bucket/private_ssh_key


## Upload buildkite bot user ssh public key to github in order to allow buildkite agent to clone github repos
## Note: githubtoken (user buildkite@fmclarity.com PAT) can be retrieved from AWS Secret Manager '/github/api-token/ssh-gpg-management'
upload-public-key-github:
	@echo "uploading ssh public key to github buildkite@fmclarity.com user."
	@githubtoken=$$(aws secretsmanager get-secret-value --secret-id /github/api-token/ssh-gpg-management --query 'SecretString' --output text); \
	pubkey=$$(cat $(sshkey).pub); \
  curl -H "Content-Type: application/json" -H "Authorization: token $$githubtoken" \
		--data "{\"title\":\"buildkite-${queue}\",\"key\":\"$$pubkey\"}" \
		https://api.github.com/user/keys
