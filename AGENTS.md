# AGENTS.md

Instructions for coding agents working in fxtrack.

Do not add AI attribution to commits or pull requests, including AI
`Co-Authored-By` trailers or generated-by signatures. Preserve genuine human
attribution. Ask before committing, merging, pushing, or deploying.

## Project

fxtrack is a fresh Ruby on Rails application. Product purpose and feature scope
are not yet defined.

Stack: Rails 8.1.4, Ruby 3.4.4, PostgreSQL, server-rendered ERB, Hotwire
(Turbo and Stimulus), and Tailwind CSS v4. Dependencies use Bundler and
`Gemfile.lock`; JavaScript uses import maps.

## Proportional engineering

Build for established requirements, not hypothetical scale, threats, or future
flexibility. Reuse existing code, the standard library, native platform features,
and installed dependencies before adding machinery.

- Unknown scale or extensibility defaults to the smaller reversible design. Do
  not infer enterprise, multi-tenant, hostile-user, or compliance requirements.
- Derive trust and data-integrity boundaries from actual reachability: untrusted
  input, auth/session/ownership, shared persisted data, destructive operations,
  payments, secrets, and sensitive data.
- Ask only when an unknown materially changes behavior, architecture, persisted
  data, interoperability, a real security boundary, or cost. Otherwise choose the
  simplest repository-native implementation.
- Add an abstraction, dependency, service, configuration surface, compatibility
  layer, or security mechanism only for a current requirement.
- Simplicity never removes real trust-boundary validation, data-loss prevention,
  accessibility, explicit security requirements, configured tests, or project rules.
- Stack-specific template standards apply only when the project uses that stack.

## Coding conventions

- Follow Rails MVC conventions and the installed `rubocop-rails-omakase` rules.
- Use snake_case Ruby filenames and methods; CamelCase classes and modules.
- Keep controllers focused on requests, models on persistence and validation,
  ERB templates in `app/views`, and Stimulus controllers in
  `app/javascript/controllers`.
- Use Active Record and Rails migrations with PostgreSQL.
- Permit request parameters explicitly and validate persisted data in models.
- Enforce server-side authorization when authentication or ownership is added.
- Tailwind CSS v4 source lives in `app/assets/tailwind/application.css`.
  Generated assets in `app/assets/builds` should not be committed.
- Use semantic HTML, accessible labels, keyboard interactions, and clear errors.
- Prefer existing Rails patterns and installed dependencies over new layers.
- Keep changes focused; comment non-obvious reasons, not obvious operations.
- Do not add em dashes, en dashes, or ellipsis characters to generated content.

## Commands

- Dev server: `bin/dev` (http://localhost:3000; Rails plus Tailwind watcher)
- Build: `bin/rails assets:precompile`
- Production server: `RAILS_ENV=production bin/rails server`
- Lint: `bin/rubocop`
- Verify: `bin/ci` (existing Rails setup, lint, and security checks)
- Database preparation: `bin/rails db:prepare`
- Database migrations: `bin/rails db:migrate`
- Console: `bin/rails console`

`bin/dev` installs Foreman if it is absent. `bin/ci` runs
`bin/setup --skip-server`, which may install missing gems and prepares the
database, followed by RuboCop, Bundler Audit, Importmap Audit, and Brakeman.
It requires a working Ruby/Bundler environment and PostgreSQL. Security audits
may need network access. Production asset compilation and startup require the
project's environment and credentials.

No test command or browser test harness is configured. Rails test support is
disabled in `config/application.rb`. Tests are not yet a gate. Configure testing
explicitly before requiring test coverage.
