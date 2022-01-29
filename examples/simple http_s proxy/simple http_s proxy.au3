#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\_netcode_Proxy.au3"

; startup _netcode proxy
_netcode_Proxy_Startup()
$__net_bTraceEnable = False

; create http proxy at port 8080
Local $hSocket = _netcode_Proxy_CreateHttpProxy("0.0.0.0", 8080)

; loop it
While True
	_netcode_Proxy_Loop()

	Sleep(10)
WEnd