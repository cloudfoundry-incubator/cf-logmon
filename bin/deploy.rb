#!/usr/bin/env ruby

require 'tempfile'
require 'yaml'
require 'securerandom'

trap 'INT' do
  puts
  puts "Bye bye..."
  exit
end

puts <<-USER_CREATION

********************************************************************************

 ▄████▄    █████▒       ██▓     ▒█████    ▄████  ███▄ ▄███▓ ▒█████   ███▄    █
▒██▀ ▀█  ▓██   ▒       ▓██▒    ▒██▒  ██▒ ██▒ ▀█▒▓██▒▀█▀ ██▒▒██▒  ██▒ ██ ▀█   █
▒▓█    ▄ ▒████ ░       ▒██░    ▒██░  ██▒▒██░▄▄▄░▓██    ▓██░▒██░  ██▒▓██  ▀█ ██▒
▒▓▓▄ ▄██▒░▓█▒  ░       ▒██░    ▒██   ██░░▓█  ██▓▒██    ▒██ ▒██   ██░▓██▒  ▐▌██▒
▒ ▓███▀ ░░▒█░          ░██████▒░ ████▓▒░░▒▓███▀▒▒██▒   ░██▒░ ████▓▒░▒██░   ▓██░
░ ░▒ ▒  ░ ▒ ░          ░ ▒░▓  ░░ ▒░▒░▒░  ░▒   ▒ ░ ▒░   ░  ░░ ▒░▒░▒░ ░ ▒░   ▒ ▒
  ░  ▒    ░            ░ ░ ▒  ░  ░ ▒ ▒░   ░   ░ ░  ░      ░  ░ ▒ ▒░ ░ ░░   ░ ▒░
░         ░ ░            ░ ░   ░ ░ ░ ▒  ░ ░   ░ ░      ░   ░ ░ ░ ▒     ░   ░ ░
░ ░                        ░  ░    ░ ░        ░        ░       ░ ░           ░
░
********************************************************************************

Welcome to CF-Logmon, we're about to do some setup. While you wait,
you may wish to create a user with the space-auditor role for us to act as.
As a reminder, this user is specifically intended to read cf-logmon logs.
Moreover, this user's credentials will be accessible in the CF environment.
Therefore, it should not be you or any other human user.

An example set of commands to create such a user:

   cf create-user <username> <password>
   cf set-space-role <username> <org> <space> SpaceAuditor

Note: keep track of the username and password. We will you ask you for these credentials in a bit.

USER_CREATION

Dir.chdir(File.expand_path('../', __dir__)) do
  puts 'Building application locally ... this may take a while.'
  system './gradlew clean assemble -Dorg.gradle.project.version=1.0.x > /dev/null'
end

username = 'admin'
password = SecureRandom.uuid

application_name = ARGV[0] || 'logmon'

puts <<-ABOUT_TO_PUSH

********************************************************************************

THE TIME HAS COME!

We're about to push cf-logmon to this target:

#{`cf target`}

If any of the above information does not look correct, please hit CTRL+C now.

Please enter the credentials you created earlier below.
Note: they will be echoed in plaintext - this is to reinforce that the credentials should be ephemeral
and not belong to a real user.

ABOUT_TO_PUSH

print "Space Auditor Username: "
log_reader_username = $stdin.gets.chomp

print "Space Auditor Password: "
log_reader_password = $stdin.gets.chomp

print "Log Cycles Per Test: (default: 1000) "
log_cycles = $stdin.gets.chomp

print "Log Byte Size: (default: 256) "
log_byte_size = $stdin.gets.chomp

print "Log Duration Milliseconds Per Test: (default: 1000) "
log_duration_millis = $stdin.gets.chomp

print "Skip SSL Validation? [y/N] "
skip_ssl = $stdin.gets.chomp

skip_validate_ssl = false
if skip_ssl == "y"
  skip_validate_ssl = true
end

if log_cycles.empty?
  log_cycles = 1000
end

if log_byte_size.empty?
  log_byte_size = 256
end

if log_duration_millis.empty?
  log_duration_millis = 1000
end

puts

manifest = {
  'applications' => [{
    'name' => application_name,
    'path' => File.expand_path('../build/libs/logmon-1.0.x.jar', __dir__),
    'env' => {
      'LOGMON_AUTH_USERNAME' => username,
      'LOGMON_AUTH_PASSWORD' => password,
      'LOGMON_CONSUMPTION_USERNAME' => log_reader_username,
      'LOGMON_CONSUMPTION_PASSWORD' => log_reader_password,
      'LOGMON_PRODUCTION_LOG_CYCLES' => log_cycles,
      'LOGMON_PRODUCTION_LOG_BYTE_SIZE' => log_byte_size,
      'LOGMON_PRODUCTION_LOG_DURATION_MILLIS' => log_duration_millis,
      'LOGMON_SKIP_CERT_VERIFY' => skip_validate_ssl,
    }
  }]
}

Tempfile.open('manifest') do |f|
  f.write YAML.dump(manifest)
  f.close

  puts 'Deploying application ...'
  system "cf push -f #{f.path}"
end

puts <<-NOTICE

********************************************************************************

The application deployed successfully!

You can now visit the UI at: https://#{`cf app #{application_name} | grep routes | awk '{print $2}'`.chomp}

The UI is protected with HTTP Basic Auth. The username and password are:

Username: #{username}
Password: #{password}

If you want to change these credentials, run the following commands:

cf set-env #{application_name} LOGMON_AUTH_USERNAME <new username>
cf set-env #{application_name} LOGMON_AUTH_PASSWORD <new password>

********************************************************************************

NOTICE
