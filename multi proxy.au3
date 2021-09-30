#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#cs
	This example is easy.
	The script starts up a set amount of processes with the cmdline "proxy" and a port
	which in return opens the proxy for the new process on the given port.

	If you set 4 proxies with the port incrementing from 1226 then
	the first connection will goto the 1226 port
	the second connection to the 1227 port
	the third to 1228
	the fourth to 1229
	the fifth to 1226
	...

	So the relay basically just forwards each incomming connection to a different process.

	Why is a multi proxy usefull? Because in its current state neither the relay nor
	the proxy uses fully non blocking sockets, or to say make full use of them.
	So each attempt to connect or send will freeze the process until the DllCall is finished.
	So a server not or slowly responding will create lag. If we split the incoming traffic,
	we basically can connect and send from each process and therefore reduce lag.

	Setup _
	1. start the script
	2. "Define the incoming port"
	3. "How many Proxy processes do you wanna run"
	4. "Define the Port from which the Proxies will increment on"
	5. Open your proxy settings. system / browser with or without addon (e.g. FoxyProxy)
	6. In case of using a addon you need to use the HTTP proxy type not HTTPS or socks. (socks is not implemented yet)
	7. Then Specify the Ip the multi proxy is running on and set the port used in 2.
	you can set HTTP-Proxy and HTTPS-Proxy. The proxy supports both.

	notes
		- you can also route your traffic directly into one or all of the proxies without
		using the relay in between. It will work. Is there a speed benefit? very little to none.

		- (WARNING) be aware that the proxy does allow to connect to your local network.
		So if you opened a port for the relay / or proxy to the internet and
		someone from the outside wants to scan your local network, then he can do that.
		Lets say you have some form of gaming server running in your network, just for you
		and your buddies and the port isnt open to the internet. Since the relay / proxy is open
		and there isnt any not goto blacklist an attacker could find that gaming server through the proxy and connect.
		So for security reasons you need to specify a black list for the local network otherwise
		you just opened a major security vulnerability.
		You could also use Socks4/5 to protect your network with a username and password
		once implemented.

		- if you compiled the multi proxy, run it and then close the relay either by taskmgr or by clicking X then
		all proxy processes will also close. The relay doesnt ProcessClose() them, thats because of Run().
		So if you start up the multi proxy from Scite and then close the relay by for example pressing
		CTRL+Break then the proxy processes will not close. (_WinAPI_GetParentProcess() could fix that)

	issues
		Neither the relay nor the proxie is yet fully developed. Because of that certain issues still
		exists.

		- If you connect to speedtest.net and run a test then you will notice that the upload test will be
		wonky or sometimes not work. Uploading stuff to other plattforms will work nice however. I couldnt
		yet determine the problem.

		- in rare cases sockets seem to get disconnected even tho they shouldnt. I experimented with
		downloading huge files from the internet and they randomly abborted. Restarting the multi proxy
		did fix it. However i couldnt find the issue yet.

		- if a proxy process gets closed, crashes or does not respond then the relay will assume its dead.
		If so then the relay will Exit() and also show a Error MsgBox()

#ce



#include "..\..\_netcode_Relay.au3"
#include "..\..\_netcode_Proxy.au3"

if $cmdline[0] <> 0 Then
	if $cmdline[0] < 2 Then Exit MsgBox(0, "", "What")

	Switch $cmdline[1]

		Case "proxy"
			_Proxy(Number($cmdline[2]))

	EndSwitch

	Exit
EndIf

Local $nRelayPort = InputBox('', 'Define the incoming port', '8080')
if @error Then Exit
$nRelayPort = Number($nRelayPort)

Local $nProxyAmount = InputBox('', 'How many Proxy processes do you wanna run?', '2')
if @error Then Exit
$nProxyAmount = Number($nProxyAmount)

Local $nPortGoFrom = InputBox('', 'Define the Port from which the Proxies will increment on', '1226')
if @error Then Exit
$nPortGoFrom = Number($nPortGoFrom)

