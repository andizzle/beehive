require 'optparse'
require 'ostruct'
require 'hornet/headquarter'

Commands = {
  'up'     => 'Spin up multiple EC2 micro instances to host bees.',
  'attack' => 'Launch an attack against a target.',
  'down'   => 'Terminate load testing servers.',
  'scale'  => 'Adjust the number of load testing servers.',
  'report' => 'Report the load testing result.',
  'help'   => 'Print the help document.',
}
AMIs = {
  'us-east-1'      => 'ami-fbb35590',
  'us-west-1'      => 'ami-831cf4c7',
  'us-west-2'      => 'ami-318eb201',
  'sa-east-1'      => 'ami-9ba92886',
  'eu-west-1'      => 'ami-094f3f7e',
  'eu-central-1'   => 'ami-a67e47bb',
  'ap-northeast-1' => 'ami-be73a2be',
  'ap-southeast-1' => 'ami-2c19217e',
  'ap-southeast-2' => 'ami-9b9de4a1'
}

class Hornet

  def self.parse(args)
    command = args.first
    options = OpenStruct.new
    parser = OptionParser.new do |opt|

      if ['--help', '-h', 'help'].include? command
        print_help = ['--help', '-h', 'help'].include? command
        command = 'help'
      end
      if not Commands.keys.include? command
        opt.banner = "Usage: hornet (%s) [options]" % Commands.keys.join('|')
      else
        opt.banner = "Usage: hornet %s [options]" % command

        if ['up', 'attack', 'scale'].include? command
          opt.separator Commands[command]
        end

        # build options depends on command

        if command == 'attack' or print_help
          opt.separator 'attack:'
          opt.on('-n', '--number [NUMBER]', 'Number of total attacks to launch (default: 1000).') do |value|
            options.number = value
          end
          opt.on('-c', '--concurrent [CONCURRENT]', 'The number of concurrent connections to make to the target (default: 100).') do |value|
            options.concurrent = value
          end
          opt.on('-b', '--bees [BEES]', 'Number of containers to create (default: 1).') do |value|
            options.bees = value
          end
          opt.on('-u', '--url [URL]', 'URL of the target to attack.') do |value|
            options.url = value
          end
        end

        if command == 'up' or print_help
          opt.separator 'up:'
          opt.on('-r', '--region [REGION]', 'Region the server will be built (default: us-east-1d).') do |value|
            options.region = value
          end
          opt.on('-n', '--number [NUMBER]', 'Number of servers to start (default: 1).') do |value|
            options.number = value
          end
          opt.on('-u', '--username [USERNAME]', 'The ssh username name to use to connect to the servers (default: ubuntu).') do |value|
            options.username = value
          end
          opt.on('-k', '--key [KEY]', 'The ssh key pair name to use to connect to the servers.') do |value|
            options.key_name = value
          end
          opt.on('-i', '--image_id [IMAGE_ID]', 'The ID of the AMI.') do |value|
            options.image_id = value
          end
        end

        if command == 'scale' or print_help
          opt.separator 'scale:'
          opt.on('-n', '--number [NUMBER]', 'Number of servers to scale to (default: 1).') do |value|
            options.number = value
          end
        end

        opt.on('-h', '--help', 'Print this help document.') do |value|
          abort parser.to_s
        end
      end

    end

    # don't parse anything if no command sepcified
    if command.nil? or ['--help', '-h', 'help'].include? command
      abort parser.to_s
    end
    parser.parse!
    options
  end

  # validate options, abort if required options is missing
  def self.validate_options(command, options)
    ops = {}
    begin
      case command
      when 'attack'
        ops = {:number => 1000, :concurrent => 100, :bees => 1}.merge options.to_h
        if not ops.has_key? :url
          raise ArgumentError.new 'Missing argument: --url'
        end
      when 'up'
        ops = {:region => 'us-east-1', :username => 'ubuntu', :number => 1}.merge options.to_h
        if not ops.has_key? :image_id
          ops[:image_id] = AMIs[ops[:region]]
        end
        if not AMIs.keys.include? ops[:region]
          raise ArgumentError.new 'Region must be in %s ' % AMIs.keys.join(', ')
        end
        if not ops.has_key? :key_name
          raise ArgumentError.new 'Missing argument: --key'
        end
      when 'scale'
        ops = {:number => 1}.merge options.to_h
      end
    rescue ArgumentError => msg
      abort msg.to_s
    end
    OpenStruct.new ops
  end

  # move on to the next step.
  def self.go(args, options)
    command = args.first
    if not command.nil?
      options = Hornet.validate_options command, options
      headquarter = Fleet::Headquarter.new(command, options.to_h)
      headquarter.dispatch
    end
  end
end
