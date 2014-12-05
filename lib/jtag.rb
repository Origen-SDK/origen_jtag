require 'rgen'
require_relative '../config/application.rb'
require_relative '../config/environment.rb'

# Include this module to add a JTAG driver to your class
module JTAG
  # Returns an instance of the JTAG::Driver
  def jtag
    @jtag ||= Driver.new(self)
  end
end
