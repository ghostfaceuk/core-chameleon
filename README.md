![Core Chameleon](https://raw.githubusercontent.com/alessiodf/core-chameleon/master/banner.png)

# Core Chameleon: A Plugin for ARK Core

THIS PRE-RELEASE SOFTWARE IS PROVIDED “AS IS”. THE DEVELOPER DISCLAIMS ANY AND ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. THE DEVELOPER SPECIFICALLY DOES NOT WARRANT THAT THE PRE-RELEASE SOFTWARE WILL BE ERROR-FREE, ACCURATE, RELIABLE, COMPLETE OR UNINTERRUPTED.

**Do not run this software on a production network or mainnet! This version is for testing only.**

# Introduction

Core Chameleon is a plugin for ARK Core 2.6 which is specifically designed for forging delegate node operators to externally close their peer-to-peer port, which is vulnerable to denial-of-service and other attacks. It also hides the IP address of the node by routing all traffic via Tor, ensuring total anonymity which prevents the identification of the node or its hosting provider. The plugin also enables the full and complete operation of a relay or forging node when running behind a firewall, which may be useful for some corporate users that cannot open an external port but still want to receive live blocks and transactions on the network. It also has other benefits which transcend beyond security, such as being able to run multiple conflicting networks on the same server.

### Hide your IP address

The plugin uses Tor so the originating IP address cannot be identified since it is never revealed to any other ARK Core node, nor does it appear in peer lists. Multiple Tor circuits are used to transmit data between other nodes to minimise latency and maintain connectivity even if one or more Tor nodes go offline.

This means nodes cannot be identified to be targeted in a cyber-attack against the network by examining log files or peer lists.

### Close the P2P port

The peer-to-peer port of the node is completely closed and inter-process communication between relay and forger is carried out using a local UNIX socket instead of an externally available websocket port. Blocks and transactions are pulled from other nodes in real time, again all via Tor, for privacy and anonymity.

Assuming a forging node operator also closes their public API and other unnecessary ports such as the webhook and RPC servers, port scanning will not be able to identify the presence of a node running ARK Core, which can give operators some peace of mind as they will not be targets of socio-abuse or technical attacks.

### Compatibility with firewalls

Some relay operators may find themselves stuck behind a restrictive corporate firewall beyond their control, but still may need to run a full node properly which is currently impossible with stock Core 2.6. Ordinarily, any node behind a corporate firewall or NAT cannot sync with the network in real time, nor can they receive transactions sent into the network from other nodes; instead they only download new blocks every minute which means they continually fall out of sync and cannot be used for any time-critical purposes.

By installing this plugin on those nodes, they will instead look and feel like normal nodes, since they will immediately receive blocks as and when they are produced by delegates and will also process incoming transactions as they propagate across the network.

### Run multiple conflicting networks

Each network powered by Core 2.6 uses a hardcoded port for P2P traffic which cannot be changed. For example, the ARK Public Network uses port 4001, the ARK Development Network uses port 4002 and Qredit uses port 4101. This is fine, because each port is different so a single node can run all three networks without issue. But, for example, the nOS Development Network also uses port 4002, which clashes with the ARK Development Network. Similarly, the Unikname Livenet uses port 4001, which clashes with the ARK Public Network. This means that it is impossible for the same IP address to reliably run a relay or forger for both ARK and nOS Development Networks concurrently, or the ARK Public Network and the Unikname Livenet at the same time. An operator wanting to reliably run nodes on conflicting networks with full functionality would need to use a separate IP address, which normally means paying for a second separate server.

This plugin eliminates that barrier, allowing the same server with the same IP address to run multiple networks that would otherwise clash, all at the same time. This is acheived with no loss of functionality and is made possible since we no longer use an external P2P port so there are no port conflicts. This has a potential cost saving for operators as they could run many networks on the same server.

Please note that operators may also need to adjust their configuration files to close or change the port of any other overlapping services such as the public API used by any conflicting networks as this plugin only handles the P2P port. This is straightforward as these other ports are not hardcoded and may be changed without causing issues, unlike the P2P port in Core 2.6.

## Installation, Configuration and Updates

**REMINDER: This is pre-release software and should not be used on any production-ready network or mainnet!**

Core Chameleon includes a script that will automatically download the plugin, install Tor and configure your node to enable (or disable) the plugin. The same script will also install any updates that are released in future.

Download the script:

```
curl -o chameleon.sh https://raw.githubusercontent.com/alessiodf/core-chameleon/master/chameleon.sh
```

If you've installed ARK Core using the default installation script provided by ARK Ecosystem, execute the script with:
```
bash ./chameleon.sh
```

If you're using a bridgechain or you have installed from Git (for example, via the Core Control program), execute the script by including the path to your Core installation. For example, in the case of nOS:
```
bash ./chameleon.sh /home/nos/nos-core
```

On the first run it will install Tor (if it is not already installed) and download the latest version of the Core Chameleon plugin. Thereafter, every time it is executed it will first check for any updates and allow the operator to enable or disable the plugin without manually editing `plugins.js`.

Remember to restart your node's processes (`core` or the `forger` and `relay` combination) when you reconfigure the plugin.

### Support

If you need support, reach out on Discord by messaging `🅶🆈🅼#0666` or you might find me lurking in Slack as `king turt`.
## License

[GPLv3](LICENSE) © [alessiodf](https://github.com/alessiodf/)
