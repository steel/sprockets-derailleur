module SprocketsDerailleur
  class Configuration
    attr_accessor :file_lock_timeout, :warn_compile_times

    def initialize
      @file_lock_timeout = 10
      @warn_compile_times = false
    end
  end
end
