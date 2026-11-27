# frozen_string_literal: true

require "fileutils"

module TestHotCellServer
  class << self
    def ensure_started!
      return if running?

      start
    end

    def start(worker: nil)
      stop if running?

      suffix = worker ? "#{Process.pid}-w#{worker}" : Process.pid.to_s
      @root = File.join("/tmp", "hc-#{suffix}")
      cell_dir = File.join(@root, "active_storage")
      FileUtils.mkdir_p(cell_dir)

      @log_path = File.join(@root, "hotcell.log")
      env = {
        "BUNDLE_GEMFILE" => Rails.root.join("hotcell/Gemfile").to_s,
        "HOTCELL_CONFIG" => Rails.root.join("hotcell/config.rb").to_s,
        "HOTCELL_OPERATIONS" => Rails.root.join("hotcell/operations").to_s,
        "HOTCELL_DIR" => cell_dir
      }

      @owner_pid = Process.pid
      @pid = Bundler.with_unbundled_env do
        Process.spawn(
          env,
          "bundle", "exec", "hotcell", "--development",
          out: @log_path,
          err: @log_path)
      end

      register_exit_hook!
      wait_for_sockets!(
        File.join(cell_dir, "work.sock"),
        File.join(cell_dir, "control.sock"))
      HotCell.root = @root
    end

    def stop
      return unless @owner_pid == Process.pid

      if @pid
        begin
          Process.kill("TERM", @pid)
          Process.wait(@pid)
        rescue Errno::ESRCH, Errno::ECHILD
          nil
        end
        @pid = nil
      end

      FileUtils.rm_rf(@root) if @root
      @root = nil
      @owner_pid = nil
    end

    private

    def running?
      @pid && @owner_pid == Process.pid && Process.waitpid(@pid, Process::WNOHANG).nil?
    rescue Errno::ECHILD
      false
    end

    def wait_for_sockets!(*paths)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
      until paths.all? { |path| File.socket?(path) }
        if Process.waitpid(@pid, Process::WNOHANG)
          log = File.exist?(@log_path) ? File.read(@log_path) : "(no log)"
          @pid = nil
          stop
          raise "Test Hot Cell exited before sockets were ready:\n#{log}"
        end
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          stop
          raise "Timed out waiting for Test Hot Cell sockets at #{paths.join(', ')}"
        end
        sleep 0.02
      end
    end

    def register_exit_hook!
      return if @exit_hook_registered

      @exit_hook_registered = true
      at_exit { TestHotCellServer.stop }
    end
  end
end
