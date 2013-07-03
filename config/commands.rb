# This file should be used to extend the rgen command line tool with tasks 
# specific to your application.
# The comments below should help to get started and you can also refer to
# lib/rgen/commands.rb in your RGen core workspace for more examples and 
# inspiration.
#
# Also see the official docs on adding commands:
#   http://rgen.freescale.net/rgen/latest/guides/custom/commands/

# Map any command aliases here, for example to allow rgen -x to refer to a 
# command called execute you would add a reference as shown below: 
aliases ={
#  "-x" => "execute",
}

# The requested command is passed in here as @command, this checks it against
# the above alias table and should not be removed.
@command = aliases[@command] || @command

# Now branch to the specific task code
case @command

# Here is an example of how to implement a command, the logic can go straight
# in here or you can require an external file if preferred.
when "execute"
  puts "Executing something..."
  require "commands/execute"    # Would load file lib/commands/execute.rb
  # You must always exit upon successfully capturing a command to prevent 
  # control flowing back to RGen
  exit 0

# Always leave an else clause to allow control to fall back through to the
# RGen command handler.
# You probably want to also add the command details to the help shown via
# rgen -h, you can do this be assigning the required text to @application_commands
# before handing control back to RGen. Un-comment the example below to get started.
else
#  @application_commands = <<-EOT
# execute      Execute something I guess
#  EOT

end 
