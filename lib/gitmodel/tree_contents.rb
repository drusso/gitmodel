module GitModel

  # This module manages the contents of a tree for interfacing with Grit.
  # Directories (trees) are represented as hashes, and files (blobs)
  # as strings.
  module TreeContents

    # Returns the contents of the tree as a hash. All blobs are
    # represented as strings, and all nested trees are represented
    # as hashes.
    def tree
      @tree ||= HashWithIndifferentAccess.new
    end
    alias :contents :tree
    alias :blobs :tree

    # Set the contents of the tree.
    #
    # The contents can be set by providing a hash _or_ by providing
    # an array containing +Grit::Tree+'s and +Grit::Blob+'s. At this
    # time it is not possible to set the contents of the tree with a
    # +Grit::Tree+.
    #
    # +GitModel::InvalidTreeContents+ is raised if the supplied tree
    # is not a hash or an array.
    def tree=(data)
      @tree = HashWithIndifferentAccess.new(
        case data
        when Array
          hash_from_git(data)
        when Hash, HashWithIndifferentAccess
          data
        end
      )
    end
    alias :contents= :tree=
    alias :blobs= :tree=

    # Iterates through all levels of the tree, and for each blob in the 
    # tree, yields with the path to and contents of that blob.
    #
    # If a path is supplied, all paths in the tree will be appended to 
    # that path.
    def paths(path_to_record='', data=nil, &block)
      data ||= tree
      data.each do |name, content|
        new_path = File.join(path_to_record, name.to_s)
        case content
          when Hash
            paths(new_path, content, &block)
          else
            yield(new_path, content)
        end
      end
    end

    private

    # Returns a hash from an array of +Grit::Blob+'s and +Grit::Tree+'s.
    # The conversion is applied down through all levels.
    def hash_from_git(tree)
      ({}).tap do |objs|
        tree.each do |b|
          objs[b.name] = (
            case b
              when Grit::Tree
                hash_from_git(b.contents)
              when Grit::Blob
                b.data
            end
          )
        end
      end
    end

  end
end
