$!q::
$^q::
$#q::
IfWinActive ahk_exe chrome.exe
{
  Send ^{w} 
} else
IfWinActive ahk_exe code.exe
{
  Send ^{w} 
} else 
IfWinActive ahk_class CASCADIA_HOSTING_WINDOW_CLASS 
{ 
  Send ^{W} 
} else 
IfWinActive ahk_class rctrl_renwnd32 
{ 
  Send ^{!} 
}  else 
IfWinActive ahk_class IrfanView 
{ 
  Send {Esc} 
} else
{ 
  Send !{F4} 
  return
}

#IfWinActive ahk_exe code.exe
#Left:: 
send, ^+{Left}
return

#Right:: 
send, ^{Right}
return

#IfWinActive, ahk_exe chrome.exe
^Left:: 
send, ^+{Tab}
return

^Right:: 
send, ^{Tab}
return

!Left:: 
send, ^+{Tab}
return

!Right:: 
send, ^{Tab}
return

#Left:: 
send, ^+{Tab}
return

#Right:: 
send, ^{Tab}
return

return
