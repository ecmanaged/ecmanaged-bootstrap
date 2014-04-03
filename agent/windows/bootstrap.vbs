<script>
echo strFileURL = "http://bootstrap.ecmanaged.com/agent/windows/setup.exe" > ecm_bootstrap.vbs
echo strHDLocation = "c:\\ecm-agent-setup.exe" >> ecm_bootstrap.vbs
echo Set objXMLHTTP = CreateObject("MSXML2.XMLHTTP") >> ecm_bootstrap.vbs
echo objXMLHTTP.open "GET", strFileURL, false >> ecm_bootstrap.vbs
echo objXMLHTTP.send() >> ecm_bootstrap.vbs
echo If objXMLHTTP.Status = 200 Then >> ecm_bootstrap.vbs
echo 	Set objADOStream = CreateObject("ADODB.Stream") >> ecm_bootstrap.vbs
echo 	objADOStream.Open >> ecm_bootstrap.vbs
echo 	objADOStream.Type = 1 >> ecm_bootstrap.vbs
echo 	objADOStream.Write objXMLHTTP.ResponseBody >> ecm_bootstrap.vbs
echo 	objADOStream.Position = 0 >> ecm_bootstrap.vbs
echo 	Set objFSO = Createobject("Scripting.FileSystemObject") >> ecm_bootstrap.vbs
echo 	If objFSO.Fileexists(strHDLocation) Then objFSO.DeleteFile strHDLocation >> ecm_bootstrap.vbs
echo 	Set objFSO = Nothing >> ecm_bootstrap.vbs
echo 	objADOStream.SaveToFile strHDLocation >> ecm_bootstrap.vbs
echo 	objADOStream.Close >> ecm_bootstrap.vbs
echo 	Set objADOStream = Nothing >> ecm_bootstrap.vbs
echo 	strCommand = strHDLocation ^& " /VERYSILENT" >> ecm_bootstrap.vbs
echo 	Set wshShell = WScript.CreateObject ("WSCript.shell") >> ecm_bootstrap.vbs
echo 	wshshell.run strCommand,6, True >> ecm_bootstrap.vbs
echo 	set wshshell = Nothing >> ecm_bootstrap.vbs
echo End if >> ecm_bootstrap.vbs
echo Set objXMLHTTP = Nothing >> ecm_bootstrap.vbs
cscript ecm_bootstrap.vbs
</script>
