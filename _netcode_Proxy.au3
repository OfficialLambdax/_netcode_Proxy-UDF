#include-once
#include "_netcode_AddonCore.au3"


#cs

	Requires the _netcode_AddonCore.au3 UDF and _netcode_Core.au3 UDF.

	TCP-IPv4, for the time being, only.

	All Sockets are non blocking.

	The proxy will only recv and send data if the send to socket is send ready.
	It pretty much checks the sockets that have something send to the proxy first
	and then filters them for the corresponding linked sockets that can be send to.

	So the proxy does not buffer data. Memory usage should therefore be low.

#ce

Global $__net_Proxy_sAddonVersion = "0.2.3.1"
Global Const $__net_Proxy_sNetcodeOfficialRepositoryURL = "https://github.com/OfficialLambdax/_netcode_Proxy-UDF"
Global Const $__net_Proxy_sNetcodeOfficialRepositoryChangelogURL = "https://github.com/OfficialLambdax/_netcode_Proxy-UDF/blob/main/%23changelog%20proxy.txt"
Global Const $__net_Proxy_sNetcodeVersionURL = "https://raw.githubusercontent.com/OfficialLambdax/_netcode-UDF/main/versions/_netcode_Proxy.version"


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Proxy_Startup
; Description ...: Startsup the Proxy UDF, required to be called.
; Syntax ........: _netcode_Proxy_Startup()
; Return values .: True				= Success
;				 : False			= Already started
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Proxy_Startup()
	_netcode_Startup()

	Local $arParents = __netcode_Addon_GetSocketList('ProxyParents')
	If IsArray($arParents) Then Return SetError(1, 0, False) ; proxy already started

	__netcode_UDFVersionCheck($__net_Proxy_sNetcodeVersionURL, $__net_Proxy_sNetcodeOfficialRepositoryURL, $__net_Proxy_sNetcodeOfficialRepositoryChangelogURL, '_netcode_Proxy', $__net_Proxy_sAddonVersion)

	__netcode_Addon_CreateSocketList('ProxyParents')

	__netcode_Addon_Log(1, 1)

	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Proxy_Shutdown
; Description ...: ~ todo
; Syntax ........: _netcode_Proxy_Shutdown()
; Parameters ....: None
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Proxy_Shutdown()

;~ 	__netcode_Addon_Log(1, 2)
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Proxy_Loop
; Description ...: Will accept new clients and receive and send data. Needs to be called frequently in order to relay the data.
; Syntax ........: _netcode_Proxy_Loop([$hSocket = False])
; Parameters ....: $hSocket             - [optional] When set to a Socket, will only loop the given proxy socket. Otherwise all.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Proxy_Loop(Const $hSocket = False)

	if $hSocket Then
		__netcode_Proxy_Loop($hSocket)
	Else

		Local $arParents = __netcode_Addon_GetSocketList('ProxyParents')
		If Not IsArray($arParents) Then Return

		For $i = 0 To UBound($arParents) - 1
			__netcode_Proxy_Loop($arParents[$i])
		Next

	EndIf

EndFunc


