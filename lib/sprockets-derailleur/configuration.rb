module SprocketsDerailleur
  class Configuration
    attr_accessor :file_lock_timeout, :warn_compile_times, :worker_count, :use_sprockets_derailleur_file_store

    def initialize
      @file_lock_timeout = 10
      @warn_compile_times = false
      @worker_count = nil
      @use_sprockets_derailleur_file_store = false
    end
  end
end
