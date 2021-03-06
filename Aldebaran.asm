;------------------------------------
; ●Aldebaranプログラム
; 作成日時：2012.12.12		Y.Yamashiro
; 更新日時：2012.12.26		Y.Yamashiro
;
; ●更新履歴
; Ver.0.1	2012.12.12	Y.Yamashiro　INCLUDE,__CONFIGを作成
; Ver.1.0	2012.12.24	Y.Yamashiro　点灯確認、EEPROM記憶化確認
; Ver.1.5	2012.12.25	Y.Yamashiro　ソースコードを整形
; Ver.C83	2012.12.26	Y.Yamashiro　初出
;
;------------------------------------
	LIST	P=PIC12F675
	INCLUDE	"P12F675.INC"
	__CONFIG _CP_OFF & _CPD_OFF & _BODEN_ON & _MCLRE_ON & _WDT_ON & _PWRTE_ON & _INTRC_OSC_NOCLKOUT
;------------------------------------
	CBLOCK	0x20	
TIMER_TMP		; タイマ用カウンタ
COLD_START_TMP	; コールドスタート時ウェイト用カウンタ
DUTY_RED		; 赤色のデューティ
DUTY_GREEN		; 緑色のデューティ
DUTY_BLUE		; 青色のデューティ
DUTY_TMP		; 3パラレルPWM周期生成用
DUTY_RED_TMP	;
DUTY_GREEN_TMP	;
DUTY_BLUE_TMP	;
OUTPUT_TMP		;
CHECK_PSW_PAST	; プッシュスイッチ入力リングバッファ
CURRENT_PRESET	; 現在のプリセットNo.
TOTAL_PRESET	; 総プリセット数
SET_COLOR_TMP	; プリセットNo.->アドレス変換用
WRITE_EEPROM_DATA	; EEPROM書き込み用
ALDEBARAN_SETTING	; Aldebaran設定
	ENDC

LED_RED		EQU	GPIO1
LED_GREEN	EQU	GPIO2
LED_BLUE	EQU	GPIO0
PUSH_SW		EQU	GPIO4
MASTER_DUTY	EQU	D'19'

;------------------------------------
	; EEPROM DATA
	 ORG 02100H
	 ; プリセット記述(4bytesで一組,R,G,B,X)
	 ; 各色0〜20で設定可能。
	DE D'20',D'00',D'00',D'00' ; 赤
	DE D'15',D'06',D'08',D'00' ; 桃
	DE D'20',D'09',D'00',D'00' ; 橙
	DE D'20',D'16',D'00',D'00' ; 黄
	DE D'00',D'20',D'00',D'00' ; 緑
	DE D'00',D'00',D'20',D'00' ; 青
	DE D'10',D'00',D'10',D'00' ; 紫
	DE D'15',D'15',D'08',D'00' ; 白

	 ORG 0217DH
	 DE B'00000001' ; 7D:アルデバラン設定
	 DE D'00'    ; 7E:最終プリセットNo.
	 DE D'07'  ; 7F:総プリセット数(0to30)
;------------------------------------
	ORG	0
	NOP
	CLRWDT
	GOTO	INITIALIZE
	NOP
	NOP
	NOP
	NOP
	NOP
	GOTO	INTERRUPT
;------------------------------------
; 割り込み発生時＝異常事態と判断。
INTERRUPT
	BANKSEL	GPIO
	CLRF	GPIO
INTERRUPT_LP
	; 無限ループ→WDTリセット。
	GOTO	INTERRUPT_LP
;------------------------------------
; 初期設定
INITIALIZE	
; 電圧安定用のウェイト(約250ms)を入れる
	CALL	COLD_START
; プリスケーラはWDT用(1:128)
; 内蔵プルアップ(GPIO)を有効
	BANKSEL	OPTION_REG
	MOVLW	B'00101111'
	MOVWF	OPTION_REG
; 内蔵プルアップ(4,5)を有効
	BANKSEL	WPU
	MOVLW	B'00110000'
	MOVWF	WPU
; 内蔵コンパレータをOFF
	BANKSEL	CMCON
	MOVLW	B'00000111'
	MOVWF	CMCON
; 全てをデジタル入出力にする
	BANKSEL	ANSEL
	CLRF	ANSEL
; 入出力設定
	BANKSEL	TRISIO
	MOVLW	B'00111000'
	MOVWF	TRISIO
; ポートの状態を初期値に
	BANKSEL	GPIO
	CLRF	GPIO
; 変数初期化
;	CLRF	DUTY_RED
;	CLRF	DUTY_GREEN
;	CLRF	DUTY_BLUE
;	CLRF	CURRENT_PRESET
;	CLRF	FLAG_SAVE_LAST_PRESET
	MOVLW	0xFF
	MOVWF	CHECK_PSW_PAST
