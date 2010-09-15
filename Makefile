NAME = rabbocop

SRC_Hs = BitRepresenation.hs MyBits.hs BitEval.hs MTDf.hs
LINK_C = clib.c hash.c
LINK_H = clib.h

LINK_O = ${LINK_C:.c=.o}
SRC = ${SRC_Hs} ${LINK_C} ${LINK_H}
OBJ = ${SRC_Hs:.hs=.hi} ${SRC_Hs:.hs=.o} Main.hi Main.o Test.hi Test.o ${LINK_O}

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
	@rm -f *.o *.hi # ${OBJ}

dist:
	rm ${NAME}.tar.bz2
	tar cjvf ${NAME}.tar.bz2 *.hs *.c *.h .vimrc .ghci Makefile .git .gitignore

.PHONY: all clean dist runtest
