require 'aws-sdk'
require 'ostruct'
require 'hornet/fleet'
require 'hornet/hive'

module Fleet
  class Headquarter

    STATE_FILE = File.expand_path('~/.hives')

    def initialize(command, options={})
      @command = command
      @options = options

      @state = OpenStruct.new options
      @state.loaded = false

      readServerState

      if @state.region
        Aws.config.update({:region => @state.region})
        @ec2_resource = Aws::EC2::Resource.new
        @ec2_client = Aws::EC2::Client.new
      end
    end

    def dispatch
      case @command
      when 'up'
        createHives @options
      when 'attack'
        hivesAttack @options
      when 'scale'
        scaleHives @options
      when 'report'
        hivesReport
      when 'down'
        destroyHives
      end
    end

    # create a number of hives using user options
    def createHives(options)
      number_of_hive = options.has_key?(:number) ? options[:number].to_i : 1
      hive_options = {
        :key_name      => nil,
        :image_id      => nil,
        :min_count     => number_of_hive,
        :max_count     => number_of_hive,
        :instance_type => 't2.micro'
      }
      hive_options.merge!(options.select {|k,v| hive_options.has_key?(k)})
      hives = @ec2_resource.create_instances hive_options
      puts "%i hives are being built" % number_of_hive

      # write the current state to the file
      @state.hives = hives.map(&:id) + @state.hives.to_a
      writeServerList

      checkHivesStatus hives

      # tagging happens after the instance is ready
      @ec2_resource.create_tags({:tags => [{:key => 'Name', :value => 'hive'}], :resources => hives.map(&:id)})
    end

    # start the attack simultaneously.
    def hivesAttack(options)
      hives = []
      attack_threads = []
      attack_options = []

      puts "Preparing the attack:"
      puts "%s bees will attack %s times, %s at a time" % [options[:bees], options[:bees].to_i * options[:number].to_i, options[:concurrent]]
      remains = options[:bees].to_i % @state.hives.count
      options[:bees] = options[:bees].to_i / @state.hives.count

      puts "Hive              Bees"
      @state.hives.each_with_index do |instance_id, index|
        if index == @state.hives.size - 1
          options[:bees] += remains
        end
        attack_options << options.clone
        puts '%s        %s' % [instance_id, options[:bees]]

        hive = Hive.new @state.username, @state.key_name, instance_id
        hives << hive
        attack_threads << Thread.new do
          hive.attack attack_options[index]
        end
      end

      puts "\n"
      attack_threads.each {|t| t.join}
      puts "\n"

      hivesReport hives
    end

    # collect report from every hive
    def hivesReport(hives=[])
      data = {}
      report_threads = []
      if not hives.any?
        @state.hives.each_with_index do |instance_id, index|
          hives << Hive.new(@state.username, @state.key_name, instance_id)
        end
      end

      # create the report threads
      hives.each do |hive|
        report_threads << Thread.new do
          data[hive.instance_id] = hive.report
        end
      end

      report_threads.each {|t| t.join}
      Fleet.print_report Fleet.report(data)
    end

    # scale hives up and down
    def scaleHives(options)
      if not @state.loaded
        abort 'Perhaps build some hives first?'
      end
      number_of_hive = options.has_key?(:number) ? options[:number].to_i : 1
      if @state.hives.count == number_of_hive
        abort 'No hives scaled'
      elsif @state.hives.count > number_of_hive
        destroyHives number_of_hive > 0 ? @state.hives[number_of_hive..-1] : {}
      else
        options = {:number => number_of_hive - @state.hives.count, :image_id => @state.image_id}
        createHives @state.to_h.merge options
      end
    end

    # tear down all running hives
    def destroyHives instances = []
      instances = instances.empty? ? @state.hives : instances
      if not instances.empty?

        # attemp the terminate ec2 instances
        begin
          @ec2_client.terminate_instances instance_ids: instances
        rescue Aws::EC2::Errors::InvalidInstanceIDNotFound => e
          # for mismatches, terminate what we can
          instances_2b_removed = instances - e.to_s.match(/\'[^']*\'/)[0].split(',').map! {|x| x.strip.tr_s("'", "")}
          @ec2_client.terminate_instances instance_ids: instances_2b_removed
        rescue Aws::EC2::Errors::InvalidInstanceIDMalformed
        end

        if instances.count == @state.hives.count
          removeServerList
        else
          @state.hives.reject! {|item| instances.include? item}
          writeServerList
        end
      else
        abord 'Perhaps build some hives first?'
      end
      puts '%i hives are teared down!' % instances.count
    end

    private

    def readServerState
      if not File.exist? STATE_FILE
        return false
      end
      server_state = IO.readlines(STATE_FILE).map! {|l| l.strip}
      begin
        @state.username = server_state[0]
        @state.key_name = server_state[1]
        @state.region   = server_state[2]
        @state.image_id = server_state[3]
        @state.hives    = server_state[4..-1]
      rescue
        abort 'A problem occured when reading hives'
      end
      @state.loaded = true
    end

    def writeServerList
      begin
        File.open(STATE_FILE, 'w') do |f|
          f.write("%s\n" % @state.username)
          f.write("%s\n" % @state.key_name)
          f.write("%s\n" % @state.region)
          f.write("%s\n" % @state.image_id)
          f.write(@state.hives.join("\n"))
        end
      rescue
        abort 'Failed to written down hives details'
      end
    end

    def removeServerList
      File.delete STATE_FILE
    end

    # check over status of hives
    def checkHivesStatus(hives)
      hives_built = []
      filters = [{:name => 'instance-state-name', :values => ['pending', 'running']}]
      while hives_built.count != hives.count do
        statuses = @ec2_client.describe_instance_status instance_ids: hives.map(&:id), include_all_instances: true, filters: filters
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
end
