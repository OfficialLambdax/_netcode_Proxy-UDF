# _netcode_Proxy-UDF
This is an Addon for the _netcode UDF.

This addon requires _netcode_AddonCore.au3
https://github.com/OfficialLambdax/_netcode_AddonCore-UDF

and _netcode_Core.au3
https://github.com/OfficialLambdax/_netcode_Core-UDF

The same describition of the Core UDF applies to here. This UDF is in its concept phase and alot of things are missing and subject to change.

It adds Proxy functionalities. Proxies need to be configured manually. It is not a specific http/s proxy. It proxies every traffic to the said destination and vise versa. So the client connecting to the Proxy can or needs to tell the Proxy where to connect to, this can either be a Browser or any other application. However the UDF only comes with basic support for HTTP/S as of yet. Any other system like a SOCKS processor needs to be manually coded and the UDF is ment to be used in that configurable way.

The proxy makes fully use of non blocking sockets.

Speedtest.net and other tests over HTTP/S through the Proxy showed zero to just a very small lag in Ping and Down- and Upling speeds (tested with a 200mbit lane and got the whole 200mbits through the proxy).
