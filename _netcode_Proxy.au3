#include-once
#include "_netcode_AddonCore.au3"


Global $__net_Proxy_sAddonVersion = "0.2"


Func _netcode_Proxy_Startup()
	_netcode_Startup()

	Local $arParents = __netcode_Addon_GetSocketList('ProxyParents')
	If IsArray($arParents) Then Return SetError(1, 0, False) ; proxy already started

	__netcode_Addon_CreateSocketList('ProxyParents')

	__netcode_Addon_Log(1, 1)

	Return True
EndFunc

Func _netcode_Proxy_Shutdown()

;~ 	__netcode_Addon_Log(1, 2)
EndFunc


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


; $sPosition
;	Connect			Gets called on connect (no data got yet received)
;	Destination		Gets called once the client send the first data, which might contain the destination
;	Between			Gets called between each send from the incoming to the outgoing and vise versa
;	Disconnect		Gets called on disconnect
;
; Callback functions require always
;	$hIncomingSocket
;	$hOutgoingSocket	Socket or Null if there is none yet
;	$sPosition			Position name
;	$sData				Data or Null if there is none
Func _netcode_Proxy_RegisterMiddleman($sID, $sCallback, $sPosition)

	if __netcode_Addon_GetVar($sID, 'Callback') Then
		__netcode_Addon_Log(1, 4, $sID, $sPosition)
		Return SetError(1, 0, False) ; middleman with this id is already known
	EndIf

	__netcode_Addon_SetVar($sID, 'Callback', $sCallback)
	__netcode_Addon_SetVar($sID, 'Position', $sPosition)

	__netcode_Addon_Log(1, 3, $sID, $sPosition)

	Return True

EndFunc


Func _netcode_Proxy_RemoveMiddleman($sID)
	_storageS_TidyGroupVars($sID)
	__netcode_Addon_Log(1, 5, $sID)
EndFunc


; $sConOrDest_MiddlemanID NEEDS to either be a connect or destination middleman
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

	; destination needs yet to be determined, incoming socket is removed once thats known
	__netcode_Addon_CreateSocketList($hSocket & '_IncomingPending')

	; only contains outgoing pending sockets
	__netcode_Addon_CreateSocketList($hSocket & '_OutgoingPending')

	; once the outgoing pending is successfully connected, both the incoming and outgoing are added to this
	__netcode_Addon_CreateSocketList($hSocket)


	; specify the middlemans
	__netcode_Addon_SetVar($hSocket, $sPosition, $sConOrDest_MiddlemanID)

	If $sDestMiddlemanID Then __netcode_Addon_SetVar($hSocket, 'Destination', $sDestMiddlemanID)
	If $sBetweenMiddlemanID Then __netcode_Addon_SetVar($hSocket, 'Between', $sBetweenMiddlemanID)
	If $sDisconnectMiddlemanID Then __netcode_Addon_SetVar($hSocket, 'Disconnect', $sDisconnectMiddlemanID)

	__netcode_Addon_Log(1, 6, $hSocket, $sConOrDest_MiddlemanID)

	Return $hSocket

EndFunc


Func _netcode_Proxy_Close(Const $hSocket)

;~ 	__netcode_Addon_Log(1, 9, $hSocket)
EndFunc


; sets a middleman either to a parent, where each client then uses it, or to a specific client (in- and outgoing).
; could also be used to change the current set middleman.
Func _netcode_Proxy_SetMiddleman(Const $hSocket, $sID)

	Local $sPosition = __netcode_Addon_GetVar($sID, 'Position')
	if Not $sPosition Then
		__netcode_Addon_Log(1, 11, $sID)
		Return SetError(1, 0, False)
	EndIf

	Local $sCallback = __netcode_Addon_GetVar($sID, 'Callback')

	__netcode_Addon_SetVar($hSocket, $sPosition, $sCallback)

	__netcode_Addon_Log(1, 10, $sID, $sPosition)

	Return True

EndFunc


Func _netcode_Proxy_CreateHttpProxy($sOpenOnIP, $nOpenOnPort)
	_netcode_Proxy_RegisterMiddleman("http_s", "__netcode_Proxy_Http_DestinationMiddleman", "Destination")

	Local $hSocket = _netcode_Proxy_Create($sOpenOnIP, $nOpenOnPort, "http_s")
	If Not $hSocket Then Return SetError(1, 0, False)

	Return $hSocket
EndFunc







Func __netcode_Proxy_Loop(Const $hSocket)

	; check for new incoming connections, one per loop
	Local $hIncomingSocket = __netcode_TCPAccept($hSocket)
	If $hIncomingSocket <> -1 Then __netcode_Proxy_NewIncoming($hSocket, $hIncomingSocket)

	; check the incoming connection middlemans for destinations
	__netcode_Proxy_CheckIncomingPending($hSocket)

	; check the outgoing pending connections
	__netcode_Proxy_CheckOutgoingPending($hSocket)

	; recv and send
	__netcode_Proxy_RecvAndSend($hSocket)

