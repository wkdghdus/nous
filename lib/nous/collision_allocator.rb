# frozen_string_literal: true

module Nous
  module CollisionAllocator
    module_function

    def next_available_path(vault_root:, directory:, basename:, extension: ".md", reserved_ids: [])
      root = PathGuard.validate_vault_root(vault_root)
      reserved = reserved_ids.each_with_object({}) { |id, values| values[id.to_s] = true }
      index = nil

      loop do
        filename = index.nil? ? "#{basename}#{extension}" : "#{basename}-#{index}#{extension}"
        relative = "#{directory}/#{filename}"
        path = PathGuard.internal_path(vault_root: root, path: relative, allow_missing: true, create_parent: true)
        id = File.basename(filename, extension)
        return { path: path, relative_path: relative, id: id } unless path.exist? || reserved.key?(id)

        index = index.nil? ? 2 : index + 1
      end
    end
  end
end
