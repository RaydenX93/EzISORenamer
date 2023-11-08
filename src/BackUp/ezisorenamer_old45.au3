#NoTrayIcon
#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Outfile=Eztest.exe
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_Res_Comment=EzISO Renamer to use with Open PS2 Launcher
#AutoIt3Wrapper_Res_Description=EzISO Renamer
#AutoIt3Wrapper_Res_Fileversion=1.2.0.0
#AutoIt3Wrapper_Res_LegalCopyright=RaydenX
#AutoIt3Wrapper_Add_Constants=n
#AutoIt3Wrapper_Run_Tidy=y
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <File.au3>
#include <Array.au3>
Global Const $prog_name = "EzISO Renamer"
Global Const $version = "1.2 BETA"

Global $error = 0
Global $logfilename = ""
Global $sTempFolder = ""
Global $logfile = ""
Global $orig_folder = ""

If $cmdline[0] <> 0 Then
	;verifica che non ci siano file iso e cartelle mischiati
	Local $szDrive, $szDir, $szFName, $szExt
	Local $iso = 0
	Local $empty = 0
	Local $unknown = 0

	For $i = 1 To $cmdline[0]
		Local $TestPath = _PathSplit($cmdline[$i], $szDrive, $szDir, $szFName, $szExt)
		Switch $TestPath[4]
			Case ".iso"
				$iso = $iso + 1

				If $TestPath[4] == ".iso" then
				Filemove($cmdline[$i],"*.iso",1)
				msgbox(0,"","Estensione maiuscola per " & $cmdline[$i])
			EndIf

				Case ""
				$empty = $empty + 1
			Case Else
				$unknown = $unknown + 1
		EndSwitch
	Next

	Switch $cmdline[0]
		Case $iso ;tutti file iso
			Startup()

			ProgressOn($prog_name, "Batch renaming...")
			LogWrite("* Starting batch renaming.")

			; *** INIZIO controllo SLES
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
				EndSwitch
			EndIf
			; *** FINE controllo SLES

			#region Batch Rename
			For $i = 1 To $cmdline[0]
				$nome_file_a = StringSplit($cmdline[$i], "\")
				$file = $nome_file_a[$nome_file_a[0]]
				ProgressSet($i * 100 / $cmdline[0], "Analyzing """ & $file & """")

				FileSetAttrib($cmdline[$i], "-R")

				;vede se il file è nominato secondo il giusto formato
				Local $string = StringLeft($file, 12)
				Local $test = StringRegExp($string, "S[[:alpha:]][[:alpha:]]S_[[:digit:]][[:digit:]][[:digit:]].[[:digit:]][[:digit:]].", 0)

				;rinomina se necessario, se $test = 0 allora è da rinominare
				If $test = 0 Then
					Local $nome = StringLeft($file, StringLen($file) - 4) ;nome del file non formattato, senza estensione

					;verifica se il nome è più corto di 32 caratteri
					If StringLen($nome) > 32 Then
						LogWrite("ERROR! - File """ & $file & """ - The filename exceeds 32 characters and therefore has not been renamed.")
						$error = $error + 1
						ContinueLoop
					EndIf

					;estrai il file magico (SLES_111.11, tipo) per l'identificazione
					ShellExecuteWait($sTempFolder & "\7z.exe", "e -y """ & $cmdline[$i] & """ S??S_???.??", "", "open", @SW_HIDE)

					Local $sles = _FileListToArray(@WorkingDir & "\", "S??S_???.??", 1)

					Switch $sles
						Case 0
							LogWrite("ERROR! - File """ & $file & """ - The ID file cannot be extracted from the ISO. Make sure you have write access for the hard drive.")
							$error = $error + 1
							ContinueLoop
						Case Else
							$id = $sles[1]
							FileDelete($id)

							If FileMove($cmdline[$i], $orig_folder & "\" & $id & "." & $nome & ".iso") = 0 Then
								LogWrite("ERROR! - File """ & $file & """ (" & $id & ") - The file cannot be renamed. Make sure you have write access for the hard drive or that the file is not open in another program or use the ID here to rename it manually.")
								$error = $error + 1
								ContinueLoop
							Else
								LogWrite("SUCCESS! - """ & $file & """ - The file has been renamed correctly.")
							EndIf
					EndSwitch
				Else
					LogWrite("The file """ & $file & """ seems to be named correctly.")
				EndIf

				Sleep(250) ;sennò non si vede la progress bar

			Next
			#endregion Batch Rename

			ProgressOff()
		Case $empty ;tutte cartelle
			Startup()
			For $i = 1 To $cmdline[0]
				Rename($cmdline[$i])
			Next
		Case $iso + $empty ;iso e cartelle mischiate
			MsgBox(16, $prog_name, "You are trying to process iso files together with folders." & @CRLF & @CRLF & "To use the Drag n Drop feature, drag here" & @CRLF & "- iso files" & @CRLF & "OR" & @CRLF & "- directories containing iso files.")
			Exit
		Case $iso + $empty + $unknown ;un mischione di tutto che non si può spiegare come
			MsgBox(16, $prog_name, "You are trying to process files and/or folders that this program cannot handle." & @CRLF & @CRLF & "To use the Drag n Drop feature, drag here" & @CRLF & "- iso files" & @CRLF & "OR" & @CRLF & "- directories containing iso files.")
			Exit
		Case Else
			MsgBox(16, $prog_name, "Something went terribly wrong.")
			Exit
	EndSwitch

	Chiudi()
EndIf

If FileExists("CD") = 0 And FileExists("DVD") = 0 Then
	MsgBox(16, $prog_name, "The program cannot find either the DVD folder nor the CD folder." & @CRLF & "You must place this program next to those two folders.")
	Exit
Else
	If MsgBox(4 + 64, $prog_name, "Welcome to " & $prog_name & " v" & $version & " by RaydenX." & @CRLF & @CRLF & "This program will rename all of your ISO files in the ""CD"" and ""DVD"" folders to OPL's required format." & @CRLF & @CRLF & "Do you want to start this task?") = 7 Then Exit
	Startup()
EndIf

;Rinomina file in cartella CD & DVD (default)
Rename("CD")
Rename("DVD")
Chiudi()

Func Chiudi()
	If $error <> 0 Then
		LogWrite("All files have been processed but some errors may have occured. Please, check this log file for more details.")
		MsgBox(64, $prog_name, "All files have been processed but some errors may have occured." & @CRLF & "Please, check the log file for more details.")
		ShellExecute(@ScriptDir & "\" & $logfilename)
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
			Local $szDrive, $szDir, $szFName, $szExt
			Local $TestPath = _PathSplit($cmdline[$i], $szDrive, $szDir, $szFName, $szExt)
			$nome_cartella = $TestPath[3]
		Case $cartella = "CD"
			$nome_cartella = "CD"
		Case $cartella = "DVD"
			$nome_cartella = "DVD"
	EndSelect

	If FileExists($cartella) = 0 Then
		ProgressOn($prog_name, $nome_cartella & " folder not found")
		LogWrite("WARNING! - Folder """ & $cartella & """ has not been found.")
		$error = $error + 1
		Sleep(1500)
		ProgressOff()
		Return 3
	Else
		ProgressOn($prog_name, "Working on """ & $nome_cartella & """ Folder", "Starting...")
		LogWrite("* Starting to work on folder """ & $cartella & """.")
		FileChangeDir($cartella & "\")
	EndIf

	FileSetAttrib("*", "-R")

	; *** INIZIO controllo SLES
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
	; *** FINE controllo SLES

	;Run(@ComSpec & " /c " & 'ren *.ISO *.iso', "", @SW_HIDE) ;rinomina da *.ISO a *.iso

	;$iso_array qua sotto avrebbe bisogno di un sistema di controllo più preciso, forse. Finora non ha dato problemi però... (24/11/2013)
	$iso_array = _FileListToArray(@WorkingDir & "\", "*.iso", 1) ;crea lista file .iso

	If $iso_array = 0 Then ;non sono stati trovati file .iso
		ProgressSet(0, "No .iso files found in folder """ & $cartella & """.")
		LogWrite("WARNING! - No .iso files found in folder """ & $cartella & """.")
		Sleep(500)
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

		Sleep(250) ;sennò non si vede la progress bar
	Next
	ProgressOff()
	FileChangeDir("..")
	Return 1
EndFunc   ;==>Rename

Func LogWrite($log)
	FileWrite($logfile, "[" & @MDAY & "/" & @MON & "/" & @YEAR & " - " & @HOUR & ":" & @MIN & ":" & @SEC & "] " & $log & @CRLF)
EndFunc   ;==>LogWrite

Func Startup()
	Global $orig_folder = @WorkingDir
	FileChangeDir(@ScriptDir & "\")

	;Crea cartella temporanea dove piazzare files
	Global $sTempFolder = _TempFile(@TempDir, "~", "")
	DirCreate($sTempFolder)
	FileInstall("D:\PS2SMB\programma\src\7z.exe", $sTempFolder & "\7z.exe")
	FileInstall("D:\PS2SMB\programma\src\7z.dll", $sTempFolder & "\7z.dll")

	;Crea file log
	$logfilename = "EzISORenamer_log_" & @MDAY & @MON & @YEAR & "_" & @HOUR & @MIN & @SEC & ".txt" ;nome del file
	$logfile = FileOpen(@ScriptDir & "\" & $logfilename, 2)
	LogWrite("---------------------------------------------------------------------------------------------------")
	LogWrite($prog_name & " v" & $version & " launched! Let's get goin'! ;)")
	LogWrite("Website: http://psx-scene.com/forums/f150/eziso-renamer-rename-your-iso-files-one-click-117233/")
	LogWrite("---------------------------------------------------------------------------------------------------")
EndFunc   ;==>Startup

