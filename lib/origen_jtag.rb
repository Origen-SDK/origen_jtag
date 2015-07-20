require 'origen'
require_relative '../config/application.rb'

# Include this module to add a JTAG driver to your class
module OrigenJTAG
  autoload :TAPController, 'origen_jtag/tap_controller'
  autoload :Driver,        'origen_jtag/driver'

  # Returns an instance of the OrigenJTAG::Driver
  def jtag
    @jtag ||= Driver.new(self)
  end
end
