#include-once
#include "_netcode_Core.au3"

#cs
	Todo

		- UDP (?)

		- Man in the Middle for disconnect and between data

		- Check Incomming and outgoing

		- Reduce CPU usage
			Same issue as with the Relay

		- TCPConnect should not hang up the Proxy


	Bugs

		Mayor - not yet found issue that makes websites to render, in rare cases, in wonky ways


	Notes
		- Comparing the speed of loading a website between using the proxy and not using it will
		show that the proxy is actually nearly as fast as connecting directly. The difference is just a few ms.

		- A test tunneling all devices from a home network through the proxy showed that
		the proxy can easiely handle them all. Netflix, youtube, a speedtest etc. where working fine.

#ce

Global $__net_proxy_arTCPSockets[0]
Global $__net_proxy_arUDPSockets[0]

Func _netcode_SetupTCPProxy($sProxyIP, $sProxyPort)
	__netcode_Init()
	Local $hProxySocket = _netcode_TCPListen($sProxyPort, $sProxyIP, Default, 200, True)
	if $hProxySocket = False Then Return SetError(1)

	__netcode_AddTCPProxySocket($hProxySocket)

	Return $hProxySocket
EndFunc

Func _netcode_StopTCPProxy($hProxySocket)
	If Not __netcode_RemoveTCPProxySocket($hProxySocket) Then Return SetError(@error)
	__netcode_TCPCloseSocket($hProxySocket)
	Return True
EndFunc

#cs
	$nWhere
		1 = on connection
		2 = on disconnect
		3 = between a data send
#ce
Func _netcode_ProxySetMiddleman($hProxySocket, $nWhere, $sCallback)
	Switch $nWhere
		Case 1
			_storageS_Overwrite($hProxySocket, '_netcode_proxy_OnConnection', $sCallback)

		Case 2
			_storageS_Overwrite($hProxySocket, '_netcode_proxy_OnDisconnect', $sCallback)

		Case 3
			_storageS_Overwrite($hProxySocket, '_netcode_proxy_BetweenData', $sCallback)


	EndSwitch
EndFunc

Func _netcode_ProxySetIPList($hProxySocket, $vIPList, $bIPListForIncomming, $bIPListIsWhitelist)

EndFunc

Func _netcode_ProxySetHttpProxy($hProxySocket)
	_netcode_ProxySetMiddleman($hProxySocket, 1, '__netcode_ProxyHttpOnConnection')
EndFunc

Func _netcode_ProxyLoop($bLoopForever = False)
	Local $nTCPArSize = UBound($__net_proxy_arTCPSockets)
	Local $nUDPArSize = UBound($__net_proxy_arUDPSockets)
	Local $nSendBytes = 0

	Do
		$nSendBytes = 0
		For $i = 0 To $nTCPArSize - 1
			$nSendBytes += __netcode_ProxyTCPLoop($__net_proxy_arTCPSockets[$i])

			; ~ todo relay UDP
		Next

		if $nSendBytes = 0 Then Sleep(10)
	Until Not $bLoopForever
EndFunc




Func __netcode_AddTCPProxySocket($hProxySocket)
	Local $arClients[0][2]
	_storageS_Overwrite($hProxySocket, '_netcode_proxy_Clients', $arClients)
	_storageS_Overwrite($hProxySocket, '_netcode_proxy_ClientsOnHold', $arClients)

	Local $nArSize = UBound($__net_proxy_arTCPSockets)

	ReDim $__net_proxy_arTCPSockets[$nArSize + 1]
	$__net_proxy_arTCPSockets[$nArSize] = $hProxySocket
EndFunc

Func __netcode_RemoveTCPProxySocket($hProxySocket)
	Local $nArSize = UBound($__net_proxy_arTCPSockets)

	Local $nIndex = -1
	For $i = 0 To $nArSize - 1
		if $__net_proxy_arTCPSockets[$i] = $hProxySocket Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next
	if $nIndex = -1 Then Return SetError(1) ; this isnt a proxy socket

	_storageS_TidyGroupVars($hProxySocket)

	$__net_proxy_arTCPSockets[$nIndex] = $__net_proxy_arTCPSockets[$nArSize - 1]
	ReDim $__net_proxy_arTCPSockets[$nArSize - 1]

	Return True
EndFunc