#cs

 Name
	_netcode_Proxy_RegisterMiddleman()

 Description
	Each proxy requires to have atleast a connect or a destination middleman.
	The middleman has to return a destination for the connected client. Otherwise
	the proxy simply has no clue where to connect the client to.

	The middleman is ment to process the packet send from the client and to determine the destination from it.
	Like with a http/s proxy. The browser sends a GET or CONNECT request containing the destination.
	The Destination middleman then reads that information and returns it to the proxy, which then
	connects to the given destination, while it also either returns a 200 to the browser or forwards the
	http request to the destination.

	So generally the proxy should be able to be compatible with any TCP protocol, because it can intercept and alter any transmission
	at any time.

 Parameters ___________________________________________________________________________________________________________________________________

 $sID
	A Identifier for the set middleman, like "Socks_5"

 $sCallback
	The function name

 $sPosition
	"Connect"			Gets called on connect of a incoming connection (no data got yet received).
						If you dont determine the destination from a packet then this position is your goto.

	"Destination"		Gets called once the client send the first data, which might contain the destination.
						Here you proccess the send data and return the destinations IP and Port, or a Socket
						(either pending or not).

	"Between"			Gets called between each send from the incoming to the outgoing and vise versa.
						Here you can see whats transmitted between the two clients and log or modify it.

	"Disconnect"		Gets called on disconnect ~ todo


 Remarks ______________________________________________________________________________________________________________________________________


 Callbacks are Functions of your own that get Called in the set Position.

 Connect callbacks require
	$hIncomingSocket			Contains the Socket that got created for a Incoming connection (like a browser connected to the Proxy).
	$sPosition					Position name of the Middleman. "Connect" In this case.
	$sData						Will be Null in this case.

 Destination callbacks require
	$hIncomingSocket			- As above -
	$sPosition					Position name. "Destination" in this case.
								Is just present incase you want the connect and destination middleman to be in the same function.
	$sData						The data received from the incoming socket that might contain the destination.

 Between callbacks require
	$hSendingSocket				The Socket that wants to send data
	$hReceivingSocket			The Socket that will get the data
	$bSendingSocketIsIncoming	True if $hSendingSocket is the incoming socket, False if the outgoing
	$sData						The data to be relayed
	$nLen						The BinaryLen of the data

 Disconnect callback requires
	~ todo


	The Middlemans have different use cases.

	Connect middleman
		Could be used just to get a information about a connection or for logging purposes.
		But you can also decide to disconnect the socket if you dont like the ip it originates from or for other reasons.
		Besides that you can also already return a destination.

		Return False 				Will disconnect the socket
		Return True					Will keep the socket
		Return $arDestination		See the destination middleman info

	Destination middleman
		This middleman is ment to proccess a packet from the incoming socket to get the destination address.
		So this callback will be called once a packet arrived from the client.
		If you use a proxy to offload from a server and where you store, non user specific, data that is requested alot then here you
		could already decide to send it the stored data instead of forwarding the request to the server that you try to offload.
		Or you could change the destination to a specific Offload server.
		Aka this Proxy could be used as a load balancer, that knows the load of each destination and then decides to go to the most not loaded
		server.

		Return False				Will disconnect the socket
		Return Null					If you couldnt determine a destination from the data yet. Your func will be called again with the next received packet

		Return $arDestination[2 - 5]

			[0] = IPv4 (IPv6 not supported yet) Or Socket (either pending or already connected)
			[1] = Port Or Empty if [0] is a Socket
			[2] = (Optional) Data that will be send to the destination once connected to it
			[3] = (Optional) Data that will be send to the incoming socket
			[4] = (Must be set if [3] is set) True / False.
					True	The Data from [3] will be send to the incoming socket once the proxy connected
							to the destination.
					False	The Data from [3] will be imidiatly send to the incoming socket.

			Keep $arDestination of size 2 if you only want to tell the proxy the destination.
			Keep it of size 3 if you want to send data to the destination
			and only make it of size 5 if you send data to the incoming.

			If you send data to the incoming but not to the destination then leave element [2] empty.

			Https for example requires that a "HTTP/1.1 200 Connection Established" packet is send back, once the connection to the destination is up.
			Other protocols might also require such a function. This is why [4] exists.


	Between middleman
		This middleman will be called with the data that is received and going to be relayed.
		You can edit, log or deny the relay.

		Return SetError(1)						Will deny the relay. data will simply be voided.
		Return SetExtended($nLen, $sData)		(String) Will relay that data. Extended needs to be the BinaryLen() of $sData.

		You always have to return $sData and the len even if you dont do anything to it. Not doing so
		will result in the sending of a String "False".

		If you want to disconnect one and / or the other socket then simply call __netcode_TCPCloseSocket(socket) and Return SetError(1).
		The proxy will detect the disconnect in the loop.


	Disconnect middleman
		~ todo



	General advice
		Code your middleman callback functions to be as non blocking as possible. Not doing so can and will cause lag.

