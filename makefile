#
AWS_REGION ?= ap-southeast-2
AWS ?= aws --region $(AWS_REGION)
PIP_INSTALL ?= pip3 install
NAME_PREFIX = my-cicd

##Default for current account
S3_KMS=69398397-ae6b-4782-b98d-047cc2aaf2d8
DEPLOyMENT_BUCKET=my-deployment-$(AWS_REGION)-account
CODEBUILD_BUCKET=my-codebuild-$(AWS_REGION)-account

#This is a onetime operation per account/per region
prereq: prereq/deployment_bucket.yaml
	aws --region ap-southeast-2 cloudformation \
		deploy --no-fail-on-empty-changeset \
		--stack-name $(NAME_PREFIX)-deployment-resources \
		--template-file prereq/deployment_bucket.yaml \
		--tags "Owner=Suman"


#upload dependencies to s3 for cloudformation
aws-output-stack-package.yaml: files/*.yaml lambdas/**/*.py
	${AWS} cloudformation package \
		--template-file files/stack.yaml \
		--s3-bucket $(DEPLOyMENT_BUCKET) --s3-prefix $(NAME_PREFIX) \
		--kms-key-id $(S3_KMS) \
		--output-template-file $@

deploy: aws-output-stack-package.yaml ca.pem
	${AWS} cloudformation deploy \
		--no-fail-on-empty-changeset \
		--stack-name ${NAME_PREFIX} \
		--template-file aws-output-stack-package.yaml \
		--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--parameter-overrides 'GithubTokenSecretName=${GHE_TOKEN_NAME}' \
							  'SecretManagerKeyId=${SECRETSMANAGER_KMS}' \
							  						'S3KEYID=${S3_KMS}' \
		--tags "Owner=Suman"
		${AWS} s3 cp helpers/add_pr_comment.py s3://${CODEBUILD_BUCKET}/scripts
		${AWS} s3 cp ca.pem s3://${CODEBUILD_BUCKET}/ca/