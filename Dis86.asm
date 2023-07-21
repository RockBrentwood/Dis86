.model small
.stack 100h

BufMax = 0ffh

putc macro Char
   mov AH, 2
   mov DL, Char
   int 21h
endm

puts macro Str
   mov AH, 9
   lea DX, Str
   int 21h
endm

FPutC macro Char
   mov DL, Char
   call _FPutC
endm

FPutSp macro Str
   lea SI, Str
   call _FPutS
endm

Fatal macro
   mov AH, 9
   int 21h
   mov AX, 4c01h
   int 21h
endm

WordHex macro
   push DX
   mov DL, AH
   mov DH, 1
   call ByteHex
   mov DL, AL
   xor DH, DH
   call ByteHex
   pop DX
endm

jeL macro Lab
   local _1f
   jne _1f
      jmp Lab
   _1f:
endm

jbL macro Lab
   local _1f
   jnb _1f
      jmp Lab
   _1f:
endm

jbeL macro Lab
   local _1f
   jnbe _1f
      jmp Lab
   _1f:
endm

.data
Eol              db 13,10,'$'
Notice           db 'Gustas Zilinskas, PS 1k., 5 gr.',10,13,'Disasembleris (visos 8086 instrukcijos)',10,13,'$'
TooManyOpenFiles db "Atidaryta per daug failu!",'$'
NoInFile         db "Ivesties failas neegzistuoja!",'$'
NoInPath         db "Ivesties failo kelias nepasiekiamas!",'$'
NoReadAccess     db "Nera teisiu ivesties failui skaityti!",'$'
CantOpenInput    db "Nepavyko atidaryti ivesties failo!",'$'
ReadingFailure   db "Klaida ivesties failo skaitymo metu!",'$'

InFile           db 80h dup (0)
InFP             dw ?
InBuf            db BufMax dup (?)
InBytes          dw 0
BufX             dw 0
BufB             db ?
CurIP            dw 100h

NoOutPath        db "Isvesties failo kelias nepasiekiamas!",'$'
NoWriteAccess    db "Nera teisiu isvesties failui sukurti!",'$'
CantOpenOutput   db "Nepavyko sukurti isvesties failo!",'$'

ReadOnly         db "Nera teisiu rasyti i isvesties faila!",'$'
NoFileSpace      db "Nepavyko irasyti visu duomenu i isvesties faila. Patikrinkite, ar diske yra laisvos vietos.",'$'
WritingFailure   db "Klaida rasymo i rezultatu faila metu!",'$'

ExName           db 80h dup (0)
ExFP             dw ?
ExBuf            db BufMax dup (?)
ExBytes          dw 0

BadOpCode        db 'Neatpazinta instrukcija!',10,13,'$'

OpItem struc
   _OpP  dw ?
   _Mode db 0
   _Arg1 db ?
   _Arg2 db ?
ends

include OpCodes.inc

bAL db "AL",'$'
bCL db "CL",'$'
bDL db "DL",'$'
bBL db "BL",'$'
bAH db "AH",'$'
bCH db "CH",'$'
bDH db "DH",'$'
bBH db "BH",'$'

wAX db "AX",'$'
wCX db "CX",'$'
wDX db "DX",'$'
wBX db "BX",'$'
wSP db "SP",'$'
wBP db "BP",'$'
wSI db "SI",'$'
wDI db "DI",'$'

sES db "ES",'$'
sSS db "SS",'$'
sCS db "CS",'$'
sDS db "DS",'$'

label Rx
Rb dw bAL,bCL,bDL,bBL,bAH,bCH,bDH,bBH
Rw dw wAX,wCX,wDX,wBX,wSP,wBP,wSI,wDI
Rs dw sES,sSS,sCS,sDS

BytePtr db "byte ptr ",'$'
WordPtr db "word ptr ",'$'

OverT enum {
   ByteOv,
   WordOv,
   RegOv,
   NoneOv
}