Global $__arProxies[$nProxyAmount][2]
Global $__nIndex = 0

For $i = 0 To $nProxyAmount - 1
	$__arProxies[$i][0] = "127.0.0.1"
	$__arProxies[$i][1] = $nPortGoFrom + $i
	Run(@ComSpec & ' /C ' & '"' & @ScriptFullPath & '" proxy ' & $nPortGoFrom + $i)
Next

_netcode_SetupTCPRelay('0.0.0.0', $nRelayPort, Null, Null)
_RelayLoop(True)


Func _Proxy(Const $nPort)
	_netcode_ProxySetConsoleLogging(True)
	Local $hProxySocket = _netcode_SetupTCPProxy('0.0.0.0', $nPort)
	_netcode_ProxySetHttpProxy($hProxySocket)
	_netcode_ProxyLoop(True)
EndFunc

; =================================================================================
; _RelayLoop() and __RelayTCPLoop() are actually _netcode_RelayLoop() and __netcode_RelayTCPLoop()
; but modified a little to to split incoming traffic to the proxy processes.

Func _RelayLoop($bLoopForever = False)
	Local $nTCPArSize = UBound($__net_relay_arTCPSockets)
	Local $nUDPArSize = UBound($__net_relay_arUDPSockets)
	Local $nSendBytes = 0

	Do
		$nSendBytes = 0
		For $i = 0 To $nTCPArSize - 1
			$nSendBytes += __RelayTCPLoop($__net_relay_arTCPSockets[$i])

			; ~ todo relay UDP
		Next

		if $nSendBytes = 0 Then Sleep(10)
	Until Not $bLoopForever
EndFunc

Func __RelayTCPLoop($hRelaySocket)

	Local $arClients = _storageS_Read($hRelaySocket, '_netcode_relay_Clients')

	Local $hSocket = __netcode_TCPAccept($hRelaySocket)
	if $hSocket <> -1 Then

		if __netcode_CheckRelayIPList($hRelaySocket, $hSocket) Then

			; ====================================================
			Local $sRelayToIP = $__arProxies[$__nIndex][0]
			Local $sRelayToPort = $__arProxies[$__nIndex][1]
			$__nIndex += 1
			if $__nIndex = UBound($__arProxies) Then $__nIndex = 0
			; ====================================================

			Local $hSocketTo = __netcode_TCPConnect($sRelayToIP, $sRelayToPort)
			if $hSocketTo <> -1 Then
				__netcode_AddTCPRelayClient($hRelaySocket, $arClients, $hSocket, $hSocketTo)

			Else
				__netcode_TCPCloseSocket($hSocket)
				__netcode_RelayDebug($hRelaySocket, 2, $hSocket)
				; ====================================================
				Exit MsgBox(16, "Relay Error", "A Proxy Process seems to be dead." & @CRLF & @CRLF & $sRelayToIP & ':' & $sRelayToPort & @CRLF & "Exiting now.")
				; ====================================================

			EndIf

		Else
			__netcode_TCPCloseSocket($hSocket)

		EndIf
	EndIf

	Local $nArSize = UBound($arClients)
	Local $nSendBytes = 0

	For $i = 0 To $nArSize - 1
		; read from incomming and send to outgoing
		If Not __netcode_RelayRecvAndSend($arClients[$i][0], $arClients[$i][1]) Then
			__netcode_RemoveTCPRelayClient($hRelaySocket, $arClients, $i)
			ContinueLoop

		Else
			$nBytes = @extended
			$nSendBytes += $nBytes

		EndIf

		; read from outgoing and send to incomming
		if Not __netcode_RelayRecvAndSend($arClients[$i][1], $arClients[$i][0]) Then
			__netcode_RemoveTCPRelayClient($hRelaySocket, $arClients, $i)
			ContinueLoop

		Else
			$nBytes = @extended
			$nSendBytes += $nBytes

		EndIf
	Next

	Return $nSendBytes
EndFunc