EndFunc

; adds the socket to the IncomingPending list only when there either is no middleman or the middleman doesnt yet tells us a destination
Func __netcode_Proxy_NewIncoming(Const $hSocket, $hIncomingSocket)

	__netcode_Addon_Log(1, 21, $hIncomingSocket)

	; inherit parents preset middlemans
	Local $sID = __netcode_Addon_GetVar($hSocket, 'Connect')
	__netcode_Addon_SetVar($hIncomingSocket, 'Connect', $sID)
	__netcode_Addon_SetVar($hIncomingSocket, 'Destination', __netcode_Addon_GetVar($hSocket, 'Destination'))
	__netcode_Addon_SetVar($hIncomingSocket, 'Between', __netcode_Addon_GetVar($hSocket, 'Between'))
	__netcode_Addon_SetVar($hIncomingSocket, 'Disconnect', __netcode_Addon_GetVar($hSocket, 'Disconnect'))

	; run middleman if present
	Local $vMiddlemanReturn = ""
	If $sID Then
		$vMiddlemanReturn = Call(__netcode_Addon_GetVar($sID, 'Callback'), $hIncomingSocket, Null, 'Connect', Null)
		If @error Then
			; show error
			__netcode_Addon_Log(1, 20, $sID)
			__netcode_Proxy_DisconnectAndRemoveClients($hSocket, $hIncomingSocket, False)
		EndIf
	EndIf

	; add to IncomingPending list if not destination is yet set
	If IsArray($vMiddlemanReturn) Then
		__netcode_Proxy_ConnectOutgoing($hSocket, $hIncomingSocket, $vMiddlemanReturn, $sID)
	Else
		__netcode_Addon_AddToSocketList($hSocket & '_IncomingPending', $hIncomingSocket)
	EndIf

EndFunc

Func __netcode_Proxy_CheckIncomingPending(Const $hSocket)

	; get socket list
	Local $arClients = __netcode_Addon_GetSocketList($hSocket & '_IncomingPending')
	Local $nArSize = UBound($arClients)

	If $nArSize = 0 Then Return

	Local $sID = "", $sCallback = "", $vMiddlemanReturn, $sPackage = ""

	; for each incoming pending client
	; note: each socket could have a different middleman set to it, so have to read it for each socket instead of just once
	For $i = 0 To $nArSize - 1

		; get destination callback
		$sCallback = __netcode_Addon_GetVar(__netcode_Addon_GetVar($arClients[$i], 'Destination'), 'Callback')

		; if there is none then disconnect and remove the socket
		If Not $sCallback Then
			__netcode_Addon_Log(1, 22, $hSocket)
			__netcode_Proxy_DisconnectAndRemoveClients($hSocket, $arClients[$i], False)
			ContinueLoop
		EndIf

		; check the recv buffer
		$sPackage = __netcode_Addon_RecvPackages($arClients[$i])

		; if the incoming connection disconnected
		if @error Then
			__netcode_Addon_Log(1, 23, $arClients[$i])
			__netcode_Proxy_DisconnectAndRemoveClients($hSocket, $arClients[$i], False)
			ContinueLoop
		EndIf

		; if we didnt receive anything
		if Not @extended Then
			; check destination timeout
			; ~ todo

;~ 			__netcode_Addon_Log(1, 26, $arClients[$i])

			ContinueLoop
		EndIf

		; run the callback if we received something
		$vMiddlemanReturn = Call($sCallback, $arClients[$i], Null, 'Destination', $sPackage)

		; if the call failed
		if @error Then
			__netcode_Addon_Log(1, 24, __netcode_Addon_GetVar($arClients[$i], 'Destination'), $hSocket)
			__netcode_Proxy_DisconnectAndRemoveClients($hSocket, $arClients[$i], False)
			ContinueLoop
		EndIf

		; check return
		If IsArray($vMiddlemanReturn) Then ; if destination is given

			; connect outgoing
			__netcode_Proxy_ConnectOutgoing($hSocket, $arClients[$i], $vMiddlemanReturn, __netcode_Addon_GetVar($arClients[$i], 'Destination'))

			; remove from incoming pending list
			__netcode_Addon_RemoveFromSocketList($hSocket & '_IncomingPending', $arClients[$i])

		ElseIf $vMiddlemanReturn = False Then ; if the middleman says to disconnect

			__netcode_Proxy_DisconnectAndRemoveClients($hSocket, $arClients[$i], False)

		ElseIf $vMiddlemanReturn = Null Then ; if no destination is known yet

			; check destination timeout
			; ~ todo

