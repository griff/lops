#!/bin/ruby

local_libexec = File.join(File.dirname(__FILE__), '../libexec');
ENV['PATH'] = "#{ENV['PATH']}:#{local_libexec}"

def usage
    commands = ENV['PATH'].split(':').map do |d|
        Dir.glob("lops-*", base: d).map{|f| f.delete_prefix("lops-") }.filter {|f| !f.include?('-')}
    end
    $stderr.puts "Usage:"
    $stderr.puts "   lops subcommand"
    $stderr.puts "Subcommands:"
    commands.flatten.each do |cmd|
        $stderr.puts "   #{cmd}"
    end
    exit 1
end

cmd = ARGV.shift
if cmd
    found = ENV['PATH'].split(':').map {|d| File.join(d, "lops-#{cmd}") }.find {|f| File.executable?(f)}
    pp found
    if found
        exec found, *ARGV
    else
        $stderr.puts "Unknown subcommand: #{cmd}"
        usage    
    end
else
    $stderr.puts "Missing subcommand"
    usage
end