#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\_netcode_Proxy.au3"
#include <Array.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <GUIListBox.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <GuiListView.au3>
#include <ListViewConstants.au3>
#include <GUIListBox.au3>

; ===============================================================================================================================
; ===============================================================================================================================
; Init

; listview styles
Local $iExWindowStyle = BitOR($WS_EX_DLGMODALFRAME, $WS_EX_CLIENTEDGE)
Local $iExListViewStyle = BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_DOUBLEBUFFER)

; clicking the tray shouldnt pause the script
Opt("TrayAutoPause", 0)

; use gui events
Opt("GuiOnEventMode", 1)

#Region ### START Koda GUI section ###
$Form1 = GUICreate("Proxy Stats", 666, 264, 658, 287)
$Label1 = GUICtrlCreateLabel("(?) Storage Size", 232, 160, 150, 20)
GUICtrlSetTip(-1, "The Amount of existing Storages")
GUICtrlSetFont(-1, 10, 400, 0, "MS Sans Serif")
$Label2 = GUICtrlCreateLabel("(?) Free Storages", 232, 184, 150, 20)
GUICtrlSetTip(-1, "How many of the Storages are free")
GUICtrlSetFont(-1, 10, 400, 0, "MS Sans Serif")
$Label3 = GUICtrlCreateLabel("(?) Used Storages", 232, 208, 150, 20)
GUICtrlSetTip(-1, "How many of the Storages are claimed")
GUICtrlSetFont(-1, 10, 400, 0, "MS Sans Serif")
$Label4 = GUICtrlCreateLabel("(?) Storage Size (bytes)", 232, 232, 150, 20)
GUICtrlSetTip(-1, "How many data in bytes all claimed storages have. Not accurate.")
GUICtrlSetFont(-1, 10, 400, 0, "MS Sans Serif")
$iStorageSize = GUICtrlCreateInput("", 384, 160, 49, 21)
$iFreeStorages = GUICtrlCreateInput("", 384, 184, 49, 21)
$iUsedStorages = GUICtrlCreateInput("", 384, 208, 49, 21)
$iStorageSizeBytes = GUICtrlCreateInput("", 384, 232, 49, 21)
$Label5 = GUICtrlCreateLabel("(?) Incoming Connections", 232, 40, 150, 20)
GUICtrlSetTip(-1, "Connected Clients who havent told the proxy the destination yet")
GUICtrlSetFont(-1, 10, 400, 0, "MS Sans Serif")
$Label6 = GUICtrlCreateLabel("(?) Connected Clients", 232, 88, 150, 20)
GUICtrlSetTip(-1, "All Clients. In and Out")
GUICtrlSetFont(-1, 10, 400, 0, "MS Sans Serif")
$Label7 = GUICtrlCreateLabel("(?) Outgoing Pending", 232, 64, 150, 20)
GUICtrlSetTip(-1, "How many TCPConnect's are currently pending")
GUICtrlSetFont(-1, 10, 400, 0, "MS Sans Serif")
$iIncoming = GUICtrlCreateInput("", 384, 40, 49, 21)
$iOutgoing = GUICtrlCreateInput("", 384, 64, 49, 21)
$iClients = GUICtrlCreateInput("", 384, 88, 49, 21)
$Label8 = GUICtrlCreateLabel("(?) _storageGO Stats", 272, 128, 150, 20)
GUICtrlSetTip(-1, "Reuse Assign/Eval Method defined in _storageS-UDF")
GUICtrlSetFont(-1, 10, 400, 4, "MS Sans Serif")
$Label9 = GUICtrlCreateLabel("Proxy Stats", 296, 8, 71, 20)
GUICtrlSetFont(-1, 10, 400, 4, "MS Sans Serif")
$lVisitedWebsites = _GUICtrlListView_Create($Form1, "", 448, 40, 209, 214, $iExWindowStyle)
$Label10 = GUICtrlCreateLabel("Recently Visited Websites", 472, 8, 161, 20)
GUICtrlSetFont(-1, 10, 400, 4, "MS Sans Serif")
$lIncomingClients = _GUICtrlListView_Create($Form1, "", 8, 40, 209, 214, $iExWindowStyle)
$Label11 = GUICtrlCreateLabel("Recently Incoming Client IP's", 24, 8, 175, 20)
GUICtrlSetFont(-1, 10, 400, 4, "MS Sans Serif")
$bClearLogs = GUICtrlCreateButton("Clear Logs", 232, 112, 203, 17)

; specify list views
_GUICtrlListView_SetExtendedListViewStyle($lVisitedWebsites, $iExListViewStyle)
_GUICtrlListView_AddColumn($lVisitedWebsites, "Website", 160)
_GUICtrlListView_AddColumn($lVisitedWebsites, "N", 40)

_GUICtrlListView_SetExtendedListViewStyle($lIncomingClients, $iExListViewStyle)
_GUICtrlListView_AddColumn($lIncomingClients, "IP", 160)
_GUICtrlListView_AddColumn($lIncomingClients, "N", 40)