;~ 			__netcode_Addon_Log(1, 26, $arClients[$i])

		Else ; invalid return

			; log to console
			__netcode_Addon_Log(1, 25, __netcode_Addon_GetVar($arClients[$i], 'Destination'), $hSocket)

			__netcode_Proxy_DisconnectAndRemoveClients($hSocket, $arClients[$i], False)

		EndIf

	Next
EndFunc

Func __netcode_Proxy_ConnectOutgoing(Const $hSocket, $hIncomingSocket, $arDestination, $sID)

	; $arDestination
	; [0] = IP
	; [1] = Port
	; [2] = Send to outgoing (needs to be of type string)
	; [3] = Send to incoming (needs to be of type string)
	; [4] = True / False (True = Send when outgoing is connected, False = Send imidiatly)

	Local $nArSize = UBound($arDestination)

	; if the array size is to small
	if $nArSize < 2 Then

		; log
		__netcode_Addon_Log(1, 30, $sID, $hSocket)

		; then remove
		__netcode_Proxy_DisconnectAndRemoveClients($hSocket, $hIncomingSocket)
		Return
	EndIf

	Local $hOutgoingSocket = __netcode_TCPConnect($arDestination[0], $arDestination[1], 2, True)

	__netcode_Addon_Log(1, 32, $arDestination[0] & ':' & $arDestination[1])

	; add to outgoing pending list
	__netcode_Addon_AddToSocketList($hSocket & '_OutgoingPending', $hOutgoingSocket)

	; inheit between and disconnect middleman ids from incoming socket
	__netcode_Addon_SetVar($hOutgoingSocket, 'Between', __netcode_Addon_GetVar($hOutgoingSocket, 'Between'))
	__netcode_Addon_SetVar($hOutgoingSocket, 'Disconnect', __netcode_Addon_GetVar($hOutgoingSocket, 'Disconnect'))

	; if there are more elements
	If $nArSize > 2 Then

		; check the "Send to outgoing" element
		If $arDestination[2] <> "" Then __netcode_Addon_SetVar($hOutgoingSocket, 'MiddlemanSend', $arDestination[2])

		; check the "Send to incoming" element
		if $nArSize > 3 Then

			; if there is some but the "True / False" is not set then
			If $nArSize < 5 Then

				; disconnect and log
				__netcode_Addon_Log(1, 31, $sID)

				__netcode_Proxy_DisconnectAndRemoveClients($hSocket, $hIncomingSocket, $hOutgoingSocket)
				Return

				; why? because the proxy cannot assume when the dev ment to send the data.
				; so instead of hoping for the best and maybe breaking the script, just disconnect and log it as a fatal to the console.

			EndIf

			; check the toggle
			if $arDestination[4] Then
				__netcode_Addon_SetVar($hIncomingSocket, 'MiddlemanSend', $arDestination[3])
			Else
				__netcode_TCPSend($hIncomingSocket, StringToBinary($arDestination[3]))
			EndIf

		EndIf
	EndIf

	; link sockets together
	__netcode_Addon_SetVar($hIncomingSocket, 'Link', $hOutgoingSocket)
	__netcode_Addon_SetVar($hOutgoingSocket, 'Link', $hIncomingSocket)

EndFunc


Func __netcode_Proxy_CheckOutgoingPending(Const $hSocket)

	Local $arClients = __netcode_Addon_GetSocketList($hSocket & '_OutgoingPending')
	Local $nArSize = UBound($arClients)

	If $nArSize = 0 Then Return

	; select for Write
	$arClients = __netcode_SocketSelect($arClients, False)
	$nArSize = UBound($arClients)

	; if some outgoing connections are connected
	If $nArSize > 0 Then

		Local $hIncomingSocket = 0
		Local $sData = ""

		For $i = 0 To $nArSize - 1

			; get incoming socket
			$hIncomingSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

			; remove from outgoing pending list
			__netcode_Addon_RemoveFromSocketList($hSocket & '_OutgoingPending', $arClients[$i])

			; add both sockets to the final list
			__netcode_Addon_AddToSocketList($hSocket, $arClients[$i])
			__netcode_Addon_AddToSocketList($hSocket, $hIncomingSocket)

			; check if there is data to send to the outgoing
			$sData = __netcode_Addon_GetVar($arClients[$i], 'MiddlemanSend')
			if $sData Then __netcode_TCPSend($arClients[$i], StringToBinary($sData), False)

			; check if there is data to send to the incoming
			$sData = __netcode_Addon_GetVar($hIncomingSocket, 'MiddlemanSend')
			if $sData Then __netcode_TCPSend($hIncomingSocket, StringToBinary($sData), False)

			__netcode_Addon_Log(1, 33, $hIncomingSocket, $arClients[$i])

		Next

	EndIf

	; reread the outgoing pending socket list
	$arClients = __netcode_Addon_GetSocketList($hSocket & '_OutgoingPending')
	$nArSize = UBound($arClients)

	if $nArSize = 0 Then Return

	; check for connect timeouts
	For $i = 0 To $nArSize - 1

		; check timeout
		; ~ todo

