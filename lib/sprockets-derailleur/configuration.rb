module SprocketsDerailleur
  class Configuration
    attr_accessor :file_lock_timeout, :warn_compile_times, :worker_count

    def initialize
      @file_lock_timeout = 10
      @warn_compile_times = false
      @worker_count = nil
    end
  end
end
