require 'aws-sdk'
require './hive'
require './report'

module Fleet
  class Hq

    @@state = nil
    @@general = nil
    @@control = nil
    @@command = nil
    @@options = {}
    @@hives = []
    @@region = 'us-east-1'
    @@username = nil
    @@key_name = nil

    STATE_FILE = File.expand_path('~/.hives')

    def initialize(command, options={})
      @@command = command
      @@options = options
      @@state = readServerList
      @@region = options.has_key?(:region) ? options[:region] : @@region

      Aws.config.update({:region => @@region})
      @@general = Aws::EC2::Resource.new
      @@control = Aws::EC2::Client.new
    end

    def dispatch
      case @@command
      when 'up'
        createHives @@options
      when 'attack'
        hivesAttack @@options
      when 'scale'
        scaleHives @@options
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
      hives = @@general.create_instances hive_options
      puts "%i hives are being built" % number_of_hive
      writeServerList options[:username], options[:key_name], options[:region], options[:image_id], hives.map(&:id) + @@hives
      checkHivesStatus hives
      # tagging happens after the instance is ready
      @@general.create_tags({:tags => [{:key => 'Name', :value => 'hive'}], :resources => hives.map(&:id)})
    end

    # start the attack simultaneously.
    def hivesAttack(options)
      hives = []
      attack_threads = []
      attack_options = []

      puts "Preparing the attack:"
      puts "%s bees will attack %s times, %s at a time" % [options[:bees], options[:bees].to_i * options[:number].to_i, options[:concurrent]]
      remains = options[:bees].to_i % @@hives.count
      options[:bees] = options[:bees].to_i / @@hives.count

      puts "Hive              Bees"
      @@hives.each_with_index do |instance_id, index|
        if index == @@hives.size - 1
          options[:bees] += remains
        end
        attack_options << options.clone
        puts '%s        %s' % [instance_id, options[:bees]]

        hive = Hive.new @@username, @@key_name, instance_id
        hives << hive
        attack_threads << ::Thread.new do
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
        @@hives.each_with_index do |instance_id, index|
          hives << Hive.new(@@username, @@key_name, instance_id)
        end
      end

      # create the report threads
      hives.each do |hive|
        report_threads << ::Thread.new do
          data[hive.instance_id] = hive.report
        end
      end

      report_threads.each {|t| t.join}
      Fleet.print_report Fleet.report(data)
    end

    # scale hives up and down
    def scaleHives(options)
      if @@state.nil?
        abort 'Perhaps build some hives first?'
      end
      number_of_hive = options.has_key?(:number) ? options[:number].to_i : 1
      if @@hives.count == number_of_hive
        abort 'No hives scaled'
      elsif @@hives.count > number_of_hive
        destroyHives number_of_hive > 0 ? @@hives[number_of_hive..-1] : {}
      else
        options = {:number => number_of_hive - @@hives.count, :image_id => @@image_id}
        createHives @@state.merge options
      end
    end

    # tear down all running hives
    def destroyHives instances = []
      instances = instances.empty? ? @@hives : instances
      if not instances.empty?

        # attemp the terminate ec2 instances
        begin
          @@control.terminate_instances instance_ids: instances
        rescue Aws::EC2::Errors::InvalidInstanceIDNotFound => e
          # for mismatches, terminate what we can
          instances_2b_removed = instances - e.to_s.match(/\'[^']*\'/)[0].split(',').map! {|x| x.strip.tr_s("'", "")}
          @@control.terminate_instances instance_ids: instances_2b_removed
        rescue Aws::EC2::Errors::InvalidInstanceIDMalformed
        end

        if instances.count == @@hives.count
          removeServerList
        else
          writeServerList @@username, @@key_name, @@region, @@image_id, @@hives.reject {|item| instances.include? item}
        end
      else
        abord 'Perhaps build some hives first?'
      end
      puts '%i hives are teared down!' % instances.count
    end

    private

    def readServerList
      if not ::File.exist? STATE_FILE
        return false
      end
      server_state = ::IO.readlines(STATE_FILE).map! {|l| l.strip}
      begin
        @@username = server_state[0]
        @@key_name = server_state[1]
        @@region   = server_state[2]
        @@image_id = server_state[3]
        @@hives    = server_state[4..-1]
      rescue
        abort 'A problem occured when reading hives'
      end
      {:username => @@username, :key_name => @@key_name, :region => @@region, :image_id => @@image_id, :instances => @@hives}
    end

    def writeServerList(username, key, region, image_id, instances)
      begin
        ::File.open(STATE_FILE, 'w') do |f|
          f.write("%s\n" % username)
          f.write("%s\n" % key)
          f.write("%s\n" % region)
          f.write("%s\n" % image_id)
          f.write(instances.join("\n"))
        end
      rescue
        abort 'Failed to written down hives details'
      end
    end

    def removeServerList
      ::File.delete STATE_FILE
    end

    # check over status of hives
    def checkHivesStatus(hives)
      hives_built = []
      filters = [{:name => 'instance-state-name', :values => ['pending', 'running']}]
      while hives_built.count != hives.count do
        statuses = @@control.describe_instance_status instance_ids: hives.map(&:id), include_all_instances: true, filters: filters
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
