#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\_netcode_Proxy.au3"

AutoItSetOption("TCPTimeout", 100)

Local $hProxySocket = _netcode_SetupTCPProxy('0.0.0.0', 8080)
_netcode_ProxySetHttpProxy($hProxySocket)

_netcode_ProxyLoop(True)