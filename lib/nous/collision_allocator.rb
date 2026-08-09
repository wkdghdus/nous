# frozen_string_literal: true

module Nous
  module CollisionAllocator
    module_function

    def next_available_path(vault_root:, directory:, basename:, extension: ".md")
      root = PathGuard.validate_vault_root(vault_root)
      index = nil

      loop do
        filename = index.nil? ? "#{basename}#{extension}" : "#{basename}-#{index}#{extension}"
        relative = "#{directory}/#{filename}"
        path = PathGuard.internal_path(vault_root: root, path: relative, allow_missing: true, create_parent: true)
        return { path: path, relative_path: relative, id: File.basename(filename, extension) } unless path.exist?

        index = index.nil? ? 2 : index + 1
      end
    end
  end
end
