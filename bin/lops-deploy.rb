#!/bin/ruby
require 'set'
require 'shellwords'
require 'optparse'
require 'json'
local_lib = File.join(File.dirname(__FILE__), '../share/lops/lib');
$LOAD_PATH << local_lib
require 'common'


def build(target)
  on = @on ? ['--on', @on.join(',')] : []
  sys = @system ? ['--system', @system] : []
  local = File.join(File.dirname(__FILE__), 'lops-build');
  if File.exists?(local)
      pipe_cmd('ruby', local, *sys, *on, *@build_args, target)
  else
      pipe_cmd('lops-build', *sys, *on, *@build_args, target)
  end
end

def show_syntax
  $stderr.puts "lops-deploy [--rollback|--on <host>|--branch <branch>] [target] [copy|dry-activate|boot|test|switch]"
  exit 1
end
ENV['PATH'] = "@path@:#{ENV['PATH']}"


# Parse the command line options.
options = {}
orig_args = ARGV.dup
extra_build_flags = []
flake_flags = ['--extra-experimental-features', 'nix-command flakes']
options[:profile] = '/nix/var/nix/profiles/system'
options[:branch] = 'main'
@maybe_sudo = []
@build_args = []
@copy_closure_flags = []

OptionParser.new do |opts|
  opts.banner = "Usage: machines-deploy [options] [target] [copy|dry-activate|boot|test|switch]"

  opts.on('--help', 'Display this help message') do
    show_syntax
  end

  opts.on('-p', '--profile-name PROFILE', 'Specify the profile name') do |profile|
    options[:profile] = profile == 'system' ? '/nix/var/nix/profiles/system' : "/nix/var/nix/profiles/system-profiles/#{profile}"
  end

  opts.on('-b', '--branch BRANCH', 'Specify the branch') do |branch|
    options[:branch] = branch
  end

  opts.on('-h', '--build-host HOST', 'Specify host to build on') do |build_host|
    @build_host = build_host
  end

  opts.on('-r', '--rollback', 'Roll back the system') do
    options[:rollback] = true
  end

  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    @verbose_script = v
    @build_args << '-v' if v
  end

  opts.on('--on HOSTS', 'Specify hosts to deploy') do |on|
    @on = on.split(',')
  end

  opts.on('--use-remote-sudo', 'Use sudo on the remote host') do
    @maybe_sudo = ['sudo', '--']
  end

  opts.on("--impure", "Allow impure evaluation") do
    @build_args << "--impure"
  end
end.parse!

if ENV['SUDO_USER']
  @maybe_sudo = ['sudo', '--']
end

# Get remaining command line arguments
target, action = ARGV
if action.nil? && Set['copy', 'switch', 'boot', 'test', 'dry-activate'] === target
  action = target
  target = nil
end
show_syntax unless action
target = "/nix/var/nix/gcroots/per-user/cache/#{options[:branch]}" unless target

unless options[:rollback]
  unless File.exists?(target)
    $stderr.puts "Target '#{target}' must exist"
    show_syntax
  end

  unless built?(target)
    target = build target
    if target == ''
      $stderr.puts 'Build failed'
      exit 1
    end
    puts "Target: #{target}"
  end

  @info = JSON.parse(File.read(File.join(target, "info.json")))
  @info.each_pair do |k, v|
    if @on.nil? || @on.include?(k)
      $stderr.puts "Deploy to #{k}"
      if v["targetUser"].strip == ""
        target_user = ENV['SSH_USER'] || ENV['USER'] || 'root'
      else
        target_user = v["targetUser"]
      end
      if v["substituteOnDestination"]
        @copy_closure_flags = ['--use-substitutes']
      else
        @copy_closure_flags = []
      end
      path_to_config=File.readlink(File.join(target, "#{k}/system"))
      target_host = "#{target_user}@#{v["targetHost"]}"
      if action == "switch" || action == "boot"
        copy_to_target target_host, @build_host, path_to_config
        if options[:profile] != "/nix/var/nix/profiles/system"
          target_host_cmd target_host, @maybe_sudo, 'mkdir', '-p', '-m', '0755', File.dirname(options[:profile])
        end
        target_host_cmd target_host, @maybe_sudo, 'nix-env', '-p', options[:profile], '--set', path_to_config
      elsif action == 'test' || action == 'copy' || action == 'dry-activate'
      else
        show_syntax
      end
      # Copy build to target host if we haven't already done it
      if action != 'switch' && action != 'boot'
        copy_to_target target_host, @build_host, path_to_config
      end

      # If we're not just building, then make the new configuration the boot
      # default and/or activate it now.
      if action == 'switch' || action == 'boot' || action == 'test' || action == 'dry-activate'
        if ! target_host_cmd(target_host, @maybe_sudo, File.join(path_to_config, 'bin/switch-to-configuration'), action)
          $stderr.puts "warning: error(s) occurred while switching to the new configuration"
          exit 1
        end
        if File.exists?(File.join(path_to_config, 'health-checks.json'))
            run_cmd 'check-health', '--target-host', target_host, File.join(path_to_config, 'health-checks.json')
        end
      end
    end
  end
else

end