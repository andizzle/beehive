require 'aws-sdk'
require 'net/ssh'
require 'hornet/report'

module Fleet
  class Hive
    attr_accessor :instance_id
    HOME_DIR = '/home/ubuntu'

    def initialize(username, key, instance_id)
      @username = username
      @key = File.expand_path('~/.ssh/%s.pem' % key)

      # grab the instance ip and id
      instance = Aws::EC2::Instance.new instance_id
      @instance_id = instance_id
      @ip = instance.public_ip_address
    end

    # attack the target, clean the previous attack result, preapre the attack and then start the attack
    def attack(option)
      Net::SSH.start(@ip, @username, :keys => [@key]) do |ssh|
        # remove all exited containers
        clean_cmd = _clean ssh
        clean_cmd.wait

        # prepare the attack
        create_cmd = _prepare ssh, option
        create_cmd.wait

        # build the command
        #open a new channel and run the container
        attack_cmd = _execute ssh, option
        attack_cmd.wait
      end
    end

    # connect to the instance and collect the results
    def report
      result = {}

      Net::SSH.start(@ip, @username, :keys => [@key]) do |ssh|

        data = ""
        collection_cmd = _collection_info ssh, data
        collection_cmd.wait

        # parse the result
        index = 1
        data.split('Connection Times (ms)').each do |d|
          data = Fleet.parse_ab_data d
          if data.any?
            result[index] = data
            index += 1
          end
        end

      end

      Fleet.report result
    end

    private
    # add new ab command to ab.sh
    def _prepare(ssh, option)
      benchmark_command = 'ab -s 60 -r -n %{number} -c %{concurrent} "%{url}" >> /root/${HOSTNAME}.out' % option
      ssh.open_channel do |cha|
        cha.exec "touch %{path}/ab.sh && echo '%{cmd}' > %{path}/ab.sh" % {:cmd => benchmark_command, :path => HOME_DIR} do |ch, success|
          raise "could not execute command" unless success
        end
      end
    end

    # start the attack
    def _execute(ssh, option)
      puts "Hive %s is starting it's attack" % @instance_id
      ssh.open_channel do |cha|
        # 'for i in {1..%s}; do nohup docker run -v /home/ubuntu:/root andizzle/debian bash /root/ab.sh; done'
        cmd = ['docker run -v /home/ubuntu:/root andizzle/debian bash /root/ab.sh'] * option[:bees]
        cha.exec cmd.join ' & ' do |ch, success|
          raise "could not execute command" unless success
          ch.on_data do |c, data|
            puts data
          end
          ch.on_close { puts "Hive %s has finished it's attack!" % @instance_id}
        end
      end
    end

    def _collection_info(ssh, data_pool)
      ssh.open_channel do |cha|
        cha.exec 'find %s -name "*.out" -exec cat {} \;' % HOME_DIR do |ch, success|
          raise "could not execute command" unless success
          ch.on_data do |c, data|
            data_pool << data
          end
        end
      end
    end

    # clean up the battlefield
    def _clean(ssh)
      ssh.open_channel do |cha|
        cha.exec 'docker ps -aq -f status=exited | xargs docker rm && find /home/ubuntu -name "*.out" -exec rm {} \;' % HOME_DIR do |ch, success|
          raise "could not execute command" unless success
        end
      end
    end
  end
end
