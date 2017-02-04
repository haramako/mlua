module Mlua
  class Table
    attr_reader :array, :map

    def self.from(src)
      case src
      when Array, Hash
        Table.new(src)
      when Table
        src
      else
        raise "src must be Array or Hash or Table"
      end
    end
    
    def initialize(*srcs)
      srcs.each do |src|
        case src
        when Array
          @array = src
        when Hash
          @map = src
        else
          raise
        end
      end
      @array ||= []
      @map ||= {}
    end

    def array_idx(idx)
      case idx
      when Fixnum
        if idx <= 0
          if idx <= @array.size
            :out_of_range
          else
            @array.size + idx
          end
        else
          idx - 1
        end
      when Float
        array_idx(idx.to_i)
      when String
        nil
      when nil
        :out_of_range
      else
        raise "invalid idx #{idx}"
      end
    end

    def [](idx)
      ai = array_idx(idx)
      if ai
        if ai != :out_of_range
          @array[ai]
        else
          nil
        end
      else
        @map[idx]
      end
    end

    def []=(idx,v)
      ai = array_idx(idx)
      if ai
        if ai != :out_of_range
          @array[ai] = v
        end
      else
        @map[idx] = v
      end
    end

    def each_ipairs
      (1..@array.size).each
    end


    def each_pairs
      @map.each_pair
    end
    
    def size
      @array.size + @map.size
    end

    def lua_slice(from=nil, to=nil)
      from = array_idx(from || 1)
      to = array_idx(to || @array.size)
      @array[from..to]
    end

    def merge(table)
      raise "cannot merge array in table" if table.array.size > 0
      @map.merge! table.map
    end

    def ==(t)
      if t.is_a? Table
        t.array == @array and t.map == @map
      else
        false
      end
    end

    def inspect
      "{" + @array.join(', ') + if @map.size > 0 then ';' + @map.inspect else '' end + '}'
    end
    alias to_s inspect
  end
end
