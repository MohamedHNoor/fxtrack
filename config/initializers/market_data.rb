# M00 evidence needs all seven pairs collected until the gate passes; then set
# this to false so only owner-enabled pairs are ingested (project plan, M04).
Rails.application.config.x.collect_all_pairs = true

# Explicit diagnostic mode for the M00 evidence worker, independent of login.
Rails.application.config.x.m00_diagnostics = ENV["M00_DIAGNOSTICS"] == "true"
Rails.application.config.x.unattended_monitoring = ENV["UNATTENDED_MONITORING"] == "true"
