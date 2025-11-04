#FLAGS = -O2 -Wall

all: clean ntt test_mult
# build ntt test program
ntt:
	gcc ntt.c main.c -o ntt

# test_mult target to build arithmetic comparison
test_mult:
	gcc barrett.c booth.c montgomery.c test_mult.c -o test_mult

# cleans artifacts
clean:
	rm -f *.o ntt test_mult
