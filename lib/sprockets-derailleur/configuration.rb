module SprocketsDerailleur
  class Configuration
    attr_accessor :file_lock_timeout

    def initialize
      @file_lock_timeout = 10
    end
  end
end
