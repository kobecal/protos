# Domain template

To add a domain:

1. Choose the owning namespace, such as `miniprogram`, `infra`, `platform`, or
   `product`.
2. Create `proto/kobecal/<namespace>/<domain>/VERSION` from
   `templates/domain/VERSION`.
3. Create `proto/kobecal/<namespace>/<domain>/v1` and add the initial `.proto`
   files.
4. Add the owning GitHub team to `.github/CODEOWNERS`.
5. Document every cross-domain import and obtain both owners' approval.
6. Run `make generate` and commit the generated nested Go module.
7. Run `make verify` before opening the pull request.

Do not copy this README into the `proto` tree; it is an onboarding template.
