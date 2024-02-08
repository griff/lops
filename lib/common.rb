def derivation?(fname)
    File.file?(fname) &&
        File.extname(fname) == '.drv'
end

def json?(fname)
    File.file?(fname) &&
        File.extname(fname) == '.json'
end

def built?(fname)
    Dir.exists?(fname) &&
        File.file?(File.join(fname, "info.json"))
end

# log the given argument to stderr if verbose mode is on
def log_verbose(*args)
    if @verbose_script
        $stderr.puts args.join(' ')
    end
end

def check_exit(*args)
    if $?.exitstatus != 0
        unless @verbose_script
            $stderr.puts args.join(' ')
        end
        $stderr.puts "command failed #{$?.exitstatus}"
        exit 1
    end
end

def json_cmd(*args)
    log_verbose '$', *args
    s = IO.popen(args, 'r') { |p| p.read.strip }
    check_exit(*args)
    JSON.parse(s) if s && !s.empty?
end

# Run a command, logging it first if verbose mode is on
def run_cmd(*args)
    env = args.shift if args.first.is_a?(Hash)
    args = args.first if args.first.is_a?(Array)
    log_verbose '$', *args
    system(env || {}, *args)
end

def pipe_cmd(*args)
    env = args.shift if args.first.is_a?(Hash)
    args = args.first if args.first.is_a?(Array)
    log_verbose '$', *args
    ret = IO.popen(env || {}, args, 'r') {|p| p.read.strip }
    check_exit(*args)
    ret
end

def target_host_cmd(target_host, maybe_sudo, *args)
    env = if target_host.is_a?(Hash)
      e = target_host
      target_host = maybe_sudo
      maybe_sudo = args.shift
      e
    else
      {}
    end
    args = args.first if args.first.is_a?(Array)
    if target_host
        ssh_opts = ENV['SSHOPTS'] ? Shellwords.split(ENV['SSHOPTS']) : []
        if @remote_nix
            run_cmd env, 'ssh', *ssh_opts, target_host, *maybe_sudo, 'env', "PATH=\"#{@remote_nix}:#{ENV['PATH']}\"", *args
        else
            run_cmd env, 'ssh', *ssh_opts, target_host, *maybe_sudo, *args
        end
    else
        run_cmd env, maybe_sudo + args
    end
end

def build_host_cmd(build_host, maybe_sudo, *args)
  env = args.first.is_a?(Hash) ? args.shift : {}
  args = args.first if args.first.is_a?(Array)

  if build_host.nil? then
      run_cmd env, args
  else
      ssh_opts = ENV['SSHOPTS'] ? Shellwords.split(ENV['SSHOPTS']) : []
      if @remote_nix
          run_cmd env, 'ssh', *ssh_opts, build_host, *maybe_sudo, 'env', "PATH=\"#{@remote_nix}:#{ENV['PATH']}\"", *args
      else
          run_cmd env, 'ssh', *ssh_opts, build_host, *maybe_sudo, *args
      end
  end
end

def pipe_host_cmd(*args)
    if @build_host.nil? then
        pipe_cmd *args
    else
        ssh_opts = ENV['SSHOPTS'] ? Shellwords.split(ENV['SSHOPTS']) : []
        if @remote_nix
            pipe_cmd 'ssh', *ssh_opts, @build_host, *@maybe_sudo, 'env', "PATH=\"#{@remote_nix}:#{ENV['PATH']}\"", *args
        else
            pipe_cmd 'ssh', *ssh_opts, @build_host, *@maybe_sudo, *args
        end
    end
end

def copy_to_target(target_host, build_host, path)
  if target_host != build_host
    if target_host.nil?
      log_verbose "Running nix-copy-closure with these NIX_SSHOPTS: #{ENV['SSHOPTS']}"
      run_cmd({'NIX_SSHOPTS' => ENV['SSHOPTS'] || ''}, 'nix-copy-closure', *@copy_closure_flags, '--from', @buildHost, path)
    elsif build_host.nil?
      log_verbose "Running nix-copy-closure with these NIX_SSHOPTS: #{ENV['SSHOPTS']}"
      run_cmd({'NIX_SSHOPTS' => ENV['SSHOPTS'] || ''}, 'nix-copy-closure', *@copy_closure_flags, '--to', target_host, path)
    else
      build_host_cmd build_host, @maybe_sudo, 'nix-copy-closure', *@copy_closure_flags, '--to', target_host, path
    end
  end
end

def nix_eval(url, expr)
    full_expr = "with builtins; let lopsHive = (getFlake \"#{url}\").lopsHive; in #{expr}"
    args = ['nix-instantiate'] + @flake_args + ['--pure-eval', '--eval', '--strict', '--read-write-mode'] + @eval_args + ['-E', full_expr]
    j = json_cmd(*args)
    exit 1 unless j
    j
end

def nix_quote(s)
    inner = s.gsub(/\\/, '\\')
        .gsub(/"/, '\\"')
        .gsub(/\${/, '\\${')
    "\"#{inner}\""
end

def assert_equal(actual, expected)
    unless actual != expected
        puts "Assert #{actual} != #{expected}"
        throw "Assert #{actual} != #{expected}"
    end
end

assert_equal nix_quote(%#["a", "b"]#),  %#"[\"a\", \"b\"]"#
assert_equal nix_quote(%#["\"a\"", "\"b\""]#), %#"[\"\\\"a\\\"\", \"\\\"b\\\"\"]"#
assert_equal nix_quote(%#${dontExpandMe}#), %#"\${dontExpandMe}"#
assert_equal nix_quote(%!\\${dontExpandMe}!), %!"\\\${dontExpandMe}"!
