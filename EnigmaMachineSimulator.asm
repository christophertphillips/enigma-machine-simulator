# Enigma Macine Simulator
# created by Christopher Phillips
# CS 3340
# Fall 2018
	
	.data

#-----------#	
# DATA      #
#-----------#

framebuffer:	.space 32768	# total size of bitmap canvas
r1_offset: 	.word 0		# initial offset for rotor 1
r2_offset: 	.word 0		# initial offset for rotor 2
r3_offset: 	.word 0		# initial offset for rotor 3

# wirings for individual rotors, reflector, and inverse rotors
r1:	.asciiz		"EKMFLGDQVZNTOWYHXUSPAIBRCJ"
r2:  	.asciiz		"AJDKSIRUXBLHWTMCQGZNPYFVOE"
r3:  	.asciiz		"BDFHJLCPRTXVZNYEIWGAKMUSQO"
ref: 	.asciiz 	"YRUHQSLDPXNGOKMIEBFZCWVJAT"
r1i: 	.asciiz 	"UWYGADFPVZBECKMTHXSLRINQOJ"
r2i: 	.asciiz 	"AJPCZWRLFBDKOTYUQGENHXMIVS"
r3i:	.asciiz 	"TAGBPCSDQEUFVNZHYIXJWLRKOM"

# letters for lampboard
row1:		.ascii "QWERTZUIO"
row2:		.ascii "ASDFGHJK"
row3:		.ascii "PYXCVBNML"

#-----------#	
# MACROS    #
#-----------#

# pushes the return address onto the stack
.macro pushReturnAddress
	addi $sp, $sp, -4
	sw $ra, 0($sp)
.end_macro
	
# pops the return address from the stack
.macro popReturnAddress	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
.end_macro

# pushes all s-registers onto the stack
.macro pushRegisters
	addi $sp, $sp, -32	
	sw $s0, 0($sp)	
	sw $s1, 4($sp)
	sw $s2, 8($sp)
	sw $s3, 12($sp)	
	sw $s4, 16($sp)
	sw $s5, 20($sp)
	sw $s6, 24($sp)
	sw $s7, 28($sp)
.end_macro

# pops all s-registers from the stack
.macro popRegisters
	lw $s0, 0($sp)	
	lw $s1, 4($sp)
	lw $s2, 8($sp)
	lw $s3, 12($sp)	
	lw $s4, 16($sp)
	lw $s5, 20($sp)
	lw $s6, 24($sp)
	lw $s7, 28($sp)
	addi $sp, $sp, 32
.end_macro

# convert a letter to an index (0-25)
.macro letterToIndex (%x)
    	subi %x, %x, 65
.end_macro

# convert an index (0-25) to a letter
.macro indexToLetter (%x)
    	addi %x, %x, 65
.end_macro

# calculate mod 26
.macro modulo(%x)
	li $t8, 26

loop:	slt $t9, %x, $zero
	beq $t9, $zero, mod

	add %x, %x, $t8
	j loop
	
mod:	div %x, $t8
    	mfhi %x
.end_macro


# configures rotors
.macro configureRotor(%x, %y)
	# increment rotor 1 by one character
	add %x, %x, %y
	modulo(%x)
	
	# draw rotors
	move $a0, $s1
	move $a1, $s2
	move $a2, $s3
	jal drawRotors
.end_macro

# stores rotor config values in $v0
.macro storeRotorConfigValues(%x)
	move $v0, $zero
	add %x, %x, $s1
	sll %x, %x, 8

	add %x, %x, $s2
	sll %x, %x, 8
	
	add %x, %x, $s3
.end_macro

# extracts rotor config values from $v0
.macro extractRotorConfigValues(%x, %y, %z)
	andi %z, $v0, 0xff
	srl $v0, $v0, 8
	
	andi %y, $v0, 0xff
	srl $v0, $v0, 8
	
	andi %x, $v0, 0xff
.end_macro


	.text

#-----------#	
# PROGRAM   #
#-----------#	