; 設定読み出し
	CALL	LOAD_SETTING
	CALL	SET_COLOR
; 設定終了
	GOTO	MAIN
;------------------------------------
; メイン処理
MAIN
	CLRWDT
	BANKSEL	GPIO
	CALL	CHECK_PSW
	CALL	MAIN_OUTPUT
	GOTO	MAIN
;------------------------------------
; 設定読み出し
LOAD_SETTING
	BANKSEL	GPIO
	MOVLW	0x7D
	CALL	READ_EEPROM
	MOVWF	ALDEBARAN_SETTING
	BTFSS	ALDEBARAN_SETTING,0
	GOTO	LOAD_SETTING_PRESET_NOSAVE
	GOTO	LOAD_SETTING_PRESET_SAVE
LOAD_SETTING_PRESET_NOSAVE
	CLRF	CURRENT_PRESET
	GOTO	LOAD_SETTING_PRESET_TOTAL
LOAD_SETTING_PRESET_SAVE
	MOVLW	0x7E
	CALL	READ_EEPROM
	MOVF	CURRENT_PRESET,W
	GOTO	LOAD_SETTING_PRESET_TOTAL
LOAD_SETTING_PRESET_TOTAL
	MOVLW	0x7F
	CALL	READ_EEPROM
	MOVWF	TOTAL_PRESET
	RETURN
;------------------------------------
; 色を設定
SET_COLOR
	BANKSEL	GPIO
	MOVF	CURRENT_PRESET,W
	MOVWF	SET_COLOR_TMP
	RLF		SET_COLOR_TMP,F
	RLF		SET_COLOR_TMP,W
	ANDLW	B'01111100'
	MOVWF	SET_COLOR_TMP
SET_COLOR_READ_RED
	MOVF	SET_COLOR_TMP,W
	ADDLW	B'00000000'
	CALL	READ_EEPROM
	MOVWF	DUTY_RED
SET_COLOR_READ_GREEN
	MOVF	SET_COLOR_TMP,W
	ADDLW	B'00000001'
	CALL	READ_EEPROM
	MOVWF	DUTY_GREEN
SET_COLOR_READ_BLUE
	MOVF	SET_COLOR_TMP,W
	ADDLW	B'00000010'
	CALL	READ_EEPROM
	MOVWF	DUTY_BLUE
; 将来の拡張用
;SET_COLOR_READ_KAKUCHO
;	MOVF	SET_COLOR_TMP,W
;	ADDLW	B'00000011'
;	CALL	READ_EEPROM
;	MOVWF	DUTY_BLUE
	RETURN
;------------------------------------
; EEPROM読み込み
READ_EEPROM
	BANKSEL	EEADR
	MOVWF	EEADR
	BSF		EECON1,RD
	MOVF	EEDATA,W
	BANKSEL	GPIO
	RETURN	
;------------------------------------
; EEPROM書き込み
WRITE_EEPROM
	BANKSEL	GPIO
	CLRF	GPIO
	BANKSEL	EEADR
	MOVWF	EEADR
	MOVF	WRITE_EEPROM_DATA,W
	MOVWF	EEDATA
WRITE_EEPROM_GO
	BSF		EECON1,WREN
	BCF		INTCON,GIE
	MOVLW	0x55
	MOVWF	EECON2
	MOVLW	0xAA
	MOVWF	EECON2
	BSF		EECON1,WR
WRITE_EEPROM_LP
	BTFSC	EECON1,WR
	GOTO	WRITE_EEPROM_LP
	BANKSEL	GPIO
	RETURN
;------------------------------------
; プッシュスイッチが押されているか？
CHECK_PSW
	BANKSEL	GPIO
CHECK_PSW_LOTATE
	RLF		CHECK_PSW_PAST,F
	BTFSC	GPIO,PUSH_SW
	BSF		CHECK_PSW_PAST,0
	BTFSS	GPIO,PUSH_SW
	BCF		CHECK_PSW_PAST,0
CHECK_PSW_JUDGE
	MOVF	CHECK_PSW_PAST,W
	XORLW	B'00000011'
	BTFSC	STATUS,Z
	GOTO	CHECK_PSW_YES
	RETURN
CHECK_PSW_YES
	INCF	CURRENT_PRESET,F
	MOVF	CURRENT_PRESET,W
	SUBWF	TOTAL_PRESET,W
	BTFSS	STATUS,C
	CLRF	CURRENT_PRESET
	CALL	SET_COLOR
