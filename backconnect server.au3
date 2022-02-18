#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\_netcode_Proxy.au3"

; the proxy accept client goes here
Global $__hProxyAcceptClient = False

; startup _netcode and the proxy udf
_netcode_Proxy_Startup()
$__net_bTraceEnable = False

; start proxy client parent
Local $hMyProxyClientParent = _netcode_TCPListen(1225, '0.0.0.0')
If Not $hMyProxyClientParent Then Exit MsgBox(16, "Server Error", "Could not start proxy client parent")

; give it socket specific events
_netcode_SetEvent($hMyProxyClientParent, 'IsProxyClient', "_Event_IsProxyClient")
_netcode_SetEvent($hMyProxyClientParent, 'ConnectedBack', "_Event_ConnectedBack")
_netcode_SetEvent($hMyProxyClientParent, 'connection', "_Event_Void")
_netcode_SetEvent($hMyProxyClientParent, 'disconnected', "_Event_Disconnect")

; start the proxy parent
_netcode_Proxy_RegisterMiddleman('relay_proxy', "_RelayProxy_ConAndDestMiddleman", 'Connect')
Global $__hMyRelayProxyParent = _netcode_Proxy_Create('0.0.0.0', 8080, 'relay_proxy', 'relay_proxy')
if Not $__hMyRelayProxyParent Then Exit


; main
While Sleep(10)
	_netcode_Loop($hMyProxyClientParent)
	_netcode_Proxy_Loop($__hMyRelayProxyParent)
WEnd



; connect and destination middleman for the proxy
Func _RelayProxy_ConAndDestMiddleman($hIncomingSocket, $sPosition, $sData)

	; if its the destination position then
	if $sPosition == 'Destination' Then
		; then save the data
		_storageGO_Append($hIncomingSocket, 'DataToOutgoing', $sData)

		; and return Null to let the proxy know that we dont want to disconnect yet
		Return Null
	EndIf

	; if the proxy accept client is not known yet
	if $__hProxyAcceptClient == False Then Return False

	; if a ID is already assigned then return Null
	if __netcode_Addon_GetVar($hIncomingSocket, 'ConnectBack') Then Return Null

	; otherwsie request a connect from the proxy client
	Local $sID = __netcode_RandomPW(5, 3)
	_storageGO_CreateGroup($sID)

	__netcode_Addon_SetVar($hIncomingSocket, 'ID', $sID)
	__netcode_Addon_SetVar($sID, 'ID', $hIncomingSocket)

	_netcode_TCPSend($__hProxyAcceptClient, 'ConnectBack', $sID)

	Return Null
EndFunc



Func _Event_ConnectedBack($hSocket, $sID)

	; get incoming socket
	Local $hIncomingSocket = __netcode_Addon_GetVar($sID, 'ID')
	If Not $hIncomingSocket Then _netcode_TCPDisconnect($hSocket)

	; release socket from _netcode
	_netcode_ReleaseSocket($hSocket)

	; create destination array
	Local $sData = _storageGO_Read($hIncomingSocket, 'DataToOutgoing')
	If Not $sData Then
		Local $arDestination[2] = [$hSocket,""]
	Else
		Local $arDestination[3] = [$hSocket,"",$sData]
	EndIf

	; add socket as outgoing for the incoming
	__netcode_Addon_ConnectOutgoingMiddleman($__hMyRelayProxyParent, $hIncomingSocket, $arDestination, 'relay_proxy', 1)

	; since the incoming is still listed as just a incoming we now remove it from there
	__netcode_Addon_RemoveFromIncomingSocketList($__hMyRelayProxyParent, $hIncomingSocket)

	_storageGO_DestroyGroup($sID)

EndFunc

Func _Event_IsProxyClient($hSocket)
	if $__hProxyAcceptClient Then Return _netcode_TCPDisconnect($hSocket)
	$__hProxyAcceptClient = $hSocket
EndFunc

Func _Event_Disconnect($hSocket, $Void, $Void2)
	if $__hProxyAcceptClient == $hSocket Then $__hProxyAcceptClient = False
EndFunc

; data that goes here is voided
Func _Event_Void($Void, $Void1 = Null, $Void2 = Null)
EndFunc