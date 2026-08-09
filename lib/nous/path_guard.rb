# frozen_string_literal: true

require "pathname"

module Nous
  module PathGuard
    module_function

    def validate_vault_root(vault_root)
      root = Pathname(vault_root).expand_path
      unless root.directory?
        raise Error.new("vault root does not exist or is not a directory", code: "NOUS_VAULT_NOT_FOUND")
      end
      reject_symlink!(root, "vault root")

      root.realpath
    rescue Errno::ENOENT
      raise Error.new("vault root does not exist or is not a directory", code: "NOUS_VAULT_NOT_FOUND")
    end

    def internal_path(vault_root:, path:, allow_missing: false, create_parent: false)
      lexical_root = Pathname(vault_root).expand_path
      root = validate_vault_root(vault_root)
      candidate = Pathname(path)
      candidate = lexical_root + candidate unless candidate.absolute?
      expanded = candidate.expand_path

      resolved = if expanded.exist?
                   reject_symlink_components!(lexical_root, root, expanded)
                   real = expanded.realpath
                   assert_contained!(root, real)
                   real
                 elsif allow_missing
                   parent = expanded.dirname
                   assert_contained_lexically!(lexical_root, parent)
                   validate_existing_parent!(lexical_root, root, parent, create_parent: create_parent)
                   root + expanded.relative_path_from(lexical_root)
                 else
                   raise Error.new("vault path does not exist", code: "NOUS_RECORD_NOT_FOUND")
                 end

      assert_contained!(root, resolved)
      resolved
    rescue Errno::ELOOP
      raise Error.new("symlinked vault paths are not allowed", code: "NOUS_SYMLINK_REJECTED")
    end

    def relative_path(vault_root:, path:)
      root = validate_vault_root(vault_root)
      candidate = Pathname(path)
      candidate = root + candidate unless candidate.absolute?
      expanded = candidate.expand_path
      if expanded.exist?
        relative_to_root(root, expanded.realpath)
      else
        relative = expanded.relative_path_from(root)
        if relative.each_filename.first == ".."
          raise Error.new("path is outside the vault", code: "NOUS_PATH_OUTSIDE_VAULT")
        end
        relative.to_s
      end
    end

    def operator_source(path)
      source = Pathname(path).expand_path
      unless source.file?
        raise Error.new("source must be a regular file", code: "NOUS_UNSUPPORTED_SOURCE")
      end
      reject_symlink!(source, "source")

      source.realpath
    rescue Errno::ENOENT
      raise Error.new("source must be a regular file", code: "NOUS_UNSUPPORTED_SOURCE")
    end

    def assert_contained!(vault_root, path)
      root = Pathname(vault_root).expand_path
      resolved = Pathname(path).expand_path
      relative_to_root(root, resolved)
      true
    end

    def relative_to_root(vault_root, path)
      relative = Pathname(path).expand_path.relative_path_from(Pathname(vault_root).expand_path)
      if relative.each_filename.first == ".."
        raise Error.new("path is outside the vault", code: "NOUS_PATH_OUTSIDE_VAULT")
      end

      relative.to_s
    rescue ArgumentError
      raise Error.new("path is outside the vault", code: "NOUS_PATH_OUTSIDE_VAULT")
    end

    def reject_symlink!(path, label)
      raise Error.new("#{label} must not be a symlink", code: "NOUS_SYMLINK_REJECTED") if Pathname(path).symlink?
    end

    def reject_symlink_components!(lexical_root, resolved_root, path)
      current = Pathname(resolved_root).expand_path
      relative = Pathname(path).expand_path.relative_path_from(Pathname(lexical_root).expand_path)
      if relative.each_filename.first == ".."
        real_path = Pathname(path).realpath
        assert_contained!(resolved_root, real_path)
        relative = real_path.relative_path_from(Pathname(resolved_root).expand_path)
      end
      relative.each_filename do |part|
        current += part
        break unless current.exist? || current.symlink?

        reject_symlink!(current, "vault path component")
      end
    rescue ArgumentError
      raise Error.new("path is outside the vault", code: "NOUS_PATH_OUTSIDE_VAULT")
    rescue Errno::ENOENT
      raise Error.new("vault path does not exist", code: "NOUS_RECORD_NOT_FOUND")
    end

    def assert_contained_lexically!(root, path)
      relative = Pathname(path).expand_path.relative_path_from(Pathname(root).expand_path)
      if relative.each_filename.first == ".."
        raise Error.new("path is outside the vault", code: "NOUS_PATH_OUTSIDE_VAULT")
      end
    rescue ArgumentError
      raise Error.new("path is outside the vault", code: "NOUS_PATH_OUTSIDE_VAULT")
    end

    def validate_existing_parent!(lexical_root, resolved_root, parent, create_parent:)
      if parent.exist?
        reject_symlink_components!(lexical_root, resolved_root, parent)
        assert_contained!(resolved_root, parent.realpath)
        return
      end

      unless create_parent
        raise Error.new("vault parent directory does not exist", code: "NOUS_RECORD_NOT_FOUND")
      end

      existing = parent
      existing = existing.dirname until existing.exist?
      reject_symlink_components!(lexical_root, resolved_root, existing)
      assert_contained!(resolved_root, existing.realpath)
    end
  end
end
