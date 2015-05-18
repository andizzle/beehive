require 'aws-sdk'

class Hq

  @@command = nil
  @@options = {}
  @@hives = []
  @@region = 'us-east-1'

  def initialize(command, options={})
    @@command = command
    @@options = options
    @@region = options.has_key?(:region) ? options[:region] : @@region
    Aws.config.update({:region => @@region})
  end

  def dispatch
    case @@command
    when 'up'
      createHives @@options
    when 'down'
      destroyHives @@options
    end
  end

  # create a number of hives using user options
  def createHives(options)
    number_of_hive = options.has_key?(:number) ? options[:number].to_i : 1
    ec2_general = Aws::EC2::Resource.new
    hive_options = {
      :image_id      => 'ami-cb49d7f1',
      :min_count     => number_of_hive,
      :max_count     => number_of_hive,
      :instance_type => 't1.micro'
    }
    hive_options.merge!(options.select {|k,v| hive_options.has_key?(k)})
    @@hives = ec2_general.create_instances hive_options
    puts "%i hives are being built" % number_of_hive
    ec2_general.create_tags({:tags => [{:key => 'Name', :value => 'hive'}], :resources => @@hives.map(&:id)})
    checkHivesStatus
  end

  def destroyHives(options)

  end

  private

  # check over status of hives
  def checkHivesStatus
    ec2_control = Aws::EC2::Client.new
    hives_built = []
    filters = [{:name => 'instance-state-name', :values => ['pending', 'running']}]
    while hives_built.count != @@hives.count do
      statuses = ec2_control.describe_instance_status instance_ids: @@hives.map(&:id), include_all_instances: true, filters: filters
      statuses.each do |response|
        response[:instance_statuses].each do |instance|
          building = instance[:instance_state].name == 'running' ? false : true
          instance_id = instance[:instance_id]
          if not building and not hives_built.include? instance_id
            puts 'Hive %s is ready!' % instance_id
            hives_built << instance_id
          end
        end
      end
      sleep(1)
    end
  end

end
