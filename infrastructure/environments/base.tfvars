name = "cloud-resume-challenge"

region = "us-east-1"

account_role_name = "OrganizationAccountAccessRole"

account_close_on_deletion = true

github_actions_role_name = "GithubActionsRole"

user_role_name = "OrganizationDeveloperRole"

github_actions_power_user_access = [true, true, true]

user_power_user_access = [true, false, false]

tags = {
  project     = "cloud-resume-challenge"
  environment = "base"
}