main:
	# load addresses used for input and output
	li $s4,	0xffff0000
	li $s5,	0xffff0004
	li $s6,	0xffff0008
	li $s7,	0xffff000c
	
	# ensure that output ready bit is set to 1
	li $t0, 1
	sw $t0,	0($s6)
	
	# load rotor offset values
	lw $s1, r1_offset
	lw $s2, r2_offset
	lw $s3, r3_offset
	
	# draw enigma
	jal drawEnigma
	
	# draw reflector
	li $a0, 0x51
	li $a1, 0x708090
	li $a2, 660
	li $a3, 512
	jal drawReflector
	
	# draw rotors
	move $a0, $s1
	move $a1, $s2
	move $a2, $s3
	jal drawRotors
	
	# draw lamps
	li $a0, 0x00000000
	jal drawLamps
	
	# wait for keyboard input; poll continuously while waiting
inLoop:	lw $t0, 0($s4)		# load check register
	andi  $t0, $t0, 0x0001  # mask all bits except least significant bit
	beq $t0, $zero, inLoop  # check if input is ready
	lw $s0, 0($s5)		# load user-inputted character
	
	# escape character (exit program)
	beq $s0, 0x1b, exit
	
	# ASCII characters less than 1 or greater than Z (invalid)
	blt $s0, 0x31, invalidChar
	bgt $s0, 0x5A, invalidChar
	
	# characters 1-6 (increment/decrement rotors)
	beq $s0, 0x32, incrementR1
	beq $s0, 0x31, decrementR1
	beq $s0, 0x34, incrementR2
	beq $s0, 0x33, decrementR2
	beq $s0, 0x36, incrementR3
	beq $s0, 0x35, decrementR3
	
	# characters 7-0 (invalid)
	blt $s0, 0x41, invalidChar
	
	
	
	# if a valid uppercase letter is entered, proceed
	j letter
	
invalidChar:
	j inLoop
	
incrementR1:
	# increment/decrement rotor
	li $t0, 1
	configureRotor($s1, $t0)
	
	# loop back to wait for user input
	j inLoop
	
decrementR1:
	# increment/decrement rotor
	li $t0, -1
	configureRotor($s1, $t0)
	
	# loop back to wait for user input
	j inLoop
	
incrementR2:
	# increment/decrement rotor
	li $t0, 1
	configureRotor($s2, $t0)
	
	# loop back to wait for user input
	j inLoop
	
decrementR2:
	# increment/decrement rotor
	li $t0, -1
	configureRotor($s2, $t0)
	
	# loop back to wait for user input
	j inLoop

incrementR3:
	# increment/decrement rotor
	li $t0, 1
	configureRotor($s3, $t0)
	
	# loop back to wait for user input
	j inLoop
	
decrementR3:
	# increment/decrement rotor
	li $t0, -1
	configureRotor($s3, $t0)
	
	# loop back to wait for user input
	j inLoop

letter:
	# move rotors
	move $a0, $s1
	move $a1, $s2
	move $a2, $s3
	jal moveRotors
	
	# extract rotor config values from moveRotors output
	extractRotorConfigValues($s1, $s2, $s3)
	
	# rotor 3, 1st traversal
	move $a0, $s0
	la $a1, r3
	move $a2, $s3
	jal traverseRotor
	
	# rotor 2, 1st traversal
	move $a0, $v0
	la $a1, r2
	move $a2, $s2
	jal traverseRotor
	
	# rotor 1, 1st traversal
	move $a0, $v0
	la $a1, r1
	move $a2, $s1
	jal traverseRotor
	
	# reflect
	move $a0, $v0
	la $a1, ref
	li $a2, 0
	jal traverseRotor
	
	# rotor 1, 2nd traversal
	move $a0, $v0
	la $a1, r1i
	move $a2, $s1
	jal traverseRotor
	
	# rotor 2, 2nd traversal
	move $a0, $v0
	la $a1, r2i
	move $a2, $s2
	jal traverseRotor
	
	# rotor 3, 2nd traversal
	move $a0, $v0
	la $a1, r3i
	move $a2, $s3
	jal traverseRotor
	
	# move encrypted letter to $s0
	move $s0, $v0
	
	# light up lamp corresponding to encrypted letter
	move $a0, $s0
	jal drawLamps
	
	# wait to print output to screen; poll continuously while waiting