_M0  db "BX+SI",'$'
_M1  db "BX+DI",'$'
_M2  db "BP+SI",'$'
_M3  db "BP+DI",'$'
_M4  db "SI",'$'
_M5  db "DI",'$'
_M6  db "BP",'$'
_M7  db "BX",'$'
MTab dw _M0,_M1,_M2,_M3,_M4,_M5,_M6,_M7

Prefixed db 0

Mnem   dw ?
Mode   db ?
Arg1   db ?
Arg2   db ?

GotXRM db 0
qX     db ?
qR     db ?
qM     db ?

Disp   dw ?
Imm    dw ?

TypeOver db ?
SegOver  db 0

.code

SpaceOver proc ;; DS:SI - argv
   _0b:
      cmp byte ptr [SI], ' '
      jne _01af
      inc SI
   loop _0b
_01af:
   ret
SpaceOver endp

GetFileName proc ;; DS:SI - argv, ES:DI - failo vardas
   _1b:
      movsb
      cmp byte ptr [SI], ' '
   loopne _1b
   ret
GetFileName endp

OpenInFile proc
   push AX DX
   mov AX, 3d00h
   lea DX, InFile
   int 21h
      jnc Ok2
   cmp AX, 02h
      je _02af
   cmp AX, 03h
      je _02bf
   cmp AX, 04h
      je _02cf
   cmp AX, 05h
      je _02df
   jmp _02Xf
_02af:
   lea DX, NoInFile
   jmp Fail2
_02bf:
   lea DX, NoInPath
   jmp Fail2
_02cf:
   lea DX, TooManyOpenFiles
   jmp Fail2
_02df:
   lea DX, NoReadAccess
   jmp Fail2
_02Xf:
   lea DX, CantOpenInput
Fail2:
   Fatal
Ok2:
   mov [InFP], AX
   pop DX AX
   ret
OpenInFile endp

GetByte proc
   push AX BX
   cmp [InBytes], 0
   jne _04df
      push CX DX
      mov AH, 3fh
      mov BX, [InFP]
      mov CX, BufMax
      lea DX, InBuf
      int 21h
      jnc _04af
         lea DX, ReadingFailure
         Fatal
      _04af:
      cmp AX, 0
      je _04bf
         mov [InBytes], AX
         mov [BufX], 0
         pop DX CX
         jmp _04df
      _04bf:
      cmp [ExBytes], 0
      je _04cf
         call FWrite
      _04cf:
      mov BX, [ExFP]
      call fclose
      mov BX, [InFP]
      call fclose
      mov AX, 4c00h
      int 21h
   _04df:
   mov BX, [BufX]
   mov AL, InBuf[BX]
   mov [BufB], AL
   dec [InBytes]
   inc [BufX]
   inc [CurIP]
   pop BX AX
   ret
GetByte endp

OpenExFile proc
   push AX CX DX
   mov AH, 3ch
   xor CX, CX
   lea DX, ExName
   int 21h
      jnc Ok5
   cmp AX, 03h
      je _05af
   cmp AX, 04h
      je _05bf
   cmp AX, 05h
      je _05cf
   jmp _05Xf
_05af:
   lea DX, NoOutPath
   jmp Fail5
_05bf:
   lea DX, TooManyOpenFiles
   jmp Fail5
_05cf:
   lea DX, NoWriteAccess
   jmp Fail5
_05Xf:
   lea DX, CantOpenOutput
Fail5:
   Fatal
Ok5:
   mov [ExFP], AX
   pop DX CX AX
   ret
OpenExFile endp

FWrite proc
   push AX BX CX DX
   mov AH, 40h
   mov BX, [ExFP]
   mov CX, [ExBytes]
   lea DX, ExBuf
   int 21h
      jc _06af
   cmp AX, CX
      jb _06bf
   jmp Ok6
_06af:
   cmp AX, 05h
   je _06cf
   jmp _06Xf
