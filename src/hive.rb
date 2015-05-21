require 'aws-sdk'
require 'net/ssh'
require './report'

module Fleet
  class Hive
    @result = {}

    def initialize(username, key, instance_id)
      @username = username
      @key = ::File.expand_path('~/.ssh/%s.pem' % key)

      # grab the instance ip and id
      instance = Aws::EC2::Instance.new instance_id
      @instance_id = instance_id
      @ip = instance.public_ip_address
    end

    def attack(option)
      data = {}

      ::Net::SSH.start(@ip, @username, :keys => [@key]) do |ssh|

        # add new ab command to ab.sh
        benchmark_command = 'ab -r -n %{number} -c %{concurrent} "%{url}" >> /root/results/ab.out' % option
        create_exec = ssh.open_channel do |cha|
          cha.exec 'echo "%s" > /home/ubuntu/ab.sh' % benchmark_command do |ch, success|

            raise "could not execute command" unless success

          end
        end

        create_exec.wait

        # build the command
        #open a new channel and run the container
        attack = _attack_command ssh, option
        attack.wait

        # remove all exited containers
        ssh.open_channel do |cha|
          cha.exec 'docker ps -aq -f status=exited | xargs docker rm' do |ch, success|
            raise "could not execute command" unless success
          end
        end

      end

      Fleet.report data
    end

    def _attack_command(ssh, option)
      ssh.open_channel do |cha|
        cha.exec 'docker-compose -f /home/ubuntu/docker-compose.yml scale ab=%s' % option[:bees] do |ch, success|

          raise "could not execute command" unless success

        end
      end
    end
  end
end