; set events
GUISetOnEvent($GUI_EVENT_CLOSE, "_GuiEvent_Exit")
GUICtrlSetOnEvent($bClearLogs, "_GuiEvent_ClearLogs")

GUISetState(@SW_SHOW)
#EndRegion ### END Koda GUI section ###

; create gui group storage
_storageMLx_CreateGroup("Incoming") ; holds the ip's
_storageMLx_CreateGroup("Outgoing") ; holds the site's
_storageGO_CreateGroup("Incoming") ; holds the amounts
_storageGO_CreateGroup("Outgoing") ; holds the amounts

; debug hotkey to see memory leaks
HotKeySet('+!d', "_ShowUnfreeVars")

; startup _netcode proxy
_netcode_Proxy_Startup()
$__net_bTraceEnable = False

; disable logging to console
_netcode_Proxy_SetLogging(False)

; create http proxy at port 8080
Global $__hProxyParent = _netcode_Proxy_CreateHttpProxy("0.0.0.0", 8080)
If Not $__hProxyParent Then Exit MsgBox(16, "Error", "Could not startup Proxy parent. Extended: " & @extended)

; ===============================================================================================================================
; ===============================================================================================================================
; Main

; loop it
Local $hTimer = TimerInit()
While True
	_netcode_Proxy_Loop($__hProxyParent)

	if TimerDiff($hTimer) > 50 Then
		_GUI()
	EndIf

;~ 	Sleep(10)
WEnd

; ===============================================================================================================================
; ===============================================================================================================================
; Gui functions

; updates the gui inputs and lists
Func _GUI()

	Local Static $hTimer = TimerInit()

	; update inputboxes
	GUICtrlSetData($iFreeStorages, _storageGO_GetInfo(2))
	GUICtrlSetData($iStorageSize, _storageGO_GetInfo(1))
	GUICtrlSetData($iUsedStorages, _storageGO_GetInfo(3))
;~ 	GUICtrlSetData($iStorageSizeBytes, _storageGO_GetInfo(4))

	GUICtrlSetData($iIncoming, UBound(__netcode_Addon_GetIncomingSocketList($__hProxyParent)))
	GUICtrlSetData($iOutgoing, UBound(__netcode_Addon_GetOutgoingSocketList($__hProxyParent)))
	GUICtrlSetData($iClients, UBound(__netcode_Addon_GetRelaySocketList($__hProxyParent)))

	; update lists each 5 seconds
	if TimerDiff($hTimer) > 5000 Then

		; begin update, makes the edit faster
		_GUICtrlListView_BeginUpdate($lIncomingClients)
		_GUICtrlListView_BeginUpdate($lVisitedWebsites)


		; delete all items in the list
		_GUICtrlListView_DeleteAllItems($lIncomingClients)
		_GUICtrlListView_DeleteAllItems($lVisitedWebsites)

		; get incoming list
		Local $arGUIClientList = _storageMLx_GetElements('Incoming')
		Local $nArSize = UBound($arGUIClientList)
		Local $arGUIClientList2D[$nArSize][2]

		For $i = 0 To $nArSize - 1
			$arGUIClientList2D[$i][0] = $arGUIClientList[$i]
			$arGUIClientList2D[$i][1] = _storageGO_Read('Incoming', $arGUIClientList[$i])
		Next

		_ArraySort($arGUIClientList2D, 1, 0, 0, 1)

		; write to gui
		Local $nItem = 0
		For $i = 0 To $nArSize - 1
			$nItem = _GUICtrlListView_AddItem($lIncomingClients, $arGUIClientList2D[$i][0])
			_GUICtrlListView_AddSubItem($lIncomingClients, $nItem, $arGUIClientList2D[$i][1], 1)
		Next

		; get outgoing list
		Local $arGUIWebsiteList = _storageMLx_GetElements('Outgoing')
		$nArSize = UBound($arGUIWebsiteList)
		Local $arGUIWebsiteList2D[$nArSize][2]

		For $i = 0 To $nArSize - 1
			$arGUIWebsiteList2D[$i][0] = $arGUIWebsiteList[$i]
			$arGUIWebsiteList2D[$i][1] = _storageGO_Read('Outgoing', $arGUIWebsiteList[$i])
		Next

		_ArraySort($arGUIWebsiteList2D, 1, 0, 0, 1)

		; write to gui
		For $i = 0 To $nArSize - 1
			$nItem = _GUICtrlListView_AddItem($lVisitedWebsites, $arGUIWebsiteList2D[$i][0])
			_GUICtrlListView_AddSubItem($lVisitedWebsites, $nItem, $arGUIWebsiteList2D[$i][1], 1)
		Next

		; end update
		_GUICtrlListView_EndUpdate($lIncomingClients)
		_GUICtrlListView_EndUpdate($lVisitedWebsites)


		$hTimer = TimerInit()

		Return
	EndIf

