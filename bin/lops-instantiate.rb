#!/bin/ruby
require 'json'
require 'set'
local_lib = File.join(File.dirname(__FILE__), '../share/lops/lib');
$LOAD_PATH << local_lib
require 'common'

ENV['PATH'] = "@path@:#{ENV['PATH']}"

@target = nil
on_filter = nil
@flake_args = ['--extra-experimental-features', 'nix-command flakes', '--json']
@eval_args = []
while !ARGV.empty?
    i = ARGV.shift
    case i
    when '--on'
        on_filter = ARGV.shift.split(',').to_set
    when '--impure', '--show-trace'
        @eval_args << i
    when '--verbose', '-v'
        @verbose_script = true
    when '-vv', '-vvv', '-vvvv', '-vvvvv', '-vvvvvv'
        @verbose_script = true
        @eval_args << i[0..-1]
    when '--system'
        @system = ARGV.shift
    else
        if @target
            $stderr.puts "Unknown option #{i}"
            exit 1
        end
        @target = i
    end
end
@system = json_cmd('nix', 'eval', '--impure', '--json', '--expr', 'builtins.currentSystem') unless @system
@target = '.' unless @target

ENV['NIX_PATH'] = ''

metadata = json_cmd('nix', 'flake', 'metadata', *@flake_args, @target)
exit 1 unless metadata
url = metadata['url']

node_names = nix_eval url, "attrNames lopsHive.nodes"
node_names = node_names.select {|name| on_filter.include? name } if on_filter
info = nix_eval url, "lopsHive.deploymentConfig"
#pp node_names
#pp info

names = nix_quote JSON.generate(node_names)
drv_paths = nix_eval url, "lopsHive.evalSelectedDrvPaths (fromJSON #{names})"
#pp drv_paths
all_paths = nix_quote JSON.generate(drv_paths)
@eval_args << '--impure'
all_imported = nix_eval url, "(lopsHive.importMachines (fromJSON #{all_paths})).#{@system}.drvPath"
puts all_imported
