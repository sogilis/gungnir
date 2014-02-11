require 'rugged'

module Git
  class Repo
    attr_accessor :repo
    def initialize(path)
      @path = path
      @repo = nil
      create_if_not_exists
      update_index
    end

    def write(content, path, message)
      commit(tree(blob(content), path), message)
    end

    def delete (id, message)
      commit(remove(id), message)
    end

    def get path
      obj = oid path
      return nil if obj == nil
      @repo.read(obj).data
    end

    def get_all rev = nil
      result = []
      get_oids(rev).each do |oid|
        result.push @repo.read(oid).data
      end
      result
    end

    def prev rev = nil
      return nil if @repo.empty?
      hash = rev || @repo.head.target
      tree = @repo.lookup hash
      parent = tree.parents.first
      parent != nil ? parent.oid : nil
    end

    def next rev = nil
      return nil if rev == nil
      return nil if rev == @repo.head.target
      walker = Rugged::Walker.new @repo
      walker.push @repo.head.target
      version = nil
      walker.each do |c|
        if c.oid == rev
          break
        end
        version = c.oid
      end
      if version == @repo.head.target
        version = ''
      end
      version
    end

    private

    def blob(content)
      @repo.write(content, :blob)
    end

    def tree(oid, path)
      @index.add(:path => path, :oid => oid, :mode => 0100644)
      @index.write_tree(@repo)
    end

    def remove(path)
      @index.remove(path)
      @index.write_tree(@repo)
    end

    def commit(tree, message)
      options = {}
      options[:tree] = tree
      options[:author] = { :email => "contact@sogilis.com", :name => 'sogilis', :time => Time.now }
      options[:committer] = { :email => "contact@sogilis.com", :name => 'sogilis', :time => Time.now }
      options[:message] ||= message
      options[:parents] = @repo.empty? ? [] : [ @repo.head.target ].compact
      options[:update_ref] = 'HEAD'

      Rugged::Commit.create(@repo, options)
    end

    def oid path
      return nil if @repo.empty?
      tree = @repo.lookup(@repo.head.target).tree
      obj = nil
      tree.walk_blobs(:postorder) do |root, entry|
        if "#{root}#{entry[:name]}" == path
          obj = entry[:oid]
          break
        end
      end
      obj
    end

    def get_oids rev = nil
      result = []
      return result if @repo.empty?
      hash = rev || @repo.head.target
      tree = @repo.lookup(hash).tree
      tree.walk_blobs(:postorder) do |root, entry|
        result.push(entry[:oid])
      end
      result
    end

    def update_index
      @index = Rugged::Index.new
      return if @repo.empty?
      tree = @repo.lookup(@repo.head.target).tree
      tree.walk_blobs(:postorder) do |root, entry|
        @index.add(:path => "#{root}#{entry[:name]}", :oid => entry[:oid], :mode => 0100644)
      end
    end

    def create_if_not_exists
      if File.exists?(@path)
        @repo = Rugged::Repository.new(@path)
      else
        @repo = Rugged::Repository.init_at(@path, :bare)
      end
    end
  end
end