_06bf:
   lea DX, NoFileSpace
   jmp Fail6
_06cf:
   lea DX, NoWriteAccess
   jmp Fail6
_06Xf:
   lea DX, WritingFailure
Fail6:
   mov BX, [ExFP]
   call fclose
   mov BX, [InFP]
   call fclose
   Fatal
Ok6:
   mov [ExBytes], 0
   pop DX CX BX AX
   ret
FWrite endp

_FPutC proc ;; DL - isvedamas simbolis
   push BX
   cmp [ExBytes], BufMax
   jb _07af
      call FWrite
   _07af:
   mov BX, [ExBytes]
   mov ExBuf[BX], DL
   inc word ptr [ExBytes]
   pop BX
   ret
_FPutC endp

_FPutS proc ;; SI - adresas simboliu eilutes, uzbaigtos '$'
   _2b:
      mov DL, [SI]
      call _FPutC
      inc SI
      cmp byte ptr [SI], '$'
   jne _2b
   ret
_FPutS endp

fclose proc ;; BX - failo deskriptorius
   push AX
   mov AH, 3eh
   int 21h
   pop AX
   ret
fclose endp

ByteHex proc ;; DL - spausdinamas baitas, DH - ar prideti nuli, jei prasideda raide
   push AX CX DX
   mov CH, DH
   mov DH, DL
   mov CL, 4
   shr DL, CL
   cmp DL, 9
   jbe _08af
      add DL, 7
      cmp CH, 0
   je _08af
      mov AL, DL
      FPutC '0'
      mov DL, AL
   _08af:
   add DL, '0'
   call _FPutC
   mov DL, DH
   and DL, 0fh
   cmp DL, 9
   jbe _08bf
      add DL, 7
   _08bf:
   add DL, '0'
   call _FPutC
   pop DX CX AX
   ret
ByteHex endp

FetchOp proc
   push AX BX
   mov AX, size OpItem
   mov BL, [BufB]
   mul BL
   lea BX, OpTab
   add BX, AX
   mov AX, [BX]._OpP
   mov [Mnem], AX
   mov AL, [BX]._Mode
   mov [Mode], AL
   mov AL, [BX]._Arg1
   mov [Arg1], AL
   mov AL, [BX]._Arg2
   mov [Arg2], AL
   pop BX AX
   ret
FetchOp endp

WorkAround proc
   cmp [BufB], 324q
   je _09af
      cmp [BufB], 325q
      jne _09bf
   _09af:
   call GetByte
   ret
_09bf:
   push CX DX
   mov DH, 1
   mov DL, [BufB]
   and DL, 7
   mov CL, 3
   shl DL, CL
   call FetchXRM
   add DL, [qR]
   call ByteHex
   FPutC 'h'
   mov [TypeOver], RegOv
   pop DX CX
   ret
WorkAround endp

FetchXRM proc
   cmp [GotXRM], 0
   jne _0aaf
   push AX CX
   call GetByte
   mov [GotXRM], 1
   mov AL, [BufB]
   and AL, 300q
   mov CL, 6
   shr AL, CL
   mov [qX], AL
   mov AL, [BufB]
   and AL, 070q
   mov CL, 3
   shr AL, CL
   mov [qR], AL
   mov AL, [BufB]
   and AL, 007q
   mov [qM], AL
   pop CX AX
_0aaf:
   ret
FetchXRM endp

FetchPagedOp proc
   push AX BX SI
   mov AL, [BufB]
   push AX
   call FetchXRM
;; Apskaiciuojame vardo indeksa isplestines komandos masyve
   xor BH, BH
   mov BL, [qR]
   pop AX
   cmp AL, 366q
   jne _0baf
      cmp BL, 0
   jne _0bbf
      mov byte ptr [Arg2], _Ib
   jmp _0bbf
   _0baf:
      cmp AL, 367q
   jne _0bbf
      cmp BL, 0
   jne _0bbf
      mov byte ptr [Arg2], _Iw