outLoop:lw $t0, 0($s6)
	andi  $t0, $t0, 0x0001
	beq $t0, $zero, outLoop
	sw $s0, 0($s7)

	# Loop to top to read a new character
	j inLoop

	# exit program
exit:
	li $v0, 10
	syscall
	
#-----------#	
# FUNCTIONS #
#-----------#

# moves rotors as user inputs characters
# moveRotors($a0 = rotor1Offset, $a1 = rotor2Offset, $a2 = rotor3Offset)
moveRotors:
	# push s-registers onto the stack
	pushRegisters
	
	move $s1, $a0
	move $s2, $a1
	move $s3, $a2
		
	#  determine which rotors to move based on Enigma rotor notches
	bne $s3, 21, rloop1
	bne $s2, 4, rLoop2
	addi, $s1, $s1, 1
rLoop2:	addi, $s2, $s2, 1
	j rEnd
rloop1:	bne $s2, 4, rEnd
	addi, $s2, $s2, 1
	addi, $s1, $s1, 1
rEnd:	addi $s3, $s3, 1

	# take mod 26 of all rotors settings
	modulo($s1)
	modulo($s2)
	modulo($s3)
	
	# draw the rotors in the bitmap display
	pushReturnAddress
	move $a0, $s1
	move $a1, $s2
	move $a2, $s3
	jal drawRotors
	popReturnAddress
	
	# store rotor config values in $v0 for function output
	storeRotorConfigValues($v0)

	# pop s-registers from the stack
	popRegisters
	
	jr $ra



# traverses the signal across a rotor
# traverseRotor($a0 = inputLetter, $a1 = rotor, $a2 = rotorOffset)
traverseRotor:
	# push s-registers onto the stack
	pushRegisters

    	# get index of message character and apply offset
	letterToIndex($a0)
	add $a0, $a0, $a2
	modulo($a0)

	# get translated chracter via its address and convert to its character index
	add $t0, $a1, $a0
	lb $t0 , 0($t0)
	letterToIndex($t0)
	
	# apply offset to translated character index and obtain encoded letter
	sub $t0, $t0, $a2
	modulo($t0)
	indexToLetter($t0)
	
	# return translated character in $v0
	move $v0, $t0
	
	# pop s-registers from the stack
	popRegisters
	
	jr $ra



# draws the background and wires on engima machine
# drawEnigma()
drawEnigma:
	# push s-registers onto the stack
	pushRegisters
	
	# store frame buffer starting byte
	la $s0, framebuffer
	
	# set color for background (brown)
	li $a0, 0x663333
	
	# draw background
	move $a1, $s0		# offset
	li $a2, 4		# wrap offset
	addi $a3, $a1, 32768	# byte loop end condition
	pushReturnAddress
	jal drawLine
	popReturnAddress

	# set color for lines (black)
	move $a0, $zero	

	# draw wire 1
	addi $a1, $s0, 3732	# offset
	li $a2, 4		# wrap offset
	addi $a3, $a1, 352	# byte loop end condition
	pushReturnAddress
	jal drawLine
	popReturnAddress

	# draw wire 2
	addi $a1, $s0, 8340	# offset
	li $a2, 4		# wrap offset
	addi $a3, $a1, 240	# byte loop end condition
	pushReturnAddress
	jal drawLine
	popReturnAddress

	# draw wire 3
	addi $a1, $s0, 4592	# offset
	li $a2, 512		# wrap offset
	addi $a3, $a1, 32768	# byte loop end condition
	pushReturnAddress
	jal drawLine
	popReturnAddress
	
	# draw wire 4
	addi $a1, $s0, 9088	# offset
	li $a2, 512		# wrap offset
	addi $a3, $a1, 2560	# byte loop end condition
	pushReturnAddress
	jal drawLine
	popReturnAddress

	# draw wire 5
	addi $a1, $s0, 11636	# offset
	li $a2, 4		# wrap offset
	addi $a3, $a1, 28	# byte loop end condition
	pushReturnAddress
	jal drawLine
	popReturnAddress
	
	# pop s-registers from the stack
	popRegisters

	jr $ra



