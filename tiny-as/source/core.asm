; ---------------
; inspired by Molten Core 1k
; ---------------

; --------------- Assembler directives
			.686P
			.XMM
			.model flat, stdcall
			OPTION CASEMAP:NONE

; --------------- Constants
XRES				equ	1280
YRES				equ	720
VK_ESCAPE           equ 1Bh
WS_POPUP            equ 80000000h
WS_VISIBLE          equ 10000000h
WS_MAXIMIZE         equ 1000000h
PM_REMOVE           equ 1h
PFD_DOUBLEBUFFER	equ	1
PFD_SUPPORT_OPENGL	equ	020h
GL_FRAGMENT_SHADER	equ	08B30h	

; --------------- Main Code
PUBLIC	main
PUBLIC	_ShaderPointer
PUBLIC	_PFD_MIDI
PUBLIC	_fragmentShader
PUBLIC	_b
PUBLIC	_API_glUseProgram
PUBLIC	_API_glCreateShaderProgramv
PUBLIC	_API_glGetUniformLocation
PUBLIC	_API_glUniform1f


EXTERN	_imp__ExitProcess@4:PROC
EXTERN	_imp__ChoosePixelFormat@8:PROC
EXTERN	_imp__SetPixelFormat@12:PROC
EXTERN	_imp__wglCreateContext@4:PROC
EXTERN	_imp__wglGetProcAddress@4:PROC
EXTERN	_imp__wglMakeCurrent@8:PROC
EXTERN	_imp__SwapBuffers@4:PROC
EXTERN	_imp__PeekMessageA@20:PROC
EXTERN	_imp__CreateWindowExA@48:PROC
EXTERN	_imp__GetAsyncKeyState@4:PROC
EXTERN	_imp__GetDC@4:PROC
EXTERN	_imp__ShowCursor@4:PROC
EXTERN	_imp__glRects@16:PROC
EXTERN	_imp__glColor3us@12:PROC


_DATA SEGMENT
time	dd  1			; location of time in the shader
puf		dd  ?			; pointer to b in the shader
pff		dd	?			; pointer to glsl prog
pfhdc	dd	?			; saved HDC pointer
fr		real4  0.1		; local increasing time
incfr	real4  0.1		; increment
_DATA ENDS


_TEXT	SEGMENT

; --------------- Program start
main	PROC

			; -----	CreateWindow
			;push	WS_POPUP or WS_VISIBLE or WS_MAXIMIZE	; dwStyle

			push	0										; lpParam
			push	0										; hInstance
			push	0										; hMenu
			push	0										; hWndParent
			push	720										; nHeight
			push	1280									; nWidth
			push	100										; y
			push	100										; x
			push	WS_VISIBLE								; dwStyle
			push	0										; lpWindowName
			push	0000c018H								; lpClassName
			push	0										; dwExStyle
			call	DWORD PTR _imp__CreateWindowExA@48		; create opengl window
			
			; -----	GetDC
			push	eax										; push window from eax
			call	DWORD PTR _imp__GetDC@4					; Get HDC
			xchg    eax, ebp								; move HDC to ebp
			mov		[pfhdc],ebp

			; -----	ChoosePixelFormat
			push	offset _PFD_MIDI						; push pixelformatdescriptor data address
			push	ebp										; push HDC from ebp
			call	DWORD PTR _imp__ChoosePixelFormat@8		; returns pixelformat to eax

			; ----- SetPixelFormat
			push	offset _PFD_MIDI						; push pixelformatdescriptor data address
			push	eax										; push pixelformat from eax
			push	ebp										; push HDC from ebp
			call	DWORD PTR _imp__SetPixelFormat@12		; set pixel format

			; ----- CreateContext
			push	ebp										; push HDC from ebp
			call	DWORD PTR _imp__wglCreateContext@4		; returns context to eax

			; ----- MakeCurrent
			push	eax										; push context from eax
			push	ebp										; push HDC from ebp
			call	DWORD PTR _imp__wglMakeCurrent@8

			; ----- Hide Cursor
			call	DWORD PTR _imp__ShowCursor@4			; hide cursor

			; -----	Create Shader Program
			push	offset _ShaderPointer					; push shader source code address
			push	1										; push number of source code strings (1)	
			push	GL_FRAGMENT_SHADER						; push shader type GL_FRAGMENT_SHADER
			push	offset _API_glCreateShaderProgramv		; push address of name for opengl process
			call	DWORD PTR _imp__wglGetProcAddress@4		; return actual address of opengl process to eax
			call	eax										; call glCreateShaderProgramv returns shader program ID to eax
			mov		[pff],eax								; save the id of the shader prog

			; -----	Use Shader Program
			push	eax										; push shader program ID from eax
			push	offset _API_glUseProgram				; push address of name for opengl process
			call	DWORD PTR _imp__wglGetProcAddress@4		; return actual address of opengl process to eax
			call	eax										; call glUseProgram

			;------ catch the uniform
			mov		eax,[pff]								; retrieve the id of shader program
			push	offset _b								; b uniform var in shader
			push	eax										; id of the program
			push	offset _API_glGetUniformLocation		; push address of name for opengl process
			call	DWORD PTR _imp__wglGetProcAddress@4		; return actual address of opengl process to eax
			call	eax										; call get proc address
			mov		[time],eax								; Store loc of var in time

			; ------ Link with the correct var
			push	offset _API_glUniform1f					; push address of name for opengl fct
			call	DWORD PTR _imp__wglGetProcAddress@4		; return actual address of opengl process to eax
			mov		[puf],eax								; save the address of fct
			call	eax										; call to get address of uniform

