require "benchmark"
require "parallel"
require "cjbottaro/parallel"

RANGE = 1..200_000
OPTIONS = { processes: 4 }
FUNC = ->(x){ x * 2 }

Benchmark.bm(20) do |mark|
  mark.report("map (Cjbottaro)"){ Cjbottaro::Parallel.map(RANGE, OPTIONS, &FUNC) }
  mark.report("map (Parallel)"){ Parallel.map(RANGE, OPTIONS, &FUNC) }

  mark.report("each (Cjbottaro)"){ Cjbottaro::Parallel.each(RANGE, OPTIONS, &FUNC) }
  mark.report("each (Parallel)"){ Parallel.each(RANGE, OPTIONS, &FUNC) }
end
