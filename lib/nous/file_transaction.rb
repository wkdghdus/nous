# frozen_string_literal: true

require "fileutils"

module Nous
  class FileTransaction
    def initialize(vault_root:)
      @vault_root = PathGuard.validate_vault_root(vault_root)
      @staged = []
      @finals_created = []
    end

    def stage(path:, bytes: nil, source_path: nil, validate: nil)
      staged = if source_path
                 AtomicWriter.stage_file(vault_root: @vault_root, path: path, source_path: source_path, validate: validate)
               else
                 AtomicWriter.stage(vault_root: @vault_root, path: path, bytes: bytes, validate: validate)
               end
      @staged << staged
      staged
    rescue StandardError
      rollback
      raise
    end

    def commit(after_finalize: nil)
      @staged.each_with_index do |staged, index|
        destination = staged.destination
        existed_before = destination.exist?
        staged.finalize(overwrite: false)
        @finals_created << destination unless existed_before
        after_finalize.call(index + 1, destination) if after_finalize
      end

      @finals_created.dup
    rescue StandardError
      rollback
      raise
    ensure
      cleanup_staged
    end

    def rollback
      cleanup_staged
      @finals_created.reverse_each do |path|
        next unless path.file?

        FileUtils.rm_f(path.to_s)
      end
      @finals_created.clear
    end

    private

    def cleanup_staged
      @staged.each(&:cleanup)
    end
  end
end