# draws a line
# drawReflector($a1 = color, $a2 = offset, $a2 = wrap offset, $a3 = ending byte)
drawLine:
	# push s-registers onto the stack
	pushRegisters
	
drawLineLoop:
	sw $a0, 0($a1)		# color pixel
	add $a1, $a1, $a2	# move to next word
	blt $a1, $a3, drawLineLoop	# if byte end condition not met, loop

	# pop s-registers from the stack
	popRegisters

	jr $ra
	


# draws a reflector
# drawReflector($a1 = color, $a2 = offset, $a3 = windowWidth)
drawReflector:
	# push s-registers onto the stack
	pushRegisters
	
	# set starting address
	la $s0, framebuffer
	
	# set color
	move $s1, $a1
				
	# set offset value
	move $s2, $a2
	
	# set width of window
	move $s3, $a3
	
	# set variable to aid drawing middle section
	li $s4, 0
	
	# draw letter
	add $s0, $s0, $s2
	sw $s1, 8($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)

	add $s0, $s0, $s3
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

reflectorMiddle:
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 20($s0)

	addi $s4, $s4, 1
	blt $s4, 18, reflectorMiddle
	
	add $s0, $s0, $s3
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
		
	add $s0, $s0, $s3
	sw $s1, 8($s0)
	sw $s1, 12($s0)

	# pop s-registers from the stack
	popRegisters

	jr $ra
    
    

# draws all three rotors (high-level)
# drawRotors($a0 = rotor1Config, $a1 = rotor2Config, $a2 = rotor3Config)
drawRotors:
	# push s-registers onto the stack
	pushRegisters

	# display notification in console
	move $s1, $a0
	move $s2, $a1
	move $s3, $a2
	indexToLetter($s1)
	indexToLetter($s2)
	indexToLetter($s3)
	
	# update rotor 1 drawing
	li $a0, 0x51
	li $a1, 0x708090
	li $a2, 700
	li $a3, 512
	pushReturnAddress
	jal drawRotor
	popReturnAddress
	
	move $a0, $s1
	li $a1, 0x00000000
	li $a2, 4804
	li $a3, 512
	pushReturnAddress
	jal drawLetter
	popReturnAddress
	
	# update rotor 2 drawing
	li $a0, 0x51
	li $a1, 0x708090
	li $a2, 752
	li $a3, 512
	pushReturnAddress
	jal drawRotor
	popReturnAddress
	
	move $a0, $s2
	li $a1, 0x00000000
	li $a2, 4856
	li $a3, 512
	pushReturnAddress
	jal drawLetter
	popReturnAddress
	
	# update rotor 3 drawing
	li $a0, 0x51
	li $a1, 0x708090
	li $a2, 804
	li $a3, 512
	pushReturnAddress
	jal drawRotor
	popReturnAddress
	
	move $a0, $s3
	li $a1, 0x00000000
	li $a2, 4908
	li $a3, 512
	pushReturnAddress
	jal drawLetter
	popReturnAddress
	
	# pop s-registers from the stack
	popRegisters

	jr $ra
    
    
    