#ce
Func _netcode_Proxy_RegisterMiddleman($sID, $sCallback, $sPosition)

	Local $bReturn = __netcode_Addon_RegisterMiddleman($sID, $sCallback, $sPosition, 1)
	Return SetError(@error, @extended, $bReturn)

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Proxy_RemoveMiddleman
; Description ...: Removes the middleman
; Syntax ........: _netcode_Proxy_RemoveMiddleman($sID)
; Parameters ....: $sID                 - The middleman ID
; Return values .: None
; Modified ......:
; Remarks .......: Clients already connected stay connected.
; Example .......: No
; ===============================================================================================================================
Func _netcode_Proxy_RemoveMiddleman($sID)

	__netcode_Addon_RemoveMiddleman($sID, 1)

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Proxy_Create
; Description ...: Starts a proxy parent (aka listener) and returns the socket.
; Syntax ........: _netcode_Proxy_Create($sOpenOnIP, $nOpenOnPort, $sConOrDest_MiddlemanID[, $sDestMiddlemanID = False[,
;                  $sBetweenMiddlemanID = False[, $sDisconnectMiddlemanID = False]]])
; Parameters ....: $sOpenOnIP           - Proxy is open to this IP (set 0.0.0.0 for everyone)
;                  $nOpenOnPort         - Port to listen
;                  $sConOrDest_MiddlemanID- Connect or Destination Middleman ID
;                  $sDestMiddlemanID    - [optional] Destination Middleman ID
;                  $sBetweenMiddlemanID - [optional] Between Middleman ID
;                  $sDisconnectMiddlemanID- [optional] Disconnect Middleman ID
; Return values .: Socket				= If success
;				 : False				= If not
; Errors ........: 1					- The $sConOrDest_MiddlemanID is neither a Connect nor a Destination middleman
;				 : 2					- The listener could not be started (called _netcode_Proxy_Startup() before?)
; Extendeds .....: see msdn https://docs.microsoft.com/de-de/windows/win32/winsock/windows-sockets-error-codes-2
; Modified ......:
; Remarks .......: The Destination, Between or Disconect middlemans dont need to be set if they are not used. They
;				 : can also be set or changed later with _netcode_Proxy_SetMiddleman()
; Example .......: No
; ===============================================================================================================================
Func _netcode_Proxy_Create($sOpenOnIP, $nOpenOnPort, $sConOrDest_MiddlemanID, $sDestMiddlemanID = False, $sBetweenMiddlemanID = False, $sDisconnectMiddlemanID = False)

	; check middleman position
	Local $sPosition = __netcode_Addon_GetVar($sConOrDest_MiddlemanID, 'Position')
	If $sPosition <> "Connect" And $sPosition <> "Destination" Then
		__netcode_Addon_Log(1, 7, $sPosition)
		Return SetError(1, 0, False) ; $sConOrDest_MiddlemanID is not a valid middleman
	EndIf

	; start listener
	Local $hSocket = __netcode_TCPListen($sOpenOnIP, $nOpenOnPort, Default)
	Local $nError = @error
	if $nError Then
		__netcode_Addon_Log(1, 8, $sOpenOnIP & ':' & $nOpenOnPort)
		Return SetError(2, $nError, False)
	EndIf

	; add to parent list
	__netcode_Addon_AddToSocketList('ProxyParents', $hSocket)

	; create socket lists
	__netcode_Addon_CreateSocketLists_InOutRel($hSocket)


	; specify the middlemans
	__netcode_Addon_SetVar($hSocket, $sPosition, $sConOrDest_MiddlemanID)

	If $sDestMiddlemanID Then __netcode_Addon_SetVar($hSocket, 'Destination', $sDestMiddlemanID)
	If $sBetweenMiddlemanID Then __netcode_Addon_SetVar($hSocket, 'Between', $sBetweenMiddlemanID)
	If $sDisconnectMiddlemanID Then __netcode_Addon_SetVar($hSocket, 'Disconnect', $sDisconnectMiddlemanID)

	__netcode_Addon_Log(1, 6, $hSocket, $sConOrDest_MiddlemanID)

	Return $hSocket

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Proxy_Close
; Description ...: ~ todo
; Syntax ........: _netcode_Proxy_Close(Const $hSocket)
; Parameters ....: $hSocket             - [const] The Socket
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Proxy_Close(Const $hSocket)

;~ 	__netcode_Addon_Log(1, 9, $hSocket)
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Proxy_SetMiddleman
; Description ...: Sets or changes a middleman for the given parent or client socket.
; Syntax ........: _netcode_Proxy_SetMiddleman(Const $hSocket, $sID)
; Parameters ....: $hSocket             - [const] The parent or client socket
;                  $sID                 - The middleman ID
; Return values .: True					= If success
;				 : False				= If not
; Errors ........: 1					- Middleman is unknown
; Modified ......:
; Remarks .......: Usefull if you only want to middleman a specific socket for a specific time. Or if you want to change
;                : to another middleman.
; Example .......: No
; ===============================================================================================================================
Func _netcode_Proxy_SetMiddleman(Const $hSocket, $sID)

	Local $bReturn = __netcode_Addon_SetMiddleman($hSocket, $sID, 1)
	Return SetError(@error, @extended, $bReturn)

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Proxy_SetLogging
; Description ...: Enables or Disables the Logging to the Console
; Syntax ........: _netcode_Proxy_SetLogging($bSet)
; Parameters ....: $bSet                - True / False (Default = True)
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Proxy_SetLogging($bSet)

	If Not IsBool($bSet) Then Return False

	__netcode_Addon_SetLogging(1, $bSet)
	Return True

EndFunc


; Barrier. Internals Below. No Functions are ment to be used individually but some probably can.
; =============================================================================================================================================
; =============================================================================================================================================
; =============================================================================================================================================
; =============================================================================================================================================

Func __netcode_Proxy_Loop(Const $hSocket)

	; check for new incoming connections, one per loop
	Local $hIncomingSocket = __netcode_TCPAccept($hSocket)
	If $hIncomingSocket <> -1 Then __netcode_Addon_NewIncomingMiddleman($hSocket, $hIncomingSocket, 1)

	; check the incoming connection middlemans for destinations
	__netcode_Addon_CheckIncomingPendingMiddleman($hSocket, 1)

	; check the outgoing pending connections
	__netcode_Addon_CheckOutgoingPendingMiddleman($hSocket, 1)

	; recv and send
	__netcode_Addon_RecvAndSendMiddleman($hSocket, 1)

EndFunc
