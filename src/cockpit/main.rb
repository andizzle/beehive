#!/usr/bin/env ruby

require 'optparse'
require './hq'

options = {}
command = nil
commands = %w(up attack down scale)

up = <<DOC

Enter the usage and command options here
DOC
attack = <<DOC

Enter the usage and command options here
DOC
scale = <<DOC

Enter the usage and command options here
DOC

docs = {:up => up, :attack => attack, :scale => scale}

opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: hive (%s) [options] [parameters]" % commands.join('|')

  command = ARGV[0]
  if !command.nil? and commands.include? command
    opt.banner = "Usage: hive %s [options] [parameters]" % command
    command.to_sym
    if ['up', 'attack', 'scale'].include? command
      docs[command.to_sym].each_line do |line|
        opt.separator line
      end
    end

    # build options depends on command
    case command
    when 'attack'
      opt.on('-n', '--number [INTEGER]', 'Number of attacks to launch') do |number|
        options[:number] = number
      end
    when 'up'
      opt.on('-r', '--region [STRING]', 'Region the hive will be built') do |region|
        options[:region] = region
      end
      opt.on('-n', '--number [INTEGER]', 'Number of hive to destroy') do |number|
        options[:number] = number
      end
      opt.on('-i', '--image_id [STRING]', 'The ID of the AMI') do |image_id|
        options[:image_id] = image_id
      end
    when 'scale'
      opt.on('-n', '--number', 'Number of hive to destroy') do |number|
        options[:number] = number
      end
      opt.on('-b', '--bees', 'Number of bees to retrieve') do |bees|
        options[:bees] = bees
      end
    end
  end
end


if __FILE__ == $0
  if ARGV.empty?  # if they just trying out, print the cmd message
    puts opt_parser
  else
    opt_parser.parse!  # parse the commpand
    if ['up', 'attack', 'scale'].include? command and options.empty?  # if up, attack and scale does not have any instructions, print help
      puts opt_parser
    else  # dispatch the requst
      hq = Hq.new(command, options)
      hq.dispatch
    end
  end
end