# draws an indivdual rotor (low-level)
# drawRotor($a1 = color, $a2 = offset, $a3 = windowWidth)
drawRotor:
	# push s-registers onto the stack
	pushRegisters
	
	# set starting address
	la $s0, framebuffer
	
	# set color
	move $s1, $a1
				
	# set offset value
	move $s2, $a2
	
	# set width of window
	move $s3, $a3
	
	# set variable to aid drawing middle section
	li $s4, 0
	
	# draw bottom of rotor
	add $s0, $s0, $s2
	sw $s1, 8($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 20($s0)
	sw $s1, 24($s0)

	add $s0, $s0, $s3
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 20($s0)
	sw $s1, 24($s0)
	sw $s1, 28($s0)
	
	# draw middle of rotor
rotorMiddle:
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 20($s0)
	sw $s1, 24($s0)
	sw $s1, 28($s0)
	sw $s1, 32($s0)
	
	addi $s4, $s4, 1
	blt $s4, 18, rotorMiddle
	
	# draw bottom of rotor
	add $s0, $s0, $s3
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 20($s0)
	sw $s1, 24($s0)
	sw $s1, 28($s0)
		
	add $s0, $s0, $s3
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 20($s0)
	sw $s1, 24($s0)

	# pop s-registers from the stack
	popRegisters

	jr $ra
    


# draws all lamps (high-level)
# drawLamps($a0 = encrypted letter)
drawLamps:
	# push s-registers onto the stack
	pushRegisters
	move $s0, $a0
	li $s4, 0		# counter for iterating through all chars

initializeRow1:
	# values used to draw first row
	la $s1, row1		# address of row 1 chars
	li $s2, 12832		# offset for lamps
	li $s3, 13864		# offset for characters
	
	j drawRow
	
initializeRow2:
	# values used to draw second row
	la $s1, row2		# address of row 2 chars
	li $s2, 19000		# offset for lamps
	li $s3, 20032		# offset for characters
	
	j drawRow

initializeRow3:
	# values used to draw third row
	la $s1, row3		# address of row 3 chars
	li $s2, 25120		# offset for lamps
	li $s3, 26152		# offset for characters

	j drawRow

drawRow:
	# determine whether to turn on lamp or not
	lb $a0, 0($s1)			# get the letter to draw
	li $a1, 0x808080		# specify backround color (off)
	bne $a0, $s0, drawLampInRow	# determine if lamp is on (if not, skip ahead)
	li $a1, 0x00FFFF00		# if lamp is on, specify background color (on)
	
drawLampInRow:
	# draw the lamps
	move $a2, $s2		# specify offset for lamp
	li $a3, 512		# specify window width
	pushReturnAddress
	jal drawLamp		# call function to draw individual lamp
	popReturnAddress
	
	# draw the letters
	lb $a0, 0($s1)		# specify letter to draw
	li $a1, 0x00000000	# specify color of letter (black)
	move $a2, $s3		# specify offset for letter
	li $a3, 512		# specify window width
	pushReturnAddress
	jal drawLetter		# call function to draw individual letter
	popReturnAddress
	
	# increment and loop as necessary
	addi $s1, $s1, 1	# increment row letter pointer to next row letter
	addi $s2, $s2, 52	# increment offset for lamps
	addi $s3, $s3, 52	# increment offset for characters
	addi $s4, $s4, 1	# increment counter

	# determine how to loop back
	#row 1	
	blt $s4, 9, drawRow 		# keep drawing row 1 if count < 9

	#row 2
	beq $s4, 9, initializeRow2 	# if count = 9, initialize values for row 2
	blt $s4, 17, drawRow		# keep drawing row 2 if count < 17

	#row 3
	beq $s4, 17, initializeRow3 	# if count = 16, initialize values for row 3
	blt $s4, 26, drawRow 		# keep drawing row 3 if count < 26
	
	# pop s-registers from the stack
	popRegisters

	jr $ra
    
    
    
# draws an individual lamp (low-level)
# drawLamp($a1 = color, $a2 = offset, $a3 = windowWidth)
drawLamp:
	# push s-registers onto the stack
	pushRegisters
	
	# set starting address
	la $s0, framebuffer
	
	# set color
	move $s1, $a1
				
	# set offset value
	move $s2, $a2
	
	# set width of window
	move $s3, $a3
	
	# set variable to aid drawing middle section
	li $s4, 0
	
	# draw top of lamp
	add $s0, $s0, $s2
	sw $s1, 8($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 20($s0)
	sw $s1, 24($s0)

	add $s0, $s0, $s3
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 20($s0)
	sw $s1, 24($s0)
	sw $s1, 28($s0)
	
	# draw middle of lamp
lampMiddle:
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 20($s0)
	sw $s1, 24($s0)
	sw $s1, 28($s0)
	sw $s1, 32($s0)
	
	addi $s4, $s4, 1
	blt $s4, 5, lampMiddle
	
	# draw bottom of lamp
	add $s0, $s0, $s3
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 20($s0)
	sw $s1, 24($s0)
	sw $s1, 28($s0)
	
	add $s0, $s0, $s3
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 20($s0)
	sw $s1, 24($s0)

	# pop s-registers from the stack
	popRegisters

	jr $ra
    


# draws letters
# drawLetter($a0 = letter, $a1 = color, $a2 = offset, a3 = windowWidth)
drawLetter:
	# push s-registers onto the stack
	pushRegisters
	
	# set starting address
	la $s0, framebuffer
	
	# set color
	move $s1, $a1
				
	# set offset value
	move $s2, $a2
	
	# set width of window
	move $s3, $a3
	
	# draw desired number
	beq $a0, 0x41, letterA
	beq $a0, 0x42, letterB
	beq $a0, 0x43, letterC
	beq $a0, 0x44, letterD
	beq $a0, 0x45, letterE
	beq $a0, 0x46, letterF
	beq $a0, 0x47, letterG
	beq $a0, 0x48, letterH
	beq $a0, 0x49, letterI
	beq $a0, 0x4A, letterJ
	beq $a0, 0x4B, letterK
	beq $a0, 0x4C, letterL
	beq $a0, 0x4D, letterM
	beq $a0, 0x4E, letterN
	beq $a0, 0x4F, letterO
	beq $a0, 0x50, letterP
	beq $a0, 0x51, letterQ
	beq $a0, 0x52, letterR
	beq $a0, 0x53, letterS
	beq $a0, 0x54, letterT
	beq $a0, 0x55, letterU
	beq $a0, 0x56, letterV
	beq $a0, 0x57, letterW
	beq $a0, 0x58, letterX
	beq $a0, 0x59, letterY
	beq $a0, 0x5A, letterZ

letterA:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	j funcEnd
	
letterB:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)

	j funcEnd	

letterC:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	j funcEnd

letterD:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)

	j funcEnd	
	
