This is a backconnect http/s proxy. Not a reverse proxy. There might be a different term for it, but i couldnt find the proper name, hence the name of what it does. The proxy itself, that connects to the requested servers from the client, is behind a firewall that does not allow a incoming connection from a Client (Browser). Aka that is inaccessible. So the Proxy connects to a Server, that is accessible to the Client (Browser).

<p align="center">
    <img src="images/backconnect proxy.png" width="500" />
</p>

In general there might be applications for this type of a proxy, but no real world example came up my mind yet. I just tried to see if a proxy of this type is possible with the already given code and to see if i find bugs and how i can improve the UDF. This example is the outcome of that just like the updated UDF.

Noted should also that the data now takes 2 Hops from the Origin to the Destination. That causes a higher Latency, but is usually not noticable.
