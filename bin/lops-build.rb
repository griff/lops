#!/bin/ruby
require 'set'
require 'shellwords'
local_lib = File.join(File.dirname(__FILE__), '../share/lops/lib');
$LOAD_PATH << local_lib
require 'common'

def nix_build_flake(target)
    log_verbose "Building in flake mode."
    if derivation?(target)
        drv = target
    elsif json?(target)
        $stderr.puts "Can't handle raw eval results yet"
        exit 1
    else
        on = @on ? ['--on', @on.join(',')] : []
        sys = @system ? ['--system', @system] : []
        local = File.join(File.dirname(__FILE__), 'lops-instantiate');
        if File.exists?(local)
            drv=pipe_cmd('ruby', local, *sys, *on, *@eval_args, target)
        else
            drv=pipe_cmd('lops-instantiate', *sys, *on, *@eval_args, target)
        end
    end
    unless File.exists?(drv)
        $stderr.puts "nix eval failed"
        exit 1
    end
    if @build_host.nil?
        out_link = @out_link ? ['--out-link', @out_link] : []
        pipe_cmd 'nix', *@flake_flags, 'build', "#{drv}^*", *out_link, *@extra_build_args
        if @out_link
            puts File.readlink(@out_link)
        else
            puts File.readlink('./result')
        end
    else
        log_verbose "Running nix with these NIX_SSHOPTS: #{ENV['SSHOPTS']}"
        run_cmd({'NIX_SSHOPTS' => ENV['SSHOPTS'] || ''}, 'nix', *@flake_flags, 'copy', '--derivation', '--to', "ssh://#{@build_host}", drv)
        out_link = @out_link ? ['--add-root', @out_link] : []
        pipe_host_cmd 'nix-store', '-r', drv, *out_link, *@extra_build_args
        if @out_link
            build_host_cmd @build_host, 'readlink', @out_link
        else
            build_host_cmd @build_host, 'readlink', './result'
        end
    end
end

def show_syntax
    $stderr.puts "machines-build [options] [target]"
    exit 1
end
ENV['PATH'] = "@path@:#{ENV['PATH']}"

@flake_flags = ['--extra-experimental-features', 'nix-command flakes']
@build_host = nil
@maybe_sudo = []
@extra_build_args = []
@eval_args = []
@target = nil
while !ARGV.empty?
    i = ARGV.shift
    case i
    when '--help'
        show_syntax
    when '--verbose', '-v'
        @verbose_script = true
        @eval_args << i
    when '-vv', '-vvv', '-vvvv', '-vvvvv', '-vvvvvv'
        @verbose_script = true
        @eval_args << i
        @extra_build_args << i[0..-1]
    when '--build-host', '-h'
        @build_host = ARGV.shift
    when '--impure'
        @eval_args << i
    when '--on'
        @on = ARGV.shift.split(',')
    when '--out-link'
        @out_link = ARGV.shift
    when '--option'
        @extra_build_args << i << ARGV.shift << ARGV.shift
    when '--system'
        @system = ARGV.shift
    when '--print-build-logs'
        @extra_build_args << i
    when '-L'
        @extra_build_args << i
    when '--log-format'
        @extra_build_args << i << ARGV.shift
    when /^--[a-zA-Z]/
        @extra_build_args << i
        @eval_args << i
    when /^-[a-zA-Z]/
        @extra_build_args << i
        @eval_args << i
    else
        if @target
            $std.err.puts "Unknown option #{i}"
            exit 1
        end
        @target = i
    end
end
@target = '.' unless @target

nix_build_flake @target