;; Paimame adresa i komandos vardo eilute is apskaiciuotos vietos isplestiniu komandu vardu masyve
   _0bbf:
   shl BL, 1
   mov SI, [Mnem]
   mov AX, [BX+SI]
   mov [Mnem], AX
   pop SI BX AX
   ret
FetchPagedOp endp

FetchArg proc
   push AX
   xor AX, AX
   cmp DL, _0 ;; nera operando
      jeL OkC
   cmp DL, _3 ;; registras arba konstanta
      jbeL OkC
   cmp DL, _Rb ;; reikalingas modrm
      jae AtXRM
;; Immediate value.
   call GetByte
   mov AL, [BufB]
   mov [TypeOver], ByteOv
   cmp DL, _Iw
   jb _0caf
      call GetByte
      mov AH, [BufB]
      inc [TypeOver]
   _0caf:
   cmp DL, _Mn
   je _0cbf
      mov [Imm], AX
      cmp DL, _Af
      jne OkC
      call GetByte
      mov AL, [BufB]
      call GetByte
      mov AH, [BufB]
   _0cbf:
   mov [Disp], AX
   jmp OkC
AtXRM:
   call FetchXRM
   cmp DL, _Eb
      jb _0ccf ;; jei, operandas yra registras, neskaitome poslinkio
   cmp [qX], 3q
      je _0ccf
   cmp [qX], 1q
      jae _0cdf
   cmp [qM], 6q
      jne _0CXf
   jmp _0cdf
_0ccf:
   mov [TypeOver], RegOv
   jmp OkC
_0cdf:
   call GetByte
   mov AL, [BufB]
   cmp [qX], 1q
   je _0cef
      call GetByte
      mov AH, [BufB]
   _0cef:
   mov [Disp], AX
_0CXf:
   cmp [TypeOver], RegOv
   je OkC
      mov [TypeOver], ByteOv
      cmp DL, _Ew
      jne OkC
      inc [TypeOver]
OkC:
   pop AX
   ret
FetchArg endp

PutArg proc
   cmp BL, _0
      jeL ExitOk
   cmp BL, _1
      jbL PutRx
      jeL Put1
   cmp BL, _3
      jeL Put3
   cmp BL, _Ib
      jeL PutIb
   cmp BL, _Is
      jeL PutIs
   cmp BL, _Iw
      jeL PutIw
   cmp BL, _An
      jeL PutAn
   cmp BL, _Mn
      jeL PutMn
   cmp BL, _Af
      jeL PutAf
   cmp BL, _Eb
      jbL PutRegR
   cmp [qX], 3q
   jne _0dbf
      mov AL, BL
      xor BH, BH
      mov BL, [qM]
      cmp AL, _Eb
      je _0daf
         add BL, 8
      _0daf:
      shl BL, 1
      mov SI, Rx[BX]
      call _FPutS
      jmp ExitOk
   _0dbf:
   cmp [TypeOver], RegOv
   jae _0ddf
      cmp [TypeOver], WordOv
      je _0dcf
         FPutSp BytePtr
         jmp _0ddf
      _0dcf:
         FPutSp WordPtr
   _0ddf:
   cmp [SegOver], 0
   je _0def
      xor BH, BH
      mov BL, [SegOver]
      shl BL, 1
      mov SI, Rx[BX]
      call _FPutS
      FPutC ':'
      mov [SegOver], 0
   _0def:
   FPutC '['
   cmp [qX], 0q
   jne _0dff
      cmp [qM], 6q
      je _0dgf
   _0dff:
      xor BH, BH
      mov BL, [qM]
      shl BL, 1
      mov SI, MTab[BX]
      call _FPutS
      cmp [qX], 0q
      je _0djf
      FPutC '+'
   _0dgf:
   mov AX, [Disp]
   cmp [qX], 1q
   jne _0dhf
      mov DH, 1
      mov DL, AL
      call ByteHex
      jmp _0dif
   _0dhf:
      WordHex
   _0dif:
   FPutC 'h'
