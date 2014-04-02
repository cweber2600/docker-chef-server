# -*- coding: utf-8 -*-
# rubocop:disable GlobalVars, SpecialGlobalVars

# Some reading: http://felipec.wordpress.com/2013/11/04/init/

require 'date'
require 'fileutils'

STDOUT.sync = true

def log(message)
  puts "[#{DateTime.now}] INIT: #{message}"
end

log "Starting #{$PROGRAM_NAME}"

log 'Initializing sysctl for postgres'
unless system 'sysctl -w kernel.shmmax=17179869184 kernel.shmall=4194304'
  fail 'sysctl FAIL'
end

unless File.exist?('/var/log/chef-server') ||
    File.symlink?('/var/log/chef-server')
  log 'Initializing log directory'
  FileUtils.mkdir_p '/var/opt/chef-server/log'
  FileUtils.ln_s '/var/opt/chef-server/log', '/var/log/chef-server'
end

log 'Starting runsvdir ...'
$pid = Process.spawn(
  '/opt/chef-server/embedded/bin/runsvdir', '-P', '/opt/chef-server/sv',
  "log: #{'.' * 128}")
log "Started runsvdir (#{$pid})"

Signal.trap('TERM') do
  log 'Got SIGTERM, shutting down runsvdir ...'
  Process.kill('HUP', $pid)
end

Signal.trap('INT') do
  log 'Got SIGINT, shutting down runsvdir ...'
  Process.kill('HUP', $pid)
end

unless File.exist? '/var/opt/chef-server/bootstrapped'
  pid = Process.spawn '/usr/bin/chef-server-ctl', 'reconfigure'
  log "Not bootstrapped, running `chef-server-ctl reconfigure' (#{pid})"
end

loop do
  chld = Process.wait
  if chld == $pid
    log "Runsvdir exited (#{$?}), exiting"
    if $?.success? || $?.exitstatus == 111
      break
    else
      exit $?.exitstatus
    end
  else
    log "Reaped PID #{chld} (#{$?})"
  end
end
