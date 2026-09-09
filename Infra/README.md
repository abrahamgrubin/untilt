# Untilt Infrastructure (Terraform)

Provisions the AWS side of the architecture doc: VPC, ECS/Fargate (API +
worker services), RDS Postgres (with pgvector), SQS, Cognito, ECR, Secrets
Manager, and CloudWatch. See the project's `architecture-design-doc.md`
for the reasoning behind each choice.

## What Terraform can't do for you

Two identity providers require accounts/consoles Terraform has no access
to. Do these first — the values they produce go into `terraform.tfvars`:

**Apple (Sign in with Apple)** — [Apple Developer](https://developer.apple.com/account):
1. Certificates, Identifiers & Profiles → Identifiers → **Services IDs** →
   create one (this is `apple_services_id`, e.g. `com.yourteam.untilt.signin`,
   distinct from the app's own bundle ID). Register it — don't configure the
   "Sign In with Apple" web settings yet, see step 3.
2. Certificates, Identifiers & Profiles → Keys → create a new key with
   "Sign in with Apple" enabled, associated with the app's primary App ID.
   Download the `.p8` file **once** (Apple won't let you re-download it) —
   its contents are `apple_private_key`, its Key ID is `apple_key_id`. Your
   Team ID (top-right of the developer portal) is `apple_team_id`.
3. **Chicken-and-egg, same as Google below**: the Services ID's "Sign In
   with Apple" configuration needs a Return URL pointing at the Cognito
   hosted UI domain, which doesn't exist until after a first `terraform
   apply`. So: apply once with these values (Return URL config still
   empty), then go back to the Services ID → Configure → Sign In with
   Apple, and add:
   - Domain: `<cognito_hosted_ui_domain output>`
   - Return URL: `https://<cognito_hosted_ui_domain output>/oauth2/idpresponse`

**Google (Google Sign-In)** — [Google Cloud Console](https://console.cloud.google.com/apis/credentials):
1. Create an OAuth 2.0 Client ID, type "Web application" (Cognito acts as
   the web client on the app's behalf).
2. Add `https://<cognito_hosted_ui_domain output>/oauth2/idpresponse` as
   an authorized redirect URI — this domain doesn't exist until after a
   first `terraform apply`, so you'll need to apply once, add the redirect
   URI, then it's stable for future applies.
3. Client ID → `google_client_id`, Client secret → `google_client_secret`.

Also needed before shipping (not before development):
- A domain + ACM certificate for `acm_certificate_arn` (HTTPS is required
  by iOS App Transport Security — the ALB serves HTTP-only until this is set).
- Fastlane setup for `.github/workflows/ios-testflight.yml` (match for code
  signing, an App Store Connect API key) — a one-time manual step from a
  Mac with Xcode, not something CI bootstraps.

## Remote state (already done)

State lives in S3 (`untilt-terraform-state-710976282506`, versioned,
encrypted, public access blocked), locked via S3's native conditional-write
locking (`use_lockfile = true` — no DynamoDB table needed on Terraform
1.10+). Set up once via plain AWS CLI calls, not Terraform itself, since
Terraform can't create the backend it's about to use to store its own state.

## First-time setup

```bash
cd Infra
cp terraform.tfvars.example terraform.tfvars   # fill in real values
terraform init
terraform plan    # review before applying against a real AWS account
terraform apply
```

The very first apply uses a placeholder public image for the ECS services
(see `container_image` in variables.tf) just so they can start — they'll
be unhealthy until GitHub Actions pushes a real image (see below). That's
expected on a first apply, not a bug.

## Wiring up GitHub Actions

`.github/workflows/backend-deploy.yml` assumes:
- An IAM role assumable via GitHub's OIDC provider (not created by this
  Terraform yet — add an `aws_iam_openid_connect_provider` +
  `aws_iam_role` scoped to your GitHub repo, or use the AWS Console's
  quickstart for "GitHub Actions OIDC"), its ARN stored as the
  `AWS_DEPLOY_ROLE_ARN` GitHub secret.
- The ECR repo, ECS cluster, and service names match what's in this
  Terraform (`untilt-server`, `untilt-staging`, `untilt-staging-backend`/
  `-worker`) — update the workflow's `env:` block if you rename anything
  here.

## Running migrations against the real database

The RDS instance is in a private subnet (no public access, per PRD
Section 9's access-control bar) — run `npm run db:migrate` from something
inside the VPC (an ECS one-off task, a bastion, or a Session Manager
port-forward), not from a laptop directly.

## Cost note

This is sized for early-stage development, not production scale:
`db.t4g.micro`, one NAT gateway (not per-AZ), single-AZ RDS. Revisit
`db_instance_class`, `single_nat_gateway`, and `multi_az` (already
production-gated on `var.environment`) before real user traffic.
