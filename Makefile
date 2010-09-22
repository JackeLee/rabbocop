NAME = rabbocop

SRC_Hs = BitRepresenation.hs MyBits.hs BitEval.hs MTDf.hs Hash.hs
LINK_C = clib.c hash.c eval.c
LINK_H = clib.h

LINK_O = ${LINK_C:.c=.o}
SRC = ${SRC_Hs} ${LINK_C} ${LINK_H}

HC = ghc
HFLAGS = -O2 -Wall -fexcess-precision -fdicts-cheap # -prof -auto-all # -threaded # -funbox-strict-fields
CC = gcc
CFLAGS = -O2 -std=c99 -Wall -pedantic

all: Main

Main: Main.hs ${SRC} ${LINK_O}
	${HC} --make Main.hs ${LINK_O} ${HFLAGS}

Test: Test.hs ${SRC} ${LINK_O}
	${HC} --make Test.hs ${LINK_O} ${HFLAGS}

runtest: Test
	./Test # ${RUN_PARAMS}

${LINK_O}: ${LINK_C} ${LINK_H}

clean:
	@echo Cleaning
	rm -f *.o *.hi *.prof

dist:
	rm ${NAME}.tar.bz2
	tar cjvf ${NAME}.tar.bz2 *.hs *.c *.h .vimrc .ghci Makefile .git .gitignore

play: Main aei-1.1/roundrobin.py arimaa-client/gui.py
	cd aei-1.1; python roundrobin.py

aei-1.1/roundrobin.py:
	wget http://arimaa.janzert.com/aei/aei-1.1.zip --directory-prefix=aei-1.1
	unzip aei-1.1/aei-1.1.zip

arimaa-client/gui.py:
	bzr branch lp:arimaa-client

.PHONY: all clean dist runtest play