EndFunc

; empties the list views and destroys the gui storages
Func _GuiEvent_ClearLogs()
	_GUICtrlListView_BeginUpdate($lIncomingClients)
	_GUICtrlListView_BeginUpdate($lVisitedWebsites)
	_GUICtrlListView_DeleteAllItems($lIncomingClients)
	_GUICtrlListView_DeleteAllItems($lVisitedWebsites)
	_GUICtrlListView_EndUpdate($lIncomingClients)
	_GUICtrlListView_EndUpdate($lVisitedWebsites)

	_storageMLx_DestroyGroup("Incoming")
	_storageMLx_DestroyGroup("Outgoing")
	_storageGO_DestroyGroup("Incoming")
	_storageGO_DestroyGroup("Outgoing")

	_storageMLx_CreateGroup("Incoming")
	_storageMLx_CreateGroup("Outgoing")
	_storageGO_CreateGroup("Incoming")
	_storageGO_CreateGroup("Outgoing")
EndFunc

Func _GuiEvent_Exit()
	Exit
EndFunc

; ===============================================================================================================================
; ===============================================================================================================================
; Functions

; debug function
Func _ShowUnfreeVars()
	Local $ar = _storageGO_GetClaimedVars()
	_ArrayDisplay($ar)
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
; Modified ......: Modified for this specfic example
; Remarks .......: Thanks to Moombas@Autoit.de for the plain and easy fix for the previous bugs with the HTTP/s functions.
; Example .......: No
; ===============================================================================================================================
Func _netcode_Proxy_CreateHttpProxy($sOpenOnIP, $nOpenOnPort)
	_netcode_Proxy_RegisterMiddleman("http_s_con", "__netcode_Proxy_Http_ConnectMiddleman", "Connect")
	_netcode_Proxy_RegisterMiddleman("http_s_dest", "__netcode_Proxy_Http_DestinationMiddleman", "Destination")

	Local $hSocket = _netcode_Proxy_Create($sOpenOnIP, $nOpenOnPort, "http_s_con", "http_s_dest")
	If Not $hSocket Then Return SetError(1, @error, False)

	Return $hSocket
EndFunc

Func __netcode_Proxy_Http_ConnectMiddleman($hIncomingSocket, $sPosition, $sPackages)

	; update client ip amount
	Local $sClientIP = __netcode_Addon_SocketToIP($hIncomingSocket)

	If _storageMLx_Exists('Incoming', $sClientIP) Then
		; _storageGO yet doesnt have the calc functions
		Return _storageGO_Overwrite('Incoming', $sClientIP, _storageGO_Read('Incoming', $sClientIP) + 1)
	Else
		_storageMLx_AddElement('Incoming', $sClientIP)
		Return _storageGO_Overwrite('Incoming', $sClientIP, 1)
	EndIf

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
		If Not IsArray($arIPAndPort) Then Return False

		; add the packet to the [2] to have it send to the destination after we connected
		ReDim $arIPAndPort[3]
		$arIPAndPort[2] = $sPackages

	ElseIf StringLeft($arPackage[0], 4) = "POST" Then
		; resolve the ip and port
		$sIP = StringTrimLeft($arPackage[0], 5)
		$sIP = StringLeft($sIP, StringInStr($sIP, ' '))

		$arIPAndPort = __netcode_Proxy_URLToIPAndPort($sIP, 80)
		If Not IsArray($arIPAndPort) Then Return False

		; add the packet to the [2] to have it send to the destination after we connected
		ReDim $arIPAndPort[3]
		$arIPAndPort[2] = $sPackages

	ElseIf StringLeft($arPackage[0], 7) = "CONNECT" Then
		; resolve the ip and port
		$sIPAndPort = StringTrimLeft($arPackage[0], 8)
		$sIPAndPort = StringLeft($sIPAndPort, StringInStr($sIPAndPort, ' '))

		$arIPAndPort = __netcode_Proxy_URLToIPAndPort($sIPAndPort)
		If Not IsArray($arIPAndPort) Then Return False

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
;~ 		Local $sStripStrings = "https://|http://|wss://|www.|ww3."
		Local $sStripStrings = "https://|http://|wss://"
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

	; update website amount
	If _storageMLx_Exists('Outgoing', $arIPAndPort[0]) Then
		_storageGO_Overwrite('Outgoing', $arIPAndPort[0], _storageGO_Read('Outgoing', $arIPAndPort[0]) + 1)
	Else
		_storageMLx_AddElement('Outgoing', $arIPAndPort[0])
		_storageGO_Overwrite('Outgoing', $arIPAndPort[0], 1)
	EndIf

	$arIPAndPort[0] = TCPNameToIP($arIPAndPort[0])
	$arIPAndPort[1] = Number($arIPAndPort[1])

	Return $arIPAndPort
EndFunc