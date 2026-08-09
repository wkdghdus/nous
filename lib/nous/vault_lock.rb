# frozen_string_literal: true

module Nous
  class VaultLock
    DEFAULT_TIMEOUT = 5.0
    POLL_INTERVAL = 0.025

    def initialize(vault_root:, timeout: nil)
      @vault_root = PathGuard.validate_vault_root(vault_root)
      @timeout = Float(timeout || DEFAULT_TIMEOUT)
      @lock_path = @vault_root + ".nous.lock"
    rescue ArgumentError
      raise Error.new("lock timeout must be numeric", code: "NOUS_INVALID_INPUT")
    end

    attr_reader :lock_path

    def with_shared(&block)
      acquire(File::LOCK_SH, &block)
    end

    def with_exclusive(&block)
      acquire(File::LOCK_EX, &block)
    end

    private

    def acquire(mode)
      raise Error.new("nested vault lock acquisition is not allowed", code: "NOUS_INVALID_INPUT") if held?
      raise Error.new("lock timeout must be positive", code: "NOUS_INVALID_INPUT") unless @timeout.positive?

      reject_symlink_lock!
      flags = File::RDWR | File::CREAT
      flags |= File::NOFOLLOW if defined?(File::NOFOLLOW)
      File.open(@lock_path.to_s, flags, 0o600) do |file|
        file.chmod(0o600)
        wait_for_lock(file, mode)
        mark_held
        begin
          yield
        ensure
          clear_held
          file.flock(File::LOCK_UN)
        end
      end
    rescue Errno::EACCES, Errno::EROFS
      raise Error.new("vault lock cannot be created", code: "NOUS_WRITE_FAILED")
    rescue Errno::ELOOP
      raise Error.new("vault lock must not be a symlink", code: "NOUS_SYMLINK_REJECTED")
    end

    def wait_for_lock(file, mode)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @timeout
      loop do
        return if file.flock(mode | File::LOCK_NB)

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise Error.new("timed out waiting for vault lock", code: "NOUS_LOCK_TIMEOUT", details: { timeout: @timeout })
        end

        sleep(POLL_INTERVAL)
      end
    end

    def reject_symlink_lock!
      return unless @lock_path.symlink?

      raise Error.new("vault lock must not be a symlink", code: "NOUS_SYMLINK_REJECTED")
    end

    def lock_key
      @lock_path.to_s
    end

    def held_locks
      Thread.current[:nous_vault_locks] ||= {}
    end

    def held?
      held_locks.key?(lock_key)
    end

    def mark_held
      held_locks[lock_key] = true
    end

    def clear_held
      held_locks.delete(lock_key)
    end
  end
end
