# Evil Hornets!
---
Hornets have won the war against bees. Now they control all beehives and enslave bees to fight other battles.
Hornet is a utility for building hives (micro EC2 instances) and create soldiers (docker containers) to attack (stress test) web applications.

### Dependencies
- AWS SDK 2
- NET SSH 2

### Installation
As an executable gem

    gem install evilhornets
    
As brew package

    brew install evilhornets

### Configuring AWS credentials
Hornet uses AWS Ruby SDK to communicate with EC2. It supports all credential storing methods that the SDK provides. These include declaring environment variables, machine-global configuration files, and per-user configuration files. Read more at <a href="http://docs.aws.amazon.com/sdkforruby/api/index.html">AWS Ruby SDK API Doc</a>

At minimum, store your credentials to `~/.aws/credentials`

    [default]
    aws_access_key_id = <ACCESS_KEY>
    aws_secret_access_key = <SECRET_KEY>

---
### Usage
#### The quick run down looks something like this:

    $ hornet up -n 1 -k hornet
    $ hornet attack -n 1000 -b 60 -c 250 -u http://TARGETURL/
    $ hornet down

This spins up 1 instance using EC2 keypair 'hornet', which private key is expected to exist in `~/.ssh/hornet.pem`.

It then starts 60 bee containers, each of them will attack 1000 times, 250 at a time, to the target url.

#### Scale
You can scale the number of hives up and down by:

    $ hornet scale -n 3

This way you can launch more bees wihtout stress hive too much.

### The caveat! (PLEASE READ)
This project is inspired by **Tribune News Applications Team**'s **<a href="https://github.com/newsapps/beeswithmachineguns">beeswithmachineguns</a>**. I hereby inherent their `caveat message!`:

If you decide to use the Hornet, please keep in mind the following important caveat: they are, more-or-less a distributed denial-of-service attack in a fancy package and, therefore, if you point them at any server you don’t own you will behaving unethically, have your Amazon Web Services account locked-out, and be liable in a court of law for any downtime you cause.

You have been warned.

### Bugs
---
Please log your bugs on the <a href="https://github.com/andizzle/evilhornets">Github issues tracker</a>.

### Credits
---
Initial inspiration from <a href="https://github.com/thejefflarson">Jeff Larson</a> and <a href="https://github.com/newsapps">Tribune News Applications Team</a>

### License
---
MIT.
