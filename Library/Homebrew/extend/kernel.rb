# typed: true # rubocop:todo Sorbet/StrictSigil
# frozen_string_literal: true

require "utils/output"

module Kernel
  sig { params(env: T.nilable(String)).returns(T::Boolean) }
  def superenv?(env)
    return false if env == "std"

    !Superenv.bin.nil?
  end
  private :superenv?

  sig { params(formula: T.nilable(Formula)).void }
  def interactive_shell(formula = nil)
    unless formula.nil?
      ENV["HOMEBREW_DEBUG_PREFIX"] = formula.prefix.to_s
      ENV["HOMEBREW_DEBUG_INSTALL"] = formula.full_name
    end

    if Utils::Shell.preferred == :zsh && (home = Dir.home).start_with?(HOMEBREW_TEMP.resolved_path.to_s)
      FileUtils.mkdir_p home
      FileUtils.touch "#{home}/.zshrc"
    end

    Process.wait fork { exec Utils::Shell.preferred_path(default: "/bin/bash") }

    return if $CHILD_STATUS.success?
    raise "Aborted due to non-zero exit status (#{$CHILD_STATUS.exitstatus})" if $CHILD_STATUS.exited?

    raise $CHILD_STATUS.inspect
  end

  def with_homebrew_path(&block)
    with_env(PATH: PATH.new(ORIGINAL_PATHS), &block)
  end

  def with_custom_locale(locale, &block)
    with_env(LC_ALL: locale, &block)
  end

  # Kernel.system but with exceptions.
  def safe_system(cmd, *args, **options)
    # TODO: migrate to utils.rb Homebrew.safe_system
    require "utils"

    return if Homebrew.system(cmd, *args, **options)

    raise ErrorDuringExecution.new([cmd, *args], status: $CHILD_STATUS)
  end

  # Run a system command without any output.
  #
  # @api internal
  def quiet_system(cmd, *args)
    # TODO: migrate to utils.rb Homebrew.quiet_system
    require "utils"

    Homebrew._system(cmd, *args) do
      # Redirect output streams to `/dev/null` instead of closing as some programs
      # will fail to execute if they can't write to an open stream.
      $stdout.reopen(File::NULL)
      $stderr.reopen(File::NULL)
    end
  end

  # Find a command.
  #
  # @api public
  def which(cmd, path = ENV.fetch("PATH"))
    PATH.new(path).each do |p|
      begin
        pcmd = File.expand_path(cmd, p)
      rescue ArgumentError
        # File.expand_path will raise an ArgumentError if the path is malformed.
        # See https://github.com/Homebrew/legacy-homebrew/issues/32789
        next
      end
      return Pathname.new(pcmd) if File.file?(pcmd) && File.executable?(pcmd)
    end
    nil
  end

  def which_editor(silent: false)
    editor = Homebrew::EnvConfig.editor
    return editor if editor

    # Find VS Code variants, Sublime Text, Textmate, BBEdit, or vim
    editor = %w[code codium cursor code-insiders subl mate bbedit vim].find do |candidate|
      candidate if which(candidate, ORIGINAL_PATHS)
    end
    editor ||= "vim"

    unless silent
      Utils::Output.opoo <<~EOS
        Using #{editor} because no editor was set in the environment.
        This may change in the future, so we recommend setting `$EDITOR`
        or `$HOMEBREW_EDITOR` to your preferred text editor.
      EOS
    end

    editor
  end

  sig { params(filenames: T.any(String, Pathname)).void }
  def exec_editor(*filenames)
    puts "Editing #{filenames.join "\n"}"
    with_homebrew_path { safe_system(*which_editor.shellsplit, *filenames) }
  end

  sig { params(args: T.any(String, Pathname)).void }
  def exec_browser(*args)
    browser = Homebrew::EnvConfig.browser
    browser ||= OS::PATH_OPEN if defined?(OS::PATH_OPEN)
    return unless browser

    ENV["DISPLAY"] = Homebrew::EnvConfig.display

    with_env(DBUS_SESSION_BUS_ADDRESS: ENV.fetch("HOMEBREW_DBUS_SESSION_BUS_ADDRESS", nil)) do
      safe_system(browser, *args)
    end
  end

  IGNORE_INTERRUPTS_MUTEX = T.let(Thread::Mutex.new.freeze, Thread::Mutex)

  def ignore_interrupts
    IGNORE_INTERRUPTS_MUTEX.synchronize do
      interrupted = T.let(false, T::Boolean)
      old_sigint_handler = trap(:INT) do
        interrupted = true

        $stderr.print "\n"
        $stderr.puts "One sec, cleaning up..."
      end

      begin
        yield
      ensure
        trap(:INT, old_sigint_handler)

        raise Interrupt if interrupted
      end
    end
  end

  def redirect_stdout(file)
    out = $stdout.dup
    $stdout.reopen(file)
    yield
  ensure
    $stdout.reopen(out)
    out.close
  end

  # Ensure the given executable is exist otherwise install the brewed version
  sig { params(name: String, formula_name: T.nilable(String), reason: String, latest: T::Boolean).returns(T.nilable(Pathname)) }
  def ensure_executable!(name, formula_name = nil, reason: "", latest: false)
    formula_name ||= name

    executable = [
      which(name),
      which(name, ORIGINAL_PATHS),
      # We prefer the opt_bin path to a formula's executable over the prefix
      # path where available, since the former is stable during upgrades.
      HOMEBREW_PREFIX/"opt/#{formula_name}/bin/#{name}",
      HOMEBREW_PREFIX/"bin/#{name}",
    ].compact.first
    return executable if executable.exist?

    require "formula"
    Formula[formula_name].ensure_installed!(reason:, latest:).opt_bin/name
  end

  sig { params(size_in_bytes: T.any(Integer, Float)).returns(String) }
  def disk_usage_readable(size_in_bytes)
    if size_in_bytes.abs >= 1_073_741_824
      size = size_in_bytes.to_f / 1_073_741_824
      unit = "GB"
    elsif size_in_bytes.abs >= 1_048_576
      size = size_in_bytes.to_f / 1_048_576
      unit = "MB"
    elsif size_in_bytes.abs >= 1_024
      size = size_in_bytes.to_f / 1_024
      unit = "KB"
    else
      size = size_in_bytes
      unit = "B"
    end

    # avoid trailing zero after decimal point
    if ((size * 10).to_i % 10).zero?
      "#{size.to_i}#{unit}"
    else
      "#{format("%<size>.1f", size:)}#{unit}"
    end
  end

  def number_readable(number)
    numstr = number.to_i.to_s
    (numstr.size - 3).step(1, -3) { |i| numstr.insert(i, ",") }
    numstr
  end

  # Truncates a text string to fit within a byte size constraint,
  # preserving character encoding validity. The returned string will
  # be not much longer than the specified max_bytes, though the exact
  # shortfall or overrun may vary.
  sig { params(str: String, max_bytes: Integer, options: T::Hash[Symbol, T.untyped]).returns(String) }
  def truncate_text_to_approximate_size(str, max_bytes, options = {})
    front_weight = options.fetch(:front_weight, 0.5)
    raise "opts[:front_weight] must be between 0.0 and 1.0" if front_weight < 0.0 || front_weight > 1.0
    return str if str.bytesize <= max_bytes

    glue = "\n[...snip...]\n"
    max_bytes_in = [max_bytes - glue.bytesize, 1].max
    bytes = str.dup.force_encoding("BINARY")
    glue_bytes = glue.encode("BINARY")
    n_front_bytes = (max_bytes_in * front_weight).floor
    n_back_bytes = max_bytes_in - n_front_bytes
    if n_front_bytes.zero?
      front = bytes[1..0]
      back = bytes[-max_bytes_in..]
    elsif n_back_bytes.zero?
      front = bytes[0..(max_bytes_in - 1)]
      back = bytes[1..0]
    else
      front = bytes[0..(n_front_bytes - 1)]
      back = bytes[-n_back_bytes..]
    end
    out = T.must(front) + glue_bytes + T.must(back)
    out.force_encoding("UTF-8")
    out.encode!("UTF-16", invalid: :replace)
    out.encode!("UTF-8")
    out
  end

  # Calls the given block with the passed environment variables
  # added to `ENV`, then restores `ENV` afterwards.
  #
  # NOTE: This method is **not** thread-safe – other threads
  #       which happen to be scheduled during the block will also
  #       see these environment variables.
  #
  # ### Example
  #
  # ```ruby
  # with_env(PATH: "/bin") do
  #   system "echo $PATH"
  # end
  # ```
  #
  # @api public
  def with_env(hash)
    old_values = {}
    begin
      hash.each do |key, value|
        key = key.to_s
        old_values[key] = ENV.delete(key)
        ENV[key] = value
      end

      yield if block_given?
    ensure
      ENV.update(old_values)
    end
  end

  sig { returns(T.proc.params(a: String, b: String).returns(Integer)) }
  def tap_and_name_comparison
    proc do |a, b|
      if a.include?("/") && b.exclude?("/")
        1
      elsif a.exclude?("/") && b.include?("/")
        -1
      else
        a <=> b
      end
    end
  end

  sig { params(input: String, secrets: T::Array[String]).returns(String) }
  def redact_secrets(input, secrets)
    secrets.compact
           .reduce(input) { |str, secret| str.gsub secret, "******" }
           .freeze
  end
end