letterE:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	j funcEnd

letterF:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)

	j funcEnd

letterG:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	j funcEnd

letterH:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	j funcEnd
			
letterI:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 8($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 8($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 8($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	j funcEnd
	
letterJ:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 16($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 16($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	j funcEnd
	
letterK:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 12($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 12($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	j funcEnd
	
letterL:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	j funcEnd

letterM:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 8($s0)
	sw $s1, 16($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	j funcEnd

letterN:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 8($s0)
	sw $s1, 16($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	j funcEnd

letterO:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	
	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	j funcEnd

letterP:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)

	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)

	j funcEnd

letterQ:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 12($s0)

	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 12($s0)

	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)

	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 16($s0)

	j funcEnd

letterR:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 12($s0)

	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	j funcEnd
	
letterS:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 16($s0)

	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	j funcEnd

letterT:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 8($s0)

	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 8($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 8($s0)
	
	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 8($s0)

	j funcEnd

letterU:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	j funcEnd

letterV:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 12($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 8($s0)

	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)

	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)

	j funcEnd

letterW:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 8($s0)
	sw $s1, 16($s0)

	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	j funcEnd

letterX:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 4($s0)
	sw $s1, 12($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 8($s0)

	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 4($s0)
	sw $s1, 12($s0)

	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	j funcEnd

letterY:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 16($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 4($s0)
	sw $s1, 12($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 8($s0)

	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 8($s0)

	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 8($s0)

	j funcEnd

letterZ:
	# draw row 1
	add $s0, $s0, $s2
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	# draw row 2
	add $s0, $s0, $s3
	sw $s1, 12($s0)
	
	# draw row 3
	add $s0, $s0, $s3
	sw $s1, 8($s0)
	
	# draw row 4
	add $s0, $s0, $s3
	sw $s1, 4($s0)

	# draw row 5
	add $s0, $s0, $s3
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)

	j funcEnd

funcEnd:
	# pop s-registers from the stack
	popRegisters

	jr $ra
