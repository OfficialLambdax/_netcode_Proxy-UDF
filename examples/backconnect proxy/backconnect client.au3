#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\_netcode_Proxy.au3"

; startup _netcode and the proxy udf
_netcode_Proxy_Startup()
$__net_bTraceEnable = False

; set default events
_netcode_PresetEvent('connection', "_Event_Void")
_netcode_PresetEvent('disconnected', "_Event_Void")

; connect to proxy server
Local $hMyClient = _netcode_TCPConnect('127.0.0.1', 1225)
If Not $hMyClient Then Exit MsgBox(16, "Client Error", "Could not connect to Proxy Server")

; give it socket specific events
_netcode_SetEvent($hMyClient, 'ConnectBack', "_Event_ConnectBack")

; tell the server that we are the proxy client
_netcode_TCPSend($hMyClient, 'IsProxyClient')

; start the proxy parent
Global $__hProxyParent = _netcode_Proxy_CreateHttpProxy('127.0.0.1', 1226)
If Not $__hProxyParent Then Exit

; main
While _netcode_Loop("000")
	_netcode_Proxy_Loop($__hProxyParent)
	Sleep(10)
WEnd



; the server will request that we connect a new socket
Func _Event_ConnectBack($hSocket, $sID)

	; connect to the proxy server non blocking
	Local $hConnectBackSocket = _netcode_TCPConnect('127.0.0.1', 1225, False, "", "", True)

	; give it a socket specifc event
	_netcode_SetEvent($hConnectBackSocket, 'connection', "_Event_Connection")

	; quo data to be send once the 'netcode' stage is reached
	_netcode_TCPSend($hConnectBackSocket, 'ConnectedBack', $sID)

EndFunc

; the data quo is triggered before the 'netcode' stage is called.
; so we force the sending and then release the socket and add it to the proxy
Func _Event_Connection($hSocket, $sStage)
	If $sStage <> 'netcode' Then Return

	; force sending
	__netcode_SendPacketQuo()

	; release socket from _netcode
	_netcode_ReleaseSocket($hSocket)

	; add to proxy as incoming socket
	__netcode_Addon_NewIncomingMiddleman($__hProxyParent, $hSocket, 1)

EndFunc

; data that goes here is voided
Func _Event_Void($Void, $Void1 = Null, $Void2 = Null)
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