MainLoop:

			; ------ Incremente 0.1
			fld     fr										; stack first arg and 64-bit
			fld     incfr									; stack second arg and 64-bit
			fadd											; add
			fstp    fr										; store in fr

			; ------ Pass to the uniform 
			push	fr										; Value of the increment
			push	[time]									; Location in shader
			mov		eax,[puf]								; retrieve the pointer to glUniform1f
			call	eax										; then go ...
			
			; ----- Draw quad
			push	1										; push quad coords
			push	1										; push quad coords
			push	-1										; push quad coords
			push	-1										; push quad coords
			call	DWORD PTR _imp__glRects@16				; draw fullscreen quad

			; ----- Swap buffers
			;push	ebp										; push HDC from ebp
			push	[pfhdc]
			call	DWORD PTR _imp__SwapBuffers@4			; swap buffers

			; ----- Remove error message
			push	PM_REMOVE								; wRemoveMsg
			push	0										; wMsgFilterMax
			push	0										; wMsgFilterMin
			push	0										; hWnd
			push	0										; lpMsg
			call	DWORD PTR _imp__PeekMessageA@20			; dispatch incoming message

			; -----	Check for escape key press
			push	VK_ESCAPE								; push escape key
			call	DWORD PTR _imp__GetAsyncKeyState@4		; check for key press
			sahf											; store result in flags
            jns     MainLoop								; jump to main loop if flag not set

Exit:
			; -----	ExitProcess
			call	DWORD PTR _imp__ExitProcess@4

; --------------- Program end
main	ENDP
_TEXT	ENDS


; --------------- Data Section : F b=gl_Color.x/80;
; db "uniform float ub;"
CONST	SEGMENT
_fragmentShader		db	"#define V vec3"
					db  0AH
					db	"#define W vec2"
					db  0AH
					db	"#define F float"
					db  0AH
					db	"#define N normalize"
					db  0AH
					db "uniform float b;"
					db	"F U(F d1,F d2){return (d1<d2) ? d1 : d2;}"
					db	"mat3 C(V ro,V ta,F cr){V cw=N(ta-ro);V cp=V(sin(cr),cos(cr),0.);V cv=N(cross(N(cross(cw,cp)),cw));return mat3(N(cross(cw,cp)),cv,cw);}"
					db	"F rt(V p){p.x=mod(p.x,4)-2;p.z=mod(p.z,4)-2;return U(p.y+2.0,length(W(length(p.xz)-1,p.y))-0.5);}"
					db	"V gN(V p){F h=0.0001;return N(V(rt(p+V(h,0,0))-rt(p-V(h,0,0)),rt(p+V(0,h,0))-rt(p-V(0,h,0)),rt(p+V(0,0,h))-rt(p-V(0,0,h))));}"
					db	"F shaS(V ro,V rd,F mint,F maxt, F k){F t=mint;F res=1.0;"
					db	"for (int i=0;i<64;++i){F h=rt(ro+rd*t);if(h<0.001)return 0.0;res=min(res,k*h/t);t+=h;if(t>maxt)break;}"
					db	"return res;}"
					db	"V S(V pos,V nrm,vec4 lt){V tL=lt.xyz-pos;F tLL=length(tL);tL=N(tL);"
					db	"F co=0.1;F vis=shaS(pos,tL,0.0625,tLL,8.0);"
					db	"if (vis>0.0){co+=2.0*max(0.0,dot(nrm,tL))*1.0-pow(min(1.0,tLL/lt.w),2.0)*vis;}"
					db	"return V(co,co,co);}"
					db	"void main(){"
					db	"V ie=V(1280,720,0.0);"
					db	"W uv=(gl_FragCoord.xy/ie.xy)*2.0-1.0;"
					db	"uv.x *=ie.x/ie.y;"
					db	"V ip;"
					db	"F t=0.0;"
					db	"F td=0.0;"
					db	"V ro=V(-0.5+3.5*cos(0.1*b),3, 0.5 + 3.5*sin(0.1*b));"
					db	"V ta=V(0.0,0.0,0.0);"
					db	"mat3 ca=C(ro,ta,0.0);"
					db	"V dir=ca*N(V(uv,1.0));"
					db	"for(int i=0;i<64;i++) {ip=ro+dir*t;td=rt(ip);if(td<0.001) break; t+=td;}"
					db	"if(td<0.001){"
					db	"if(ip.y<-1)gl_FragColor=0.4+0.1*b*mod(floor(5.0*ip.z)+floor(5.0*ip.x),2.0)*vec4(1.0);"
					db	"gl_FragColor+=vec4(S(ip,gN(ip),vec4(cos(b*0.5)*3.0,5.0,sin(b*0.5)*3.0,9.9))*V(1.0,0.5,0.5)+S(ip,gN(ip),vec4(-cos(b*0.5)*3.0,5.0,-sin(b*0.5)*3.0,9.9))*V(0.5,0.5,1.0),1.0);"
					db	"}"
					db	"else gl_FragColor=vec4(0.9,0.9,1.0,1.0);"
					db	"}", 0
CONST	ENDS


CONST	SEGMENT
_PFD_MIDI					dd	0										; nSize / nVersion
							dd	PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER	; dwFlags
CONST	ENDS

CONST	SEGMENT
_ShaderPointer				dd	_fragmentShader
CONST	ENDS

CONST	SEGMENT
_API_glCreateShaderProgramv	db	"glCreateShaderProgramv", 0
CONST	ENDS

CONST	SEGMENT
_API_glUseProgram			db	"glUseProgram",0
CONST	ENDS

CONST	SEGMENT
_API_glGetUniformLocation	db "glGetUniformLocation",0
CONST	ENDS

CONST	SEGMENT
_API_glUniform1f			db "glUniform1f",0

CONST	SEGMENT
_b							db "b",0
CONST	ENDS


END
