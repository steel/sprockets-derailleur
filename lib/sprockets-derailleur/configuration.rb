module SprocketsDerailleur
  class Configuration
    attr_accessor :file_lock_timeout, :compile_times_to_info_log, :worker_count, :use_sprockets_derailleur_file_store

    def initialize
      @file_lock_timeout = 10
      @compile_times_to_info_log = false
      @worker_count = nil
      @use_sprockets_derailleur_file_store = false
    end
  end
end
