# frozen_string_literal: true

require "securerandom"
require "fileutils"
require "pathname"

module Nous
  module AtomicWriter
    module_function

    def create(vault_root:, path:, bytes:, validate: nil)
      write(vault_root: vault_root, path: path, bytes: bytes, overwrite: false, validate: validate)
    end

    def replace(vault_root:, path:, bytes:, validate: nil)
      write(vault_root: vault_root, path: path, bytes: bytes, overwrite: true, validate: validate)
    end

    def replace_adapter_path(path:, bytes:, validate: nil)
      begin
        destination = Pathname(path).expand_path
        destination.dirname.mkpath
        temp_path = unique_temp_path(destination)
        File.open(temp_path.to_s, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          file.binmode
          file.write(bytes.to_s)
          file.flush
          file.fsync
        end

        validate.call(temp_path) if validate
        File.rename(temp_path.to_s, destination.to_s)
        destination
      rescue Error
        raise
      rescue SystemCallError
        raise write_failed
      ensure
        FileUtils.rm_f(temp_path.to_s) if temp_path && temp_path.exist?
      end
    end

    def write(vault_root:, path:, bytes:, overwrite:, validate: nil)
      begin
        destination = PathGuard.internal_path(vault_root: vault_root, path: path, allow_missing: true, create_parent: true)
        destination.dirname.mkpath
        temp_path = unique_temp_path(destination)
        File.open(temp_path.to_s, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          file.binmode
          file.write(bytes.to_s)
          file.flush
          file.fsync
        end

        validate.call(temp_path) if validate
        if overwrite
          File.rename(temp_path.to_s, destination.to_s)
        else
          link_no_replace(temp_path, destination)
          FileUtils.rm_f(temp_path.to_s)
        end
        destination
      rescue Error
        raise
      rescue SystemCallError
        raise write_failed
      ensure
        FileUtils.rm_f(temp_path.to_s) if temp_path && temp_path.exist?
      end
    end

    def stage(vault_root:, path:, bytes:, validate: nil)
      destination = PathGuard.internal_path(vault_root: vault_root, path: path, allow_missing: true, create_parent: true)
      destination.dirname.mkpath
      temp_path = unique_temp_path(destination)

      File.open(temp_path.to_s, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
        file.binmode
        file.write(bytes.to_s)
        file.flush
        file.fsync
      end
      validate.call(temp_path) if validate

      StagedWrite.new(vault_root: PathGuard.validate_vault_root(vault_root), destination: destination, temp_path: temp_path)
    rescue Error
      FileUtils.rm_f(temp_path.to_s) if temp_path
      raise
    rescue SystemCallError
      FileUtils.rm_f(temp_path.to_s) if temp_path
      raise write_failed
    end

    def stage_file(vault_root:, path:, source_path:, validate: nil)
      destination = PathGuard.internal_path(vault_root: vault_root, path: path, allow_missing: true, create_parent: true)
      destination.dirname.mkpath
      temp_path = unique_temp_path(destination)

      File.open(source_path.to_s, "rb") do |source|
        File.open(temp_path.to_s, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          file.binmode
          IO.copy_stream(source, file)
          file.flush
          file.fsync
        end
      end
      validate.call(temp_path) if validate

      StagedWrite.new(vault_root: PathGuard.validate_vault_root(vault_root), destination: destination, temp_path: temp_path)
    rescue Error
      FileUtils.rm_f(temp_path.to_s) if temp_path
      raise
    rescue SystemCallError
      FileUtils.rm_f(temp_path.to_s) if temp_path
      raise write_failed
    end

    def unique_temp_path(destination)
      destination.dirname + ".tmp-nous-#{Process.pid}-#{Thread.current.object_id}-#{SecureRandom.hex(8)}"
    end

    class StagedWrite
      def initialize(vault_root:, destination:, temp_path:)
        @vault_root = vault_root
        @destination = destination
        @temp_path = temp_path
        @finalized = false
      end

      attr_reader :destination, :temp_path

      def finalize(overwrite: false)
        PathGuard.assert_contained!(@vault_root, @destination)
        if overwrite
          File.rename(@temp_path.to_s, @destination.to_s)
        else
          AtomicWriter.link_no_replace(@temp_path, @destination)
          FileUtils.rm_f(@temp_path.to_s)
        end
        @finalized = true
        @destination
      rescue Error
        raise
      rescue SystemCallError
        raise AtomicWriter.write_failed
      end

      def cleanup
        FileUtils.rm_f(@temp_path.to_s) unless @finalized
      end
    end

    def link_no_replace(temp_path, destination)
      File.link(temp_path.to_s, destination.to_s)
    rescue Errno::EEXIST
      raise Error.new("destination already exists", code: "NOUS_WRITE_FAILED")
    rescue SystemCallError
      raise write_failed
    end

    def write_failed
      Error.new("failed to finalize import", code: "NOUS_WRITE_FAILED")
    end
  end
end
