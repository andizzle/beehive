require 'aws-sdk'
require 'net/ssh'

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
    ::Net::SSH.start(@ip, @username, :keys => [@key]) do |ssh|
      b_no = 1
      attacks = []

      # start an attack for every bee
      option[:bees].to_i.times do
        option[:b_no] = b_no

        # build the command
        benchmark_command = 'ab -r -n %{number} -c %{concurrent} -e /root/%{b_no}.csv "%{url}"' % option
        puts "Bee %s-%s has started the attack!\n" % [@instance_id, b_no]

        #open a new channel and run the container
        attacks << ssh.open_channel do |cha|
          cha.exec 'docker run -v /home/ubuntu/results:/root andizzle/debian %s' % benchmark_command do |ch, success|

            raise "could not execute command" unless success

            ch.on_data { |c, data|

            }

            ch.on_close {
              puts "Bee %s-%i is out of ammo!" % [@instance_id, ch.local_id.to_i + 1]
            }
          end
        end

        b_no += 1 # bee number increment

      end #end of attack session creation

      attacks.each do |attack|
        attack.wait
      end

    end
  end

  def report
  end

  def parse_ab_data(data)
  end

end