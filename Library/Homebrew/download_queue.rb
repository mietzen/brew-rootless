# typed: strict
# frozen_string_literal: true

require "downloadable"
require "concurrent/promises"
require "concurrent/executors"
require "retryable_download"
require "resource"
require "utils/output"

module Homebrew
  class DownloadQueue
    include Utils::Output::Mixin

    sig { params(retries: Integer, force: T::Boolean, pour: T::Boolean).returns(T.nilable(DownloadQueue)) }
    def self.new_if_concurrency_enabled(retries: 1, force: false, pour: false)
      return if Homebrew::EnvConfig.download_concurrency <= 1

      new(retries:, force:, pour:)
    end

    sig { params(retries: Integer, force: T::Boolean, pour: T::Boolean).void }
    def initialize(retries: 1, force: false, pour: false)
      @concurrency = T.let(EnvConfig.download_concurrency, Integer)
      @quiet = T.let(@concurrency > 1, T::Boolean)
      @tries = T.let(retries + 1, Integer)
      @force = force
      @pour = pour
      @pool = T.let(Concurrent::FixedThreadPool.new(concurrency), Concurrent::FixedThreadPool)
    end

    sig {
      params(
        downloadable:      Downloadable,
        check_attestation: T::Boolean,
      ).void
    }
    def enqueue(downloadable, check_attestation: false)
      downloads[downloadable] ||= Concurrent::Promises.future_on(
        pool, RetryableDownload.new(downloadable, tries:, pour:),
        force, quiet, check_attestation
      ) do |download, force, quiet, check_attestation|
        download.clear_cache if force
        download.fetch(quiet:)
        if check_attestation
          bottle = T.cast(downloadable, Bottle)
          Utils::Attestation.check_attestation(bottle, quiet: true)
        end
      end
    end

    sig { void }
    def fetch
      return if downloads.empty?

      if concurrency == 1
        downloads.each do |downloadable, promise|
          promise.wait!
        rescue ChecksumMismatchError => e
          opoo "#{downloadable.download_queue_type} reports different checksum: #{e.expected}"
          Homebrew.failed = true if downloadable.is_a?(Resource::Patch)
        rescue => e
          raise e unless bottle_manifest_error?(downloadable, e)
        end
      else
        spinner = Spinner.new
        remaining_downloads = downloads.dup.to_a
        previous_pending_line_count = 0
        tty = $stdout.tty?

        begin
          stdout_print_and_flush_if_tty Tty.hide_cursor

          output_message = lambda do |downloadable, future, last|
            status = case future.state
            when :fulfilled
              if tty
                "#{Tty.green}✔︎#{Tty.reset}"
              else
                "✔︎"
              end
            when :rejected
              if tty
                "#{Tty.red}✘#{Tty.reset}"
              else
                "✘"
              end
            when :pending, :processing
              "#{Tty.blue}#{spinner}#{Tty.reset}" if tty
            else
              raise future.state.to_s
            end

            exception = future.reason if future.rejected?
            next 1 if bottle_manifest_error?(downloadable, exception)

            message = "#{downloadable.download_queue_type} #{downloadable.download_queue_name}"
            if tty
              stdout_print_and_flush "#{status} #{message}#{"\n" unless last}"
            elsif status
              puts "#{status} #{message}"
            end

            if future.rejected?
              if exception.is_a?(ChecksumMismatchError)
                actual = Digest::SHA256.file(downloadable.cached_download).hexdigest
                opoo "#{downloadable.download_queue_type} reports different checksum: #{exception.expected}"
                puts (" " * downloadable.download_queue_type.size) + " SHA-256 checksum of downloaded file: #{actual}"
                Homebrew.failed = true if downloadable.is_a?(Resource::Patch)
                next 2
              elsif exception.is_a?(CannotInstallFormulaError)
                if (cached_download = downloadable.cached_download)&.exist?
                  cached_download.unlink
                end
                raise exception
              else
                message = future.reason.to_s
                ofail message
                next message.count("\n")
              end
            end

            1
          end

          until remaining_downloads.empty?
            begin
              finished_states = [:fulfilled, :rejected]

              finished_downloads, remaining_downloads = remaining_downloads.partition do |_, future|
                finished_states.include?(future.state)
              end

              finished_downloads.each do |downloadable, future|
                previous_pending_line_count -= 1
                stdout_print_and_flush_if_tty Tty.clear_to_end
                output_message.call(downloadable, future, false)
              end

              previous_pending_line_count = 0
              max_lines = [concurrency, Tty.height].min
              remaining_downloads.each_with_index do |(downloadable, future), i|
                break if previous_pending_line_count >= max_lines

                stdout_print_and_flush_if_tty Tty.clear_to_end
                last = i == max_lines - 1 || i == remaining_downloads.count - 1
                previous_pending_line_count += output_message.call(downloadable, future, last)
              end

              if previous_pending_line_count.positive?
                if (previous_pending_line_count - 1).zero?
                  stdout_print_and_flush_if_tty Tty.move_cursor_beginning
                else
                  stdout_print_and_flush_if_tty Tty.move_cursor_up_beginning(previous_pending_line_count - 1)
                end
              end

              sleep 0.05
            # We want to catch all exceptions to ensure we can cancel any
            # running downloads and flush the TTY.
            rescue Exception # rubocop:disable Lint/RescueException
              remaining_downloads.each do |_, future|
                # FIXME: Implement cancellation of running downloads.
              end

              cancel

              if previous_pending_line_count.positive?
                stdout_print_and_flush_if_tty Tty.move_cursor_down(previous_pending_line_count - 1)
              end

              raise
            end
          end
        ensure
          stdout_print_and_flush_if_tty Tty.show_cursor
        end
      end

      downloads.clear
    end

    sig { params(message: String).void }
    def stdout_print_and_flush_if_tty(message)
      stdout_print_and_flush(message) if $stdout.tty?
    end

    sig { params(message: String).void }
    def stdout_print_and_flush(message)
      $stdout.print(message)
      $stdout.flush
    end

    sig { void }
    def shutdown
      pool.shutdown
      pool.wait_for_termination
    end

    private

    sig { params(downloadable: Downloadable, exception: T.nilable(Exception)).returns(T::Boolean) }
    def bottle_manifest_error?(downloadable, exception)
      return false if exception.nil?

      downloadable.is_a?(Resource::BottleManifest) || exception.is_a?(Resource::BottleManifest::Error)
    end

    sig { void }
    def cancel
      # FIXME: Implement graceful cancellation of running downloads based on
      #        https://ruby-concurrency.github.io/concurrent-ruby/master/Concurrent/Cancellation.html
      #        instead of killing the whole thread pool.
      pool.kill
    end

    sig { returns(Concurrent::FixedThreadPool) }
    attr_reader :pool

    sig { returns(Integer) }
    attr_reader :concurrency

    sig { returns(Integer) }
    attr_reader :tries

    sig { returns(T::Boolean) }
    attr_reader :force

    sig { returns(T::Boolean) }
    attr_reader :quiet

    sig { returns(T::Boolean) }
    attr_reader :pour

    sig { returns(T::Hash[Downloadable, Concurrent::Promises::Future]) }
    def downloads
      @downloads ||= T.let({}, T.nilable(T::Hash[Downloadable, Concurrent::Promises::Future]))
    end

    class Spinner
      FRAMES = [
        "⠋",
        "⠙",
        "⠚",
        "⠞",
        "⠖",
        "⠦",
        "⠴",
        "⠲",
        "⠳",
        "⠓",
      ].freeze

      sig { void }
      def initialize
        @start = T.let(Time.now, Time)
        @i = T.let(0, Integer)
      end

      sig { returns(String) }
      def to_s
        now = Time.now
        if @start + 0.1 < now
          @start = now
          @i = (@i + 1) % FRAMES.count
        end

        FRAMES.fetch(@i)
      end
    end
  end
end
