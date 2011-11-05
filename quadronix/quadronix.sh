#!/bin/bash -i
# QUADRONIX
# Matvej Kotov <matvej.kotov@gmail.com>, 2011

declare -r -i MAP_HEIGHT=10
declare -r -i MAP_WIDTH=10
declare -r -a COLORS=( 
	"\e[1;31;41m"
	"\e[1;32;42m" 
	"\e[1;33;43m" 
	"\e[1;34;44m" 
)
declare -r -i CELL_WIDTH=4
declare -r -i CELL_HEIGHT=2
declare -i mapXPosition
declare -i mapYPosition
declare -r CLEAR_SCREEN_CODE="\e[0m\e[2J"
declare -r HIDE_CURSOR_CODE="\e[?25l"
declare -r EXIT_CODE='[xXqQ]'
declare -r NEW_GAME_CODE='[nN]'
declare -r ESC_CODE=$'\e'
declare -r REGULAR_CELL_CHAR=" "
declare -r SELECTED_CELL_CHAR="█"
declare -i -r TIME_LIMIT=60
declare -i -r TIMER_WIDTH=4
declare -i -r TIMER_HEIGHT=$((MAP_HEIGHT * CELL_HEIGHT))
declare -i timerXPosition
declare -i timerYPosition
declare -i -r FAIL_DELTA_TIME=5
declare -r ENOUGH_TIME_COLOR="\e[0;32;42m"
declare -r LOW_TIME_COLOR="\e[0;33;43m"
declare -r TINY_TIME_COLOR="\e[0;31;41m"
declare -r ANIMATION_DELAY="0.02"
declare -r FOOTER_COLOR="\e[1;37;46m"
declare -r FOOTER_MESSAGE="N -- начать новую игру, X -- выход"
declare -r SCORE_MESSAGE="Счёт: "
declare -r TOP_SCORE_MESSAGE="Лучший результат: "
declare -r HEADER_COLOR="\e[1;37;46m"
declare -r MESSAGE_COLOR="\e[1;31;47m"
declare -r TOP_SCORES_FILE_NAME='results.txt'
declare -i -r COUNT_TOP_SCORES=10
declare -i -r TOP_SCORES_WIDTH=30
declare -r YOU_WON_MESSAGE="Вы выиграли! Введите своё имя:"
declare -r TOP_SCORES_MESSAGE_COLOR="\e[1;31;46m"
declare -r TOP_SCORES_COLOR="\e[1;32;46m"
declare -r TOP_SCORES_MESSAGE="Лучшие результаты:"
declare -r TOP_SCORES_BAR_CHAR="\e[0;32;46m "
declare -i isInvalidated=0
declare -i mouseX
declare -i mouseY
declare -i mouseButton
declare -a map
declare -i firstAngleX
declare -i firstAngleY
declare -i score
declare -a topScores
declare -i time

