#!/bin/ruby

require 'json'
require 'net/http'
require 'openssl'
require 'timeout'
require 'open3'
require 'shellwords'
require 'pp'

def run_program(target_host, program)
  # Get the command and description from the JSON object
  cmd = program['cmd']
  description = program['description']
  timeout = program['timeout']

  if target_host
    if ENV['SSHOPTS']
      ssh_opts = Shellwords.split(ENV['SSHOPTS'])
      cmd = ['ssh'] + ssh_opts + [target_host] + cmd
    else
      cmd = ['ssh', target_host] + cmd
    end
  end
  
  # Execute the command and capture stdout and stderr
  stdoe, status = Open3.popen2e(*cmd) do |i, oe, t|
    outerr_reader = Thread.new { oe.read }
    i.close
    status = begin
      Timeout::timeout(timeout) do
        t.value
      end
    rescue Timeout::Error
      Process::kill("KILL", t.pid)
      outerr_reader.value
      raise Timeout::Error
    end
    [outerr_reader.value, status]
  end

  # Check if the program executed successfully
  if status.success?
    $stderr.puts "\t* #{description}: OK"
    0
  else
    $stderr.puts "\t* #{description}: Failed (#{stdoe})"
    status.exitstatus
  end
rescue Timeout::Error
  $stderr.puts "\t* #{description}: Failed (Timeout after #{timeout}s)"
  -1
end

def run_http(default_host, http_check)
  description = http_check['description']
  host = http_check['host'] || default_host
  scheme = http_check['scheme']
  port = http_check['port']
  path = http_check['path']
  headers = http_check['headers']
  period = http_check['period']
  timeout = http_check['timeout']
  ignore_ssl_errors = http_check['insecureSSL']

  uri = URI("#{scheme}://#{host}#{port.nil? ? "" : ":" + port}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = scheme == 'https'
  if ignore_ssl_errors
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  else
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  end

  Timeout::timeout(timeout) do
    response = http.get(uri, headers)

    code = response.code.to_i
    if 200 <= code && code < 300
      $stderr.puts "\t* #{description}: OK"
      0
    else
      $stderr.puts "\t* #{description}: Failed (#{response.message})"
      response.code
    end
  end
rescue Timeout::Error
  $stderr.puts "\t* #{description}: Failed (Timeout after #{timeout}s)"
  -1
end

def run_check(args)
  while yield != 0
    sleep (args['period'] || 2)
  end
end


def perform(target_host, file, timeout)
  # Parse the JSON file
  file = File.read(file)
  checks = JSON.parse(file)

  host = checks['host']
  $stderr.puts "Running healthchecks on #{host}"

  # Execute each program in parallel using threads
  cmd_checks = (checks['cmd'] || []).map do |program|
    Thread.new do
      run_check(program) do
        run_program target_host, program
      end
    end
  end
  http_checks = (checks['http'] || []).map do |http_check|
    Thread.new do
      run_check(http_check) do
        run_http host, http_check
      end
    end
  end
  threads = cmd_checks + http_checks

  # Wait for all threads to complete
  if timeout > 0
    begin
      Timeout::timeout(timeout) do
        threads.each(&:join)
        $stderr.puts 'Health checks OK'
      end
    rescue Timeout::Error
      $stderr.puts "Timeout: Gave up waiting for health checks to complete after #{timeout} seconds"
    end
  else 
    threads.each(&:join)
    $stderr.puts 'Health checks OK'
  end
end

def show_syntax
  $stderr.puts 'check-health [--timeout <timeout>|--target-host <host>] <file>'
  exit 1
end

filename=nil
target_host=nil
timeout=0
while !ARGV.empty?
  arg = ARGV.shift
  if arg.start_with?('--') || arg.start_with?('-')
    case arg
    when '--target-host', '-t'
      target_host=ARGV.shift
    when '--timeout'
      timeout = ARGV.shift.to_i
    else
      $stderr.puts "Unknown option: #{arg}"
      show_syntax
    end
  elsif filename.nil?
    filename = arg
  else
    $stderr.puts "Unexpected argument: #{arg}"
    show_syntax
  end
end
perform target_host, filename, timeout