#NoTrayIcon
#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Outfile=EzISORenamer.exe
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_Res_Comment=EzISO Renamer to use with Open PS2 Launcher
#AutoIt3Wrapper_Res_Description=EzISO Renamer to use with Open PS2 Launcher
#AutoIt3Wrapper_Res_Fileversion=1.2.0.0
#AutoIt3Wrapper_Res_LegalCopyright=RaydenX
#AutoIt3Wrapper_Run_Tidy=y
#AutoIt3Wrapper_Run_Obfuscator=y
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <File.au3>
#include <Array.au3>
Global Const $prog_name = "EzISO Renamer"
Global Const $version = "1.2"

Global $error = 0
Global $changedir = 0

If $cmdline[0] <> 0 Then
	Startup()

	$param_a = StringSplit($cmdline[1], "\") ;VERIFICARE CON CARTELLA VUOTA/nonesistente CHE SUCCEDE
	$param = $param_a[$param_a[0]]

	If StringRight($param, 4) = "*.iso" or StringRight($param, 4) = "*.ISO" Then
		file_singolo($cmdline[1])
	Else
		Rename($cmdline[1])
	Endif

Chiudi()
EndIf

If FileExists("CD") = 0 And FileExists("DVD") = 0 Then
	MsgBox(16, "Error", "The program cannot find either the DVD folder nor the CD folder." & @CRLF & "You must place this program next to those two folders.")
	Exit
Else
	If MsgBox(4 + 64, $prog_name, "Welcome to " & $prog_name & " v" & $version & " by RaydenX." & @CRLF & @CRLF & "This program will rename all of your ISO files in the ""CD"" and ""DVD"" folders to OPL's required format." & @CRLF & @CRLF & "Do you want to start this task?") = 7 Then Exit
	Startup()
EndIf

;Rinomina file in cartella CD & DVD (default)
Rename("CD")
Rename("DVD")
Chiudi()

;Chiusura
Func Chiudi()
	If $error <> 0 Then
		LogWrite("All files have been processed but some errors may have occured. Please, check this log file for more details.")
		MsgBox(64, $prog_name, "All files have been processed but some errors may have occured." & @CRLF & "Please, check the log file for more details.")
		ShellExecute($logfilename)
	Else
		LogWrite("All files have been processed with no errors! :)")
		MsgBox(64, $prog_name, "All files have been processed with no errors!" & @CRLF & "Thanks for using this program.")
	EndIf

	If DirRemove($sTempFolder, 1) = 0 Then LogWrite("WARNING! - The temp folder """ & $sTempFolder & """ could not be deleted. Please delete it manually.")
	FileClose($logfile)
	Exit
EndFunc   ;==>Chiudi

Func Rename($cartella)
	;VALORI CHE RITORNA LA FUNZIONE
	;0 se non trova file .iso da rinominare nella cartella indicata
	;1 se è tutto ok
	;2 se ci sono già file SLES e non riesce a cancellarli
	;3 se la cartella indicata non esiste

	Select
		Case $cartella <> "DVD" And $cartella <> "CD"
			$nome_cartella_a = StringSplit($cartella, "\") ;VERIFICARE CON CARTELLA VUOTA/nonesistente CHE SUCCEDE
			$nome_cartella = $nome_cartella_a[$nome_cartella_a[0]]
		Case $cartella = "CD"
			$nome_cartella = "CD"
		Case $cartella = "DVD"
			$nome_cartella = "DVD"
	EndSelect

	If FileExists($cartella) = 0 Then
		ProgressOn($prog_name, $nome_cartella & " folder not found")
		LogWrite("WARNING! - Folder """ & $cartella & """ has not been found.")
		$error = $error + 1
		Sleep(500)
		ProgressOff()
		Return 3
	Else
		ProgressOn($prog_name, "Working on " & $nome_cartella & " Folder", "Starting...")
		LogWrite("* Starting to work on folder """ & $cartella & """.")
		FileChangeDir($cartella & "\")
	EndIf

	FileSetAttrib("*", "-R")

	Local $sles = _FileListToArray(@WorkingDir & "\", "S??S_???.??", 1) ;si assicura che non ci siano già dei file id (SLES_111.11) in giro
	If $sles <> 0 Then
		LogWrite("WARNING! - Too many ""S??S_???.??"" files found in """ & @WorkingDir & "\"" folder! Trying to delete them.")
		$error = $error + 1

		Local $var = 0 ;per ogni filedelete riuscito +1, se $var uguale al numero di file vuol dire che li ha cancellati tutti
		For $i = 1 To $sles[0]
			$var = $var + FileDelete($sles[$i])
		Next

		Switch $var
			Case $sles[0] ;tutto ok
				LogWrite("SUCCESS! - All ""S??S_???.??"" files found in """ & @WorkingDir & "\"" folder have been deleted! Continuing task as normal.")
			Case Else ;altre rogne, abbandonare
				LogWrite("ERROR! - Could not delete ""S??S_???.??"" files in """ & @WorkingDir & "\"" folder! Aborting task for " & @WorkingDir & " folder.")
				$error = $error + 1
				ProgressOff()
				FileChangeDir("..")
				Return 2
		EndSwitch
	EndIf

	Run(@ComSpec & " /c " & 'ren *.ISO *.iso', "", @SW_HIDE) ;rinomina da *.ISO a *.iso

	;$iso_array qua sotto avrebbe bisogno di un sistema di controllo più preciso, forse. Finora non ha dato problemi però... (24/11/2013)
	$iso_array = _FileListToArray(@WorkingDir & "\", "*.iso", 1) ;crea lista file .iso

	If $iso_array = 0 Then ;non sono stati trovati file .iso
		LogWrite("WARNING! - No .iso files found in folder """ & $cartella & """.")
		$error = $error + 1
		ProgressOff()
		FileChangeDir("..")
		Return 0
	EndIf

	For $i = 1 To $iso_array[0]
		ProgressSet($i * 100 / $iso_array[0], "Analyzing """ & $iso_array[$i] & """")

		;vede se il file è nominato secondo il giusto formato
		Local $string = StringLeft($iso_array[$i], 12)
		Local $test = StringRegExp($string, "S[[:alpha:]][[:alpha:]]S_[[:digit:]][[:digit:]][[:digit:]].[[:digit:]][[:digit:]].", 0)

		;rinomina se necessario, se $test = 0 allora è da rinominare
		If $test = 0 Then
			Local $nome = StringLeft($iso_array[$i], StringLen($iso_array[$i]) - 4) ;nome del file non formattato, senza estensione

			;verifica se il nome è più corto di 32 caratteri
			If StringLen($nome) > 32 Then
				LogWrite("ERROR! - File """ & $iso_array[$i] & """ - The filename exceeds 32 characters and therefore has not been renamed. Shorten it and try again.")
				$error = $error + 1
				ContinueLoop
			EndIf

			;estrai il file magico (SLES_111.11, tipo) per l'identificazione
			ShellExecuteWait($sTempFolder & "\7z.exe", "e -y """ & $iso_array[$i] & """ S??S_???.??", "", "open", @SW_HIDE)

			Local $sles = _FileListToArray(@WorkingDir & "\", "S??S_???.??", 1)

			Switch $sles
				Case 0
					LogWrite("ERROR! - File """ & $iso_array[$i] & """ - The ID file cannot be extracted from the ISO. Make sure you have write access for the hard drive.")
					$error = $error + 1
					ContinueLoop
				Case Else
					$id = $sles[1]
					FileDelete($id)

					If FileMove($iso_array[$i], $id & "." & $nome & ".iso") = 0 Then
						LogWrite("ERROR! - File """ & $iso_array[$i] & """ (" & $id & ") - The file cannot be renamed. Make sure you have write access for the hard drive or that the file is not open in another program or use the ID here to rename it manually.")
						$error = $error + 1
						ContinueLoop
					Else
						LogWrite("SUCCESS! - """ & $iso_array[$i] & """ - The file has been renamed correctly.")
					EndIf
			EndSwitch
		Else
			LogWrite("The file """ & $iso_array[$i] & """ seems to be named correctly.")
		EndIf

		Sleep(350) ;sennò non si vede la progress bar
	Next
	ProgressOff()
	FileChangeDir("..")
	Return 1
EndFunc   ;==>Rename

Func LogWrite($log)
	FileWrite($logfile, "[" & @MDAY & "/" & @MON & "/" & @YEAR & " - " & @HOUR & ":" & @MIN & ":" & @SEC & "] " & $log & @CRLF)
EndFunc   ;==>LogWrite

Func startup()
	;Crea cartella temporanea dove piazzare files
	Global Const $sTempFolder = _TempFile(@TempDir, "~", "")
	DirCreate($sTempFolder)
	FileInstall("D:\PS2SMB\7z.exe", $sTempFolder & "\7z.exe")
	FileInstall("D:\PS2SMB\7z.dll", $sTempFolder & "\7z.dll")

	;Crea file log
	$logfilename = "EzISORenamer_log_" & @MDAY & @MON & @YEAR & "_" & @HOUR & @MIN & @SEC & ".txt" ;nome del file
	$logfile = FileOpen($logfilename, 2)
	LogWrite("---------------------------------------------------------------------------------------------------")
	LogWrite($prog_name & " v" & $version & " launched! Let's get goin'! ;)")
	LogWrite("Website: http://psx-scene.com/forums/f150/eziso-renamer-rename-your-iso-files-one-click-117233/")
	LogWrite("---------------------------------------------------------------------------------------------------")
EndFunc   ;==>startup

Func file_singolo($file)

EndFunc   ;==>file_singolo

