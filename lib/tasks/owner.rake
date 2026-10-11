require "io/console"

# Owner provisioning replaces public registration. Passwords are read without
# echo so they never appear in shell history, process lists or logs.
namespace :owner do
  read_password = lambda do
    abort "Run this task in an interactive terminal" unless $stdin.tty?
    password = $stdin.getpass("Password (12 to 72 characters): ")
    confirmation = $stdin.getpass("Confirm password: ")
    abort "Passwords did not match" unless password == confirmation
    password
  end

  desc "Create the sole FXTrack owner: bin/rails \"owner:create[owner@example.com]\" (or EMAIL=..., or prompt)"
  task :create, [ :email ] => :environment do |_, args|
    abort "FXTrack already has an owner" if User.exists?
    email = args[:email].presence || ENV["EMAIL"].presence || ($stdout.print("Owner email: ") && $stdin.gets.to_s.strip)
    user = User.new(email_address: email, password: read_password.call)
    abort user.errors.full_messages.to_sentence unless user.save
    puts "Owner created for #{user.email_address}"
  end

  desc "Set a new owner password and sign out every device"
  task password: :environment do
    user = User.first or abort "No owner exists; run owner:create"
    user.password = read_password.call
    abort user.errors.full_messages.to_sentence unless user.save
    user.sessions.destroy_all
    puts "Password updated; all sessions signed out"
  end

  desc "Delete expired owner sessions"
  task prune_sessions: :environment do
    expired = Session.where.not(id: Session.active.select(:id))
    puts "Deleted #{expired.destroy_all.size} expired sessions"
  end
end
