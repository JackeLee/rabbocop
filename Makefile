NAME = rabbocop
BINs = IterativeAB MCTS MTDf Test Fight

SRC_Hs = \
	libs/AEI.hs \
	libs/AlphaBeta.hs \
	libs/Bits/BitRepresentation.hs \
	libs/Bits/MyBits.hs \
	libs/Eval/BitEval.hs \
	libs/Eval/MonteCarloEval.hs \
	libs/Hash/HaskellHash.hs \
	libs/Hash/IntMapHash.hs \
	libs/Hash/JudyHash.hs \
	libs/Hash.hs \
	libs/Helpers.hs \
	libs/Computation.hs \
	IterativeAB.hs \
	MCTS.hs \
	MTDf.hs \

LINK_C = libs/basic.c libs/Bits/bits.c
LINK_H = libs/clib.h
STATIC_EVAL_TABLES = data/staticeval_g.c data/staticeval_s.c

ifeq (${EVAL},fairy)
	LINK_C += libs/Eval/eval-fairy.c
else
	LINK_C += libs/Eval/eval.c
endif
LINK_O = ${LINK_C:.c=.o} libs/Eval/akimot-goalCheck.o

SRC = ${SRC_Hs} ${LINK_C} ${LINK_H}

# HC = ghc-core --no-syntax --no-cast --no-asm --
HC = ghc
HFLAGS = -O2 -Wall -fexcess-precision -fdicts-cheap -threaded -ilibs -lstdc++ -fspec-constr-count=16 -rtsopts
# HFLAGS += -fhpc -funbox-strict-fields
CC = gcc
CFLAGS = -O2 -std=c99 -Wall -pedantic
SHELL = /usr/bin/env bash


ENABLED_DEFINES = JUDY HASKELL_HASH VERBOSE WINDOW noHH noHeavyPlayout \
                  abHH NULL_MOVE canPass CORES noGoalCheck
HFLAGS += $(foreach v, $(ENABLED_DEFINES), $(if $($(v)), -D$(v)=$($(v))))

ifdef PROF
	HFLAGS += -prof -fforce-recomp -auto # -auto-all
endif

ifdef CORES
	GHCRTS += -N${CORES}
	export GHCRTS
endif


all: IterativeAB MCTS

IterativeAB MCTS MTDf: HFLAGS += -DENGINE

$(BINs): % : %.hs ${SRC} ${LINK_O}
	${HC} --make $@.hs ${LINK_O} ${HFLAGS}

runtest: Test
	time -p ./Test +RTS -A50m # ${RUN_PARAMS}

# Additional dependencies
Test: libs/Test/TestPositions.hs libs/Test/TestBitRepresentation.hs
libs/Eval/eval.o: ${STATIC_EVAL_TABLES}
${LINK_O}: ${LINK_C} ${LINK_H}

# Prepare part of static evaluation based on considering actual position
tools/BoardToCode: tools/BoardToCode.hs
	${HC} --make tools/BoardToCode.hs ${HFLAGS}

${STATIC_EVAL_TABLES}: data/staticeval.txt tools/BoardToCode
	./tools/BoardToCode data/staticeval.txt         > data/staticeval_g.c
	./tools/BoardToCode data/staticeval.txt REVERSE > data/staticeval_s.c

clean:
	@echo Cleaning
	rm -f *.prof *.tix
	rm -f {,libs/,libs/*/,tools/}{*.o,*.hi}
	rm -f ${STATIC_EVAL_TABLES}


playAB playMCTS playMatch: IterativeAB MCTS prepareEnv
	cp data/roundrobin-$@.cfg aei-1.1/roundrobin.cfg
	cd aei-1.1; python roundrobin.py

# Download and instal GUI and testing suite
prepareEnv: aei-1.1/roundrobin.py arimaa-client/gui.py

aei-1.1/roundrobin.py:
	wget http://arimaa.janzert.com/aei/aei-1.1.zip --directory-prefix=aei-1.1
	unzip aei-1.1/aei-1.1.zip

arimaa-client/gui.py:
	bzr branch lp:arimaa-client

.PHONY: all clean runtest play