_0djf:
   FPutC ']'
   jmp ExitOk
PutRx:
   xor BH, BH
   shl BL, 1
   mov SI, Rx[BX]
   call _FPutS
   ret
Put1:
   FPutC '1'
   ret
Put3:
   FPutC '3'
   ret
PutIb:
   mov DX, [Imm]
   mov DH, 1
   call ByteHex
   FPutC 'h'
   ret
PutIs:
   mov AX, [Imm]
   cbw
   add AX, [CurIP]
   WordHex
   FPutC 'h'
   ret
PutIw:
   mov AX, [Imm]
   WordHex
   FPutC 'h'
   ret
PutAn:
   mov AX, [CurIP]
   mov BX, [Imm]
   add AX, BX
   WordHex
   FPutC 'h'
   ret
PutMn:
   FPutC '['
   mov AX, [Disp]
   WordHex
   FPutC 'h'
   FPutC ']'
   ret
PutAf:
   mov AX, [Disp]
   WordHex
   FPutC ':'
   mov AX, [Imm]
   WordHex
   ret
PutRegR:
   mov AL, [qR]
   cmp BL, _Rb
   je _0dkf
      add AL, 8
   cmp BL, _Rw
   je _0dkf
      add AL, 8
   _0dkf:
   xor BH, BH
   mov BL, AL
   shl BL, 1
   mov SI, Rx[BX]
   call _FPutS
   ret
ExitOk:
   ret
PutArg endp

__main__:
   cmp byte ptr ES:[80h], 0
   jne readCmdArguments
      jmp Usage
   readCmdArguments:
   xor CH, CH
   mov CL, ES:[80h]
   mov SI, 81h
   mov AX, @data
   mov ES, AX
   call SpaceOver
   lea DI, InFile
   call GetFileName
   call SpaceOver
   cmp CX, 0
   jne readOutputFilename
      jmp Usage
   readOutputFilename:
   lea DI, ExName
   call GetFileName
   mov AX, @data
   mov DS, AX
   call OpenInFile
   call OpenExFile
   _3b:
      mov [GotXRM], 0
      mov [Imm], 0
      mov [Disp], 0
      mov [TypeOver], 0
      call GetByte
      call FetchOp
      cmp [Mode], SegM
      jne _0eaf
         mov AX, [Mnem]
         mov [SegOver], AL
         jmp _3b
      _0eaf:
      cmp [Prefixed], 1
      je _0ecf
         mov AX, [CurIP]
         dec AX
         cmp [SegOver], 0
         je _0ebf
            dec AX
         _0ebf:
         xor DH, DH
         mov DL, AH
         call ByteHex
         mov DL, AL
         call ByteHex
         FPutC ':'
         FPutC ' '
      _0ecf:
      cmp [Mode], UnM
      jne _0edf
         FPutSp BadOpCode
         jmp _3b
      _0edf:
      cmp [Mode], PageM
      jne _0eef
         call FetchPagedOp
      _0eef:
      mov SI, [Mnem]
      call _FPutS
      FPutC ' '
      cmp [Mode], PreM
      jne _0eff
         mov [Prefixed], 1
         jmp _3b
      _0eff:
      cmp [Mode], ExtM
      jne _0egf
         call WorkAround
      _0egf:
      mov DL, [Arg1]
      call FetchArg
      mov DL, [Arg2]
      call FetchArg
      mov BL, [Arg1]
      call PutArg
      cmp [Arg2], _0
      je _0ehf
         FPutC ','
         FPutC ' '
         mov BL, [Arg2]
         call PutArg
      _0ehf:
      FPutSp Eol
      mov [Prefixed], 0
   jmp _3b
Usage:
   mov AX, @data
   mov DS, AX
   puts Notice
   mov AX, 4c00h
   int 21h
end __main__
