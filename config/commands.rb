# This file should be used to extend the origen command line tool with tasks 
# specific to your application.
# The comments below should help to get started and you can also refer to
# lib/origen/commands.rb in your Origen core workspace for more examples and 
# inspiration.
#
# Also see the official docs on adding commands:
#   http://origen.freescale.net/origen/latest/guides/custom/commands/

# Map any command aliases here, for example to allow origen -x to refer to a 
# command called execute you would add a reference as shown below: 
aliases ={
#  "-x" => "execute",
}

# The requested command is passed in here as @command, this checks it against
# the above alias table and should not be removed.
@command = aliases[@command] || @command

def path_to_coverage_report
  require 'pathname'
  Pathname.new("#{Origen.root}/coverage/index.html").relative_path_from(Pathname.pwd)
end

def enable_coverage(name, merge=true)
  if ARGV.delete("-c") || ARGV.delete("--coverage")
    require 'simplecov'
    SimpleCov.start do
      command_name name

      at_exit do
        SimpleCov.result.format!
        puts ""
        puts "To view coverage report:"
        puts "  firefox #{path_to_coverage_report} &"
        puts ""
      end
    end
    yield
  else
    yield
  end
end

# Now branch to the specific task code
case @command

when "examples"  
  Origen.load_application
  enable_coverage("examples") do 

    # Pattern generator tests
    ARGV = %w(jtag_workout -t v93k.rb -r approved)
    load "#{Origen.top}/lib/origen/commands/generate.rb"
    ARGV = %w(jtag_workout -t debug_RH1 -r approved)
    load "#{Origen.top}/lib/origen/commands/generate.rb"
    ARGV = %w(jtag_workout -t debug_RL1 -r approved)
    load "#{Origen.top}/lib/origen/commands/generate.rb"

    ARGV = %w(jtag_workout -t v93k_RH4.rb -r approved)
    load "#{Origen.top}/lib/origen/commands/generate.rb"
    ARGV = %w(jtag_workout -t debug_RH4 -r approved)
    load "#{Origen.top}/lib/origen/commands/generate.rb"
    ARGV = %w(jtag_workout -t debug_RL4 -r approved)
    load "#{Origen.top}/lib/origen/commands/generate.rb"
    
    if Origen.app.stats.changed_files == 0 &&
       Origen.app.stats.new_files == 0 &&
       Origen.app.stats.changed_patterns == 0 &&
       Origen.app.stats.new_patterns == 0

      Origen.app.stats.report_pass
    else
      Origen.app.stats.report_fail
    end
    puts ""
  end
  exit 0

# Always leave an else clause to allow control to fall back through to the
# Origen command handler.
# You probably want to also add the command details to the help shown via
# origen -h, you can do this be assigning the required text to @application_commands
# before handing control back to Origen. Un-comment the example below to get started.
else
  @application_commands = <<-EOT
 examples     Run the examples (tests), -c will enable coverage
  EOT

end 