Func __netcode_ProxyHttpOnConnection($hSocket, $nWhere)
	Local $sPackage = __netcode_ProxyRecvPackages($hSocket)
	if @error Then Return False
	if $sPackage = '' Then Return Null

	Local $arPackage = StringSplit($sPackage, @CRLF, 1 + 2)

	if StringLeft($arPackage[0], 3) = "GET" Then
		$sIP = StringTrimLeft($arPackage[0], 4)
		$sIP = StringLeft($sIP, StringInStr($sIP, ' '))

		$arIPAndPort = __netcode_ProxyURLToIPAndPort($sIP, 80)
		ReDim $arIPAndPort[3]
		$arIPAndPort[2] = $sPackage

	ElseIf StringLeft($arPackage[0], 4) = "POST" Then
		$sIP = StringTrimLeft($arPackage[0], 5)
		$sIP = StringLeft($sIP, StringInStr($sIP, ' '))

		$arIPAndPort = __netcode_ProxyURLToIPAndPort($sIP, 80)
		ReDim $arIPAndPort[3]
		$arIPAndPort[2] = $sPackage

	ElseIf StringLeft($arPackage[0], 7) = "CONNECT" Then
		$sIPAndPort = StringTrimLeft($arPackage[0], 8)
		$sIPAndPort = StringLeft($sIPAndPort, StringInStr($sIPAndPort, ' '))

		$arIPAndPort = __netcode_ProxyURLToIPAndPort($sIPAndPort)

;~ 		__netcode_TCPSend($hSocket, StringToBinary($sPackage))
		__netcode_TCPSend($hSocket, StringToBinary("HTTP/1.1 200 Connection Established" & @CRLF & @CRLF))

;~ 		ReDim $arIPAndPort[3]
;~ 		$arIPAndPort[2] = $sPackage

	Else

		Return False
	EndIf

	if $arIPAndPort[0] = "" Then
;~ 		_ArrayDisplay($arPackage)
		Return False
	EndIf
	Return $arIPAndPort
EndFunc

;~ TCPStartup()
;~ __netcode_ProxyURLToIPAndPort("http://ocsp.sca1b.amazontrust.com/", 80)

Func __netcode_ProxyURLToIPAndPort(Const $sURL, $nForcePort = 0, $bForcePortIsOptional = True)
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
	; Log will be written to @ScriptDir & "\debuglog.txt"
;~ 	__netcode_ProxyURLToIPAndPort_Debug($sURL, $sURLFormatted, $arIPAndPort[0], $arIPAndPort[1])

	Return $arIPAndPort
EndFunc

Func __netcode_ProxyURLToIPAndPort_Debug($sURL, $sURLFormatted, $sIP, $sPort)
	Local Static $hOpen = 0
	If $hOpen = 0 Then $hOpen = FileOpen(@ScriptDir & "\debuglog.txt", 2)

	FileWrite($hOpen, @HOUR & ':' & @MIN & ':' & @SEC & '.' & @MSEC & @TAB & @TAB _
			& $sIP & ':' & $sPort & @TAB & @TAB & '<-' & @TAB _
			& $sURLFormatted & @TAB & '<-' & @TAB _
			& $sURL & @CRLF)
EndFunc

Func __netcode_CheckProxyIPList($hProxySocket, $hSocket)
	; ~ todo
	Return True
EndFunc

Func __netcode_CheckProxyMiddleman($hProxySocket, $nWhere, $hSocket)
;~ 	ConsoleWrite($hSocket & @CRLF)
	Switch $nWhere
		Case 1
			Local $sCallback = _storageS_Read($hProxySocket, '_netcode_proxy_OnConnection')
			if $sCallback Then Return Call($sCallback, $hSocket, $nWhere)

		Case 2
			Local $sCallback = _storageS_Read($hProxySocket, '_netcode_proxy_OnDisconnect')
			if $sCallback Then Return Call($sCallback, $hSocket, $nWhere)

		Case 3
			Local $sCallback = _storageS_Read($hProxySocket, '_netcode_proxy_BetweenData')
			if $sCallback Then Return Call($sCallback, $hSocket, $nWhere)

	EndSwitch
EndFunc

Func __netcode_AddTCPProxyClient($hProxySocket, $arClients, $hSocket, $hSocketTo)
	Local $nArSize = UBound($arClients)

	ReDim $arClients[$nArSize + 1][2]
	$arClients[$nArSize][0] = $hSocket
	$arClients[$nArSize][1] = $hSocketTo

	_storageS_Overwrite($hProxySocket, '_netcode_proxy_Clients', $arClients)
EndFunc

Func __netcode_RemoveTCPProxyClient($hProxySocket, $arClients, $nIndex)
	Local $nArSize = UBound($arClients)

	__netcode_TCPCloseSocket($arClients[$nIndex][0])
	__netcode_TCPCloseSocket($arClients[$nIndex][1])

	$arClients[$nIndex][0] = $arClients[$nArSize - 1][0]
	$arClients[$nIndex][1] = $arClients[$nArSize - 1][1]
	ReDim $arClients[$nArSize - 1][2]

	_storageS_Overwrite($hProxySocket, '_netcode_proxy_Clients', $arClients)
EndFunc

