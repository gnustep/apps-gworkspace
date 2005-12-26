
INCLUDES="-I/usr/src/linux/include -I/usr/src/linux-2.4/include"

all:
	$(CC) -g -O2 -Wall -DMODULE -D__KERNEL__ $(INCLUDES) -c ./fswatcher.c

clean:
	rm fswatcher.o

#install:
#	(/bin/mknod /dev/fswatcher c 40 0; exit 0 )
#	chmod 0600 /dev/fswatcher

.NOEXPORT:

