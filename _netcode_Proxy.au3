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

Global $__net_Proxy_sAddonVersion = "0.2.1"


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

 Description
	Each proxy requires to have atleast a connect or a destination middleman.
	The middleman has to return a destination for the connected client. Otherwise
	the proxy simply has no clue where to connect to.

	The middleman is ment to process the packet send from the client and to determine the destination from it.
	Like with a http/s proxy. The browser sends a GET or CONNECT request containing the destination.
	The Destination middleman then reads that information and returns it to the proxy, which then
	connects to the given destination, while it also either returns a 200 to the browser or forwards the
	http request to the destination.

	So generally the proxy should be able to be compatible with any TCP protocol.

	A between middleman can also be used to intercept packets and to modify them.

 Parameters ___________________________________________________________________________________________________________________________________

 $sID
	A Identifier for the set middleman, like "Socks_5"

 $sCallback
	The function name

 $sPosition
	"Connect"			Gets called on connect of a incoming connection (no data got yet received).
						If you dont determine the destination from a packet then this position is your goto.

	"Destination"		Gets called once the client send the first data, which might contain the destination.
						Here you proccess the send data and return the destinations IP and Port.

	"Between"			Gets called between each send from the incoming to the outgoing and vise versa.
						Here you can see whats transmitted between the two clients and log or modify it.

	"Disconnect"		Gets called on disconnect ~ todo


 Remarks ______________________________________________________________________________________________________________________________________


 Connect callbacks require
	$hIncomingSocket
	$sPosition					Position name
	$sData						Will be Null

 Destination callbacks require
	$hIncomingSocket
	$sPosition					Position name | is just present incase you want the connect and destination middleman to be the same function
	$sData						The data received from the incoming socket that might contain the destination

 Between callbacks require
	$hSendingSocket				The Socket that wants to send data
	$hReceivingSocket			The Socket that will get the data
	$bSendingSocketIsIncoming	True if $hSendingSocket is the incoming socket, False if the outgoing
	$sData						The data to be relayed

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

		Return False				Will disconnect the socket
		Return Null					If you couldnt determine a destination from the data. Your func will be called again with the next received packet

		Return $arDestination[2 - 5]

			[0] = IPv4 (IPv6 not supported yet)
			[1] = Port
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


	Between middleman
		This middleman will be called with the data that is received and going to be relayed.
		You can edit, log or deny the relay.

		Return SetError(1)						Will deny the relay. data will simply be voided.
		Return SetExtended($nLen, $sData)		(String) Will relay that data. Extended needs to be the BinaryLen() of $sData.

		You always have to return $sData and the len even if you dont do anything to it. Not doing so
		will cause bugs.

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

	#cs
	; destination needs yet to be determined, incoming socket is removed once thats known
	__netcode_Addon_CreateSocketList($hSocket & '_IncomingPending')

	; only contains outgoing pending sockets
	__netcode_Addon_CreateSocketList($hSocket & '_OutgoingPending')

	; once the outgoing pending is successfully connected, both the incoming and outgoing are added to this
	__netcode_Addon_CreateSocketList($hSocket)
	#ce


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
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Proxy_SetMiddleman(Const $hSocket, $sID)

	Local $bReturn = __netcode_Addon_SetMiddleman($hSocket, $sID, 1)
	Return SetError(@error, @extended, $bReturn)

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Proxy_CreateHttpProxy
; Description ...: Creates a HTTP/S Proxy and returns the Socket
; Syntax ........: _netcode_Proxy_CreateHttpProxy($sOpenOnIP, $nOpenOnPort)
; Parameters ....: $sOpenOnIP           - Open at this IP (set 0.0.0.0 to open for everyone)
;                  $nOpenOnPort         - Listen at port
; Return values .: Socket				= If success
;				 : False				= If not
; Errors ........: 1					- Could not create listener
; Extendes ......: See msdn https://docs.microsoft.com/de-de/windows/win32/winsock/windows-sockets-error-codes-2
; Modified ......:
; Remarks .......: The http/s proxy is not officially supported, it is more of a very old example to show of the proxy UDF.
;				 : It has Bugs. Some sites cannot be reached duo to TCPNameToIP returning a wrong IP.
;				 : And http sites often return Error 400 "bad request". Thats not a issue with the UDF but with the destination
;				 : middleman being poorly written by me.
; Example .......: No
; ===============================================================================================================================
Func _netcode_Proxy_CreateHttpProxy($sOpenOnIP, $nOpenOnPort)
	_netcode_Proxy_RegisterMiddleman("http_s", "__netcode_Proxy_Http_DestinationMiddleman", "Destination")

	Local $hSocket = _netcode_Proxy_Create($sOpenOnIP, $nOpenOnPort, "http_s")
	If Not $hSocket Then Return SetError(1, @error, False)

	Return $hSocket
EndFunc







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

Func __netcode_Proxy_Http_DestinationMiddleman($hIncomingSocket, $sPosition, $sPackages)

	; split the package by @CRLF
	Local $arPackage = StringSplit($sPackages, @CRLF, 1 + 2)

	; determine the type of the data "GET, POST, or CONNECT"
	if StringLeft($arPackage[0], 3) = "GET" Then
		; resolve the ip and port
		$sIP = StringTrimLeft($arPackage[0], 4)
		$sIP = StringLeft($sIP, StringInStr($sIP, ' '))

		$arIPAndPort = __netcode_Proxy_URLToIPAndPort($sIP, 80)

		; add the packet to the [2] to have it send to the destination after we connected
		ReDim $arIPAndPort[3]
		$arIPAndPort[2] = $sPackages

	ElseIf StringLeft($arPackage[0], 4) = "POST" Then
		; resolve the ip and port
		$sIP = StringTrimLeft($arPackage[0], 5)
		$sIP = StringLeft($sIP, StringInStr($sIP, ' '))

		$arIPAndPort = __netcode_Proxy_URLToIPAndPort($sIP, 80)

		; add the packet to the [2] to have it send to the destination after we connected
		ReDim $arIPAndPort[3]
		$arIPAndPort[2] = $sPackages

	ElseIf StringLeft($arPackage[0], 7) = "CONNECT" Then
		; resolve the ip and port
		$sIPAndPort = StringTrimLeft($arPackage[0], 8)
		$sIPAndPort = StringLeft($sIPAndPort, StringInStr($sIPAndPort, ' '))

		$arIPAndPort = __netcode_Proxy_URLToIPAndPort($sIPAndPort)

		; send a 200 back to the socket once the connection to the destination succeeded
		ReDim $arIPAndPort[5]
		$arIPAndPort[3] = "HTTP/1.1 200 Connection Established" & @CRLF & @CRLF
		$arIPAndPort[4] = True

	Else
		; if we got something else but a "GET, POST or CONNECT"

		Return False
	EndIf

	; if we couldnt resolve a ip and port then Return False and therefore remove the socket
	if $arIPAndPort[0] = "" Then
		Return False
	EndIf

	; if we could resolve a ip and port then return it
	Return $arIPAndPort
EndFunc

Func __netcode_Proxy_URLToIPAndPort(Const $sURL, $nForcePort = 0, $bForcePortIsOptional = True)
	Local Static $arStripStrings[0][2]
	if UBound($arStripStrings) = 0 Then
		Local $sStripStrings = "https://|http://|wss://|www.|ww3."
		Local $arSplitStrings = StringSplit($sStripStrings, '|', 1)

		ReDim $arStripStrings[$arSplitStrings[0]][2]

		For $i = 0 To $arSplitStrings[0] - 1
			$arStripStrings[$i][0] = $arSplitStrings[$i + 1]
			$arStripStrings[$i][1] = StringLen($arSplitStrings[$i + 1])
		Next
	EndIf

	Local $sURLFormatted = $sURL
	For $i = 0 To UBound($arStripStrings) - 1
		if StringLeft($sURLFormatted, $arStripStrings[$i][1]) = $arStripStrings[$i][0] Then
			$sURLFormatted = StringTrimLeft($sURLFormatted, $arStripStrings[$i][1])
		EndIf
	Next

	if StringInStr($sURLFormatted, '/') Then $sURLFormatted = StringLeft($sURLFormatted, StringInStr($sURLFormatted, '/') - 1)

	Local $arIPAndPort = StringSplit($sURLFormatted, ':', 1 + 2)
	if UBound($arIPAndPort) = 1 And $nForcePort = 0 Then Return False ; no port
	if UBound($arIPAndPort) = 1 Then ReDim $arIPAndPort[2]
	if $arIPAndPort[1] = "" Then $arIPAndPort[1] = $nForcePort
	if Not $bForcePortIsOptional Then $arIPAndPort[1] = $nForcePort

	$arIPAndPort[0] = TCPNameToIP($arIPAndPort[0])
	$arIPAndPort[1] = Number($arIPAndPort[1])

	Return $arIPAndPort
EndFunc