Func __netcode_AddTCPProxyClientOnHold($hProxySocket, $hSocket)
	Local $arClients = _storageS_Read($hProxySocket, '_netcode_proxy_ClientsOnHold')
	Local $nArSize = UBound($arClients)

	ReDim $arClients[$nArSize + 1][2]
	$arClients[$nArSize][0] = $hSocket
	$arClients[$nArSize][1] = TimerInit()

	_storageS_Overwrite($hProxySocket, '_netcode_proxy_ClientsOnHold', $arClients)
EndFunc

Func __netcode_RemoveTCPProxyClientOnHold($hProxySocket, $hSocket)
	Local $arClients = _storageS_Read($hProxySocket, '_netcode_proxy_ClientsOnHold')
	Local $nArSize = UBound($arClients)

	Local $nIndex = -1
	For $i = 0 To $nArSize - 1
		if $arClients[$i][0] = $hSocket Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next

	$arClients[$nIndex][0] = $arClients[$nArSize - 1][0]
	$arClients[$nIndex][1] = $arClients[$nArSize - 1][1]
	ReDim $arClients[$nArSize - 1][2]

	_storageS_Overwrite($hProxySocket, '_netcode_proxy_ClientsOnHold', $arClients)
;~ 	ConsoleWrite($hSocket & @CRLF)
EndFunc

Func __netcode_ProxyTCPLoop($hProxySocket)

	Local $arClientsOnHold = _storageS_Read($hProxySocket, '_netcode_proxy_ClientsOnHold')
	Local $arClients = _storageS_Read($hProxySocket, '_netcode_proxy_Clients')
;~ 	Local Static $hClientTimer = TimerInit()

	For $i = 0 To UBound($arClientsOnHold) - 1
		$arMiddleman = __netcode_CheckProxyMiddleman($hProxySocket, 1, $arClientsOnHold[$i][0])
		If IsArray($arMiddleman) Then ; if IP and Port
			; check outgoing ip here

			$hSocketTo = __netcode_TCPConnect($arMiddleman[0], $arMiddleman[1])
;~ 			$hSocketTo = TCPConnect($arMiddleman[0], $arMiddleman[1])
			if Not @error Then
				__netcode_AddTCPProxyClient($hProxySocket, $arClients, $arClientsOnHold[$i][0], $hSocketTo)
				__netcode_RemoveTCPProxyClientOnHold($hProxySocket, $arClientsOnHold[$i][0])

				if UBound($arMiddleman) = 3 Then __netcode_TCPSend($hSocketTo, StringToBinary($arMiddleman[2]))

				__netcode_ProxyDebug($hProxySocket, 3, $arClientsOnHold[$i][0], $hSocketTo, $arMiddleman[0] & ':' & $arMiddleman[1])

			Else
;~ 				ConsoleWrite
				__netcode_RemoveTCPProxyClientOnHold($hProxySocket, $arClientsOnHold[$i][0])
				__netcode_TCPCloseSocket($arClientsOnHold[$i][0])
				__netcode_ProxyDebug($hProxySocket, 2, $arMiddleman[0], $arMiddleman[1])

			EndIf

		ElseIf $arMiddleman = Null Then ; if we still want to wait
			if TimerDiff($arClientsOnHold[$i][1]) > 2000 Then
				__netcode_RemoveTCPProxyClientOnHold($hProxySocket, $arClientsOnHold[$i][0])
				__netcode_TCPCloseSocket($arClientsOnHold[$i][0])
				__netcode_ProxyDebug($hProxySocket, 9, $arClientsOnHold[$i][0])
			EndIf
			ContinueLoop

		Elseif $arMiddleman = False Then ; if proxy denies
			__netcode_RemoveTCPProxyClientOnHold($hProxySocket, $arClientsOnHold[$i][0])
			__netcode_TCPCloseSocket($arClientsOnHold[$i][0])
			__netcode_ProxyDebug($hProxySocket, 8, $arClientsOnHold[$i][0])
		EndIf
	Next

	Local $hSocket = __netcode_TCPAccept($hProxySocket)
	if $hSocket <> -1 Then
		__netcode_ProxyDebug($hProxySocket, 1, $hSocket)

		if __netcode_CheckProxyIPList($hProxySocket, $hSocket) Then
			__netcode_AddTCPProxyClientOnHold($hProxySocket, $hSocket)

		Else
			__netcode_TCPCloseSocket($hSocket)
			__netcode_ProxyDebug($hProxySocket, 6, $hSocket)

		EndIf
	EndIf

	Local $nArSize = UBound($arClients)
	Local $nSendBytes = 0

	For $i = 0 To $nArSize - 1
		; read from incomming and send to outgoing
		If Not __netcode_ProxyRecvAndSend($arClients[$i][0], $arClients[$i][1]) Then
			__netcode_RemoveTCPProxyClient($hProxySocket, $arClients, $i)
			__netcode_ProxyDebug($hProxySocket, 4, $arClients[$i][0], $arClients[$i][1])
			ContinueLoop

		Else
			$nBytes = @extended
			$nSendBytes += $nBytes
			if $nBytes > 0 Then __netcode_ProxyDebug($hProxySocket, 5, $arClients[$i][0], $arClients[$i][1], $nBytes)

		EndIf

		; read from outgoing and send to incomming
		if Not __netcode_ProxyRecvAndSend($arClients[$i][1], $arClients[$i][0]) Then
			__netcode_RemoveTCPProxyClient($hProxySocket, $arClients, $i)
			__netcode_ProxyDebug($hProxySocket, 4, $arClients[$i][1], $arClients[$i][0])
			ContinueLoop

		Else
			$nBytes = @extended
			$nSendBytes += $nBytes
			if $nBytes > 0 Then __netcode_ProxyDebug($hProxySocket, 5, $arClients[$i][1], $arClients[$i][0], $nBytes)

		EndIf
	Next