;~ 		__netcode_Addon_Log(1, 34, $arClients[$i])

	Next

EndFunc

Func __netcode_Proxy_RecvAndSend(Const $hSocket)

	; get sockets
	Local $arClients = __netcode_Addon_GetSocketList($hSocket)
	if UBound($arClients) = 0 Then Return

	; select these that have something received or that are disconnected
	$arClients = __netcode_SocketSelect($arClients, True)
	Local $nArSize = UBound($arClients)
	if $nArSize = 0 Then Return

	; get the linked sockets
	Local $arSockets[$nArSize]
	For $i = 0 To $nArSize - 1
		$arSockets[$i] = __netcode_Addon_GetVar($arClients[$i], 'Link')
	Next

	; filter the linked sockets, for those that are send ready
	$arClients = __netcode_SocketSelect($arSockets, False)
	Local $nArSize = UBound($arClients)

	if $nArSize = 0 Then Return

	Local $sData = ""
	Local $hLinkSocket = 0
	Local $nLen = 0
	Local $sCallback = ""

	; recv and send
	For $i = 0 To $nArSize - 1

		; get the socket that had something to be received
		$hLinkSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

		; get the recv buffer
		$sData = __netcode_Addon_RecvPackages($hLinkSocket)

		; check if we disconnected
		if @error Then
			__netcode_Proxy_DisconnectAndRemoveClients($hSocket, $hLinkSocket, $arClients[$i])
			ContinueLoop
		EndIf

		$nLen = @extended
		If $nLen Then

			; get middleman callback
			$sCallback = __netcode_Addon_GetVar(__netcode_Addon_GetVar($hLinkSocket, 'Between'), 'Callback')
			If $sCallback Then
				$sData = Call($sCallback, $hLinkSocket, $sData)

				; if either the call failed or if the middleman sais it doesnt want to forward the packet
				if @error Then
					__netcode_Addon_Log(1, 36, $hLinkSocket, $arClients[$i], __netcode_Addon_GetVar($hLinkSocket, 'Between'))
					ContinueLoop
				EndIf

				$nLen = @extended
			EndIf

			; send the data non blocking
			__netcode_TCPSend($arClients[$i], StringToBinary($sData), False)

			__netcode_Addon_Log(1, 35, $hLinkSocket, $arClients[$i], $nLen)

		EndIf

	Next

EndFunc




; could maybe be a shared func
Func __netcode_Proxy_DisconnectAndRemoveClients(Const $hSocket, $hIncomingSocket, $hOutgoingSocket = False)

	__netcode_Addon_Log(1, 99, $hIncomingSocket)
	if $hOutgoingSocket Then __netcode_Addon_Log(1, 99, $hOutgoingSocket)

	; disconnect
	__netcode_TCPCloseSocket($hIncomingSocket)
	if $hOutgoingSocket Then __netcode_TCPCloseSocket($hOutgoingSocket)

	; remove from lists
	__netcode_Addon_RemoveFromSocketList($hSocket & '_IncomingPending', $hIncomingSocket)
	If $hOutgoingSocket Then __netcode_Addon_RemoveFromSocketList($hSocket & '_OutgoingPending', $hOutgoingSocket)

	__netcode_Addon_RemoveFromSocketList($hSocket, $hIncomingSocket)
	If $hOutgoingSocket Then __netcode_Addon_RemoveFromSocketList($hSocket, $hOutgoingSocket)

	; tidy vars of the sockets
	_storageS_TidyGroupVars($hIncomingSocket)
	If $hOutgoingSocket Then _storageS_TidyGroupVars($hOutgoingSocket)

EndFunc

; $arDestination
; [0] = IP
; [1] = Port
; [2] = Send to outgoing (needs to be of type string)
; [3] = Send to incoming (needs to be of type string)
; [4] = True / False (True = Send when outgoing is connected, False = Send imidiatly)
Func __netcode_Proxy_Http_DestinationMiddleman($hIncomingSocket, $hOutgoingSocket, $sPosition, $sPackages)

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

	; uncomment if you want to log every URL. Its for Debug. Doesnt work on the MultiProxy example.
;~ 	__netcode_ProxyURLToIPAndPort_Debug($sURL, $sURLFormatted, $arIPAndPort[0], $arIPAndPort[1])

	Return $arIPAndPort
EndFunc