require "sprockets-derailleur/version"
require "sprockets-derailleur/manifest"
require "sprockets-derailleur/file_store"
require "sprockets-derailleur/configuration"

module SprocketsDerailleur
  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  def self.number_of_processors
    if RUBY_PLATFORM =~ /linux/
      return `cat /proc/cpuinfo | grep processor | wc -l`.to_i
    elsif RUBY_PLATFORM =~ /darwin/
      return `sysctl -n hw.physicalcpu`.to_i
    elsif RUBY_PLATFORM =~ /win32/
      # this works for windows 2000 or greater
      require 'win32ole'
      wmi = WIN32OLE.connect("winmgmts://")
      wmi.ExecQuery("select * from Win32_ComputerSystem").each do |system|
        begin
          processors = system.NumberOfLogicalProcessors
        rescue
          processors = 0
        end
        return [system.NumberOfProcessors, processors].max
      end
    end
    raise "can't determine 'number_of_processors' for '#{RUBY_PLATFORM}'"
  end

  def self.worker_count
    worker_count = ENV['SPROCKETS_DERAILLEUR_WORKER_COUNT'].to_i
    return worker_count if worker_count > 0
    number_of_processors
  rescue
    1
  end
end
