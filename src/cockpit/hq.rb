require 'aws-sdk'

class Hq

  @command = nil
  @options = {}
  @hives = []
  @region = 'us-east-1d'

  def initialize(command, options={})
    @command = command
    @options = options
    @region = options.has_key?(:region) ? options[:region] : @region
    Aws.config.update({:region => @region})
  end

  def dispatch
    case @command
    when 'up'
      createHives(@options)
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
    @hives = ec2_general.create_instances hive_options
    ec2_general.create_tags({:tags => [{:key => 'Name', :value => 'hive'}], :resources => @hives.map(&:id)})
  end

  def destroyHives(options)

  end
end