function initMap() {
        local -i i
        local -i j
        for ((i = 0; i < MAP_HEIGHT; ++i)); do
                for ((j = 0; j < MAP_WIDTH; ++j)); do
                        map[i * MAP_WIDTH + j]=$((RANDOM % ${#COLORS[@]}))
                done
        done
}

function drawString() {
        echo -ne "\e[$1;$2f$3"
}

function drawCell() {
        local -i i
        local -i j
        for ((i = 0; i < CELL_HEIGHT; ++i)); do
                for ((j = 0; j < CELL_WIDTH; ++j)); do
			drawString $((mapYPosition + $1 * CELL_HEIGHT + i)) \
				$((mapXPosition + $2 * CELL_WIDTH + j)) \
				"${COLORS[${map[$(($1 * MAP_WIDTH + $2))]}]}$3"
                done
        done
}

function drawMap() {
        local -i i
        local -i j
        for ((i = 0; i < MAP_HEIGHT; ++i)); do
                for ((j = 0; j < MAP_WIDTH; ++j)); do
			drawCell $i $j "$REGULAR_CELL_CHAR"
                done
        done
}

function initGame() {
        echo -ne $CLEAR_SCREEN_CODE
        score=0
	initMap
	repaint
	firstAngleX=-1
	firstAngleY=-1
        time=TIME_LIMIT
	readTopScores
}

function updateRectangle() {
	local -i y1=$1
	local -i x1=$2
	local -i y2=$3
	local -i x2=$4
	local -i t
	if ((y2 < y1)); then
		t=y2
		y2=y1
		y1=t
	fi
	if ((x2 < x1)); then
		t=x2
		x2=x1
		x1=t
	fi
	local -r -i width=$((x2 - x1 + 1))
	local -r -i height=$((y2 - y1 + 1))
	local -i maxSize
	if ((width > height)); then
		maxSize=width	
	else
		maxSize=height
	fi

	local -i i
	local -i j
	for ((i = 0; i < 2 * maxSize; ++i)); do
		for ((j = 0; j <= i; ++j)); do
			if (( ( (i - j) < height) && (j < width) )); then
				drawCell $((y1 + i - j)) $((x1 + j)) "$SELECTED_CELL_CHAR"
				sleep $ANIMATION_DELAY
			fi
		done
	done
	for ((i = 0; i < 2 * maxSize; ++i)); do
		for ((j = 0; j <= i; ++j)); do
			if (( ( (i - j) < height) && (j < width) )); then
				map[ (y1 + i - j) * MAP_WIDTH + x1 + j]=$((RANDOM % ${#COLORS[@]}))
				drawCell $((y1 + i - j)) $((x1 + j)) "$REGULAR_CELL_CHAR"
				sleep $ANIMATION_DELAY
			fi
		done
	done
	((score += width * height))
	((time += (2 * width * height * TIME_LIMIT) / (MAP_WIDTH * MAP_HEIGHT) ))
	if ((time > TIME_LIMIT)); then 
		time=TIME_LIMIT
	fi
}

function rectangleSelected() {
	if (( $1 == $3 || $2 == $4 )); then
		return 1
	fi
	local -i -r color1=${map[$1 * MAP_WIDTH + $2]}
	local -i -r color2=${map[$3 * MAP_WIDTH + $2]}
	local -i -r color3=${map[$1 * MAP_WIDTH + $4]}
	local -i -r color4=${map[$3 * MAP_WIDTH + $4]}
	local -i -r areEqual=$(( (color1 == color2) && (color2 == color3) &&
		(color3 == color4) && (color4 == color1) ))
	return $((!areEqual))
}

function mouseClicked() {
	if (( mouseX >= mapXPosition && mouseX < mapXPosition + MAP_WIDTH * CELL_WIDTH && \
		mouseY >= mapYPosition && mouseY < mapYPosition + MAP_HEIGHT * CELL_HEIGHT)); then
		local -i x=$(((mouseX - mapXPosition) / CELL_WIDTH))
		local -i y=$(((mouseY - mapYPosition) / CELL_HEIGHT))
		if ((firstAngleX == -1 && firstAngleY == -1)); then
			firstAngleX=x
			firstAngleY=y
			drawCell $y $x "$SELECTED_CELL_CHAR"
		elif ((x == firstAngleX && y == firstAngleY)); then
			drawCell $y $x "$REGULAR_CELL_CHAR"
			firstAngleX=-1
			firstAngleY=-1
		elif rectangleSelected $firstAngleY $firstAngleX $y $x; then
			updateRectangle $firstAngleY $firstAngleX $y $x
			firstAngleX=-1
			firstAngleY=-1
		else 
			drawCell $firstAngleY $firstAngleX "$REGULAR_CELL_CHAR"
			firstAngleX=-1
			firstAngleY=-1
			if ((time >= FAIL_DELTA_TIME)); then
				((time -= FAIL_DELTA_TIME))
			else
				time=0
			fi
		fi
	fi
}

readMouse() {
	local mouseButtonData
	local mouseXData
	local mouseYData
	read -r -s -n 1 -t 1 mouseButtonData 
	read -r -s -n 1 -t 1 mouseXData
	read -r -s -n 1 -t 1 mouseYData
	local -i mouseButtonCode
	local -i mouseXCode
	local -i mouseYCode
	LC_ALL=C printf -v mouseButtonCode '%d' "'$mouseButtonData"
	LC_ALL=C printf -v mouseXCode '%d' "'$mouseXData"
	LC_ALL=C printf -v mouseYCode '%d' "'$mouseYData"
    	((mouseButton = mouseButtonCode + 1))
	((mouseX = mouseXCode - 32))
	((mouseY = mouseYCode - 32))
}

function runGame() {
        local key
	local -i time1=`date '+%s'`
	local -i time2
	local -i delta
	echo -ne "\e[?9h"	
        while true; do
		if ((isInvalidated)); then
			repaint
		fi
		drawTimer
		drawHeader
		key=""
		read -r -s -n 1 -t 0.1 key
		case "$key" in
			$NEW_GAME_CODE)
				continue 2;;
			$EXIT_CODE) 
				break 2;;
			$ESC_CODE) 
				read -r -s -t 1 -n 1 key
				if [[ "$key" == '[' ]]; then
					read -r -s -t 1 -n 1 key
					if [[ "$key" == "M" ]]; then
				 		readMouse
						if ((mouseX != 0 && mouseY != 0)); then
							mouseClicked
						fi
					fi
				fi;;
		esac
		time2=`date '+%s'`
		delta=$((time2 - time1))
		if ((delta != 0)); then
			((time -= delta + score / 100 ))
			time1=time2
		fi
		if ((time <= 0)); then
			break
		fi
        done
	echo -ne "\e[?9l"
}

function drawHeader() {
	if ((${#topScores[@]} != 0)); then
		drawString 1 2 "$HEADER_COLOR\e[2K${SCORE_MESSAGE}$score\t\t\
${TOP_SCORE_MESSAGE}${topScores[1]}"
	else 
		drawString 1 2 "$HEADER_COLOR\e[2K${SCORE_MESSAGE}$score"
	fi
}

function drawFooter() {
	drawString $LINES 2 "$FOOTER_COLOR\e[2K$FOOTER_MESSAGE"
}

function drawTimer() {
	local color
	if (( time > (TIME_LIMIT / 2) )); then
		color=$ENOUGH_TIME_COLOR
	elif (( time > (TIME_LIMIT / 4) )); then
		color=$LOW_TIME_COLOR
	else
		color=$TINY_TIME_COLOR
	fi
	local -i i
	local -i j
	for ((i = 0; i < (time * TIMER_HEIGHT) / TIME_LIMIT; ++i)); do
		for ((j = 0; j < TIMER_WIDTH; ++j)); do
			drawString $((timerYPosition + TIMER_HEIGHT - 1 - i)) \
				$((timerXPosition + j)) "$color "
		done
	done
	for ((i = (time * TIMER_HEIGHT) / TIME_LIMIT; i < TIMER_HEIGHT; ++i)); do
		for ((j = 0; j < TIMER_WIDTH; ++j)); do
			drawString $((timerYPosition + TIMER_HEIGHT - 1 - i)) \
				$((timerXPosition + j)) "\e[0m "
		done
	done
}

function drawMessage() {
	drawString $((LINES - 1)) 2 "$MESSAGE_COLOR\e[2K$1"
}

function drawInput() {
	drawString $((LINES - 1)) 2 "$MESSAGE_COLOR\e[2K$1 "
	stty echo
	REPLY=""
	read
	stty -echo
}

function clearMessage() {
	drawString $((LINES - 1)) 1 "$BACKGROUND\e[2K"
}

function readTopScores() {
	topScores=( )
	if [[ -r "$TOP_SCORES_FILE_NAME" ]]; then
		readarray -t topScores < "$TOP_SCORES_FILE_NAME"
	fi
}

function writeTopScores() {
	(IFS=$'\n'; echo "${topScores[*]}" > "$TOP_SCORES_FILE_NAME")
}

function playerWon() {
	if (( score == 0 || time > 0 )); then
		return 1
	fi
	if (( ${#topScores[@]} < COUNT_TOP_SCORES * 2)); then
		return 0
	fi
	local -i i
	for ((i = 0; i < COUNT_TOP_SCORES; ++i)); do
		if (( score > ${topScores[2 * i + 1]} )); then
			return 0
		fi
	done 
	return 1
}

function addPlayerToTopScores() {
	local -r name="$1"
	local -i i
	local -i pos
	for ((i = 0; i < ${#topScores[@]} / 2; ++i)); do
		if (( score > ${topScores[2 * i + 1]} )); then
			break
		fi
	done
	pos=i
	local -i last=$((COUNT_TOP_SCORES - 1))
	if (( (${#topScores[@]} / 2) < last)); then
		last=$((${#topScores[@]} / 2))
	fi
	for ((i = last; i > pos; --i)); do
		topScores[2 * i]=${topScores[2 * i - 2]}
		topScores[2 * i + 1]=${topScores[2 * i - 1]}
	done
	topScores[2 * pos]="$name"
	topScores[2 * pos + 1]=$score
}

function drawTopScores() {
	local -i i
	local -i j
	for ((j = 0; j < COUNT_TOP_SCORES + 1; ++j)); do
		for ((i = 0; i < TOP_SCORES_WIDTH; ++i)); do
			drawString $((LINES / 2 - COUNT_TOP_SCORES / 2 + j)) \
				$((COLUMNS / 2 - TOP_SCORES_WIDTH / 2 + i)) \
				"$TOP_SCORES_BAR_CHAR"
		done
	done
	echo -ne $TOP_SCORES_MESSAGE_COLOR
	drawString $((LINES / 2 - COUNT_TOP_SCORES / 2)) \
		$((COLUMNS / 2 - ${#TOP_SCORES_MESSAGE} / 2)) \
		"$TOP_SCORES_MESSAGE"
	echo -ne $TOP_SCORES_COLOR
	for ((i = 0; i < COUNT_TOP_SCORES; ++i)); do
		drawString $((LINES / 2 - COUNT_TOP_SCORES / 2 + i + 1)) \
			$((COLUMNS / 2 - TOP_SCORES_WIDTH / 2 + 1)) \
			"${topScores[2 * i + 1]}"
		drawString $((LINES / 2 - COUNT_TOP_SCORES / 2 + i + 1)) \
			$((COLUMNS / 2 - TOP_SCORES_WIDTH / 2 + 9)) \
			"${topScores[2 * i]:0:TOP_SCORES_WIDTH - 10}"
	done
}

function finishGame() {
	if playerWon; then
		drawInput "$YOU_WON_MESSAGE"
		clearMessage
		drawFooter
		addPlayerToTopScores "$REPLY"
		writeTopScores
	fi
	drawTopScores
	local -l key
	while true; do
		read -s -n 1 key
		case "$key" in
			$EXIT_CODE)	break 2;;
			$NEW_GAME_CODE)	break;;
		esac
	done
}

function repaint() {
	LINES=`tput lines`
	COLUMNS=`tput cols`
	mapXPosition=$(((COLUMNS - CELL_WIDTH * MAP_WIDTH) / 2 + 1))
	mapYPosition=$(((LINES - CELL_HEIGHT * MAP_HEIGHT) / 2 + 1))
	timerXPosition=$((MAP_WIDTH * CELL_WIDTH + mapXPosition + 6))
	timerYPosition=$((mapYPosition))
	echo -ne "\e[0m"
	clear
	drawMap
	drawHeader
	drawFooter
	((isInvalidated = 0))
}

function initApplication() {
	stty -echo
	echo -ne $HIDE_CURSOR_CODE
	trap finishApplication EXIT
	trap "((isInvalidated = 1))" SIGWINCH
}

function runApplication() {
	while true; do
		initGame
		runGame
		finishGame
	done
}

function finishApplication() {
	trap EXIT
	reset	
}

initApplication
runApplication
finishApplication

