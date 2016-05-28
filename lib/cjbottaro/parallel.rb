require "cjbottaro/parallel/version"
require "cjbottaro/parallel/mapper"

module Cjbottaro
  module Parallel

    class Stop; end
    class Done; end

    def self.map(enumerable, options = {}, &block)
      Mapper.new(enumerable, options, &block).run
    end

    def self.each(enumerable, options = {}, &block)
      options = options.merge(ignore_result: true)
      Mapper.new(enumerable, options, &block).run
      enumerable
    end

  end
end