;~ 	If TimerDiff($hClientTimer) > 1000 Then
;~ 		__netcode_ProxyDebug($hProxySocket, 10, UBound($arClients), UBound($arClientsOnHold))
;~ 		$hClientTimer = TimerInit()
;~ 	EndIf

	Return $nSendBytes

EndFunc

Func __netcode_ProxyRecvAndSend($hSocket, $hSocketTo)
;~ 	Local $sPackages = __netcode_ProxyRecvPackages($hSocket)
	Local $sPackages = __netcode_RecvPackages($hSocket)
	if @error Then Return False
;~ 	ConsoleWrite($hSocket & @TAB & $sPackages & @CRLF)
	if $sPackages = '' Then Return True

	Local $nBytes = __netcode_TCPSend($hSocketTo, StringToBinary($sPackages))
	$nError = @error
;~ 	if $nError Then MsgBox(0, "", $nError)
	if $nError Then Return False

	Return SetError(0, $nBytes, True)
EndFunc

Func __netcode_ProxyRecvPackages(Const $hSocket)
	Local $sPackages = ''
	Local $sTCPRecv = ''
	Local $hTimer = TimerInit()

	Do

		$sTCPRecv = __netcode_TCPRecv($hSocket)
		if @extended = 1 Then
			if $sPackages <> '' Then ExitLoop ; in case the client send something and then closed his socket instantly.
			Return SetError(1, 0, False)
		EndIf

		$sPackages &= BinaryToString($sTCPRecv)
		; todo ~ check size and if it exceeds the max Recv Buffer Size
		; if then just Exitloop instead of discarding it

		if TimerDiff($hTimer) > 20 Then ExitLoop

	Until $sTCPRecv = ''

	Return $sPackages
EndFunc

#cs
	$nInformation
	1 = new connection
	2 = Couldnt connect
	3 = bind to
	4 = disconnected
	5 = send bytes
	6 = incoming is blocked
;~ 	7 = Proxy Destination
	8 = Middleman denied
	9 = Timeout
	10 = Clients

#ce
Func __netcode_ProxyDebug($hProxySocket, $nInformation, $Element0, $Element1 = "", $Element2 = "")
;~ 	if $nInformation <> 10 Then Return

	Switch $nInformation
		Case 1
			__netcode_Debug("Proxy @ " & $hProxySocket & " New Incomming Connection @ " & $Element0)

		Case 2
			__netcode_Debug("Proxy @ " & $hProxySocket & " Couldnt connect to Proxy Destination " & $Element0 & ":" & $Element1)

		Case 3
			__netcode_Debug("Proxy @ " & $hProxySocket & " Bind @ " & $Element0 & " To @ " & $Element1 & " Destination " & $Element2)

		Case 4
			__netcode_Debug("Proxy @ " & $hProxySocket & " Disconnected @ " & $Element0 & " & @ " & $Element1)

		Case 5
			__netcode_Debug("Proxy @ " & $hProxySocket & " Send Data from @ " & $Element0 & " To @ " & $Element1 & " = " & Round($Element2 / 1024, 2) & " KB")

		Case 6
			__netcode_Debug("Proxy @ " & $hProxySocket & " Incomming Connection was blocked @ " & $Element0)

;~ 		Case 7
;~ 			__netcode_Debug("Proxy @ " & $hProxySocket & " Connected @ " & $Element0 & " to " & $Element1)

		Case 8
			__netcode_Debug("Proxy @ " & $hProxySocket & " Middleman denies @ " & $Element0 & " destination")

		Case 9
			__netcode_Debug("Proxy @ " & $hProxySocket & " Socket @ " & $Element0 & " timeouted")

		Case 10
			__netcode_Debug("Proxy @ " & $hProxySocket & " Has " & $Element0 & " Clients and Waits for " & $Element1)

	EndSwitch


EndFunc