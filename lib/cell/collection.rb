module Cell
  class Collection
    def initialize(ary, options, cell_class)
      options.delete(:collection)
      set_deprecated_options(options) # TODO: remove in 5.0.

      @ary        = ary
      @options    = options    # these options are "final" and will be identical for all collection cells.
      @cell_class = cell_class
    end

    def set_deprecated_options(options) # TODO: remove in 5.0.
      self.method = options.delete(:method)                   if options.include?(:method)
      self.collection_join = options.delete(:collection_join) if options.include?(:collection_join)
    end

    module Call
      def call(state=:show)
        join(collection_join) { |cell, i| cell.(method || state) }
      end

    end
    include Call

    def to_s
      call
    end

    # Iterate collection and build a cell for each item.
    # The passed block receives that cell and the index.
    # Its return value is captured and joined.
    def join(separator="", &block)
      cached_cells = {}
      cached_keys = {}
      
      state = @cell_class.version_procs.keys.first
      cached_keys = build_cache_keys(state) if state

      if cached_keys.any?
        cached_cells = fetch_collection(cached_keys.values)
      end
      
      @ary.each_with_index.collect do |model, i|
        key = model.try(:id) || model
        if cached_cell = cached_cells[cached_keys[key]]
          block_given? ? yield(cached_cell, i) : cached_cell
        else
          cell = @cell_class.build(model, @options)
          block_given? ? yield(cell, i) : cell
        end
      end.join(separator)
    end

    def build_cache_keys(state)
      keys_map = {}

      @ary.each do |collection_item|
        cell = @cell_class.build(collection_item, @options)
        procs = cell.class.version_procs[state].(cell, @options)
        next unless cell.cache?(state, @options)
        key = collection_item.try(:id) || collection_item
        keys_map[key] = @cell_class.state_cache_key(state, procs)
      end

      keys_map
    end

    private

    def fetch_collection(cached_keys)
      #TODO - move this fetch to caching.rb
      collection_cache.read_multi(*cached_keys)
    end
    
    def collection_cache
      #TODO - implement cache store for class so we don't need to ask for child method
      @collection_cache ||= @cell_class.build(@ary.first).cache_store
    end

    module Layout
      def call(*) # WARNING: THIS IS NOT FINAL API.
        layout = @options.delete(:layout) # we could also override #initialize and that there?

        content = super # DISCUSS: that could come in via the pipeline argument.
        ViewModel::Layout::External::Render.(content, @ary, layout, @options)
      end
    end
    include Layout

    # TODO: remove in 5.0.
    private
    attr_accessor :collection_join, :method

    extend Gem::Deprecate
    deprecate :method=, "`call(method)` as documented here: http://trailblazer.to/gems/cells/api.html#collection", 2016, 7
    deprecate :collection_join=, "`join(\"<br>\")` as documented here: http://trailblazer.to/gems/cells/api.html#collection", 2016, 7
  end
end

# Collection#call
# |> Header#call
# |> Layout#call
