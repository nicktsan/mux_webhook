build:
	yarn --cwd lambda build

package:
	yarn --cwd lambda package

init:
	terraform init

validate:
	terraform fmt -recursive
	terraform validate

plan:
	terraform plan -var-file input.tfvars -out out.tfplan

apply:
	terraform apply out.tfplan

sync:
	terraform apply -refresh-only -var-file='input.tfvars' --auto-approve

destroy:
	terraform destroy -var-file input.tfvars

all: build package init sync validate plan apply