; 最後に使ったプリセットを保存しておくか？
	BTFSS	ALDEBARAN_SETTING,0
	RETURN
	MOVF	CURRENT_PRESET,W
	MOVWF	WRITE_EEPROM_DATA
	MOVLW	0x7E
	CALL	WRITE_EEPROM
	RETURN
;------------------------------------
; LEDを点灯させる処理
MAIN_OUTPUT
	BANKSEL	GPIO
	MOVLW	MASTER_DUTY
	MOVWF	DUTY_TMP
	MOVF	DUTY_RED,W
	MOVWF	DUTY_RED_TMP
	MOVF	DUTY_GREEN,W
	MOVWF	DUTY_GREEN_TMP
	MOVF	DUTY_BLUE,W
	MOVWF	DUTY_BLUE_TMP
;--------------------
; ループ
MAIN_OUTPUT_LP
	CLRF	OUTPUT_TMP
;----------
; 赤色を出力
MAIN_OUTPUT_LP_RED
	MOVF	DUTY_RED_TMP,W
	BTFSC	STATUS,Z
	GOTO	MAIN_OUTPUT_LP_RED_END
	DECFSZ	DUTY_RED_TMP,F
	GOTO	MAIN_OUTPUT_LP_RED_ON
	GOTO	MAIN_OUTPUT_LP_RED_OFF
MAIN_OUTPUT_LP_RED_ON
	BSF		OUTPUT_TMP,LED_RED
	NOP
	NOP
	GOTO	MAIN_OUTPUT_LP_GREEN
MAIN_OUTPUT_LP_RED_OFF
	BCF		OUTPUT_TMP,LED_RED
	GOTO	MAIN_OUTPUT_LP_GREEN
MAIN_OUTPUT_LP_RED_END
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	GOTO	MAIN_OUTPUT_LP_GREEN	
;----------
; 緑色を出力
MAIN_OUTPUT_LP_GREEN
	MOVF	DUTY_GREEN_TMP,W
	BTFSC	STATUS,Z
	GOTO	MAIN_OUTPUT_LP_GREEN_END
	DECFSZ	DUTY_GREEN_TMP,F
	GOTO	MAIN_OUTPUT_LP_GREEN_ON
	GOTO	MAIN_OUTPUT_LP_GREEN_OFF
MAIN_OUTPUT_LP_GREEN_ON
	BSF		OUTPUT_TMP,LED_GREEN
	NOP
	NOP
	GOTO	MAIN_OUTPUT_LP_BLUE
MAIN_OUTPUT_LP_GREEN_OFF
	BCF		OUTPUT_TMP,LED_GREEN
	GOTO	MAIN_OUTPUT_LP_BLUE
MAIN_OUTPUT_LP_GREEN_END
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	GOTO	MAIN_OUTPUT_LP_BLUE
;----------
; 青色を出力
MAIN_OUTPUT_LP_BLUE
	MOVF	DUTY_BLUE_TMP,W
	BTFSC	STATUS,Z
	GOTO	MAIN_OUTPUT_LP_BLUE_END
	DECFSZ	DUTY_BLUE_TMP,F
	GOTO	MAIN_OUTPUT_LP_BLUE_ON
	GOTO	MAIN_OUTPUT_LP_BLUE_OFF
MAIN_OUTPUT_LP_BLUE_ON
	BSF		OUTPUT_TMP,LED_BLUE
	NOP
	NOP
	GOTO	MAIN_OUTPUT_LP_DEAD
MAIN_OUTPUT_LP_BLUE_OFF
	BCF		OUTPUT_TMP,LED_BLUE
	GOTO	MAIN_OUTPUT_LP_DEAD
MAIN_OUTPUT_LP_BLUE_END
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	GOTO	MAIN_OUTPUT_LP_DEAD
MAIN_OUTPUT_LP_DEAD
	MOVF	OUTPUT_TMP,W
	MOVWF	GPIO
	DECFSZ	DUTY_TMP,F
	GOTO	MAIN_OUTPUT_LP
	RETURN
;------------------------------------
; 簡易タイマー
TIMER
	BANKSEL	GPIO
	MOVWF	TIMER_TMP
	MOVF	TIMER_TMP,W
	BTFSC	STATUS,Z
	RETURN
TIMER_LP
	NOP
	DECFSZ	TIMER_TMP,F
	GOTO	TIMER_LP
	RETURN
;------------------------------------
; コールドスタート時に電圧安定まで待つ
COLD_START
	BANKSEL	GPIO
	MOVLW	0xFF
	MOVWF	COLD_START_TMP
COLD_START_LP
	MOVLW	0xFF
	CALL	TIMER
	DECFSZ	COLD_START_TMP,F
	GOTO	COLD_START_LP
	RETURN
;------------------------------------
	END
