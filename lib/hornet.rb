require 'optparse'
require 'hornet/hq'

Commands = %w(up attack down scale)

Up = <<DOC

Enter the usage and command options here
DOC

Attack = <<DOC

Enter the usage and command options here
DOC

Scale = <<DOC

Enter the usage and command options here
DOC

Docs = {:up => Up, :attack => Attack, :scale => Scale}

class Hornet
  attr_accessor :command
  attr_accessor :options
  attr_accessor :parser

  def initialize
    @options = {}
    @command = nil
    @parser = nil
  end

  def prepare
    @parser = OptionParser.new do |opt|
      opt.banner = "Usage: hive (%s) [options] [parameters]" % Commands.join('|')

      @command = ARGV[0]
      if !@command.nil? and Commands.include? @command
        opt.banner = "Usage: hive %s [options] [parameters]" % @command
        @command.to_sym
        if ['up', 'attack', 'scale'].include? @command
          Docs[command.to_sym].each_line do |line|
            opt.separator line
          end
        end

        # build options depends on command
        case @command
        when 'attack'
          opt.on('-n', '--number [INTEGER]', 'Number of total attacks to launch.') do |value|
            @options[:number] = value
          end
          opt.on('-c', '--concurrent [INTEGER]', 'The number of concurrent connections to make to the target (default: 100)..') do |value|
            @options[:concurrent] = value
          end
          opt.on('-b', '--bees [INTEGER]', 'Number of concurrent connections to make to the target.') do |value|
            @options[:bees] = value
          end
          opt.on('-u', '--url [STRING]', 'URL of the target to attack.') do |value|
            @options[:url] = value
          end
        when 'up'
          opt.on('-r', '--region [STRING]', 'Region the hive will be built.') do |value|
            @options[:region] = value
          end
          opt.on('-n', '--number [INTEGER]', 'Number of hive to start.') do |value|
            @options[:number] = value
          end
          opt.on('-u', '--username [STRING]', 'The ssh username name to use to connect to the new servers.') do |value|
            @options[:username] = value
          end
          opt.on('-k', '--key [STRING]', 'The ssh key pair name to use to connect to the new servers.') do |value|
            @options[:key_name] = value
          end
          opt.on('-i', '--image_id [STRING]', 'The ID of the AMI.') do |value|
            @options[:image_id] = value
          end
        when 'scale'
          opt.on('-n', '--number [INTEGER]', 'Number of hive to scale to.') do |value|
            @options[:number] = value
          end
        end
      end
    end
  end

  def self.march
    hornet = Hornet.new
    hornet.prepare
    if ARGV.empty?  # if they just trying out, print the cmd message
      puts hornet.parser
    else
      hornet.parser.parse!  # parse the commpand
      if ['up', 'attack', 'scale'].include? hornet.command and hornet.options.empty?  # if up, attack and scale does not have any instructions, print help
        puts hornet.parser
      else  # dispatch the requst
        hq = Fleet::Hq.new(hornet.command, hornet.options)
        hq.dispatch
      end
    end
  end
end
